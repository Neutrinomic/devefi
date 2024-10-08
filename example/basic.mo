import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";
import T "./types";
import Timer "mo:base/Timer";
import Prng "mo:prng";
import DeVeFi "../src/";
import Nat "mo:base/Nat";
import ICRC55 "../src/ICRC55";
import Node "../src/node";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";

actor class () = this {


    stable let dvf_mem = DeVeFi.Mem();
    let rng = Prng.SFC64a();
    rng.init(123456);



    let dvf = DeVeFi.DeVeFi<system>({ mem = dvf_mem });


    stable let node_mem = Node.Mem<T.Mem>();
    let nodes = Node.Node<system, T.CreateRequest, T.Mem, T.Shared, T.ModifyRequest>({
        mem = node_mem;
        dvf;
        
        settings = {
            Node.DEFAULT_SETTINGS with
            MAX_SOURCES = 1 : Nat8;
            MAX_DESTINATIONS = 1 : Nat8;
            PYLON_NAME = "Transcendence";
            PYLON_GOVERNED_BY = "Neutrinite DAO";
            PYLON_FEE_ACCOUNT = ?{ owner = Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai"); subaccount = null };
        };
        toShared = T.toShared;
        sourceMap = T.sourceMap;
        destinationMap = T.destinationMap;
        createRequest2Mem = T.createRequest2Mem;
        modifyRequestMut = T.modifyRequestMut;
        getDefaults = T.getDefaults;
        meta = T.meta;
        nodeMeta = T.nodeMeta;
        authorAccount = T.authorAccount;
    });

    private func proc() {
            let now = Nat64.fromNat(Int.abs(Time.now()));
            label vloop for ((vid, vec) in nodes.entries()) {
                if (not vec.active) continue vloop;
                if (not nodes.hasDestination(vec, 0)) continue vloop;

                let ?source = nodes.getSource(vid, vec, 0) else continue vloop;
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

                            ignore source.send(#destination({ port = 0 }), amount);

                        };
                    };
                    case (#split(n)) {

                          // First loop: Calculate totalSplit and find the largest share destination
                        var totalSplit = 0;
                        var largestPort : ?Nat = null;
                        var largestAmount = 0;

                        label iniloop for (port_id in n.variables.split.keys()) {
                            if (not nodes.hasDestination(vec, port_id)) continue iniloop;
                            
                            let splitShare = n.variables.split[port_id];
                            totalSplit += splitShare;

                            if (splitShare > largestAmount) {
                                largestPort := ?port_id;
                                largestAmount := splitShare;
                            }
                        };

                        // If no valid destinations, skip the rest of the loop
                        if (totalSplit == 0) continue vloop;

                        var remainingBalance = bal;

                        // Second loop: Send to each valid destination
                        label port_send for (port_id in n.variables.split.keys()) {
                            if (not nodes.hasDestination(vec, port_id)) continue port_send;

                            let splitShare = n.variables.split[port_id];
                            
                            // Skip the largestPort for now, as we will handle it last
                            if (?port_id == largestPort) continue port_send;

                            let amount = bal * splitShare / totalSplit;
                            if (amount <= fee * 100) continue port_send; // Skip if below fee threshold

                            ignore source.send(#destination({ port = port_id }), amount);
                            remainingBalance -= amount;
                        };

                        // Send the remaining balance to the largest share destination
                        if (remainingBalance > 0) {
                            ignore do ? {source.send(#destination({ port = largestPort! }), remainingBalance);}
                        }

                        
                    };
                    case (_) ();
                };

            };
        };

    system func heartbeat() : async () {
        nodes.heartbeat(proc);
    };

    public query func icrc55_get_pylon_meta() : async ICRC55.NodeFactoryMetaResp {
        nodes.icrc55_get_pylon_meta();
    };


    public shared ({ caller }) func icrc55_command(cmds : [ICRC55.Command<T.CreateRequest, T.ModifyRequest>]) : async [ICRC55.CommandResponse<T.Shared>] {
        nodes.icrc55_command(caller, cmds);
    };

    public query func icrc55_get_nodes(req : [ICRC55.GetNode]) : async [?Node.NodeShared<T.Shared>] {
        nodes.icrc55_get_nodes(req);
    };

    public query ({ caller }) func icrc55_get_controller_nodes(req : ICRC55.GetControllerNodesRequest) : async [Node.NodeShared<T.Shared>] {
        nodes.icrc55_get_controller_nodes(caller, req);
    };

    public query func icrc55_get_defaults(id : Text) : async T.CreateRequest {
        nodes.icrc55_get_defaults(id);
    };

    public query ({caller}) func icrc55_virtual_balances(req : ICRC55.VirtualBalancesRequest) : async ICRC55.VirtualBalancesResponse {
        nodes.icrc55_virtual_balances(caller, req);
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

    public func add_supported_ledger(id : Principal, ltype : {#icp; #icrc}) : () {
        dvf.add_ledger<system>(id, ltype);
    };

    public query func get_ledger_errors() : async [[Text]] {
        dvf.getErrors();
    };

    public query func get_ledgers_info() : async [DeVeFi.LedgerInfo] {
        dvf.getLedgersInfo();
    };


};
