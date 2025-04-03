import ICRC55 "./ICRC55";

module {

    public type ChronoRecord = {
        #account: C100_Account;
        #dex: C200_Dex;
    };


    //100
    public type C100_Account = {
        #received: Received;
        #sent: Sent;
    };

    public type C200_Dex = {
        #swap: Swap;
        #liquidityAdd: LiquidityAdd;
        #liquidityRemove: LiquidityRemove;
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
    };

    public type Swap = {
        from: ICRC55.Account;
        to: ICRC55.Account;
        amountIn: Nat;
        amountOut: Nat;
        zeroForOne: Bool;
        newPrice: Float;
    };

    public type LiquidityAdd = {
        fromA: ICRC55.Account;
        amountA: Nat;
        fromB: ICRC55.Account;
        to: ICRC55.Account;
        amountB: Nat;
    };

    public type LiquidityRemove = {
        from: ICRC55.Account;
        toA: ICRC55.Account;
        amountA: Nat;
        toB: ICRC55.Account;
        amountB: Nat;
    };


}