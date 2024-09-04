import ICRC55 "../src/ICRC55";
import Node "../src/node";

module {
    // These separate vector types are connected in ./types.mo

    public type Request = {
        init : {
            ledger : Principal;
        };
        variables : {
            interval_sec : NumVariant;
            max_amount : NumVariant;
        };
    };

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

    public func Request2Mem(t : Request) : Mem {
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

    public func Request2Sources(t : Request, id : Node.NodeId, thiscan : Principal) : [ICRC55.Endpoint] {
        [
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
        ];
    };

    // Inner types
    public type NumVariant = {
        #fixed : Nat64;
        #rnd : { min : Nat64; max : Nat64 };
    };

    

};
