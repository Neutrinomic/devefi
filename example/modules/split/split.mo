import ICRC55 "../../../src/ICRC55";
import Sys "../../../src/sys";
import Result "mo:base/Result";
import U "../../../src/utils";
import Billing "../../billing_all";
import MU "mo:mosup";
import Ver1 "./memory/v1";
import Map "mo:map/Map";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Core "../../../src/core";

module {

    public module Mem {
        public module Vector {
            public let V1 = Ver1;
        }
    };
    let VM = Mem.Vector.V1;

    public let ID = "split";
    public type CreateRequest = VM.CreateRequest;
    public type ModifyRequest = VM.ModifyRequest;
    public type Shared = VM.Shared;

    public class Mod({
        xmem : MU.MemShell<VM.Mem>;
        core : Core.Mod
        }) : Core.VectorClass<VM.VMem, VM.CreateRequest, VM.ModifyRequest, VM.Shared> {

        let mem = MU.access(xmem);

        public func meta() : ICRC55.ModuleMeta {
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

        // Create state from request
        public func create(id : Sys.NodeId, t : VM.CreateRequest) : Result.Result<Sys.ModuleId, Text> {

            let obj : VM.VMem = {
                init = t.init;
                variables = {
                    var split = t.variables.split;
                };
                internals = {};
            };
            ignore Map.put(mem.main, Map.n32hash, id, obj);
            #ok(ID);
        };

        public func defaults() : VM.CreateRequest {
            {
                init = {

                };
                variables = {
                    split = [50, 50];
                };
            };
        };

        public func delete(id: Sys.NodeId) : () {
            ignore Map.remove(mem.main, Map.n32hash, id);
        };

        public func run(id:Core.NodeId, vec:Core.NodeMem) {
            let ?n = Map.get(mem.main, Map.n32hash, id) else return;

            let ?source = core.getSource(id, vec, 0) else return;
            let now = U.now();
            let bal = source.balance();
            let fee = source.fee();

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

                ignore source.send(#destination({ port = port_id }), amount);
                remainingBalance -= amount;
            };

            // Send the remaining balance to the largest share destination
            if (remainingBalance > 0) {
                ignore do ? {
                    source.send(#destination({ port = largestPort! }), remainingBalance);
                };
            };

    };

    // How does the modify request change memory
    public func modify(id : Sys.NodeId, m : VM.ModifyRequest) : Result.Result<(), Text> {
        let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

        t.variables.split := m.split;
        #ok();
    };

    // Convert memory to shared
    public func toShared(id : Sys.NodeId) : Result.Result<VM.Shared, Text> {
        let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

        #ok {
            init = t.init;
            variables = {
                split = t.variables.split;
            };
            internals = {};
        };
    };

    public func sources(_id : Sys.NodeId) : Sys.EndpointsDescription {
        [(0, "")];
    };

    public func destinations(id : Sys.NodeId) : Sys.EndpointsDescription {
        let ?t = Map.get(mem.main, Map.n32hash, id) else return [];

        Array.tabulate<(Nat, Text)>(
            t.variables.split.size(),
            func(idx : Nat) { (0, Nat.toText(t.variables.split[idx])) },
        );
    };

};

};
