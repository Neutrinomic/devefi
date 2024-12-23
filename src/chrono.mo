import ICRC55 "./ICRC55";

module {

    public type ChronoRecord = {
        #account: C100_Account;
    };

    //100
    public type C100_Account = {
        #received: Received;
        #sent: Sent;
    };


    public type Received = {
        ledger: Principal;
        from: { #icrc: ICRC55.Account; #icp: Blob };
        amount: Nat;
    };

    public type Sent = {
        ledger: Principal;
        to: { #icrc: ICRC55.Account; #icp: Blob };
        amount: Nat;
    }

}