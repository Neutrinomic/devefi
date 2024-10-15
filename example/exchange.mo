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
            id = "exchange"; // This has to be same as the variant in vec.custom
            name = "Exchange";
            description = "Exchange X for Y";
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
            ledger_from : Principal;
            ledger_to : Principal;
        };
        variables : {
            var max_per_sec : Nat;
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {
            ledger_from : Principal;
            ledger_to : Principal;
        };
        variables : {
            max_per_sec : Nat;
        };
    };

    // Create state from request
    public func create(t : CreateRequest) : Mem {
        {
            init = t.init;
            variables = {
                var max_per_sec = t.variables.max_per_sec;
            };
            internals = {};
        };
    };

    public func defaults(all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
        let #ic(ledger_from) = all_ledgers[0] else Debug.trap("No ledgers found");
        let #ic(ledger_to) = all_ledgers[1] else Debug.trap("No ledgers found");
        {
            init = {
                ledger_from;
                ledger_to;
            };
            variables = {
                max_per_sec = 100000000;
            };
        };
    };

    // Modify request
    public type ModifyRequest = {
        max_per_sec : Nat;
    };

    // How does the modify request change memory
    public func modify(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
        mem.variables.max_per_sec := t.max_per_sec;
        #ok();
    };

    // Public shared state
    public type Shared = {
        init : {
            ledger_from : Principal;
            ledger_to : Principal;
        };
        variables : {
            max_per_sec : Nat;
        };
        internals : {};
    };

    // Convert memory to shared
    public func toShared(t : Mem) : Shared {
        {
            init = t.init;
            variables = {
                max_per_sec = t.variables.max_per_sec;
            };
            internals = {};
        };
    };


    public func sources(t : Mem) : Node.PortsDescription {
        [(t.init.ledger_from, "")];
    };

    public func destinations(t : Mem) : Node.PortsDescription {
        [(t.init.ledger_to, "")];
    };




};
