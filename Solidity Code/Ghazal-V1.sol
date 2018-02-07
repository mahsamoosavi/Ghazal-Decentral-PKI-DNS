pragma solidity ^0.4.0;
contract Ghazal{

    bytes32 public DomainName;
    uint Registration_Fee = 1 ether; //The amount that a user has to pay in order to register a domain.
    mapping (bytes32 => Domain) public Domains;
    Domain public CurrentDomain;
    enum States {Unregistered,Registered,Expired,TLSKeyEntered,DNSHashEntered,TLSKey_And_DNSHashEntered}
    mapping(address => uint) refunds;


//************************************************************************************************************************//
   struct Domain{ //Domain struct represents each domain which posses DomainName, RegistrantName, Validity

        bytes32 DomainName;
        address DomainOwner;
        uint RegistrationTime;
        bytes32[] TLSKeys; // Dynamic array of bytes32 to store multiple certificates for a single domain.
        bytes32 DNSHash;
        bool isValue; //IF the Domain struct is initiallized for a key (_DomianName), this value is set to true.
        States state; //Keeps the state of the domain.

    }
//************************************************************************************************************************//
    //Cost function modifier allows a function to get executed if the msg.value is equal or greater than the Registration_Fee (Which we defined as 1 ether)
    modifier Costs() {
        require(msg.value >= Registration_Fee);
        _;

    }
//************************************************************************************************************************//
    //OnlyOwner function modifier allows a function to get executed if the entity that is invoking a function is the same as domain owner.
    modifier OnlyOwner(bytes32 _DomainName) {
        require (Domains[_DomainName].DomainOwner == msg.sender);
        _;
    }
//************************************************************************************************************************//
    //AtStage function modifier allows a function to get executed if the domain is in desired states.
    modifier AtStage(bytes32 _DomainName, States stage_1, States stage_2) {
        require (Domains[_DomainName].state == stage_1  || Domains[_DomainName].state == stage_2);
        _;
    }
//************************************************************************************************************************//
    //Not_AtStage function modifier allows a function to get executed if the domain is not in the specified states.
    modifier Not_AtStage(bytes32 _DomainName, States stage_1, States stage_2) {
        require (Domains[_DomainName].state != stage_1 && Domains[_DomainName].state != stage_2);
        _;
    }
//************************************************************************************************************************//
    //CheckDomainExpiry function modifier checks if the domain name is expired or not.
    modifier CheckDomainExpiry (bytes32 _DomainName) {
        if (Domains[_DomainName].isValue == false) {Domains[_DomainName].state=States.Unregistered;} //IF the Domain struct is initiallized for the key (_DomianName), it updates the domain's state to Unregistered.
        if (now >= Domains[_DomainName].RegistrationTime + 10 minutes) // each domain expires in 5 years.
        {
            Domains[_DomainName].state = States.Expired;}
        _;
    }
//************************************************************************************************************************//
    //A user can Register a Domain using the Register function.
    function Register (string _DomainName) payable public CheckDomainExpiry (stringToBytes32(_DomainName)) Costs() AtStage(stringToBytes32(_DomainName),States.Unregistered,States.Expired)
    {
        DomainName = stringToBytes32(_DomainName);
        CurrentDomain.DomainName = DomainName;
        CurrentDomain.DomainOwner = msg.sender;
        CurrentDomain.RegistrationTime = now;
        CurrentDomain.isValue = true;
        delete CurrentDomain.TLSKeys;
        CurrentDomain.state = States.Registered;
        Domains[DomainName] = CurrentDomain;
        refunds[block.coinbase] += Registration_Fee;
        uint refund = refunds[block.coinbase];
        refunds[block.coinbase] = 0;
        block.coinbase.transfer(refund);
    }
//************************************************************************************************************************//
    //Domain Owner can renew the domain at least 1 year before the domain is expired. Note that Domian validation period is 5 years.
    function Renew (string _DomainName) public payable CheckDomainExpiry (stringToBytes32(_DomainName)) Costs() OnlyOwner(stringToBytes32(_DomainName))
    {
        DomainName = stringToBytes32(_DomainName);
        require (now >= Domains[DomainName].RegistrationTime + 10 minutes);
        Domains[DomainName].RegistrationTime = now;
        refunds[block.coinbase] += Registration_Fee;
        uint refund = refunds[block.coinbase];
        refunds[block.coinbase] = 0;
        block.coinbase.transfer(refund);
    }
//************************************************************************************************************************//
    //A user can add unlimited number of certificates to his Domain using the Add_TLSKey function.
    function Add_TLSKey (string _DomainName,bytes32 _TLSKey)  public CheckDomainExpiry (stringToBytes32(_DomainName)) Not_AtStage(stringToBytes32(_DomainName),States.Unregistered,States.Expired) OnlyOwner(stringToBytes32(_DomainName))
    {
        DomainName = stringToBytes32(_DomainName);
        Domains[DomainName].TLSKeys.push(_TLSKey);
        if (Domains[DomainName].state == States.Registered) {Domains[DomainName].state = States.TLSKeyEntered;}//if the domain is in the registered state, it transitions to TLSKeyEntered.
        if (Domains[DomainName].state == States.DNSHashEntered) {Domains[DomainName].state = States.TLSKey_And_DNSHashEntered;}//if the domain contains the DNSHash, it transitions to TLSKey_And_DNSHashEntered.
        //if Domain's state is TLSKeyEntered OR TLSKey_And_DNSHashEntered, its state will not  change.

    }

//************************************************************************************************************************//
    //A user can add the hash of it DNS to his Domain using the Add_DNSHash function.
    function Add_DNSHash (string _DomainName,bytes32 _DNSHash)  public CheckDomainExpiry (stringToBytes32(_DomainName)) Not_AtStage(stringToBytes32(_DomainName),States.Unregistered,States.Expired) OnlyOwner(stringToBytes32(_DomainName))
    {
        DomainName = stringToBytes32(_DomainName);
        Domains[DomainName].DNSHash = _DNSHash;
        if (Domains[DomainName].state == States.Registered) {Domains[DomainName].state = States.DNSHashEntered;}//if the domain is in the registered state, it transitions to DNSHashEntered.
        if (Domains[DomainName].state == States.TLSKeyEntered) {Domains[DomainName].state = States.TLSKey_And_DNSHashEntered;}//if the domain contains the TLSKey, it transitions to TLSKey_And_DNSHashEntered.
        //if Domain's state is DNSHashEntered OR TLSKey_And_DNSHashEntered, its state will not  change.
    }
//************************************************************************************************************************//
    //A user can add certificates and DNSHash to his domain usign the Add_TLSKey_AND_DNSHash function.
    function Add_TLSKey_AND_DNSHash (string _DomainName,bytes32 _TLSKey, bytes32 _DNSHash)  public CheckDomainExpiry (stringToBytes32(_DomainName)) Not_AtStage(stringToBytes32(_DomainName),States.Unregistered,States.Expired) OnlyOwner(stringToBytes32(_DomainName))
    {
        DomainName = stringToBytes32(_DomainName);
        Domains[DomainName].DNSHash = _DNSHash;
        Domains[DomainName].TLSKeys.push(_TLSKey);
        Domains[DomainName].state = States.TLSKey_And_DNSHashEntered;

    }
//************************************************************************************************************************//
    //DomainOwner can transfer the Domain to any address he wants if and only if the Domain is not Unregistered and Expired.
    //1- DomainOwner can only transfer the domain name. To do so, he wipes the associated DNS Hash and TLS Key by supplying them with zero.
    //2-  DomainOwner can transfer the domain name in addition to the corresponding certificate and and/or DNS Hash. This is done by supplying these arguments with their previous values.
    //Note that the Domain State and Registration_Time will not change and remain the same .
    function Transfer_Domain (string _DomainName, address _Reciever,bytes32 _TLSKey, bytes32 _DNSHash) public CheckDomainExpiry (stringToBytes32(_DomainName)) Not_AtStage(stringToBytes32(_DomainName),States.Unregistered,States.Expired) OnlyOwner(stringToBytes32(_DomainName))
    {
        DomainName = stringToBytes32(_DomainName);
        Domains[DomainName].DomainOwner = _Reciever;
        if (_TLSKey == 0 && _DNSHash != 0) { Wipe_TLSKeys(DomainName); }
        if (_DNSHash == 0 && _TLSKey != 0 ) { Wipe_DNSHash(DomainName); }
        if (_DNSHash == 0 && _TLSKey == 0 ) { Wipe_TLSKeys_and_DNSHash(DomainName); }

    }
//************************************************************************************************************************//
    function Wipe_TLSKeys (bytes32 _DomainName) internal{
      delete Domains[_DomainName].TLSKeys;
      if (Domains[_DomainName].state == States.TLSKey_And_DNSHashEntered) {Domains[_DomainName].state = States.DNSHashEntered;}
    }

//************************************************************************************************************************//

    function Wipe_DNSHash (bytes32 _DomainName) internal{
      
        delete Domains[_DomainName].DNSHash;
      if (Domains[_DomainName].state == States.TLSKey_And_DNSHashEntered) {Domains[_DomainName].state = States.TLSKeyEntered;}
    }
//************************************************************************************************************************//
    function Wipe_TLSKeys_and_DNSHash (bytes32 _DomainName) internal{
      delete Domains[_DomainName].DNSHash;
      delete Domains[_DomainName].TLSKeys;
      Domains[_DomainName].state = States.Registered;
    }

//************************************************************************************************************************//
    //A user can revoke any certificates that belong to his domain using the Revoke_TLSkey function.
    function Revoke_TLSkey (string _DomainName, bytes32 _TLSKey) public CheckDomainExpiry (stringToBytes32(_DomainName)) Not_AtStage(stringToBytes32(_DomainName),States.Unregistered,States.Expired) OnlyOwner(stringToBytes32(_DomainName))
    {
      DomainName = stringToBytes32(_DomainName);
      //var DomainVar = Domains[DomainName];
      for (uint j=0; j<Domains[DomainName].TLSKeys.length;j++)
      {
        if (Domains[DomainName].TLSKeys[j] == _TLSKey){ delete Domains[DomainName].TLSKeys[j]; }
      }

    }

//************************************************************************************************************************//
    //stringToBytes32 is an internal function which converts bytes to string whenever called.
    function stringToBytes32(string memory source) internal pure returns (bytes32 result)
    {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
        return 0x0;
    }

    assembly {
        result := mload(add(source, 32))

    }

}

//************************************************************************************************************************//
    //Get_TLSKey is a constant function which returns the TLSKeys a domain name.
    function Get_TLSKey (string _DomainName) public view returns (bytes32[])
    {
      var DomainVar = Domains[stringToBytes32(_DomainName)];
      return DomainVar.TLSKeys;
    }
//************************************************************************************************************************//

}
