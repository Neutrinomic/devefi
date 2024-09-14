import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Debug "mo:base/Debug";

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
            ledger_for : Principal;
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
            ledger_for : Principal;
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
        let #ic(ledger_for) = all_ledgers[1] else Debug.trap("No ledgers found");
        {
            init = {
                ledger_lend;
                ledger_for;
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
            ledger_for : Principal;
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
            }
        ]);
    };

    // Mapping of destination node ports
    //
    // Allows you to change destinations and dynamically create new ones based on node state upon creation or modification
    // Fills in the account field when destination accounts are given
    // or leaves them null when not given
    public func request2Destinations(t : Mem, req : [ICRC55.DestinationEndpoint]) : Result.Result<[ICRC55.DestinationEndpoint], Text> {
        let liquidation_account = switch(expectAccount(t.init.ledger_for, req, 0)) {
            case (#ok(account)) account;
            case (#err(e)) return #err(e);
        };
        let fee_account = switch(expectAccount(t.init.ledger_for, req, 1)) {
            case (#ok(account)) account;
            case (#err(e)) return #err(e);
        };

        #ok([
            #ic {
                ledger = t.init.ledger_for;
                account = liquidation_account;
            },
            #ic {
                ledger = t.init.ledger_for;
                account = fee_account;
            }
        ]);
    };

    private func expectAccount(expected_ledger: Principal, req : [ICRC55.DestinationEndpoint], idx : Nat) : Result.Result<?ICRC55.Account, Text> {
        if (req.size() <= idx) return #ok(null);
        
        let #ic(x) = req[idx] else return #err("Invalid destination");
        if (x.ledger != expected_ledger) return #err("Invalid destination ledger");
        #ok(x.account);
    };

};
