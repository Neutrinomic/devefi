import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Debug "mo:base/Debug";
import U "../src/utils";

module {

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : ICRC55.NodeMeta {
        {
            id = "lend"; // This has to be same as the variant in vec.custom
            name = "Lend";
            description = "Lend X tokens against Y tokens";
            governed_by = "Neutrinite DAO";
            supported_ledgers = all_ledgers;
            pricing = "1 NTN";
        };
    };

    // Internal vector state
    public type Mem = {
        init : {
            ledger_lend : Principal;
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
            ledger_lend : Principal;
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
        let #ic(ledger_lend) = all_ledgers[0] else Debug.trap("No ledgers found");
        let #ic(ledger_collateral) = all_ledgers[1] else Debug.trap("No ledgers found");
        {
            init = {
                ledger_lend;
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
            ledger_lend : Principal;
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
    public func request2Sources(t : Mem, id : Node.NodeId, thiscan : Principal) : Result.Result<[ICRC55.Endpoint], Text> {
        #ok([
            #ic {
                ledger = t.init.ledger_lend;
                account = {
                    owner = thiscan;
                    subaccount = ?Node.port2subaccount({
                        vid = id;
                        flow = #input;
                        id = 0;
                    });
                };
                name = "Lend";
            }
        ]);
    };

    // Mapping of destination node ports
    //
    // Allows you to change destinations and dynamically create new ones based on node state upon creation or modification
    // Fills in the account field when destination accounts are given
    // or leaves them null when not given
    public func request2Destinations(t : Mem, req : [ICRC55.DestinationEndpoint]) : Result.Result<[ICRC55.DestinationEndpoint], Text> {
   
        let #ok(liquidation_account) = U.expectAccount(t.init.ledger_collateral, req, 0) else return #err("Invalid destination 0");
        let #ok(fee_account) = U.expectAccount(t.init.ledger_collateral, req, 1) else return #err("Invalid destination 1");
        let #ok(return_account) = U.expectAccount(t.init.ledger_lend, req, 2) else return #err("Invalid destination 2");

        #ok([
            #ic {
                ledger = t.init.ledger_collateral;
                account = liquidation_account;
                name = "Liquidation";
            },
            #ic {
                ledger = t.init.ledger_collateral;
                account = fee_account;
                name = "Fee";
            },
            #ic {
                ledger = t.init.ledger_lend;
                account = return_account;
                name = "Repayment";
            }
        ]);
    };



};
