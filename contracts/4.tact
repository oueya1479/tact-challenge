import "@stdlib/deploy";

/*
  TASK 4 - NFT locker
  Implement a smart contract that will lock NFT for a period of time specified by the owner.
  Smart conrtact should contain logic to process following messages and getters: 

  Messages: 
  * OwnershipAssigned
   - Recives nft + time (in a forwardPayload message as uint32) for which this nft will be locked + address of the sender of the nft (prevOwner).
   - If the smart contract already holds an nft then return the incoming nft back to the sender
  * NftWithdrawal
   - Request withdrawal of the locked nft
   - If sender is not the owner (that came from OwnershipAssigned as prevOwner address) then throw "Invalid sender" 
   - If time has not passed then send message back to the sender with the comment "NFT is still locked" according to the TON's "message with text comment" standard 
   - Otherwise (all good) send the locked nft back to the owner with all the remaining TON balance
   Note that the order of checks is important
   (in case: "sender is not the owner" and "time has not passed" at the same time, "Invalid sender" error takes priority)

  Getters:
  * time
   - get how much lock time is left
  * nft
   - get the address of the locked nft 
  * owner
   - get the owner of the locked nft (that came from OwnershipAssigned as prevOwner)
*/

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address; // NFT 송신자 주소
    forwardPayload: Slice as remaining; // 남은 시간이 담김
}

message(0x5fcc3d14) Transfer { 
    queryId: Int as uint64;            
    newOwner: Address; 
    responseDestination: Address; 
    customPayload: Cell?; 
    forwardAmount: Int as coins; 
    forwardPayload: Slice as remaining; 
}

message NftWithdrawal { // 잠긴 NFT의 인출을 요청
  queryId: Int as uint64;
  nftAddress: Address;
}

contract Task4 with Deployable {
  seed: Int as uint128;
  deadline: Int?;
  nft: Address?;
  prevOwner: Address?;
  
  init(seed: Int) {
    self.seed = seed; // needed to deploy multiple smart contracts copies from one admin address
  }

  receive(msg: OwnershipAssigned) {

    require (self.nft == null, "incoming nft back to the sender.");

    self.nft = sender();
    self.deadline = msg.forwardPayload.loadUint(32);
    self.prevOwner = msg.prevOwner;

  }

  receive(msg: NftWithdrawal) {

    require(sender() == self.prevOwner, "Invalid sender");
    require(self.deadline != null, "Empty");
    require(now() > self.deadline!!, "NFT is still locked");

    send(SendParameters{
      to: self.prevOwner!!,
      value: myBalance() - context().value,
      mode: SendRemainingValue + SendIgnoreErrors,
      body: Transfer{
        queryId: 0,
        newOwner: self.prevOwner!!,
        responseDestination: myAddress(),
        customPayload: null,
        forwardAmount: ton("0.01"),
        forwardPayload: emptySlice()
      }.toCell()
    });

    self.nft = null;
    self.deadline = null;
    self.prevOwner = null;
  }

  get fun time(): Int {
    return self.seed;
  }

  get fun nft(): Address? {
    return self.nft;
  }

  get fun owner(): Address? {
    return self.prevOwner;
  }
}