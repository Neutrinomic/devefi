import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";
import Array "mo:base/Array";

import Nat "mo:base/Nat";
import Billing "./billing_all";

module {


    public func meta() : ICRC55.NodeMeta {
        {
            id = "split"; // This has to be same as the variant in vec.custom
            name = "Split";
            description = "Split X tokens";
            supported_ledgers = [];
            version = #alpha([0,0,1]);
            create_allowed = true;
            ledgers_required = [
                "Split",
            ];
            billing = billing();
            sources = sources(create(defaults()));
            destinations = destinations(create(defaults()));         
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
        };
        variables : {
            var split : [Nat];
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {
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

    public func defaults() : CreateRequest {
        {
            init = {
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


    public func sources(_t : Mem) : Node.PortsDescription {
        [(0, "")];
    };

    public func destinations(t : Mem) : Node.PortsDescription {
        Array.tabulate<(Nat, Text)>(
            t.variables.split.size(),
            func(idx : Nat) {
                (0, Nat.toText(t.variables.split[idx]))
            },
        );
    };


};
