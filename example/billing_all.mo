import ICRC55 "../src/ICRC55";
import Principal "mo:base/Principal";

module {

    // These should be defined in each vector module, these are for example

    public func get() : ICRC55.Billing {
           {
                // The ledger id from pocket IC tests
                // We will need a script replace this, can't be drilling from root to here to make tests work
                // And this needs to be hardcoded by authors at the end
                ledger = Principal.fromText("lxzze-o7777-77777-aaaaa-cai"); 
                min_create_balance = 5000000;
                cost_per_day = 10_0000;
                operation_cost = 1000;
                freezing_threshold_days = 10;
                exempt_daily_cost_balance = null;
                transaction_fee = #none;
                split = {
                    pylon = 300; 
                    author = 500;
                    affiliate = 200;
                };
            };
          
    };

    public func authorAccount() : ICRC55.Account {
        {
            owner = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
            subaccount = null;
        }
    }
}