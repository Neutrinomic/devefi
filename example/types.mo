
import ICRC55 "../src/ICRC55";
import Node "../src/node";
import ThrottleVector "./throttle";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Lending "./lending";

module {

    public type CreateRequest = {
        #throttle : ThrottleVector.CreateRequest;
        #lend: Lending.CreateRequest;
        //...
    };
    public type Mem = {
        #throttle : ThrottleVector.Mem;
        #lend: Lending.Mem;
        //...
    };
    public type Shared = {
        #throttle : ThrottleVector.Shared;
        #lend: Lending.Shared;
        //...
    };
    public type ModifyRequest = {
        #throttle : ThrottleVector.ModifyRequest;
        #lend: Lending.ModifyRequest;
        //...
    };

    public func toShared(node : Mem) : Shared {
        switch (node) {
            case (#throttle(t)) #throttle(ThrottleVector.toShared(t));
            case (#lend(t)) #lend(Lending.toShared(t));
            //...
        };
    };

    public func getDefaults(id:Text, all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
        switch(id) {
            case ("throttle") #throttle(ThrottleVector.defaults(all_ledgers));
            case ("lend") #lend(Lending.defaults(all_ledgers));
            case (_) Debug.trap("Unknown variant");
        };
    };

    public func sourceMap(id: Node.NodeId, custom : Mem, thiscan : Principal) : Result.Result<[ICRC55.Endpoint], Text> {
        switch (custom) {
            case (#throttle(t)) ThrottleVector.request2Sources(t, id, thiscan);
            case (#lend(t)) Lending.request2Sources(t, id, thiscan);
            //...
        };
    };

    public func destinationMap(custom : Mem,  destinationsProvided: [ICRC55.DestinationEndpoint] ) : Result.Result<[ICRC55.DestinationEndpoint], Text> {
        switch (custom) {
            case (#throttle(t)) ThrottleVector.request2Destinations(t, destinationsProvided);
            case (#lend(t)) Lending.request2Destinations(t, destinationsProvided);
            //...
        };
    };

    public func createRequest2Mem(req : CreateRequest) : Mem {
        switch (req) {
            case (#throttle(t)) #throttle(ThrottleVector.createRequest2Mem(t));
            case (#lend(t)) #lend(Lending.createRequest2Mem(t));
            //...
        };
    };

    public func modifyRequestMut(custom : Mem, creq : ModifyRequest) : Result.Result<(), Text> {
        switch (custom, creq) {
            case (#throttle(t), #throttle(r)) ThrottleVector.modifyRequestMut(t, r);
            case (#lend(t), #lend(r)) Lending.modifyRequestMut(t, r);
            case (_) Debug.trap("You need to provide same id-variant");
            //...
        };
    };

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : [ICRC55.NodeMeta] {
        [
            ThrottleVector.meta(all_ledgers),
            Lending.meta(all_ledgers),
        //...
        ];
    };
};
