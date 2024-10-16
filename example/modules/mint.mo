import ICRC55 "../../src/ICRC55";
import Node "../../src/node";
import Result "mo:base/Result";
import U "../../src/utils";
import Billing "../billing_all";

module {

    public type VMem = {};
    public func VMem() : VMem {
        {};
    };
    
    public class Module(vmem : {
        var mint : ?VMem;
    }) : Node.VectorClass<Mem, CreateRequest, ModifyRequest, Shared> {

        if (vmem.mint == null) vmem.mint := ?VMem();
        let m = U.not_opt(vmem.mint);

        public func meta() : ICRC55.NodeMeta {
            {
                id = "mint"; // This has to be same as the variant in vec.custom
                name = "Mint";
                author = "Neutrinite";
                description = "Mint X tokens for Y tokens";
                supported_ledgers = [];
                version = #alpha([0, 0, 1]);
                create_allowed = true;
                ledger_slots = [
                    "Mint",
                    "Take",
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

        // Create state from request
        public func create(t : CreateRequest) : Result.Result<Mem, Text> {
            #ok {
                init = t.init;
                variables = {};
                internals = {};
            };
        };

        public func defaults() : CreateRequest {

            {
                init = {

                };
                variables = {};
            };
        };

        // How does the modify request change memory
        public func modify(_mem : Mem, _t : ModifyRequest) : Result.Result<(), Text> {
            #ok();
        };

        // Convert memory to shared
        public func toShared(t : Mem) : Shared {
            {
                init = t.init;
                variables = {};
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

    // Internal vector state
    public type Mem = {
        init : {

        };
        variables : {};
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {

        };
        variables : {};
    };
    // Modify request
    public type ModifyRequest = {};

    // Public shared state
    public type Shared = {
        init : {

        };
        variables : {};
        internals : {};
    };

};
