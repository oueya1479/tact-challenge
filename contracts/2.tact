import "@stdlib/deploy";

/*
  TASK 2 - Proxy 
  Create a contract that forwards all received TONs
  to the admin contract (whose address is set in init_store).
  Message from this proxy contract to the admin contract should contain:
    - Address of user who sent original message (should be stored in the outcoming body's data/bits)
    - Original message that proxy smart contract received from user (should be stored in the outcoming body's first ref)
  o Also, if admin contract decides to reject message (if it sends to the proxy "Refund" message with opcode=0x44),
  o proxy contract needs to forward all TONs (attached to Refund message) back to the user.
  o User address will be provided in Refund message body as "sender".
  o In refund transaction, it is important to have a check that the refund message came from the admin address
*/

message(0x44) Refund {
  queryId: Int as uint64;
  sender: Address;
}

message SomeMessage {
  address: Address;
  msg: Slice;
}

contract Task2 with Deployable {
  admin: Address;

  init(admin: Address) {
    self.admin = admin;
  }
  
  receive(msg: Refund) {
    if (sender() == self.admin) {
      send(SendParameters{
        to: msg.sender,
        value: myBalance(),
        mode: SendRemainingBalance + SendIgnoreErrors,
        bounce: true
      });
    }
  }

  receive(msg: Slice) {
    send(SendParameters{
      to: self.admin,
      value: myBalance(),
      mode: SendRemainingBalance + SendIgnoreErrors,
      bounce: true,
      body: SomeMessage{address: sender(), msg: msg}.toCell()
    });
  }
}
