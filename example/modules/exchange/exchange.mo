import Billing "../../billing_all";
import MU "mo:mosup";
import Ver1 "./memory/v1";
import Map "mo:map/Map";
import Core "../../../src/core";
import I "./interface";
import U "../../../src/utils";
import Result "mo:base/Result";
import DeVeFi "../../../src/lib";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import IT "mo:itertools/Iter";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Vector "mo:vector";
import Swap "../../shared_modules/swap/swap";

module {
    let T = Core.VectorModule;
    public let Interface = I;
    type R<A,B> = Result.Result<A,B>;

    public module Mem {
        public module Vector {
            public let V1 = Ver1;
        };
    };
    let VM = Mem.Vector.V1;


    public let ID = "exchange";


    public class Mod({
        xmem : MU.MemShell<VM.Mem>;
        core : Core.Mod;
        swap : Swap.Mod;
    }) : T.Class<I.CreateRequest, I.ModifyRequest, I.Shared> {

        let mem = MU.access(xmem);

        public func meta() : T.Meta {
            {
                id = ID; // This has to be same as the variant in vec.custom
                name = "Exchange";
                author = "Neutrinite";
                description = "Exchange X tokens for Y";
                supported_ledgers = [];
                version = #alpha([0, 0, 1]);
                create_allowed = true;
                ledger_slots = [
                    "From",
                    "To",
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
                    var interest = t.variables.interest;
                };
                internals = {};
            };
            ignore Map.put(mem.main, Map.n32hash, id, obj);
            #ok(ID);
        };

        public func defaults() : I.CreateRequest {
            {
                init = {

                };
                variables = {
                    interest = 20;
                };
            };
        };

        public func delete(id : T.NodeId) : () {
            ignore Map.remove(mem.main, Map.n32hash, id);
        };

        public func modify(id : T.NodeId, m : I.ModifyRequest) : T.Modify {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

            t.variables.interest := m.interest;
            #ok();
        };

        public func get(id : T.NodeId) : T.Get<I.Shared> {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

            #ok {
                init = t.init;
                variables = {
                    interest = t.variables.interest;
                };
                internals = {};
            };
        };

        public func sources(_id : T.NodeId) : T.Endpoints {
            [(0, "From")];
        };

        public func destinations(_id : T.NodeId) : T.Endpoints {
            [(1, "To")];
        };


        public func run(vid : T.NodeId, vec : T.NodeCoreMem) : () {
            let ?th = Map.get(mem.main, Map.n32hash, vid) else return;
            let now = U.now();

            let ?source = core.getSource(vid, vec, 0) else return;
            let bal = core.Source.balance(source);

            let intent = swap.Intent.get([U.onlyICLedger(vec.ledgers[0]), U.onlyICLedger(vec.ledgers[1])], bal);
            let quote = swap.Intent.quote(intent);
            swap.Intent.commit(intent);
        
        };

       

    };




};
