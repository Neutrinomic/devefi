import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import ICRC55 "../src/ICRC55";
import Node "../src/node";

module {

    public type NodeId = Nat32;

    public type NumVariant = {
        #fixed:Nat64;
        #rnd:{min:Nat64; max:Nat64};
    };


    public type CustomNodeRequest = {
        // ledger: Principal;
        // destination: ?ICRC55.Account;
        init: {
            ledger: Principal;
        };
        variables : {
            interval_sec: NumVariant;
            max_amount: NumVariant;
        };
    };

    public type CustomNode = {
        init : {
            ledger: Principal;
        };
        variables : {
            var interval_sec: NumVariant;
            var max_amount: NumVariant;
        };
        internals : {
            var wait_until_ts : Nat64;
        };
    };

    public type CustomNodeShared = {
        init : {
            ledger: Principal;
        };
        variables: {
            interval_sec: NumVariant;
            max_amount: NumVariant;
        };
        internals : {
            wait_until_ts: Nat64;
        }
    };

    public module CustomNode {
        public func toShared(node: CustomNode) : CustomNodeShared {
            {
                init = node.init;
                variables = {
                    interval_sec = node.variables.interval_sec;
                    max_amount = node.variables.max_amount;
                };
                internals = {
                    wait_until_ts = node.internals.wait_until_ts;
                };
            }
        };
    };


    public type CreateNode = {
        #ok: Node.NodeId;
        #err: Text;
    };

    

}