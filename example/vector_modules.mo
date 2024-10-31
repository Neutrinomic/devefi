import ICRC55 "../src/ICRC55";
import Core "../src/core";
import ThrottleVector "./modules/throttle/throttle";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Lend "./modules/lend/lend";
import Borrow "./modules/borrow/borrow";
import Exchange "./modules/exchange/exchange";
import Escrow "./modules/escrow/escrow";
import Split "./modules/split/split";

// THIS SHOULD BE AUTO-GENERATED FILE

module {

    public type CreateRequest = {
        #throttle : ThrottleVector.Interface.CreateRequest;
        #lend: Lend.Interface.CreateRequest;
        #borrow: Borrow.Interface.CreateRequest;
        #exchange: Exchange.Interface.CreateRequest;
        #escrow: Escrow.Interface.CreateRequest;
        #split: Split.Interface.CreateRequest;
        //...
    };

    public type Shared = {
        #throttle : ThrottleVector.Interface.Shared;
        #lend: Lend.Interface.Shared;
        #borrow: Borrow.Interface.Shared;
        #exchange: Exchange.Interface.Shared;
        #escrow: Escrow.Interface.Shared;
        #split: Split.Interface.Shared;
        //...
    };
    
    public type ModifyRequest = {
        #throttle : ThrottleVector.Interface.ModifyRequest;
        #lend: Lend.Interface.ModifyRequest;
        #borrow: Borrow.Interface.ModifyRequest;
        #exchange: Exchange.Interface.ModifyRequest;
        #escrow: Escrow.Interface.ModifyRequest;
        #split: Split.Interface.ModifyRequest;
        //...
    };


    public class VectorModules(m: {
        vec_throttle : ThrottleVector.Mod;
        vec_lend : Lend.Mod;
        vec_borrow : Borrow.Mod;
        vec_exchange : Exchange.Mod;
        vec_escrow : Escrow.Mod;
        vec_split : Split.Mod;
    }) {
    
        public func get(mid :Core.ModuleId, id : Core.NodeId) : Result.Result<Shared, Text> {
            
            if (mid == ThrottleVector.ID) {
                switch(m.vec_throttle.get(id)) {
                    case (#ok(x)) return #ok(#throttle(x));
                    case (#err(x)) return #err(x);
                }
            };
            if (mid == Lend.ID) {
                switch(m.vec_lend.get(id)) {
                    case (#ok(x)) return #ok(#lend(x));
                    case (#err(x)) return #err(x);
                }
            };
            if (mid == Borrow.ID) {
                switch(m.vec_borrow.get(id)) {
                    case (#ok(x)) return #ok(#borrow(x));
                    case (#err(x)) return #err(x);
                }
            };
            if (mid == Exchange.ID) {
                switch(m.vec_exchange.get(id)) {
                    case (#ok(x)) return #ok(#exchange(x));
                    case (#err(x)) return #err(x);
                }
            };
            if (mid == Escrow.ID) {
                switch(m.vec_escrow.get(id)) {
                    case (#ok(x)) return #ok(#escrow(x));
                    case (#err(x)) return #err(x);
                }
            };
            if (mid == Split.ID) {
                switch(m.vec_split.get(id)) {
                    case (#ok(x)) return #ok(#split(x));
                    case (#err(x)) return #err(x);
                }
            };

            #err("Unknown variant");
        };

        public func getDefaults(mid:Core.ModuleId) : CreateRequest {
            if (mid == ThrottleVector.ID) return #throttle(m.vec_throttle.defaults());
            if (mid == Lend.ID) return #lend(m.vec_lend.defaults());
            if (mid == Borrow.ID) return #borrow(m.vec_borrow.defaults());
            if (mid == Exchange.ID) return #exchange(m.vec_exchange.defaults());
            if (mid == Escrow.ID) return #escrow(m.vec_escrow.defaults());
            if (mid == Split.ID) return #split(m.vec_split.defaults());
            Debug.trap("Unknown variant");

        };


        public func sources(mid :Core.ModuleId, id : Core.NodeId) : Core.EndpointsDescription {
            if (mid == ThrottleVector.ID) return m.vec_throttle.sources(id);
            if (mid == Lend.ID) return m.vec_lend.sources(id);
            if (mid == Borrow.ID) return m.vec_borrow.sources(id);
            if (mid == Exchange.ID) return m.vec_exchange.sources(id);
            if (mid == Escrow.ID) return m.vec_escrow.sources(id);
            if (mid == Split.ID) return m.vec_split.sources(id);
            Debug.trap("Unknown variant");
            
        };

        public func destinations(mid :Core.ModuleId, id : Core.NodeId) : Core.EndpointsDescription {
            if (mid == ThrottleVector.ID) return m.vec_throttle.destinations(id);
            if (mid == Lend.ID) return m.vec_lend.destinations(id);
            if (mid == Borrow.ID) return m.vec_borrow.destinations(id);
            if (mid == Exchange.ID) return m.vec_exchange.destinations(id);
            if (mid == Escrow.ID) return m.vec_escrow.destinations(id);
            if (mid == Split.ID) return m.vec_split.destinations(id);
            Debug.trap("Unknown variant");
        };



        public func create(id:Core.NodeId, req : CreateRequest) : Result.Result<Core.ModuleId, Text> {
            
            switch (req) {
                case (#throttle(t)) return m.vec_throttle.create(id, t);
                case (#lend(t)) return m.vec_lend.create(id, t);
                case (#borrow(t)) return m.vec_borrow.create(id, t);
                case (#exchange(t)) return m.vec_exchange.create(id, t);
                case (#escrow(t)) return m.vec_escrow.create(id, t);
                case (#split(t)) return m.vec_split.create(id, t);
                //...
            };
            #err("Unknown variant or mismatch");
        };

        public func modify(mid :Core.ModuleId, id:Core.NodeId, creq : ModifyRequest) : Result.Result<(), Text> {
            switch (creq) {
                case (#throttle(r)) if (mid == ThrottleVector.ID) return m.vec_throttle.modify(id, r);
                case (#lend(r)) if (mid == Lend.ID) return m.vec_lend.modify(id, r);
                case (#borrow(r)) if (mid == Borrow.ID) return m.vec_borrow.modify(id, r);
                case (#exchange(r)) if (mid == Exchange.ID) return m.vec_exchange.modify(id, r);
                case (#escrow(r)) if (mid == Escrow.ID) return m.vec_escrow.modify(id, r);
                case (#split(r)) if (mid == Split.ID) return m.vec_split.modify(id, r);
                //...
            };
            #err("Unknown variant or mismatch");
        };

        public func delete(mid :Core.ModuleId, id:Core.NodeId) : () {
            if (mid == ThrottleVector.ID) return m.vec_throttle.delete(id);
            if (mid == Lend.ID) return m.vec_lend.delete(id);
            if (mid == Borrow.ID) return m.vec_borrow.delete(id);
            if (mid == Exchange.ID) return m.vec_exchange.delete(id);
            if (mid == Escrow.ID) return m.vec_escrow.delete(id);
            if (mid == Split.ID) return m.vec_split.delete(id);
            Debug.trap("Unknown variant");
        };

        public func nodeMeta(mid :Core.ModuleId) : ICRC55.ModuleMeta {
            if (mid == ThrottleVector.ID) return m.vec_throttle.meta();
            if (mid == Lend.ID) return m.vec_lend.meta();
            if (mid == Borrow.ID) return m.vec_borrow.meta();
            if (mid == Exchange.ID) return m.vec_exchange.meta();
            if (mid == Escrow.ID) return m.vec_escrow.meta();
            if (mid == Split.ID) return m.vec_split.meta();
            Debug.trap("Unknown variant");
        };


        public func meta() : [ICRC55.ModuleMeta] {
            [
                m.vec_throttle.meta(),
                m.vec_lend.meta(),
                m.vec_borrow.meta(),
                m.vec_exchange.meta(),
                m.vec_escrow.meta(),
                m.vec_split.meta(),
            //...
            ];
        };

    };
};
