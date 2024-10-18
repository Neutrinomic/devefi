
import ICRC55 "../src/ICRC55";
import Node "../src/node";
import ThrottleVector "./modules/throttle";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Lend "./modules/lend";
import Borrow "./modules/borrow";
import Exchange "./modules/exchange";
import Escrow "./modules/escrow";
import Split "./modules/split";
import Mint "./modules/mint";

// THIS SHOULD BE AUTO-GENERATED FILE

module {

    public type CreateRequest = {
        #throttle : ThrottleVector.CreateRequest;
        #lend: Lend.CreateRequest;
        #borrow: Borrow.CreateRequest;
        #exchange: Exchange.CreateRequest;
        #escrow: Escrow.CreateRequest;
        #split: Split.CreateRequest;
        #mint: Mint.CreateRequest;
        //...
    };

    public type Mem = {
        #throttle : ThrottleVector.Mem;
        #lend: Lend.Mem;
        #borrow: Borrow.Mem;
        #exchange: Exchange.Mem;
        #escrow: Escrow.Mem;
        #split: Split.Mem;
        #mint: Mint.Mem;
        //...
    };
    public type Shared = {
        #throttle : ThrottleVector.Shared;
        #lend: Lend.Shared;
        #borrow: Borrow.Shared;
        #exchange: Exchange.Shared;
        #escrow: Escrow.Shared;
        #split: Split.Shared;
        #mint: Mint.Shared;
        //...
    };
    public type ModifyRequest = {
        #throttle : ThrottleVector.ModifyRequest;
        #lend: Lend.ModifyRequest;
        #borrow: Borrow.ModifyRequest;
        #exchange: Exchange.ModifyRequest;
        #escrow: Escrow.ModifyRequest;
        #split: Split.ModifyRequest;
        #mint: Mint.ModifyRequest;
        //...
    };


    public type VMem = {
        var throttle : ?ThrottleVector.VMem;
        var lend : ?Lend.VMem;
        var borrow : ?Borrow.VMem;
        var exchange : ?Exchange.VMem;
        var escrow : ?Escrow.VMem;
        var split : ?Split.VMem;
        var mint : ?Mint.VMem;
        //...
    };

    public func VMem() : VMem {
        {
            var throttle = null;
            var lend = null;
            var borrow = null;
            var exchange = null;
            var escrow = null;
            var split = null;
            var mint = null;
            //...
        };
    };

    public class VectorModules(vmem: VMem) {

        let vec_throttle = ThrottleVector.Module(vmem);
        let vec_lend = Lend.Module(vmem);
        let vec_borrow = Borrow.Module(vmem);
        let vec_exchange = Exchange.Module(vmem);
        let vec_escrow = Escrow.Module(vmem);
        let vec_split = Split.Module(vmem);
        let vec_mint = Mint.Module(vmem);


        public func toShared(node : Mem) : Shared {
            switch (node) {
                case (#throttle(t)) #throttle(vec_throttle.toShared(t));
                case (#lend(t)) #lend(vec_lend.toShared(t));
                case (#borrow(t)) #borrow(vec_borrow.toShared(t));
                case (#exchange(t)) #exchange(vec_exchange.toShared(t));
                case (#escrow(t)) #escrow(vec_escrow.toShared(t));
                case (#split(t)) #split(vec_split.toShared(t));
                case (#mint(t)) #mint(vec_mint.toShared(t));
                //...
            };
        };

        public func getDefaults(id:Text) : CreateRequest {
            switch(id) {
                case ("throttle") #throttle(vec_throttle.defaults());
                case ("lend") #lend(vec_lend.defaults());
                case ("borrow") #borrow(vec_borrow.defaults());
                case ("exchange") #exchange(vec_exchange.defaults());
                case ("escrow") #escrow(vec_escrow.defaults());
                case ("split") #split(vec_split.defaults());
                case ("mint") #mint(vec_mint.defaults());
                case (_) Debug.trap("Unknown variant");
            };
        };

        public func authorAccount(node: Mem) : ICRC55.Account {
            switch (node) {
                case (#throttle(_)) vec_throttle.authorAccount();
                case (#lend(_)) vec_lend.authorAccount();
                case (#borrow(_)) vec_borrow.authorAccount();
                case (#exchange(_)) vec_exchange.authorAccount();
                case (#escrow(_)) vec_escrow.authorAccount();
                case (#split(_)) vec_split.authorAccount();
                case (#mint(_)) vec_mint.authorAccount();
                //...
            };
        
        };

        public func sources(custom : Mem) : Node.PortsDescription {
            switch (custom) {
                case (#throttle(t)) vec_throttle.sources(t);
                case (#lend(t)) vec_lend.sources(t);
                case (#borrow(t)) vec_borrow.sources(t);
                case (#exchange(t)) vec_exchange.sources(t);
                case (#escrow(t)) vec_escrow.sources(t);
                case (#split(t)) vec_split.sources(t);
                case (#mint(t)) vec_mint.sources(t);
                //...
            };
        };

        public func destinations(custom : Mem) : Node.PortsDescription {
            switch (custom) {
                case (#throttle(t)) vec_throttle.destinations(t);
                case (#lend(t)) vec_lend.destinations(t);
                case (#borrow(t)) vec_borrow.destinations(t);
                case (#exchange(t)) vec_exchange.destinations(t);
                case (#escrow(t)) vec_escrow.destinations(t);
                case (#split(t)) vec_split.destinations(t);
                case (#mint(t)) vec_mint.destinations(t);
                //...
            };
        };

        public func create(req : CreateRequest) : Result.Result<Mem, Text> {
            let re = switch (req) {
                case (#throttle(t)) #throttle(vec_throttle.create(t));
                case (#lend(t)) #lend(vec_lend.create(t));
                case (#borrow(t)) #borrow(vec_borrow.create(t));
                case (#exchange(t)) #exchange(vec_exchange.create(t));
                case (#escrow(t)) #escrow(vec_escrow.create(t));
                case (#split(t)) #split(vec_split.create(t));
                case (#mint(t)) #mint(vec_mint.create(t));
                //...
            };
            switch (re) {
                // Ok
                case (#throttle(#ok(t))) #ok(#throttle(t));
                case (#lend(#ok(t))) #ok(#lend(t));
                case (#borrow(#ok(t))) #ok(#borrow(t));
                case (#exchange(#ok(t))) #ok(#exchange(t));
                case (#escrow(#ok(t))) #ok(#escrow(t));
                case (#split(#ok(t))) #ok(#split(t));
                case (#mint(#ok(t))) #ok(#mint(t));
                // Err
                case (#throttle(#err(e))) #err(e);
                case (#lend(#err(e))) #err(e);
                case (#borrow(#err(e))) #err(e);
                case (#exchange(#err(e))) #err(e);
                case (#escrow(#err(e))) #err(e);
                case (#split(#err(e))) #err(e);
                case (#mint(#err(e))) #err(e);
            }
        };

        public func modify(custom : Mem, creq : ModifyRequest) : Result.Result<(), Text> {
            switch (custom, creq) {
                case (#throttle(t), #throttle(r)) vec_throttle.modify(t, r);
                case (#lend(t), #lend(r)) vec_lend.modify(t, r);
                case (#borrow(t), #borrow(r)) vec_borrow.modify(t, r);
                case (#exchange(t), #exchange(r)) vec_exchange.modify(t, r);
                case (#escrow(t), #escrow(r)) vec_escrow.modify(t, r);
                case (#split(t), #split(r)) vec_split.modify(t, r);
                case (#mint(t), #mint(r)) vec_mint.modify(t, r);
                case (_) #err("You need to provide same id-variant");
                //...
            };
        };

        public func nodeMeta(custom: Mem) : ICRC55.NodeMeta {
            switch (custom) {
                case (#throttle(_t)) vec_throttle.meta();
                case (#lend(_t)) vec_lend.meta();
                case (#borrow(_t)) vec_borrow.meta();
                case (#exchange(_t)) vec_exchange.meta();
                case (#escrow(_t)) vec_escrow.meta();
                case (#split(_t)) vec_split.meta();
                case (#mint(_t)) vec_mint.meta();
                //...
            };
        };

        public func nodeBilling(custom: Mem) : ICRC55.Billing {
            switch (custom) {
                case (#throttle(_t)) vec_throttle.billing();
                case (#lend(_t)) vec_lend.billing();
                case (#borrow(_t)) vec_borrow.billing();
                case (#exchange(_t)) vec_exchange.billing();
                case (#escrow(_t)) vec_escrow.billing();
                case (#split(_t)) vec_split.billing();
                case (#mint(_t)) vec_mint.billing();
                //...
            };
        };

        public func meta() : [ICRC55.NodeMeta] {
            [
                vec_throttle.meta(),
                vec_lend.meta(),
                vec_borrow.meta(),
                vec_exchange.meta(),
                vec_escrow.meta(),
                vec_split.meta(),
                vec_mint.meta(),
            //...
            ];
        };

    };
};
