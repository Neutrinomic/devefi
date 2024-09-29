import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Debug "mo:base/Debug";
import U "../src/utils";
import Option "mo:base/Option";

module {

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : ICRC55.NodeMeta {
        {
            id = "throttle"; // This has to be same as the variant in vec.custom
            name = "Throttle";
            description = "Send X tokens every Y seconds";
            supported_ledgers = all_ledgers;
            pricing = "1 NTN";
            version = #alpha;
        }
    };

    // Internal vector state
    public type Mem = {
        init : {
            ledger : Principal;
        };
        variables : {
            var interval_sec : NumVariant;
            var max_amount : NumVariant;
        };
        internals : {
            var wait_until_ts : Nat64;
        };
    };

    // Create request
    public type CreateRequest = {
        init : {
            ledger : Principal;
        };
        variables : {
            interval_sec : NumVariant;
            max_amount : NumVariant;
        };
    };

    // Create state from request
    public func createRequest2Mem(t : CreateRequest) : Mem {
        {
            init = t.init;
            variables = {
                var interval_sec = t.variables.interval_sec;
                var max_amount = t.variables.max_amount;
            };
            internals = {
                var wait_until_ts = 0;
            };
        };
    };


    public func defaults(all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
        let #ic(ledger) = all_ledgers[0] else Debug.trap("No ledgers found");
        {
            init = {
                ledger;
            };
            variables = {
                interval_sec = #fixed(10);
                max_amount = #fixed(100_0000);
            };
        };
    };

    // Modify request
    public type ModifyRequest = {
        interval_sec : NumVariant;
        max_amount : NumVariant;
    };

    // How does the modify request change memory
    public func modifyRequestMut(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
        mem.variables.interval_sec := t.interval_sec;
        mem.variables.max_amount := t.max_amount;
        #ok();
    };



    // Public shared state
    public type Shared = {
        init : {
            ledger : Principal;
        };
        variables : {
            interval_sec : NumVariant;
            max_amount : NumVariant;
        };
        internals : {
            wait_until_ts : Nat64;
        };
    };

    // Convert memory to shared 
    public func toShared(t : Mem) : Shared {
        {
            init = t.init;
            variables = {
                interval_sec = t.variables.interval_sec;
                max_amount = t.variables.max_amount;
            };
            internals = {
                wait_until_ts = t.internals.wait_until_ts;
            };
        };
    };

    // Mapping of source node ports
    public func request2Sources(t : Mem, id : Node.NodeId, thiscan : Principal, sources:[ICRC55.Endpoint]) : Result.Result<[ICRC55.Endpoint], Text> {
        let #ok(a0) = U.expectSourceAccount(t.init.ledger, thiscan, sources, 0) else return #err("Invalid source 0");

        #ok(
            Array.tabulate<ICRC55.Endpoint>(1, func(idx:Nat) = #ic {
                ledger = t.init.ledger;
                account = Option.get(a0, {
                    owner = thiscan;
                    subaccount = ?Node.port2subaccount({
                        vid = id;
                        flow = #input;
                        id = Nat8.fromNat(idx);
                    });
                });
                name = "";
            })
        );
    };

    // Mapping of destination node ports
    //
    // Allows you to change destinations and dynamically create new ones based on node state upon creation or modification
    // Fills in the account field when destination accounts are given
    // or leaves them null when not given
    public func request2Destinations(t : Mem, req:[ICRC55.DestinationEndpoint]) : Result.Result<[ICRC55.DestinationEndpoint], Text> {
        let #ok(acc) = U.expectDestinationAccount(t.init.ledger, req, 0) else return #err("Invalid destination 0");

        #ok([
            #ic {
                ledger = t.init.ledger;
                account = acc;
                name = "";
            }
        ]);
    };

    // Other custom types
    public type NumVariant = {
        #fixed : Nat64;
        #rnd : { min : Nat64; max : Nat64 };
    };

    

};
