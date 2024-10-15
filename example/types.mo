
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

    public func getDefaults(id:Text, all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
        switch(id) {
            case ("throttle") #throttle(ThrottleVector.defaults(all_ledgers));
            case ("lend") #lend(Lend.defaults(all_ledgers));
            case ("borrow") #borrow(Borrow.defaults(all_ledgers));
            case ("exchange") #exchange(Exchange.defaults(all_ledgers));
            case ("escrow") #escrow(Escrow.defaults(all_ledgers));
            case ("split") #split(Split.defaults(all_ledgers));
            case ("mint") #mint(Mint.defaults(all_ledgers));
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

    public func createRequest2Mem(req : CreateRequest) : Mem {
        switch (req) {
            case (#throttle(t)) #throttle(ThrottleVector.createRequest2Mem(t));
            case (#lend(t)) #lend(Lend.createRequest2Mem(t));
            case (#borrow(t)) #borrow(Borrow.createRequest2Mem(t));
            case (#exchange(t)) #exchange(Exchange.createRequest2Mem(t));
            case (#escrow(t)) #escrow(Escrow.createRequest2Mem(t));
            case (#split(t)) #split(Split.createRequest2Mem(t));
            case (#mint(t)) #mint(Mint.createRequest2Mem(t));
            //...
        };
    };

    public func modifyRequestMut(custom : Mem, creq : ModifyRequest) : Result.Result<(), Text> {
        switch (custom, creq) {
            case (#throttle(t), #throttle(r)) ThrottleVector.modifyRequestMut(t, r);
            case (#lend(t), #lend(r)) Lend.modifyRequestMut(t, r);
            case (#borrow(t), #borrow(r)) Borrow.modifyRequestMut(t, r);
            case (#exchange(t), #exchange(r)) Exchange.modifyRequestMut(t, r);
            case (#escrow(t), #escrow(r)) Escrow.modifyRequestMut(t, r);
            case (#split(t), #split(r)) Split.modifyRequestMut(t, r);
            case (#mint(t), #mint(r)) Mint.modifyRequestMut(t, r);
            case (_) Debug.trap("You need to provide same id-variant");
            //...
        };
    };

    public func nodeMeta(custom: Mem, all_ledgers : [ICRC55.SupportedLedger]) : ICRC55.NodeMeta {
        switch (custom) {
            case (#throttle(_t)) ThrottleVector.meta(all_ledgers);
            case (#lend(_t)) Lend.meta(all_ledgers);
            case (#borrow(_t)) Borrow.meta(all_ledgers);
            case (#exchange(_t)) Exchange.meta(all_ledgers);
            case (#escrow(_t)) Escrow.meta(all_ledgers);
            case (#split(_t)) Split.meta(all_ledgers);
            case (#mint(_t)) Mint.meta(all_ledgers);
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

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : [ICRC55.NodeMeta] {
        [
            ThrottleVector.meta(all_ledgers),
            Lend.meta(all_ledgers),
            Borrow.meta(all_ledgers),
            Exchange.meta(all_ledgers),
            Escrow.meta(all_ledgers),
            Split.meta(all_ledgers),
            Mint.meta(all_ledgers),
        //...
        ];
    };
};
