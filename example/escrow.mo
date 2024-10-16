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
            id = "escrow"; // This has to be same as the variant in vec.custom
            name = "Escrow";
            description = "Escrow X tokens";
            supported_ledgers = all_ledgers;
            version = #alpha;
            create_allowed = true;
            ledgers_required = [
                "Borrow",
                "Lend"
            ]
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

    public func defaults(all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
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


    public func sources(t : Mem) : Node.PortsDescription {
        [(0, "")];
    };

    public func destinations(t : Mem) : Node.PortsDescription {
        [(0, "Success"), (0, "Fail")];
    };




};
