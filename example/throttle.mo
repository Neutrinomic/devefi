import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";

import Billing "./billing_all";

module {

    public func meta() : ICRC55.NodeMeta {
        {
            id = "throttle"; // This has to be same as the variant in vec.custom
            name = "Throttle";
            description = "Send X tokens every Y seconds";
            supported_ledgers = [];
            version = #alpha([0,0,1]);
            create_allowed = true;
            ledgers_required = [
                "Throttle",
            ];
            billing = billing();
            sources = sources(create(defaults()));
            destinations = destinations(create(defaults()));         
        }
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
            var interval_sec : NumVariant;
            var max_amount : NumVariant;
        };
        internals : {
            var wait_until_ts : Nat64;
        };
    };

    // Create request
    public type CreateRequest = {
        init : {
        };
        variables : {
            interval_sec : NumVariant;
            max_amount : NumVariant;
        };
    };

    // Create state from request
    public func create(t : CreateRequest) : Mem {
        {
            init = t.init;
            variables = {
                var interval_sec = t.variables.interval_sec;
                var max_amount = t.variables.max_amount;
            };
            internals = {
                var wait_until_ts = 0;
            };
        };
    };


    public func defaults() : CreateRequest {
        {
            init = {
            };
            variables = {
                interval_sec = #fixed(10);
                max_amount = #fixed(100_0000);
            };
        };
    };

    // Modify request
    public type ModifyRequest = {
        interval_sec : NumVariant;
        max_amount : NumVariant;
    };

    // How does the modify request change memory
    public func modify(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
        mem.variables.interval_sec := t.interval_sec;
        mem.variables.max_amount := t.max_amount;
        #ok();
    };



    // Public shared state
    public type Shared = {
        init : {
        };
        variables : {
            interval_sec : NumVariant;
            max_amount : NumVariant;
        };
        internals : {
            wait_until_ts : Nat64;
        };
    };

    // Convert memory to shared 
    public func toShared(t : Mem) : Shared {
        {
            init = t.init;
            variables = {
                interval_sec = t.variables.interval_sec;
                max_amount = t.variables.max_amount;
            };
            internals = {
                wait_until_ts = t.internals.wait_until_ts;
            };
        };
    };


    public func sources(_t : Mem) : Node.PortsDescription {
        [(0, "")];
    };

    public func destinations(_t : Mem) : Node.PortsDescription {
        [(0, "")];
    };


    // Other custom types
    public type NumVariant = {
        #fixed : Nat64;
        #rnd : { min : Nat64; max : Nat64 };
    };

    

};
