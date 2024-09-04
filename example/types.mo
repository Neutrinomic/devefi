import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import ICRC55 "../src/ICRC55";
import Node "../src/node";
import U "../src/utils";
import ThrottleVector "./throttle";

module {

    public type NodeId = Node.NodeId;

    public type CustomNodeRequest = {
        #throttle : ThrottleVector.Request;
    };
    public type CustomNode = {
        #throttle : ThrottleVector.Mem;
    };
    public type CustomNodeShared = {
        #throttle : ThrottleVector.Shared;
    };

    public module CustomNode {
        public func toShared(node : CustomNode) : CustomNodeShared {
            switch (node) {
                case (#throttle(t)) #throttle(ThrottleVector.toShared(t));
            };
        };
    };

    public type GetNodeResponse = ICRC55.GetNodeResponse and {
        custom : CustomNodeShared;
    };
   
    public func requestToNode(req : ICRC55.NodeRequest, creq : CustomNodeRequest, id : Node.NodeId, thiscan : Principal) : Node.NodeMem<CustomNode> {
        let (sources, custom : CustomNode) = switch (creq) {
            case (#throttle(t)) {
                (
                    [#ic {
                        ledger = t.init.ledger;
                        account = {
                            owner = thiscan;
                            subaccount = ?Node.port2subaccount({
                                vid = id;
                                flow = #input;
                                id = 0;
                            });
                        };
                    }],
                    #throttle({
                        init = t.init;
                        internals = {
                            var wait_until_ts = 0;
                        };
                        variables = {
                            var interval_sec = t.variables.interval_sec;
                            var max_amount = t.variables.max_amount;
                        };
                    }:ThrottleVector.Mem),
                );
            };
        };

        let node : Node.NodeMem<CustomNode> = {
            sources;
            destinations = req.destinations;
            created = U.now();
            modified = U.now();
            controllers = req.controllers;
            custom;
            var expires = null;
        };
        node;
    };

};
