import Map "mo:map/Map";
import DeVeFi "./lib";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Result "mo:base/Result";
import U "./utils";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import I "mo:itertools/Iter";
import Array "mo:base/Array";
import ICRC55 "./ICRC55";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Timer "mo:base/Timer";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Vector "mo:vector";
import Debug "mo:base/Debug";

module {

    public type R<A, B> = Result.Result<A, B>;
    public type NodeId = Nat32;

    public type Account = {
        owner : Principal;
        subaccount : ?Blob;
    };

    public type Endpoint = ICRC55.Endpoint;

    public type CreateNodeResp<A> = {
        #ok : NodeShared<A>;
        #err : Text;
    };

    public type NodeMem<A> = {
        sources : [Endpoint];
        destinations : [Endpoint];
        refund : [Endpoint];
        controllers : [Principal];
        created : Nat64;
        modified : Nat64;
        var expires : ?Nat64;
        custom : A;
    };

    public type NodeShared<AS> = {
        id : NodeId;
        sources : [Endpoint];
        destinations : [Endpoint];
        controllers : [Principal];
        created : Nat64;
        modified : Nat64;
        expires : ?Nat64;
        custom : AS;
    };

    public type Flow = { #input; #payment };
    public type Port = {
        vid : NodeId;
        flow : Flow;
        id : Nat8;
    };

    public type PortInfo = {
        balance : Nat;
        fee : Nat;
        ledger : Principal;
    };

    public type Mem<A> = {
        nodes : Map.Map<NodeId, NodeMem<A>>;
        var next_node_id : NodeId;
        var thiscan : ?Principal;
    };

    public func Mem<A>() : Mem<A> {
        {
            nodes = Map.new<NodeId, NodeMem<A>>();
            var next_node_id : NodeId = 0;
            var thiscan = null;
        };
    };

    public type SETTINGS = {
        TEMP_NODE_EXPIRATION_SEC : Nat64;
        ALLOW_TEMP_NODE_CREATION : Bool;
        MAX_SOURCES : Nat8;
        MAX_DESTINATIONS : Nat8;
    };

    public let DEFAULT_SETTINGS : SETTINGS = {
        ALLOW_TEMP_NODE_CREATION = true;
        TEMP_NODE_EXPIRATION_SEC = 3600;
        MAX_SOURCES = 1;
        MAX_DESTINATIONS = 1;
    };

    public class Node<system, NR, A, AS>({
        mem : Mem<A>;
        dvf : DeVeFi.DeVeFi;
        requestToNode : (ICRC55.NodeRequest, NR, NodeId, Principal) -> NodeMem<A>;
        nodeCreateFee : (NodeMem<A>) -> {
            amount : Nat;
            ledger : Principal;
        };
        settings : SETTINGS;
        toShared : (A) -> AS;
    }) {

        public class Source(
            cls : {
                endpoint : Endpoint;
                port : Nat;
                vec : NodeMem<A>;
            }
        ) {

            public let endpoint = cls.endpoint;
            public let port = cls.port;
            public func balance() : Nat {
                switch (endpoint) {
                    case (#ic({ ledger; account })) {
                        dvf.balance(ledger, account.subaccount);
                    };
                    case (_) {
                        Debug.trap("Not supported");
                    };
                };
            };
            public func fee() : Nat {
                switch (endpoint) {
                    case (#ic({ ledger; account })) {
                        dvf.fee(ledger);
                    };
                    case (_) {
                        Debug.trap("Not supported");
                    };
                };
            };
            public func send(
                location : {
                    #destination : { port : Nat };
                    #source : { port : Nat };
                    #remote_destination : { node : NodeId; port : Nat };
                    #remote_source : { node : NodeId; port : Nat };
                    #external_account : Account;
                },
                amount : Nat,
            ) : () {
                let to : Account = switch (location) {
                    case (#destination({ port })) {
                        onlyIC(cls.vec.destinations[port]).account;
                    };

                    case (#remote_destination({ node; port })) {
                        let ?to_vec = Map.get(mem.nodes, Map.n32hash, node) else return;
                        onlyIC(to_vec.destinations[port]).account;
                    };

                    case (#remote_source({ node; port })) {
                        let ?to_vec = Map.get(mem.nodes, Map.n32hash, node) else return;
                        onlyIC(to_vec.sources[port]).account;
                    };

                    case (#source({ port })) {
                        onlyIC(cls.vec.sources[port]).account;
                    };

                    case (#external_account(account)) {
                        account;
                    };
                };

                let #ic(source_ep) = endpoint else Debug.trap("Not supported");

                ignore dvf.send({
                    ledger = source_ep.ledger;
                    to;
                    amount;
                    memo = null;
                    from_subaccount = source_ep.account.subaccount;
                });
            };
        };

        public func hasDestination(vec : NodeMem<A>, port_idx : Nat) : Bool {
            port_idx < vec.destinations.size();
        };

        public func getSource(vec : NodeMem<A>, port_idx : Nat) : ?Source {
            if (port_idx >= vec.sources.size()) return null;
            let source = Source({
                endpoint = vec.sources[port_idx];
                port = port_idx;
                vec = vec;
            });
            return ?source;
        };

        public func entries() : Iter.Iter<(NodeId, NodeMem<A>)> {
            Map.entries(mem.nodes);
        };

        public func getNextNodeId() : NodeId {
            mem.next_node_id;
        };

        public func delete(vid : NodeId) : () {
            let ?vec = Map.get(mem.nodes, Map.n32hash, vid) else return;

            let fee = nodeCreateFee(vec);
            // REFUND: Send staked tokens from the node to the first controller
            do {
                let from_subaccount = port2subaccount({
                    vid;
                    flow = #payment;
                    id = 0;
                });

                let bal = dvf.balance(fee.ledger, ?from_subaccount);
                if (bal > 0 and vec.controllers.size() > 0) {
                    ignore dvf.send({
                        ledger = fee.ledger;
                        to = { owner = vec.controllers[0]; subaccount = null };
                        amount = bal;
                        memo = null;
                        from_subaccount = ?from_subaccount;
                    });
                };
            };

            label source_refund for (xsource in vec.sources.vals()) {
                let source = onlyIC(xsource);
                dvf.unregisterSubaccount(source.account.subaccount);

                // RETURN tokens from all sources
                do {
                    let bal = dvf.balance(source.ledger, source.account.subaccount);
                    if (bal > 0) {
                        // try to find refund endpoint for that ledger source
                        let ?xf = Array.find<ICRC55.Endpoint>(vec.refund, func (x) = onlyIC(x).ledger == source.ledger) else continue source_refund;
                        let refund = onlyIC(xf);

                        ignore dvf.send({
                            ledger = source.ledger;
                            to = refund.account;
                            amount = bal;
                            memo = null;
                            from_subaccount = source.account.subaccount;
                        });
                    };
                };
            };

            ignore Map.remove(mem.nodes, Map.n32hash, vid);
        };

        public func setThisCanister(can : Principal) : () {
            mem.thiscan := ?can;
        };

        public func icrc55_create_node(caller : Principal, req : ICRC55.NodeRequest, custom : NR) : CreateNodeResp<AS> {
            let ?thiscanister = mem.thiscan else return #err("This canister not set");
            // TODO: Limit tempory node creation per hour (against DoS)

            // if (Option.isNull(dvf.get_ledger(v.ledger))) return #err("Ledger not supported");

            // Payment - If the local caller wallet has enough funds send the fee to the node payment balance
            // Once the node is deleted, we can send the fee back to the caller
            let id = mem.next_node_id;

            let node = requestToNode(req, custom, id, thiscanister);

            let nfee = nodeCreateFee(node);

            let caller_subaccount = ?Principal.toLedgerAccount(caller, null);
            let caller_balance = dvf.balance(nfee.ledger, caller_subaccount);
            var paid = false;
            if (caller_balance >= nfee.amount) {
                let node_payment_account = port2subaccount({
                    vid = id;
                    flow = #payment;
                    id = 0;
                });
                ignore dvf.send({
                    ledger = nfee.ledger;
                    to = {
                        owner = thiscanister;
                        subaccount = ?node_payment_account;
                    };
                    amount = nfee.amount;
                    memo = null;
                    from_subaccount = caller_subaccount;
                });
                paid := true;
            };

            if (not paid and not settings.ALLOW_TEMP_NODE_CREATION) return #err("Temp node creation not allowed");

            if (not paid) node.expires := ?(U.now() + settings.TEMP_NODE_EXPIRATION_SEC * 1_000_000_000);

            ignore Map.put(mem.nodes, Map.n32hash, id, node);

            // Registration required because the ICP ledger is hashing owner+subaccount
            dvf.registerSubaccount(?port2subaccount({ vid = id; flow = #input; id = 0 }));

            mem.next_node_id += 1;

            let ?node_shared = icrc55_get_node(#id(id)) else return #err("Couldn't find after create");
            #ok(node_shared);
        };

        public func getNode(req : ICRC55.GetNode) : ?(NodeId, NodeMem<A>) {
            let (vec : NodeMem<A>, vid : NodeId) = switch (req) {
                case (#id(id)) {
                    let ?v = Map.get(mem.nodes, Map.n32hash, id) else return null;
                    (v, id);
                };
                case (#subaccount(subaccount)) {
                    let ?port = subaccount2port(subaccount) else return null;
                    let ?v = Map.get(mem.nodes, Map.n32hash, port.vid) else return null;
                    (v, port.vid);
                };
            };

            return ?(vid, vec);
        };

        public func icrc55_get_node(req : ICRC55.GetNode) : ?NodeShared<AS> {
            let ?(vid, vec) = getNode(req) else return null;

            return ?{
                id = vid;
                custom = toShared(vec.custom);
                created = vec.created;
                modified = vec.modified;
                controllers = vec.controllers;
                expires = vec.expires;
                sources = vec.sources;
                destinations = vec.destinations;
            };

        };

        public func icrc55_get_controller_nodes(controller : Principal) : [NodeId] {
            // Unoptimised for now, but it will get it done
            let res = Vector.new<NodeId>();
            for ((vid, vec) in entries()) {
                if (not Option.isNull(Array.indexOf(controller, vec.controllers, Principal.equal))) {
                    Vector.add(res, vid);
                };
            };
            Vector.toArray(res);
        };

        public func icrc55_create_node_get_fee(creator : Principal, req : ICRC55.NodeRequest, custom : NR) : ICRC55.NodeCreateFee {
            let ?thiscanister = mem.thiscan else Debug.trap("Not initialized");
            let { ledger; amount } = nodeCreateFee(requestToNode(req, custom, 0, thiscanister));
            {
                ledger;
                amount;
                subaccount = Principal.toLedgerAccount(creator, null);
            };
        };

        dvf.onEvent(
            func(event) {
                switch (event) {
                    case (#received(r)) {

                        let ?port = subaccount2port(r.to.subaccount) else return; // We can still recieve tokens in caller subaccounts, which we won't send back right away
                        let found = getNode(#id(port.vid));

                        // RETURN tokens: If no node is found send tokens back (perhaps it was deleted)
                        if (Option.isNull(found)) {
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
                        let ?(_, rvec) = found else return;
                        let from_subaccount = port2subaccount({
                            vid = port.vid;
                            flow = #payment;
                            id = 0;
                        });

                        let bal = dvf.balance(r.ledger, ?from_subaccount);
                        let fee = nodeCreateFee(rvec);
                        if (bal >= fee.amount) {
                            rvec.expires := null;
                        };

                    };
                    case (_) ();
                };
            }
        );

        private func onlyIC(ep : Endpoint) : ICRC55.ICEndpoint {
            let #ic(x) = ep else Debug.trap("Not supported");
            x;
        };

        // Remove expired nodes
        ignore Timer.recurringTimer<system>(
            #seconds(60),
            func() : async () {
                let now = Nat64.fromNat(Int.abs(Time.now()));
                label vloop for ((vid, vec) in entries()) {
                    let ?expires = vec.expires else continue vloop;
                    if (now > expires) {

                        // DELETE Node from memory
                        delete(vid);
                    };
                };
            },
        );

    };

    public func port2subaccount(p : Port) : Blob {
        let whobit : Nat8 = switch (p.flow) {
            case (#input) 1;
            case (#payment) 2;
        };
        Blob.fromArray(Iter.toArray(I.pad(I.flattenArray<Nat8>([[whobit], [p.id], U.ENat32(p.vid)]), 32, 0 : Nat8)));
    };

    public func subaccount2port(subaccount : ?Blob) : ?Port {
        let ?sa = subaccount else return null;
        let array = Blob.toArray(sa);
        let whobit = array[0];
        let id = array[1];
        let ?vid = U.DNat32(Iter.toArray(Array.slice(array, 2, 6))) else return null;
        let flow = if (whobit == 1) #input else if (whobit == 2) #payment else return null;
        ?{
            vid = vid;
            flow = flow;
            id = id;
        };
    };
};
