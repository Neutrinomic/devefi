import ICRC55 "../../../src/ICRC55";
import Sys "../../../src/sys";
import Result "mo:base/Result";
import U "../../../src/utils";
import Billing "../../billing_all";
import MU "mo:mosup";
import Ver1 "./memory/v1";
import Map "mo:map/Map";
import Core "../../../src/core";

module {

    public module Mem {
        public module Vector {
            public let V1 = Ver1;
        }
    };
    let VM = Mem.Vector.V1;

    public let ID = "lend";
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
                name = "Lend";
                author = "Neutrinite";
                description = "Lend X";
                supported_ledgers = [];
                version = #alpha([0, 0, 1]);
                create_allowed = true;
                ledger_slots = [
                    "Lend",
                    "Borrow",
                ];
                billing = Billing.get();
                sources = sources(0);
                destinations = destinations(0);
                author_account = Billing.authorAccount();
            };
        };


        // Create state from request
        public func create(id: Sys.NodeId, t : VM.CreateRequest) : Result.Result<Sys.ModuleId, Text> {
            
            let obj:VM.VMem = {
                init = t.init;
                variables = {
                    var interest = t.variables.interest;
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
                    interest = 20;
                };
            };
        };

        // How does the modify request change memory
        public func modify(id: Sys.NodeId, m : VM.ModifyRequest) : Result.Result<(), Text> {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

            t.variables.interest := m.interest;
            #ok();
        };

        public func delete(id: Sys.NodeId) : () {
            ignore Map.remove(mem.main, Map.n32hash, id);
        };

        // Convert memory to shared
        public func get(id: Sys.NodeId) : Result.Result<VM.Shared, Text> {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

            #ok {
                init = t.init;
                variables = {
                    interest = t.variables.interest;
                };
                internals = {};
            };
        };

        public func sources(_id: Sys.NodeId) : Sys.EndpointsDescription {
            [(0, "Lend")];
        };

        public func destinations(_id: Sys.NodeId) : Sys.EndpointsDescription {
            [(1, "Collateral")];
        };

    };





};
