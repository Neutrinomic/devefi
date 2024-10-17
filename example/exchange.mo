import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";
import U "../src/utils";


import Billing "./billing_all";

module {

    public func meta() : ICRC55.NodeMeta {
        {
            id = "exchange"; // This has to be same as the variant in vec.custom
            name = "Exchange";
            author = "Neutrinite";            
            description = "Exchange X for Y";
            supported_ledgers = [];
            version = #alpha([0,0,1]);
            create_allowed = true;
            ledgers_required = [
                "Exchange",
            ];
            billing = billing();
            sources = sources(U.ok_or_trap(create(defaults())));
            destinations = destinations(U.ok_or_trap(create(defaults())));
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
            var max_per_sec : Nat;
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {
   
        };
        variables : {
            max_per_sec : Nat;
        };
    };

    // Create state from request
    public func create(t : CreateRequest) : Result.Result<Mem, Text> {
        #ok {
            init = t.init;
            variables = {
                var max_per_sec = t.variables.max_per_sec;
            };
            internals = {};
        };
    };

    public func defaults() : CreateRequest {
        {
            init = {
     
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


    public func sources(_t : Mem) : Node.PortsDescription {
        [(0, "")];
    };

    public func destinations(_t : Mem) : Node.PortsDescription {
        [(1, "")];
    };




};
