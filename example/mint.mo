import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";


import Billing "./billing_all";

module {

    public func meta() : ICRC55.NodeMeta {
        {
            id = "mint"; // This has to be same as the variant in vec.custom
            name = "Mint";
            description = "Mint X tokens for Y tokens";
            supported_ledgers = [];
            version = #alpha([0,0,1]);
            create_allowed = true;
            ledgers_required = [
                "Mint",
                "Take"
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
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {

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

    public func defaults() : CreateRequest {

        {
            init = {

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



    public func sources(_t : Mem) : Node.PortsDescription {
        [(1, "")];
    };

    public func destinations(_t : Mem) : Node.PortsDescription {
        [(0, "Mint"), (1, "")];
    };



};
