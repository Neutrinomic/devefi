import ICRC55 "../src/ICRC55";
import Principal "mo:base/Principal";

module {


    public func get(ledger: Principal) : {billing: ICRC55.Billing; billing_fee_collecting: ICRC55.BillingFeeCollecting} {
            {
            billing = {
                ledger = ledger;
                min_create_balance = 5000000;
                cost_per_day = 10_0000;
                operation_cost = 1000;
                freezing_threshold_days = 10;
                exempt_balance = null;
                transaction_fee = #none;
            };
            billing_fee_collecting = {
                pylon = 1; 
                author = 10;
                author_account_ic = {
                    owner = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
                    subaccount = null;
                };
                author_account_other = []
            };
            }
    }
}