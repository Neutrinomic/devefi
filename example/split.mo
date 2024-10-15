import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Debug "mo:base/Debug";
import U "../src/utils";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Billing "./billing_all";

module {

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : ICRC55.NodeMeta {
        {
            billing = billing();
            id = "split"; // This has to be same as the variant in vec.custom
            name = "Split";
            description = "Split X tokens";
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
            ledger : Principal;
        };
        variables : {
            var split : [Nat];
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {
            ledger : Principal;
        };
        variables : {
            split : [Nat];
        };
    };

    // Create state from request
    public func create(t : CreateRequest) : Mem {
        {
            init = t.init;
            variables = {
                var split = t.variables.split;
            };
            internals = {};
        };
    };

    public func defaults(all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
        let #ic(ledger) = all_ledgers[0] else Debug.trap("No ledgers found");
        {
            init = {
                ledger;
            };
            variables = {
                split = [50, 50];
            };
        };
    };

    // Modify request
    public type ModifyRequest = {
        split : [Nat];
    };

    // How does the modify request change memory
    public func modify(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
        mem.variables.split := t.split;
        #ok();
    };

    // Public shared state
    public type Shared = {
        init : {
            ledger : Principal;
        };
        variables : {
            split : [Nat];
        };
        internals : {};
    };

    // Convert memory to shared
    public func toShared(t : Mem) : Shared {
        {
            init = t.init;
            variables = {
                split = t.variables.split;
            };
            internals = {};
        };
    };


    public func sources(t : Mem) : Node.PortsDescription {
        [(t.init.ledger, "")];
    };

    public func destinations(t : Mem) : Node.PortsDescription {
        Array.tabulate<(Principal, Text)>(
            t.variables.split.size(),
            func(idx : Nat) {
                (t.init.ledger, Nat.toText(t.variables.split[idx]))
            },
        );
    };


};
