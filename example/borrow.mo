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
            id = "borrow"; // This has to be same as the variant in vec.custom
            name = "Borrow";
            description = "Borrow X tokens while providing Y tokens collateral";
            supported_ledgers = all_ledgers;
            pricing = "1 NTN";
            version = #alpha;
        };
    };

    // Internal vector state
    public type Mem = {
        init : {
            ledger_borrow : Principal;
            ledger_collateral : Principal;
        };
        variables : {
            var interest : Nat;
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {
            ledger_borrow : Principal;
            ledger_collateral : Principal;
        };
        variables : {
            interest : Nat;
        };
    };

    // Create state from request
    public func createRequest2Mem(t : CreateRequest) : Mem {
        {
            init = t.init;
            variables = {
                var interest = t.variables.interest;
            };
            internals = {};
        };
    };

    public func defaults(all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
        let #ic(ledger_borrow) = all_ledgers[0] else Debug.trap("No ledgers found");
        let #ic(ledger_collateral) = all_ledgers[1] else Debug.trap("No ledgers found");
        {
            init = {
                ledger_borrow;
                ledger_collateral;
            };
            variables = {
                interest = 20;
            };
        };
    };

    // Modify request
    public type ModifyRequest = {
        interest : Nat;
    };

    // How does the modify request change memory
    public func modifyRequestMut(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
        mem.variables.interest := t.interest;
        #ok();
    };

    // Public shared state
    public type Shared = {
        init : {
            ledger_borrow : Principal;
            ledger_collateral : Principal;
        };
        variables : {
            interest : Nat;
        };
        internals : {};
    };

    // Convert memory to shared
    public func toShared(t : Mem) : Shared {
        {
            init = t.init;
            variables = {
                interest = t.variables.interest;
            };
            internals = {};
        };
    };

    // Mapping of source node ports
    public func request2Sources(t : Mem, id : Node.NodeId, thiscan : Principal, sources:[ICRC55.Endpoint]) : Result.Result<[ICRC55.Endpoint], Text> {
        let #ok(a0) = U.expectSourceAccount(t.init.ledger_collateral, thiscan, sources, 0) else return #err("Invalid source 0");
        let #ok(a1) = U.expectSourceAccount(t.init.ledger_collateral, thiscan, sources, 1) else return #err("Invalid source 1");

        #ok([
            #ic {
                ledger = t.init.ledger_collateral;
                account = Option.get(a0, {
                    owner = thiscan;
                    subaccount = ?Node.port2subaccount({
                        vid = id;
                        flow = #input;
                        id = 0;
                    });
                });
                name = "Collateral";
            },
            #ic {
                ledger = t.init.ledger_borrow;
                account = Option.get(a1, {
                    owner = thiscan;
                    subaccount = ?Node.port2subaccount({
                        vid = id;
                        flow = #input;
                        id = 1;
                    });
                });
                name = "Repayment";
            }
        ]);
    };

    // Mapping of destination node ports
    //
    // Allows you to change destinations and dynamically create new ones based on node state upon creation or modification
    // Fills in the account field when destination accounts are given
    // or leaves them null when not given
    public func request2Destinations(t : Mem, req : [ICRC55.DestinationEndpoint]) : Result.Result<[ICRC55.DestinationEndpoint], Text> {
   
        let #ok(borrow_account) = U.expectDestinationAccount(t.init.ledger_borrow, req, 0) else return #err("Invalid destination 0");
        let #ok(return_account) = U.expectDestinationAccount(t.init.ledger_collateral, req, 1) else return #err("Invalid destination 1");

        #ok([
            #ic {
                ledger = t.init.ledger_borrow;
                account = borrow_account;
                name = "";
            },
            #ic {
                ledger = t.init.ledger_collateral;
                account = return_account;
                name = "Collateral";
            }
        ]);
    };



};
