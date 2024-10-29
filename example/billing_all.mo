import ICRC55 "../src/ICRC55";
import Principal "mo:base/Principal";

module {

    // These should be defined in each vector module, these are for example

    public func get() : ICRC55.Billing {
           {
                cost_per_day = 10_0000;
                transaction_fee = #none;
           };
          
    };

    public func authorAccount() : ICRC55.Account {
        {
            owner = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
            subaccount = null;
        }
    }
}