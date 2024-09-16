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
            id = "mint"; // This has to be same as the variant in vec.custom
            name = "Mint";
            description = "Mint X tokens for Y tokens";
            governed_by = "Neutrinite DAO";
            supported_ledgers = all_ledgers;
            pricing = "1 NTN";
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
    public func modifyRequestMut(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
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
    public func request2Sources(t : Mem, id : Node.NodeId, thiscan : Principal) : Result.Result<[ICRC55.Endpoint], Text> {
        #ok([
            #ic {
                ledger = t.init.ledger_for;
                account = {
                    owner = thiscan;
                    subaccount = ?Node.port2subaccount({
                        vid = id;
                        flow = #input;
                        id = 0;
                    });
                };
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

        let #ok(mint_account) = U.expectAccount(t.init.ledger_mint, req, 0) else return #err("Invalid destination 0");   
        let #ok(for_account) = U.expectAccount(t.init.ledger_for, req, 1) else return #err("Invalid destination 1");

        

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
