import ICRC55 "../../src/ICRC55";
import Node "../../src/node";
import Result "mo:base/Result";
import Array "mo:base/Array";
import U "../../src/utils";
import Nat "mo:base/Nat";
import Billing "../billing_all";

module {

    public type VMem = {};

    public func VMem() : VMem {
        {};
    };
    
    public class Module(vmem : {
        var split : ?VMem;
    }) : Node.VectorClass<Mem, CreateRequest, ModifyRequest, Shared> {

        if (vmem.split == null) vmem.split := ?VMem();
        let m = U.not_opt(vmem.split);

        public func meta() : ICRC55.NodeMeta {
            {
                id = "split"; // This has to be same as the variant in vec.custom
                name = "Split";
                author = "Neutrinite";
                description = "Split X tokens";
                supported_ledgers = [];
                version = #alpha([0, 0, 1]);
                create_allowed = true;
                ledger_slots = [
                    "Split",
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
                    var split = t.variables.split;
                };
                internals = {};
            };
        };

        public func defaults() : CreateRequest {
            {
                init = {};
                variables = {
                    split = [50, 50];
                };
            };
        };

        // How does the modify request change memory
        public func modify(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
            mem.variables.split := t.split;
            #ok();
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
                func(idx : Nat) { (0, Nat.toText(t.variables.split[idx])) },
            );
        };

    };

    // Internal vector state
    public type Mem = {
        init : {};
        variables : {
            var split : [Nat];
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {};
        variables : {
            split : [Nat];
        };
    };
    // Modify request
    public type ModifyRequest = {
        split : [Nat];
    };
    // Public shared state
    public type Shared = {
        init : {};
        variables : {
            split : [Nat];
        };
        internals : {};
    };

};
