import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Result "mo:base/Result";
import Array "mo:base/Array";

module {

    public func meta(all_ledgers : [ICRC55.SupportedLedger]) : ICRC55.NodeMeta {
        {
            id = "throttle";
            name = "Throttle";
            description = "Send X tokens every Y seconds";
            governed_by = "Neutrinite DAO";
            supported_ledgers = all_ledgers;
            pricing = "1 NTN";
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
            var source_count : Nat8;
            var destination_count : Nat8;
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
            source_count : Nat8;
            destination_count : Nat8;
        };
    };

    // Create state from request
    public func CreateRequest2Mem(t : CreateRequest) : Mem {
        {
            init = t.init;
            variables = {
                var interval_sec = t.variables.interval_sec;
                var max_amount = t.variables.max_amount;
                var source_count = t.variables.source_count;
                var destination_count = t.variables.destination_count;
            };
            internals = {
                var wait_until_ts = 0;
            };
        };
    };

    // Modify request
    public type ModifyRequest = {
        interval_sec : NumVariant;
        max_amount : NumVariant;
        source_count : Nat8;
        destination_count : Nat8;
    };

    // How does the modify request change memory
    public func ModifyRequestMut(mem : Mem, t : ModifyRequest) : Result.Result<(), Text> {
        mem.variables.interval_sec := t.interval_sec;
        mem.variables.max_amount := t.max_amount;
        mem.variables.source_count := t.source_count;
        mem.variables.destination_count := t.destination_count;
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
            source_count : Nat8;
            destination_count : Nat8;
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
                source_count = t.variables.source_count;
                destination_count = t.variables.destination_count;
            };
            internals = {
                wait_until_ts = t.internals.wait_until_ts;
            };
        };
    };

    // Mapping of source node ports
    public func Request2Sources(t : Mem, id : Node.NodeId, thiscan : Principal) : Result.Result<[ICRC55.Endpoint], Text> {
        #ok([
            #ic {
                ledger = t.init.ledger;
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
    public func Request2Destinations(t : Mem, req:[ICRC55.DestinationEndpoint]) : Result.Result<[ICRC55.DestinationEndpoint], Text> {
        let dest_0_account : ?ICRC55.Account = do { 
            if (req.size() >= 1) {
                let #ic(x) = req[0] else return #err("Invalid destination 0");
                if (x.ledger != t.init.ledger) {
                    return #err("Invalid destination 0 ledger");
                    };
                x.account;
            } else {
                null;    
            }
        };
        #ok([
            #ic {
                ledger = t.init.ledger;
                account = dest_0_account;
            }
        ]);
    };

    // Other custom types
    public type NumVariant = {
        #fixed : Nat64;
        #rnd : { min : Nat64; max : Nat64 };
    };

    

};
