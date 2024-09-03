import Principal "mo:base/Principal";
import Map "mo:map/Map";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";
import T "./types";
import Timer "mo:base/Timer";
import Prng "mo:prng";
import DeVeFi "../src/";
import Nat "mo:base/Nat";
import Account "mo:account";
import ICRC55 "../src/ICRC55";
import Vector "mo:vector";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Node "../src/node";
import Nat8 "mo:base/Nat8";

actor class () = this {

    // Throttle vector
    // It will send X amount of tokens every Y seconds


    let NTN_LEDGER = Principal.fromText("f54if-eqaaa-aaaaq-aacea-cai");
    let NODE_FEE = 1_0000_0000;

    stable let dvf_mem = DeVeFi.Mem();
    let rng = Prng.SFC64a();
    rng.init(123456);

    let supported_ledgers : [Principal] = [
        Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai"),
        NTN_LEDGER,
    ];

    let dvf = DeVeFi.DeVeFi<system>({ mem = dvf_mem });
    dvf.add_ledger<system>(supported_ledgers[0], #icp);
    dvf.add_ledger<system>(supported_ledgers[1], #icrc);


    stable let node_mem = Node.Mem<T.CustomNode>();
    let nodes = Node.Node<system, T.CustomNode, T.CustomNodeShared>({ 
        mem = node_mem; 
        dvf;
        nodeCreateFee = func(node) { // Pricing could depend on the vector being created
            {
                amount = NODE_FEE;
                ledger = NTN_LEDGER;
            };
        };
        settings = {
            Node.DEFAULT_SETTINGS with 
            MAX_SOURCES = 1:Nat8;
            MAX_DESTINATIONS = 1:Nat8;
        };
        toShared = T.CustomNode.toShared;
    });

    // Main DeVeFi logic
    //
    // Every 2 seconds it goes over all nodes
    // And decides whether to send tokens to destinations or not

    // Notes:
    // The balances are automatically synced with ledgers and can be used synchronously
    // Sending tokens also works synchronously - adds them to queue and sends them in the background
    // No need to handle errors when sending, the transactions will be retried until they are successful
    ignore Timer.recurringTimer<system>(
        #seconds(2),
        func() : async () {
            let now = Nat64.fromNat(Int.abs(Time.now()));
            label vloop for ((vid, vec) in nodes.entries()) {
                
                if (not nodes.hasDestination(vec, 0)) continue vloop;

                let ?source = nodes.getSource(vec, 0) else continue vloop;
                let bal = source.balance();

                let fee = source.fee();
                if (bal <= fee * 100) continue vloop;

                if (now > vec.custom.internals.wait_until_ts) {
                    switch (vec.custom.variables.interval_sec) {
                        case (#fixed(fixed)) {
                            vec.custom.internals.wait_until_ts := now + fixed*1_000_000_000;
                        };
                        case (#rnd({ min; max })) {
                            let dur : Nat64 = if (min >= max) 0 else rng.next() % (max - min);
                            vec.custom.internals.wait_until_ts := now + (min + dur) * 1_000_000_000;
                        };
                    };

                    let max_amount : Nat64 = switch (vec.custom.variables.max_amount) {
                        case (#fixed(fixed)) fixed;
                        case (#rnd({ min; max })) if (min >= max) 0 else min + rng.next() % (max - min);
                    };

                    var amount = Nat.min(bal, Nat64.toNat(max_amount));
                    if (bal - amount:Nat <= fee * 100) amount := bal; // Don't leave dust

                    source.send(#destination({ port = 0 }), amount);
                  
                };
            };
        },
    );

    public query func icrc55_get_nodefactory_meta() : async ICRC55.NodeFactoryMeta {
        {
            name = "Throttle";
            description = "Send X tokens every Y seconds";
            governed_by = "Neutrinite DAO";
            supported_ledgers;
            pricing = "1 NTN";
        };
    };

    public query func icrc55_create_node_get_fee(creator: Principal, req : ICRC55.NodeRequest, creq: T.CustomNodeRequest) : async ICRC55.NodeCreateFee {
        {
            ledger = NTN_LEDGER;
            amount = NODE_FEE;
            subaccount = Principal.toLedgerAccount(creator, null);
        };
    };

    public shared ({ caller }) func icrc55_create_node(req : ICRC55.NodeRequest, creq: T.CustomNodeRequest) : async T.CreateNode {
        
        let sources = [{
                    ledger = creq.init.ledger;
                    account = {
                        owner = Principal.fromActor(this);
                        subaccount = ?Node.port2subaccount({
                            vid = nodes.getNextNodeId();
                            flow = #input;
                            id = 0;
                        });
                    };
                }];
        
        let nodereq = {
            sources;
            destinations = req.destinations;
            controllers = req.controllers;
        };
        
        nodes.createNode(caller, nodereq, {
            init = creq.init;
            internals = {
                var wait_until_ts = 0;
            };
            variables = {
                var interval_sec = creq.variables.interval_sec;
                var max_amount = creq.variables.max_amount;
            }
            });

    };


    // We need to start the vector manually once when canister is installed, because we can't init dvf from the body
    // https://github.com/dfinity/motoko/issues/4384
    // Sending tokens before starting the canister for the first time wont get processed
    public shared ({ caller }) func start() {
        assert (Principal.isController(caller));
        dvf.start<system>(Principal.fromActor(this));
    };


    public query func icrc55_get_node(req : ICRC55.GetNode) : async ?Node.NodeShared<T.CustomNodeShared> {
        nodes.getNodeShared(req);
    };

    // public query ({caller}) func icrc55_get_controller_nodes() : async ICRC55.GetControllerNodes {
    //     // Unoptimised for now, but it will get it done
    //     let res = Vector.new<T.NodeId>();
    //     for ((vid, vec) in Map.entries(nodes)) {
    //         if (not Option.isNull(Array.indexOf(caller, vec.controllers, Principal.equal))) {
    //             Vector.add(res, vid);
    //         };
    //     };
    //     Vector.toArray(res);
    // };

    // Debug functions

    public query func get_ledger_errors() : async [[Text]] {
        dvf.getErrors();
    };

    public query func get_ledgers_info() : async [DeVeFi.LedgerInfo] {
        dvf.getLedgersInfo();
    };

    // Dashboard explorer doesn't show icrc accounts in text format, this does
    // Hard to send tokens to Candid ICRC Accounts
    // public query func get_node_addr(vid : T.NodeId) : async (Text, Nat) {
    //     let ?vec = Map.get(nodes, Map.n32hash, vid) else return ("", 0);

    //     let subaccount = ?T.port2subaccount({
    //         vid;
    //         flow = #input;
    //         id = 0;
    //     });

    //     let bal = dvf.balance(vec.ledger, subaccount);

    //     (Account.toText({ owner = Principal.fromActor(this); subaccount }), bal);
    // };
};
