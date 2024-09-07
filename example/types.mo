
import ICRC55 "../src/ICRC55";
import Node "../src/node";
import ThrottleVector "./throttle";
import Result "mo:base/Result";

module {

    public type CreateRequest = {
        #throttle : ThrottleVector.CreateRequest;
        //...
    };
    public type Mem = {
        #throttle : ThrottleVector.Mem;
        //...
    };
    public type Shared = {
        #throttle : ThrottleVector.Shared;
        //...
    };
    public type ModifyRequest = {
        #throttle : ThrottleVector.ModifyRequest;
        //...
    };

    public func toShared(node : Mem) : Shared {
        switch (node) {
            case (#throttle(t)) #throttle(ThrottleVector.toShared(t));
            //...
        };
    };

    public func sourceMap(id: Node.NodeId, custom : Mem, thiscan : Principal) : Result.Result<[ICRC55.Endpoint], Text> {
        switch (custom) {
            case (#throttle(t)) ThrottleVector.Request2Sources(t, id, thiscan);
            //...
        };
    };

    public func destinationMap(custom : Mem,  destinationsProvided: [ICRC55.DestinationEndpoint] ) : Result.Result<[ICRC55.DestinationEndpoint], Text> {
        switch (custom) {
            case (#throttle(t)) ThrottleVector.Request2Destinations(t, destinationsProvided);
            //...
        };
    };

    public func createRequest2Mem(req : CreateRequest) : Mem {
        switch (req) {
            case (#throttle(t)) #throttle(ThrottleVector.CreateRequest2Mem(t));
            //...
        };
    };

    public func modifyRequestMut(custom : Mem, creq : ModifyRequest) : Result.Result<(), Text> {
        switch (custom, creq) {
            case (#throttle(t), #throttle(r)) ThrottleVector.ModifyRequestMut(t, r);
            //...
        };
    };

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : [ICRC55.NodeMeta] {
        [
            ThrottleVector.meta(all_ledgers),
        //...
        ];
    };
};
