
import ICRC55 "../src/ICRC55";
import Node "../src/node";
import ThrottleVector "./throttle";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Lend "./lend";
import Borrow "./borrow";
import Exchange "./exchange";
import Escrow "./escrow";
import Split "./split";
import Mint "./mint";

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

    public func toShared(node : Mem) : Shared {
        switch (node) {
            case (#throttle(t)) #throttle(ThrottleVector.toShared(t));
            case (#lend(t)) #lend(Lend.toShared(t));
            case (#borrow(t)) #borrow(Borrow.toShared(t));
            case (#exchange(t)) #exchange(Exchange.toShared(t));
            case (#escrow(t)) #escrow(Escrow.toShared(t));
            case (#split(t)) #split(Split.toShared(t));
            case (#mint(t)) #mint(Mint.toShared(t));
            //...
        };
    };

    public func getDefaults(id:Text) : CreateRequest {
        switch(id) {
            case ("throttle") #throttle(ThrottleVector.defaults());
            case ("lend") #lend(Lend.defaults());
            case ("borrow") #borrow(Borrow.defaults());
            case ("exchange") #exchange(Exchange.defaults());
            case ("escrow") #escrow(Escrow.defaults());
            case ("split") #split(Split.defaults());
            case ("mint") #mint(Mint.defaults());
            case (_) Debug.trap("Unknown variant");
        };
    };

    public func authorAccount(node: Mem) : ICRC55.Account {
        switch (node) {
            case (#throttle(_)) ThrottleVector.authorAccount();
            case (#lend(_)) Lend.authorAccount();
            case (#borrow(_)) Borrow.authorAccount();
            case (#exchange(_)) Exchange.authorAccount();
            case (#escrow(_)) Escrow.authorAccount();
            case (#split(_)) Split.authorAccount();
            case (#mint(_)) Mint.authorAccount();
            //...
        };
     
    };

    public func sources(custom : Mem) : Node.PortsDescription {
        switch (custom) {
            case (#throttle(t)) ThrottleVector.sources(t);
            case (#lend(t)) Lend.sources(t);
            case (#borrow(t)) Borrow.sources(t);
            case (#exchange(t)) Exchange.sources(t);
            case (#escrow(t)) Escrow.sources(t);
            case (#split(t)) Split.sources(t);
            case (#mint(t)) Mint.sources(t);
            //...
        };
    };

    public func destinations(custom : Mem) : Node.PortsDescription {
        switch (custom) {
            case (#throttle(t)) ThrottleVector.destinations(t);
            case (#lend(t)) Lend.destinations(t);
            case (#borrow(t)) Borrow.destinations(t);
            case (#exchange(t)) Exchange.destinations(t);
            case (#escrow(t)) Escrow.destinations(t);
            case (#split(t)) Split.destinations(t);
            case (#mint(t)) Mint.destinations(t);
            //...
        };
    };

    public func create(req : CreateRequest) : Mem {
        switch (req) {
            case (#throttle(t)) #throttle(ThrottleVector.create(t));
            case (#lend(t)) #lend(Lend.create(t));
            case (#borrow(t)) #borrow(Borrow.create(t));
            case (#exchange(t)) #exchange(Exchange.create(t));
            case (#escrow(t)) #escrow(Escrow.create(t));
            case (#split(t)) #split(Split.create(t));
            case (#mint(t)) #mint(Mint.create(t));
            //...
        };
    };

    public func modify(custom : Mem, creq : ModifyRequest) : Result.Result<(), Text> {
        switch (custom, creq) {
            case (#throttle(t), #throttle(r)) ThrottleVector.modify(t, r);
            case (#lend(t), #lend(r)) Lend.modify(t, r);
            case (#borrow(t), #borrow(r)) Borrow.modify(t, r);
            case (#exchange(t), #exchange(r)) Exchange.modify(t, r);
            case (#escrow(t), #escrow(r)) Escrow.modify(t, r);
            case (#split(t), #split(r)) Split.modify(t, r);
            case (#mint(t), #mint(r)) Mint.modify(t, r);
            case (_) #err("You need to provide same id-variant");
            //...
        };
    };

    public func nodeMeta(custom: Mem) : ICRC55.NodeMeta {
        switch (custom) {
            case (#throttle(_t)) ThrottleVector.meta();
            case (#lend(_t)) Lend.meta();
            case (#borrow(_t)) Borrow.meta();
            case (#exchange(_t)) Exchange.meta();
            case (#escrow(_t)) Escrow.meta();
            case (#split(_t)) Split.meta();
            case (#mint(_t)) Mint.meta();
            //...
        };
    };

    public func nodeBilling(custom: Mem) : ICRC55.Billing {
        switch (custom) {
            case (#throttle(_t)) ThrottleVector.billing();
            case (#lend(_t)) Lend.billing();
            case (#borrow(_t)) Borrow.billing();
            case (#exchange(_t)) Exchange.billing();
            case (#escrow(_t)) Escrow.billing();
            case (#split(_t)) Split.billing();
            case (#mint(_t)) Mint.billing();
            //...
        };
    };

    public func meta() : [ICRC55.NodeMeta] {
        [
            ThrottleVector.meta(),
            Lend.meta(),
            Borrow.meta(),
            Exchange.meta(),
            Escrow.meta(),
            Split.meta(),
            Mint.meta(),
        //...
        ];
    };
};
