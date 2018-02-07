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
        //AuctionStates AuctionState;

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
        if (now >= Domains[_DomainName].RegistrationTime + 10 minutes) {Domains[_DomainName].state = States.Expired;} // each domain expires in 5 years.
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
//********************************************AUCTION SMART CONTRACT*************************************

contract Auction is Ghazal{

    enum Stages {Opened, Locked, Ended} //Opened: biddingTime, Settlement has not yet started.
                                        //Locked: biddingTime's over, Settlement's satrted and not finished yet.
                                        //Ended: biddingTime and Settlement are both over, which means the auction's ended.

    //There is an struct called "AuctionStruct" for each auction that will be invoked.
    struct AuctionStruct
    {
        uint CreationTime;      //The time auction was opened.
        address Owner;          //The address who opened the auction.
        uint highestBid;        //The highestBid that has been bid in the auction.
        address highestBidder;  //The address who bid the highest bid in the auction.
        address Winner;         //The address of the winner of this auction.
        Stages stage;           //variable stage is frm type Stages which keeps the stage of the auction.
        mapping(address => uint) pendingReturns;    //To return the bids that were overbid.
        mapping(address => uint) deposits;          //To return the deposits they've made.
        mapping(address => bool) already_bid;       //Once an address bids in the auction this variable will be set to true
        bool AuctionisValue;                                            //So the next time they bid in the same auction, they dont have to deposit again.
      }

    //AuctionLists mappings store auction structs, the keys are the DomainNames that are auctioned and the values are the auction structs.
    mapping (bytes32 => AuctionStruct) public AuctionLists;

    uint Deposit_Fee = 1 ether;
    uint public biddingTime = 3 days;   //Bidding period. Users can ONLY bid in this period.
    uint public Settlement = 1 days;    //Settlement period. Users can Withdraw their pendingReturns (bids that were overbid)
                                        //Plus their deposits. Note that the Winner cannot withdraw his deposit until he claims the Domain
                                        //and pays to the DomainOwner.
    uint min_Price = 1 ether;

//********************************************************************************************************************
   //Checks if the person's bid is higher than the minimum price.
   modifier CheckMinPrice (bytes32 _DomainName) {
        require(msg.value >= min_Price);

        _;
    }
//********************************************************************************************************************
    //Checks if the auction's state.
    modifier CheckAuctionExpiray (bytes32 _DomainName) {
        if (now >= AuctionLists[_DomainName].CreationTime + biddingTime + Settlement) {AuctionLists[_DomainName].stage = Stages.Ended;}
        if (now >= AuctionLists[_DomainName].CreationTime + biddingTime && now <= AuctionLists[_DomainName].CreationTime + biddingTime + Settlement) {AuctionLists[_DomainName].stage = Stages.Locked;} // each domain expires in 5 years.
         _;
    }
//********************************************************************************************************************
    //To start and auction on a DomainName.
    function OpenAuction(bytes32 _DomainName, address _DomainOwner) public
    {
        //1-Only the DomainOwner call open auction on a domain.
        //2-There should not be any other auction currently open on the same domain.
        //3-Domain expiration should be greater than the whole period of auction (biddingTime+Settlement)
        require (Domains[_DomainName].DomainOwner == _DomainOwner && AuctionLists[_DomainName].stage == Stages.Ended );
        require (now <= Domains[_DomainName].RegistrationTime + 10 minutes && now <= Domains[_DomainName].RegistrationTime + 10 minutes - biddingTime - Settlement);

        if (AuctionLists[_DomainName].AuctionisValue == true) { delete AuctionLists[_DomainName]; }

        AuctionLists[_DomainName].Owner = msg.sender;
        AuctionLists[_DomainName].CreationTime = now;
        AuctionLists[_DomainName].stage = Stages.Opened;
        AuctionLists[_DomainName].AuctionisValue = true;
    }
//********************************************************************************************************************
    //To bid in the auction.
    function bid(bytes32 _DomainName) public payable CheckMinPrice(_DomainName) CheckAuctionExpiray(_DomainName)
    {
        //The auction should be opened.
        require (AuctionLists[_DomainName].stage == Stages.Opened);
        uint bid;

        //If the bidder has already bid in this auction, he does not deposit.
        if (AuctionLists[_DomainName].already_bid[msg.sender] == true) {bid = msg.value;}
        else
        {   //If the bidder has NOT bid in this auction, he deposits.
            bid = msg.value-Deposit_Fee;
            //Deposit_Fee will be added to the bidder's deposits.
            AuctionLists[_DomainName].deposits[msg.sender] = Deposit_Fee;
            AuctionLists[_DomainName].already_bid[msg.sender] = true;
        }

        //if the bidder's bid is not higher than the highest bid, send the money back.
        //By adding the bids of the person to his pending returns which he can withdrwa when the auction is Locked or Ended.
        require(bid > AuctionLists[_DomainName].highestBid);

        if (AuctionLists[_DomainName].highestBidder != 0)
        {
            AuctionLists[_DomainName].pendingReturns[AuctionLists[_DomainName].highestBidder] +=  AuctionLists[_DomainName].highestBid;
        }


         AuctionLists[_DomainName].highestBidder = msg.sender;
         AuctionLists[_DomainName].highestBid = msg.value - Deposit_Fee;
         AuctionLists[_DomainName].Winner =  AuctionLists[_DomainName].highestBidder;

    }

//********************************************************************************************************************
// Withdraw a bid that was overbid. Only when Auction is Locked.
    function withdraw_bid(bytes32 _DomainName) public CheckAuctionExpiray(_DomainName) returns (bool) {
        //Bidders can withdraw their bids ONLY when the auction is Locked.
        require (AuctionLists[_DomainName].stage == Stages.Locked);

        uint amount = AuctionLists[_DomainName].pendingReturns[msg.sender];
        if (amount > 0) {
            // It is important to set this to zero because the recipient
            // can call this function again as part of the receiving call
            // before `send` returns.
            AuctionLists[_DomainName].pendingReturns[msg.sender] = 0;

            if (!msg.sender.send(amount)) {
                // No need to call throw here, just reset the amount owing
                AuctionLists[_DomainName].pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }
//********************************************************************************************************************
// Withdraw Deposits. Only when Auction is Locked. Th Winner CANNOT witdraw his deposit.
    function withdraw_deposits(bytes32 _DomainName) public CheckAuctionExpiray(_DomainName) returns (bool) {
        require (msg.sender != AuctionLists[_DomainName].Winner && AuctionLists[_DomainName].stage == Stages.Locked);

        uint amount = AuctionLists[_DomainName].deposits[msg.sender];
        if (amount > 0) {
            // It is important to set this to zero because the recipient
            // can call this function again as part of the receiving call
            // before `send` returns.
            AuctionLists[_DomainName].deposits[msg.sender] = 0;

            if (!msg.sender.send(amount)) {
                // No need to call throw here, just reset the amount owing
                AuctionLists[_DomainName].deposits[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

//********************************************************************************************************************
//End the auction,send the highest bid to the auction's owner, transfer the Domainname to the auction's winner.
//Only Winner acn call the function Settle.
    function settle(bytes32 _DomainName) public CheckAuctionExpiray(_DomainName) returns (bool) {

        require (msg.sender == AuctionLists[_DomainName].Winner && AuctionLists[_DomainName].stage != Stages.Opened);

        //Return back the Winner's deposits.
        uint amount = AuctionLists[_DomainName].pendingReturns[msg.sender];
        if (amount > 0) {
            // It is important to set this to zero because the recipient
            // can call this function again as part of the receiving call
            // before `send` returns.
            AuctionLists[_DomainName].deposits[msg.sender] = 0;

            if (!msg.sender.send(amount)) {
                // No need to call throw here, just reset the amount owing
                AuctionLists[_DomainName].deposits[msg.sender] = amount;
                return false;
            }
        }

        //Transfer the highest bid to the Auction Owner.
        AuctionLists[_DomainName].Owner.transfer(AuctionLists[_DomainName].highestBid);
        //Changes the ownership of the DomainName and transfers it to the auction's Winner.
        Domains[_DomainName].DomainOwner = AuctionLists[_DomainName].Winner;
        AuctionLists[_DomainName].stage = Stages.Ended;

        return true;

    }
//********************************************************************************************************************
}
