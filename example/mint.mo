import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";

import Debug "mo:base/Debug";
import U "../src/utils";
import Option "mo:base/Option";
import Billing "./billing_all";

module {

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : ICRC55.NodeMeta {
        {
            billing = billing();
            id = "mint"; // This has to be same as the variant in vec.custom
            name = "Mint";
            description = "Mint X tokens for Y tokens";
            supported_ledgers = all_ledgers;
            version = #alpha;
            create_allowed = true;
        };
    };

    public func billing() : ICRC55.Billing {
        Billing.get();
    };

    public func authorAccount() : ICRC55.Account {
        Billing.authorAccount();
    };


    // Internal vector state
    public type Mem = {
        init : {
            ledger_mint : Principal;
            ledger_for : Principal;
        };
        variables : {
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {
            ledger_mint: Principal;
            ledger_for: Principal;
        };
        variables : {
        };
    };

    // Create state from request
    public func create(t : CreateRequest) : Mem {
        {
            init = t.init;
            variables = {
            };
            internals = {};
        };
    };

    public func defaults(all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
        let #ic(ledger_mint) = all_ledgers[0] else Debug.trap("No ledgers found");
        let #ic(ledger_for) = all_ledgers[1] else Debug.trap("No ledgers found");
        {
            init = {
                ledger_mint;
                ledger_for;
            };
            variables = {
            };
        };
    };

    // Modify request
    public type ModifyRequest = {
    };

    // How does the modify request change memory
    public func modify(_mem : Mem, _t : ModifyRequest) : Result.Result<(), Text> {
        #ok();
    };

    // Public shared state
    public type Shared = {
        init : {
            ledger_mint : Principal;
            ledger_for : Principal;
        };
        variables : {
        };
        internals : {};
    };

    // Convert memory to shared
    public func toShared(t : Mem) : Shared {
        {
            init = t.init;
            variables = {
            };
            internals = {};
        };
    };



    public func sources(t : Mem) : Node.PortsDescription {
        [(t.init.ledger_for, "")];
    };

    public func destinations(t : Mem) : Node.PortsDescription {
        [(t.init.ledger_mint, "Mint"), (t.init.ledger_for, "")];
    };



};
