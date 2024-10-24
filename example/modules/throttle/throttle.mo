import ICRC55 "../../../src/ICRC55";
import Sys "../../../src/sys";
import Result "mo:base/Result";
import U "../../../src/utils";
import Billing "../../billing_all";
import MU "mo:mosup";
import Ver1 "./memory/v1";
import Map "mo:map/Map";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Prng "mo:prng";
import Core "../../../src/core";

module {

    public module Mem {
        public module Vector {
            public let V1 = Ver1;
        }
    };
    let VM = Mem.Vector.V1;

    public let ID = "throttle";
    public type CreateRequest = VM.CreateRequest;
    public type ModifyRequest = VM.ModifyRequest;
    public type Shared = VM.Shared;

    public class Mod({
        xmem : MU.MemShell<VM.Mem>;
        core : Core.Mod
        }) : Core.VectorClass<VM.VMem, VM.CreateRequest, VM.ModifyRequest, VM.Shared> {

        let rng = Prng.SFC64a();
        rng.init(123456);

        let mem = MU.access(xmem);

        public func meta() : ICRC55.NodeMeta {
            {
                id = ID; // This has to be same as the variant in vec.custom
                name = "Throttle";
                author = "Neutrinite";
                description = "Send X tokens every Y seconds";
                supported_ledgers = [];
                version = #alpha([0, 0, 1]);
                create_allowed = true;
                ledger_slots = [
                    "Throttle"
                ];
                billing = Billing.get();
                sources = sources(0);
                destinations = destinations(0);
                author_account = Billing.authorAccount();
            };
        };

  

        public func run(id:Sys.NodeId, vec:Core.NodeMem) {
            let ?th = Map.get(mem.main, Map.n32hash, id) else return;
            let ?source = core.getSource(id, vec, 0) else return;
            let now = U.now();
            let bal = source.balance();
            let fee = source.fee();

            if (now > th.internals.wait_until_ts) {
                switch (th.variables.interval_sec) {
                    case (#fixed(fixed)) {
                        th.internals.wait_until_ts := now + fixed * 1_000_000_000;
                    };
                    case (#rnd({ min; max })) {
                        let dur : Nat64 = if (min >= max) 0 else rng.next() % (max - min);
                        th.internals.wait_until_ts := now + (min + dur) * 1_000_000_000;
                    };
                };

                let max_amount : Nat64 = switch (th.variables.max_amount) {
                    case (#fixed(fixed)) fixed;
                    case (#rnd({ min; max })) if (min >= max) 0 else min + rng.next() % (max - min);
                };

                var amount = Nat.min(bal, Nat64.toNat(max_amount));
                if (bal - amount : Nat <= fee * 100) amount := bal; // Don't leave dust

                ignore source.send(#destination({ port = 0 }), amount);

            };
        };

        public func create(id : Sys.NodeId, t : VM.CreateRequest) : Result.Result<Sys.ModuleId, Text> {

            let obj : VM.VMem = {
                init = t.init;
                variables = {
                    var interval_sec = t.variables.interval_sec;
                    var max_amount = t.variables.max_amount;
                };
                internals = {
                    var wait_until_ts = 0;
                };
            };
            ignore Map.put(mem.main, Map.n32hash, id, obj);
            #ok(ID);
        };

        public func defaults() : VM.CreateRequest {
            {
                init = {};
                variables = {
                    interval_sec = #fixed(10);
                    max_amount = #fixed(100_0000);
                };
            };
        };

        // How does the modify request change memory
        public func modify(id : Sys.NodeId, m : VM.ModifyRequest) : Result.Result<(), Text> {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

            t.variables.interval_sec := m.interval_sec;
            t.variables.max_amount := m.max_amount;

            #ok();
        };

        // Convert memory to shared
        public func toShared(id : Sys.NodeId) : Result.Result<VM.Shared, Text> {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

            #ok {
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

        public func sources(_id : Sys.NodeId) : Sys.PortsDescription {
            [(0, "")];
        };

        public func destinations(_id : Sys.NodeId) : Sys.PortsDescription {
            [(0, "")];
        };

    };

};
