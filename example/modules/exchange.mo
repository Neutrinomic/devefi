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
        var exchange : ?VMem;
    }) : Node.VectorClass<Mem, CreateRequest, ModifyRequest, Shared> {

        if (vmem.exchange == null) vmem.exchange := ?VMem();
        let m = U.not_opt(vmem.exchange);

        public func meta() : ICRC55.NodeMeta {
            {
                id = "exchange"; // This has to be same as the variant in vec.custom
                name = "Exchange";
                author = "Neutrinite";
                description = "Exchange X for Y";
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

        // How does the modify request change memory
        public func modify(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
            mem.variables.max_per_sec := t.max_per_sec;
            #ok();
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

    // Modify request
    public type ModifyRequest = {
        max_per_sec : Nat;
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
};
