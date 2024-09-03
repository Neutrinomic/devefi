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

    // stable let nodes = Map.new<T.NodeId, T.Node>();
    // stable var next_node_id : T.NodeId = 0;

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
    let nodes = Node.Node<T.CustomNode, T.CustomNodeShared>({ 
        mem = node_mem; 
        dvf;
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
                let ?destination = vec.destination else continue vloop;
                let from_subaccount = T.port2subaccount({
                    vid;
                    flow = #input;
                    id = 0;
                });

                let bal = dvf.balance(vec.ledger, ?from_subaccount);

                let fee = dvf.fee(vec.ledger);
                if (bal <= fee * 100) continue vloop;

                if (now > vec.internals.wait_until_ts) {
                    switch (vec.variables.interval_sec) {
                        case (#fixed(fixed)) {
                            vec.internals.wait_until_ts := now + fixed*1_000_000_000;
                        };
                        case (#rnd({ min; max })) {
                            let dur : Nat64 = if (min >= max) 0 else rng.next() % (max - min);
                            vec.internals.wait_until_ts := now + (min + dur) * 1_000_000_000;
                        };
                    };

                    let max_amount : Nat64 = switch (vec.variables.max_amount) {
                        case (#fixed(fixed)) fixed;
                        case (#rnd({ min; max })) if (min >= max) 0 else min + rng.next() % (max - min);
                    };

                    var amount = Nat.min(bal, Nat64.toNat(max_amount));
                    if (bal - amount:Nat <= fee * 100) amount := bal; // Don't leave dust

                    ignore dvf.send({
                        ledger = vec.ledger;
                        to = destination;
                        amount;
                        memo = null;
                        from_subaccount = ?from_subaccount;
                    });
                };
            };
        },
    );

    // Remove expired nodes
    ignore Timer.recurringTimer<system>(#seconds(60),
        func() : async () {
          let now = Nat64.fromNat(Int.abs(Time.now()));
            label vloop for ((vid, vec) in nodes.entries()) {
                let ?expires = vec.expires else continue vloop;
                if (now > expires) {
                    // TODO: dvf has no unregisterSubaccount
                    // dvf.unregisterSubaccount(?T.port2subaccount({
                    //     vid;
                    //     flow = #input;
                    //     id = 0;
                    // }));
                    
                    // REFUND: Send payment tokens from the node to the first controller
                    do {
                        let from_subaccount = Node.port2subaccount({
                            vid;
                            flow = #payment;
                            id = 0;
                        });

                        let bal = dvf.balance(vec.sources[0].ledger, ?from_subaccount);
                        if (bal > 0 and vec.controllers.size() > 0) {
                            ignore dvf.send({
                                ledger = vec.sources[0].ledger;
                                to = {owner = vec.controllers[0]; subaccount = null};
                                amount = bal;
                                memo = null;
                                from_subaccount = ?from_subaccount;
                            });
                        };
                    };

                    // RETURN port tokens
                    do {
                        let from_subaccount = Node.port2subaccount({
                            vid;
                            flow = #input;
                            id = 0;
                        });

                        let bal = dvf.balance(vec.sources[0].ledger, ?from_subaccount);
                        if (bal > 0 and vec.controllers.size() > 0) {
                            ignore dvf.send({
                                ledger = vec.sources[0].ledger;
                                to = {owner = vec.controllers[0]; subaccount = null};
                                amount = bal;
                                memo = null;
                                from_subaccount = ?from_subaccount;
                            });
                        };
                    };

                    // DELETE Node from memory
                    nodes.delete(vid);
                };
            }
    });

    dvf.onEvent(
        func(event) {
            switch (event) {
                case (#received(r)) {
                    
                    let ?port = T.subaccount2port(r.to.subaccount) else return; // We can still recieve tokens in caller subaccounts, which we won't send back right away
                    let vec = Map.get(nodes, Map.n32hash, port.vid);

                    // RETURN tokens: If no node is found send tokens back (perhaps it was deleted)
                    if (Option.isNull(vec)) {
                        let #icrc(addr) = r.from else return; // Can only send to icrc accounts for now
                        ignore dvf.send({
                            ledger = r.ledger;
                            to = addr;
                            amount = r.amount;
                            memo = null;
                            from_subaccount = r.to.subaccount;
                        });
                        return;
                    };

                    // Handle payment after temporary vector was created
                    let ?rvec = vec else return;
                    let from_subaccount = T.port2subaccount({
                        vid = port.vid;
                        flow = #payment;
                        id = 0;
                    });

                    let bal = dvf.balance(r.ledger, ?from_subaccount);
                    if (bal >= NODE_FEE) {
                        rvec.expires := null;  
                    };

                };
                case (_) ();
            };
        }
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

        nodes.createNode(caller, nodereq, creq);

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
