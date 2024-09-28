import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";

import Debug "mo:base/Debug";
import U "../src/utils";

module {

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : ICRC55.NodeMeta {
        {
            id = "exchange"; // This has to be same as the variant in vec.custom
            name = "Exchange";
            description = "Exchange X for Y";
            supported_ledgers = all_ledgers;
            pricing = "1 NTN";
            version = #alpha;
        };
    };

    // Internal vector state
    public type Mem = {
        init : {
            ledger_from : Principal;
            ledger_to : Principal;
        };
        variables : {
            var max_per_sec : Nat;
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {
            ledger_from : Principal;
            ledger_to : Principal;
        };
        variables : {
            max_per_sec : Nat;
        };
    };

    // Create state from request
    public func createRequest2Mem(t : CreateRequest) : Mem {
        {
            init = t.init;
            variables = {
                var max_per_sec = t.variables.max_per_sec;
            };
            internals = {};
        };
    };

    public func defaults(all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
        let #ic(ledger_from) = all_ledgers[0] else Debug.trap("No ledgers found");
        let #ic(ledger_to) = all_ledgers[1] else Debug.trap("No ledgers found");
        {
            init = {
                ledger_from;
                ledger_to;
            };
            variables = {
                max_per_sec = 100000000;
            };
        };
    };

    // Modify request
    public type ModifyRequest = {
        max_per_sec : Nat;
    };

    // How does the modify request change memory
    public func modifyRequestMut(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
        mem.variables.max_per_sec := t.max_per_sec;
        #ok();
    };

    // Public shared state
    public type Shared = {
        init : {
            ledger_from : Principal;
            ledger_to : Principal;
        };
        variables : {
            max_per_sec : Nat;
        };
        internals : {};
    };

    // Convert memory to shared
    public func toShared(t : Mem) : Shared {
        {
            init = t.init;
            variables = {
                max_per_sec = t.variables.max_per_sec;
            };
            internals = {};
        };
    };

    // Mapping of source node ports
    public func request2Sources(t : Mem, id : Node.NodeId, thiscan : Principal) : Result.Result<[ICRC55.Endpoint], Text> {
        #ok([
            #ic {
                ledger = t.init.ledger_from;
                account = {
                    owner = thiscan;
                    subaccount = ?Node.port2subaccount({
                        vid = id;
                        flow = #input;
                        id = 0;
                    });
                };
                name = "From";
            }
        ]);
    };

    // Mapping of destination node ports
    //
    // Allows you to change destinations and dynamically create new ones based on node state upon creation or modification
    // Fills in the account field when destination accounts are given
    // or leaves them null when not given
    public func request2Destinations(t : Mem, req : [ICRC55.DestinationEndpoint]) : Result.Result<[ICRC55.DestinationEndpoint], Text> {
   
        let #ok(to_account) = U.expectAccount(t.init.ledger_to, req, 0) else return #err("Invalid destination 0");

        #ok([
            #ic {
                ledger = t.init.ledger_to;
                account = to_account;
                name = "To";
            }
        ]);
    };



};
