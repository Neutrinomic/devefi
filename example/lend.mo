import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";


import Billing "./billing_all";

module {

    public func meta() : ICRC55.NodeMeta {
        {
            id = "lend"; // This has to be same as the variant in vec.custom
            name = "Lend";
            description = "Lend X tokens against Y tokens";
            supported_ledgers = [];
            version = #alpha([0,0,1]);
            create_allowed = true;
            ledgers_required = [
                "Borrow",
                "Lend"
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
            var interest : Nat;
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {

        };
        variables : {
            interest : Nat;
        };
    };

    // Create state from request
    public func create(t : CreateRequest) : Mem {
        {
            init = t.init;
            variables = {
                var interest = t.variables.interest;
            };
            internals = {};
        };
    };

    public func defaults() : CreateRequest {
        {
            init = {

            };
            variables = {
                interest = 20;
            };
        };
    };

    // Modify request
    public type ModifyRequest = {
        interest : Nat;
    };

    // How does the modify request change memory
    public func modify(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
        mem.variables.interest := t.interest;
        #ok();
    };

    // Public shared state
    public type Shared = {
        init : {

        };
        variables : {
            interest : Nat;
        };
        internals : {};
    };

    // Convert memory to shared
    public func toShared(t : Mem) : Shared {
        {
            init = t.init;
            variables = {
                interest = t.variables.interest;
            };
            internals = {};
        };
    };

    public func sources(_t : Mem) : Node.PortsDescription {
        [(0, "Lend")];
    };

    public func destinations(_t : Mem) : Node.PortsDescription {
        [(1, "Liquidation"), (1, "Fee"), (1, "Repayment")];
    };




};
