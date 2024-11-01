import U "../../../src/utils";
import Billing "../../billing_all";
import MU "mo:mosup";
import Ver1 "./memory/v1";
import Map "mo:map/Map";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Core "../../../src/core";
import I "./interface";

module {
    let T = Core.VectorModule;
    public let Interface = I;

    public module Mem {
        public module Vector {
            public let V1 = Ver1;
        };
    };
    let VM = Mem.Vector.V1;

    public let ID = "split";

    public class Mod({
        xmem : MU.MemShell<VM.Mem>;
        core : Core.Mod;
    }) : T.Class<I.CreateRequest, I.ModifyRequest, I.Shared> {

        let mem = MU.access(xmem);

        public func meta() : T.Meta {
            {
                id = ID; // This has to be same as the variant in vec.custom
                name = "Split";
                author = "Neutrinite";
                description = "Split X tokens while providing Y tokens collateral";
                supported_ledgers = [];
                version = #alpha([0, 0, 1]);
                create_allowed = true;
                ledger_slots = [
                    "Split",
                ];
                billing = Billing.get();
                sources = sources(0);
                destinations = destinations(0);
                author_account = Billing.authorAccount();
            };
        };

        public func create(id : T.NodeId, t : I.CreateRequest) : T.Create {

            let obj : VM.NodeMem = {
                init = t.init;
                variables = {
                    var split = t.variables.split;
                };
                internals = {};
            };
            ignore Map.put(mem.main, Map.n32hash, id, obj);
            #ok(ID);
        };

        public func get(id : T.NodeId) : T.Get<I.Shared> {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

            #ok {
                init = t.init;
                variables = {
                    split = t.variables.split;
                };
                internals = {};
            };
        };

        public func modify(id : T.NodeId, m : I.ModifyRequest) : T.Modify {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

            t.variables.split := m.split;
            #ok();
        };

        public func delete(id : T.NodeId) : () {
            ignore Map.remove(mem.main, Map.n32hash, id);
        };

        public func defaults() : I.CreateRequest {
            {
                init = {

                };
                variables = {
                    split = [50, 50];
                };
            };
        };

        public func run(vid : T.NodeId, vec : T.NodeCoreMem) {
            let ?n = Map.get(mem.main, Map.n32hash, vid) else return;

            let ?source = core.getSource(vid, vec, 0) else return;
            let bal = core.Source.balance(source);
            let fee = core.Source.fee(source);

            // First loop: Calculate totalSplit and find the largest share destination
            var totalSplit = 0;
            var largestPort : ?Nat = null;
            var largestAmount = 0;

            label iniloop for (port_id in n.variables.split.keys()) {
                if (not core.hasDestination(vec, port_id)) continue iniloop;

                let splitShare = n.variables.split[port_id];
                totalSplit += splitShare;

                if (splitShare > largestAmount) {
                    largestPort := ?port_id;
                    largestAmount := splitShare;
                };
            };

            // If no valid destinations, skip the rest of the loop
            if (totalSplit == 0) return;

            var remainingBalance = bal;

            // Second loop: Send to each valid destination
            label port_send for (port_id in n.variables.split.keys()) {
                if (not core.hasDestination(vec, port_id)) continue port_send;

                let splitShare = n.variables.split[port_id];

                // Skip the largestPort for now, as we will handle it last
                if (?port_id == largestPort) continue port_send;

                let amount = bal * splitShare / totalSplit;
                if (amount <= fee * 100) continue port_send; // Skip if below fee threshold

                ignore core.Source.send(source, #destination({ port = port_id }), amount);
                remainingBalance -= amount;
            };

            // Send the remaining balance to the largest share destination
            if (remainingBalance > 0) {
                ignore do ? {
                    core.Source.send(source, #destination({ port = largestPort! }), remainingBalance);
                };
            };

        };

        public func sources(_id : T.NodeId) : T.Endpoints {
            [(0, "")];
        };

        public func destinations(id : T.NodeId) : T.Endpoints {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return [];

            Array.tabulate<(Nat, Text)>(
                t.variables.split.size(),
                func(idx : Nat) { (0, Nat.toText(t.variables.split[idx])) },
            );
        };

    };

};
