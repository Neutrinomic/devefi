import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";

import Debug "mo:base/Debug";
import U "../src/utils";
import Option "mo:base/Option";
import Billing "./billing_all";

module {

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : ICRC55.NodeMeta {
        let billing = Billing.get(U.onlyICLedger(all_ledgers[0]));
        {
            billing
            with
            id = "mint"; // This has to be same as the variant in vec.custom
            name = "Mint";
            description = "Mint X tokens for Y tokens";
            supported_ledgers = all_ledgers;
            pricing = "1 NTN";
            version = #alpha;
        };
    };

    // Internal vector state
    public type Mem = {
        init : {
            ledger_mint : Principal;
            ledger_for : Principal;
        };
        variables : {
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {
            ledger_mint: Principal;
            ledger_for: Principal;
        };
        variables : {
        };
    };

    // Create state from request
    public func createRequest2Mem(t : CreateRequest) : Mem {
        {
            init = t.init;
            variables = {
            };
            internals = {};
        };
    };

    public func defaults(all_ledgers : [ICRC55.SupportedLedger]) : CreateRequest {
        let #ic(ledger_mint) = all_ledgers[0] else Debug.trap("No ledgers found");
        let #ic(ledger_for) = all_ledgers[1] else Debug.trap("No ledgers found");
        {
            init = {
                ledger_mint;
                ledger_for;
            };
            variables = {
            };
        };
    };

    // Modify request
    public type ModifyRequest = {
    };

    // How does the modify request change memory
    public func modifyRequestMut(_mem : Mem, _t : ModifyRequest) : Result.Result<(), Text> {
        #ok();
    };

    // Public shared state
    public type Shared = {
        init : {
            ledger_mint : Principal;
            ledger_for : Principal;
        };
        variables : {
        };
        internals : {};
    };

    // Convert memory to shared
    public func toShared(t : Mem) : Shared {
        {
            init = t.init;
            variables = {
            };
            internals = {};
        };
    };

    // Mapping of source node ports
    public func request2Sources(t : Mem, id : Node.NodeId, thiscan : Principal, sources:[ICRC55.Endpoint]) : Result.Result<[ICRC55.Endpoint], Text> {
        let #ok(a0) = U.expectSourceAccount(t.init.ledger_for, thiscan, sources, 0) else return #err("Invalid source 0");

        #ok([
            #ic {
                ledger = t.init.ledger_for;
                account = Option.get(a0, {
                    owner = thiscan;
                    subaccount = ?Node.port2subaccount({
                        vid = id;
                        flow = #input;
                        id = 0;
                    });
                });
                name = "";
            }
        ]);
    };

    // Mapping of destination node ports
    //
    // Allows you to change destinations and dynamically create new ones based on node state upon creation or modification
    // Fills in the account field when destination accounts are given
    // or leaves them null when not given
    public func request2Destinations(t : Mem, req : [ICRC55.DestinationEndpoint]) : Result.Result<[ICRC55.DestinationEndpoint], Text> {

        let #ok(mint_account) = U.expectDestinationAccount(t.init.ledger_mint, req, 0) else return #err("Invalid destination 0");   
        let #ok(for_account) = U.expectDestinationAccount(t.init.ledger_for, req, 1) else return #err("Invalid destination 1");

        

        #ok([
            #ic {
                ledger = t.init.ledger_mint;
                account = mint_account;
                name = "Mint";
            },
            #ic {
                ledger = t.init.ledger_for;
                account = for_account;
                name = "";
            }
        ]);
    };



};
