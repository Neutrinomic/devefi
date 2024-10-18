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
        var exchange_liquidity : ?VMem;
    }) : Node.VectorClass<Mem, CreateRequest, ModifyRequest, Shared> {

        if (vmem.exchange_liquidity == null) vmem.exchange_liquidity := ?VMem();
        let m = U.not_opt(vmem.exchange_liquidity);

        public func meta() : ICRC55.NodeMeta {
            {
                id = "exchange_liquidity"; // This has to be same as the variant in vec.custom
                name = "Exchange Liquidity";
                author = "Neutrinite";
                description = "Exchange Liquidity in pair X for Y";
                supported_ledgers = [];
                version = #alpha([0, 0, 1]);
                create_allowed = true;
                ledger_slots = [
                    "From",
                    "To",
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
                variables = {
                    var remove = t.variables.remove;
                };
                internals = {};
            };
        };

        public func defaults() : CreateRequest {
            {
                init = {

                };
                variables = {
                    remove = false;
                };
            };
        };

        // How does the modify request change memory
        public func modify(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
            mem.variables.remove := t.remove;
            #ok();
        };

        // Convert memory to shared
        public func toShared(t : Mem) : Shared {
            {
                init = t.init;
                variables = {
                    remove = t.variables.remove;
                };
                internals = {};
            };
        };

        public func sources(_t : Mem) : Node.PortsDescription {
            [(0, ""), (1, "")];
        };

        public func destinations(_t : Mem) : Node.PortsDescription {
            [(0, ""), (1, "")];
        };

    };

    // Internal vector state
    public type Mem = {
        init : {

        };
        variables : {
            var remove : Bool;
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {

        };
        variables : {
            remove : Bool;
        };
    };

    // Public shared state
    public type Shared = {
        init : {

        };
        variables : {
            remove : Bool;
        };
        internals : {};
    };

    // Modify request
    public type ModifyRequest = {
        remove : Bool;
    };
};
