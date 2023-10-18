import "@stdlib/deploy";

/*
  TASK 3 - DEX
  Create a simple jetton dex contract that trades one pair of jettons: A and B.
  The price of jettons depends on the amount of jettons that smart contract has.
  Therefore, the smart contract needs to keep track of how much jettons it has.
  
  Price for the jetton A in swap B->A should be calculated by formula "amountOfJettonAOnContract * decimal / amountOfJettonBOnContract".
  Token prices must be decimalized for accuracy, so it is the prices that must be adjusted to decimal 1e9.
  Decimals are only needed for price accuracy. It should be set as 1e9.
  So, if smart contract has 10 of jetton A and 2 of jetton B, then after sending 1 jetton B you should receive 5 of jettons A.

  Example formula for amountOfAJettonToSend in B->A swap will be
  (amountOfJettonAOnContract * decimal / amountOfJettonBOnContract) * amountOfTokenBToSwap / decimal

  If smart contract pool doesn't have enough jettons to trade,
  then it should send incoming jettons back to the user. For a clearer explanation,
  let's look at the example we described above (smart contract has 10 of jetton A and 2 of jetton B).
  If user will send 3 jettons B, smart contract should reject the message (because contract does not have 3 * 5 = 15 jettons A)
  and send 3 jettons B back to the user.

  If smart contract receives a different jetton (neither A nor B) then throw an error.

  Implement a getter that returns the number of jettons in the pool and
  one more to get the price of jetton A or jetton B.
  Getters' behavior with incorrect parameter (address other than that of jetton A or B)
  is undefined (there are no such tests).
  
  Note:
  Admin can add jettons A and B just by sending them to the smart contract (we need to add initial supply to the pool for it to be functional).
  To be exact: any jettons (A or B) received from the admin are "added". Admin can't swap.
*/

message(0x7362d09c) TokenNotification {
    queryId: Int as uint64;
    amount: Int as coins; // 얼만큼 보냈는지
    from: Address; // 보낸 사람
    forwardPayload: Slice as remaining;
}

message(0xf8a7ea5) TokenTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    responseDestination: Address?;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

contract Task3 with Deployable {
  owner: Address;
  aAmount: Int;
  bAmount: Int;
  jettonAddressA: Address;
  jettonAddressB: Address;
  decimal: Int;

  init(admin: Address, newJettonAddressA: Address, newJettonAddressB: Address) {
    self.owner = admin;
    self.jettonAddressA = newJettonAddressA;
    self.jettonAddressB = newJettonAddressB;
    self.aAmount = 0;
    self.bAmount = 0;
    self.decimal = 1000000000;
  }

  receive(msg: TokenNotification) {

    let ctx: Context = context();
    require (ctx.sender == self.jettonAddressA || ctx.sender == self.jettonAddressB, "Access denied");

    if (msg.from == self.owner) {
      if (ctx.sender == self.jettonAddressA) {
        self.aAmount = self.aAmount + msg.amount;
      } else {
        self.bAmount = self.bAmount + msg.amount;
      }
    } else {
      let amountOfJettonToSend: Int = self.pricef(ctx.sender) * msg.amount / self.decimal;

      let fromJetton: Address = ctx.sender;
      let toJetton: Address = self.reversef(ctx.sender);

      if (self.balancef(toJetton) - amountOfJettonToSend < 0) {
        self.sendParameter(fromJetton, msg.amount, msg.queryId, msg.from);
      } else {
        self.sendParameter(toJetton, amountOfJettonToSend, msg.queryId, msg.from);
        self.update(fromJetton, msg.amount, amountOfJettonToSend);
      }
    }

  } 
  
  get fun price(jetton: Address): Int {
    require (jetton == self.jettonAddressA || jetton == self.jettonAddressB, "Access denied");
    if (jetton == self.jettonAddressA) {
      return self.bAmount * self.decimal / self.aAmount;
    } else {
      return self.aAmount * self.decimal / self.bAmount;
    }
  }
  
  get fun balance(jetton: Address): Int {
    require (jetton == self.jettonAddressA || jetton == self.jettonAddressB, "Access denied");
    if (jetton == self.jettonAddressA) {
      return self.aAmount;
    } else {
      return self.bAmount;
    }
  }

  fun sendParameter(to: Address, amount: Int, queryId: Int, destination: Address) {
    send(SendParameters{
      to: to,
      value: 0,
      bounce: false,
      body: TokenTransfer{
        queryId: queryId,
        amount: amount,
        destination: destination,
        customPayload: emptyCell(),
        responseDestination: myAddress(),
        forwardTonAmount: 0,
        forwardPayload: emptySlice()
      }.toCell()
    });
  }

  fun pricef(jetton: Address): Int {
    if (jetton == self.jettonAddressA) {
      return self.bAmount * self.decimal / self.aAmount;
    } else {
      return self.aAmount * self.decimal / self.bAmount;
    }
  }
  
  fun balancef(jetton: Address): Int {
    if (jetton == self.jettonAddressA) {
      return self.aAmount;
    } else {
      return self.bAmount;
    }
  }

  fun reversef(jetton: Address): Address {
    if (jetton == self.jettonAddressA) {
      return self.jettonAddressB;
    } else {
      return self.jettonAddressA;
    }
  }

  fun update(jetton: Address, amount: Int, sendAmount: Int) {
    if (jetton == self.jettonAddressA) {
      self.aAmount = self.aAmount + amount;
      self.bAmount = self.bAmount - sendAmount;
    } else {
      self.aAmount = self.aAmount - sendAmount;
      self.bAmount = self.bAmount + amount;
    }
  }
}
