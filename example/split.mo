import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Debug "mo:base/Debug";
import U "../src/utils";
import Nat "mo:base/Nat";

module {

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : ICRC55.NodeMeta {
        {
            id = "split"; // This has to be same as the variant in vec.custom
            name = "Split";
            description = "Split X tokens";
            governed_by = "Neutrinite DAO";
            supported_ledgers = all_ledgers;
            pricing = "1 NTN";
        };
    };

    // Internal vector state
    public type Mem = {
        init : {
            ledger : Principal;
        };
        variables : {
            var split : [Nat];
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {
            ledger : Principal;
        };
        variables : {
            split : [Nat];
        };
    };

    // Create state from request
    public func createRequest2Mem(t : CreateRequest) : Mem {
        {
            init = t.init;
            variables = {
                var split = t.variables.split;
            };
            internals = {};
        };
    };

    public func defaults(all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
        let #ic(ledger) = all_ledgers[0] else Debug.trap("No ledgers found");
        {
            init = {
                ledger;
            };
            variables = {
                split = [50, 50];
            };
        };
    };

    // Modify request
    public type ModifyRequest = {
        split : [Nat];
    };

    // How does the modify request change memory
    public func modifyRequestMut(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
        mem.variables.split := t.split;
        #ok();
    };

    // Public shared state
    public type Shared = {
        init : {
            ledger : Principal;
        };
        variables : {
            split : [Nat];
        };
        internals : {};
    };

    // Convert memory to shared
    public func toShared(t : Mem) : Shared {
        {
            init = t.init;
            variables = {
                split = t.variables.split;
            };
            internals = {};
        };
    };

    // Mapping of source node ports
    public func request2Sources(t : Mem, id : Node.NodeId, thiscan : Principal) : Result.Result<[ICRC55.Endpoint], Text> {
        #ok(
            Array.tabulate<ICRC55.Endpoint>(
                1,
                func(idx : Nat) = #ic {
                    ledger = t.init.ledger;
                    account = {
                        owner = thiscan;
                        subaccount = ?Node.port2subaccount({
                            vid = id;
                            flow = #input;
                            id = Nat8.fromNat(idx);
                        });
                    };
                    name = "";
                },
            )
        );
    };

    // Mapping of destination node ports
    //
    // Allows you to change destinations and dynamically create new ones based on node state upon creation or modification
    // Fills in the account field when destination accounts are given
    // or leaves them null when not given
    public func request2Destinations(t : Mem, req : [ICRC55.DestinationEndpoint]) : Result.Result<[ICRC55.DestinationEndpoint], Text> {

        #ok(
            Array.tabulate<ICRC55.DestinationEndpoint>(
                t.variables.split.size(),
                func(idx : Nat) {
                    let acc = switch (U.expectAccount(t.init.ledger, req, idx)) {
                        case (#ok(acc)) acc;
                        case (#err()) null;
                    };
                    #ic {
                        ledger = t.init.ledger;
                        account = acc;
                        name = Nat.toText(t.variables.split[idx]);
                    };
                },
            )
        );
    };

};
