import ICRC55 "../src/ICRC55";
import Principal "mo:base/Principal";

module {


    public func get(ledger: Principal) : ICRC55.Billing {
           {
                ledger = ledger;
                min_create_balance = 5000000;
                cost_per_day = 10_0000;
                operation_cost = 1000;
                freezing_threshold_days = 10;
                one_time_payment = null;
                transaction_fee = #none;
                split = {
                    pylon = 1; 
                    author = 10;
                    affiliate = 1;
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