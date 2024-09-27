import Principal "mo:base/Principal";
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
import Node "../src/node";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";

actor class () = this {

    // Throttle vector
    // It will send X amount of tokens every Y seconds

    let NTN_LEDGER = Principal.fromText("f54if-eqaaa-aaaaq-aacea-cai");
    let NODE_FEE = 1_0000_0000;

    stable let dvf_mem = DeVeFi.Mem();
    let rng = Prng.SFC64a();
    rng.init(123456);

    let supportedLedgers : [Principal] = [
        Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai"),
        NTN_LEDGER,
        // Principal.fromText("mxzaz-hqaaa-aaaar-qaada-cai"),
        // Principal.fromText("xevnm-gaaaa-aaaar-qafnq-cai"),
    ];

    let dvf = DeVeFi.DeVeFi<system>({ mem = dvf_mem });
    dvf.add_ledger<system>(supportedLedgers[0], #icp);
    dvf.add_ledger<system>(supportedLedgers[1], #icrc);
    // dvf.add_ledger<system>(supportedLedgers[2], #icrc);
    // dvf.add_ledger<system>(supportedLedgers[3], #icrc);

    stable let node_mem = Node.Mem<T.Mem>();
    let nodes = Node.Node<system, T.CreateRequest, T.Mem, T.Shared, T.ModifyRequest>({
        mem = node_mem;
        dvf;
        nodeCreateFee = func(_node) {
            {
                amount = NODE_FEE;
                ledger = NTN_LEDGER;
            };
        };
        supportedLedgers = Array.map<Principal, ICRC55.SupportedLedger>(supportedLedgers, func (x) = #ic(x));
        settings = {
            Node.DEFAULT_SETTINGS with
            MAX_SOURCES = 1 : Nat8;
            MAX_DESTINATIONS = 1 : Nat8;
            PYLON_NAME = "Transcendence";
            PYLON_GOVERNED_BY = "Neutrinite DAO"
        };
        toShared = T.toShared;
        sourceMap = T.sourceMap;
        destinationMap = T.destinationMap;
        createRequest2Mem = T.createRequest2Mem;
        modifyRequestMut = T.modifyRequestMut;
        getDefaults = T.getDefaults;
        meta = T.meta;
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

                switch (vec.custom) {
                    case (#throttle(th)) {
                        if (now > th.internals.wait_until_ts) {
                            switch (th.variables.interval_sec) {
                                case (#fixed(fixed)) {
                                    th.internals.wait_until_ts := now + fixed * 1_000_000_000;
                                };
                                case (#rnd({ min; max })) {
                                    let dur : Nat64 = if (min >= max) 0 else rng.next() % (max - min);
                                    th.internals.wait_until_ts := now + (min + dur) * 1_000_000_000;
                                };
                            };

                            let max_amount : Nat64 = switch (th.variables.max_amount) {
                                case (#fixed(fixed)) fixed;
                                case (#rnd({ min; max })) if (min >= max) 0 else min + rng.next() % (max - min);
                            };

                            var amount = Nat.min(bal, Nat64.toNat(max_amount));
                            if (bal - amount : Nat <= fee * 100) amount := bal; // Don't leave dust

                            source.send(#destination({ port = 0 }), amount);

                        };
                    };
                };

            };
        },
    );

    public query func icrc55_get_nodefactory_meta() : async ICRC55.NodeFactoryMetaResp {
        nodes.icrc55_get_nodefactory_meta();
    };

    public query ({ caller }) func icrc55_create_node_get_fee(req : ICRC55.NodeRequest, creq : T.CreateRequest) : async ICRC55.NodeCreateFeeResp {
        nodes.icrc55_create_node_get_fee(caller, req, creq);
    };

    public shared ({caller }) func icrc55_command(cmds : [ICRC55.Command<T.CreateRequest, T.ModifyRequest>]) : async [ICRC55.CommandResponse<T.Shared>] {
        nodes.icrc55_command(caller, cmds);
    };

    public shared ({ caller }) func icrc55_create_node(req : ICRC55.NodeRequest, creq : T.CreateRequest) : async Node.CreateNodeResp<T.Shared> {
        nodes.icrc55_create_node(caller, req, creq);
    };

    public query func icrc55_get_node(req : ICRC55.GetNode) : async ?Node.NodeShared<T.Shared> {
        nodes.icrc55_get_node(req);
    };

    public query ({ caller }) func icrc55_get_controller_nodes(req: ICRC55.GetControllerNodesRequest) : async [Node.NodeShared<T.Shared>] {
        nodes.icrc55_get_controller_nodes(caller, req);
    };

    public shared ({caller}) func icrc55_delete_node(vid : ICRC55.LocalNodeId) : async ICRC55.DeleteNodeResp {
        nodes.icrc55_delete_node(caller, vid);
    };

    public shared ({caller}) func icrc55_modify_node(vid : ICRC55.LocalNodeId, req : ?ICRC55.CommonModRequest, creq : ?T.ModifyRequest) : async Node.ModifyNodeResp<T.Shared> {
        nodes.icrc55_modify_node(caller, vid, req, creq);
    };

    public query func icrc55_get_defaults(id : Text) : async T.CreateRequest {
        nodes.icrc55_get_defaults(id);
    };

    // We need to start the vector manually once when canister is installed, because we can't init dvf from the body
    // https://github.com/dfinity/motoko/issues/4384
    // Sending tokens before starting the canister for the first time wont get processed
    public shared ({ caller }) func start() {
        assert (Principal.isController(caller));
        dvf.start<system>(Principal.fromActor(this));
        nodes.start<system>(Principal.fromActor(this));
    };





    // ---------- Debug functions -----------

    public query func get_ledger_errors() : async [[Text]] {
        dvf.getErrors();
    };

    public query func get_ledgers_info() : async [DeVeFi.LedgerInfo] {
        dvf.getLedgersInfo();
    };

    // Dashboard explorer doesn't show icrc accounts in text format, this does
    // Hard to send tokens to Candid ICRC Accounts
    public query func get_node_addr(vid : Node.NodeId) : async ?Text {
        let ?(_,vec) = nodes.getNode(#id(vid)) else return null;

        let subaccount = ?Node.port2subaccount({
            vid;
            flow = #input;
            id = 0;
        });

        ?Account.toText({ owner = Principal.fromActor(this); subaccount });
    };
};
