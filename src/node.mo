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
import Nat32 "mo:base/Nat32";
import ICRCLedger "mo:devefi-icrc-ledger";
import Prim "mo:⛔";

module {

    public type R<A, B> = Result.Result<A, B>;
    public type NodeId = Nat32;

    public type Account = {
        owner : Principal;
        subaccount : ?Blob;
    };

    public type Endpoint = ICRC55.Endpoint;
    public type DestinationEndpoint = ICRC55.DestinationEndpoint;

    public type CreateNodeResp<A> = ICRC55.CreateNodeResponse<A>;

    public type ModifyNodeResp<A> = ICRC55.ModifyNodeResponse<A>;

    public type NodeMem<A> = {
        var sources : [Endpoint];
        var extractors : [NodeId];
        var destinations : [DestinationEndpoint];
        var refund : Account;
        var controllers : [Principal];
        var affiliate : ?Account;
        created : Nat64;
        var modified : Nat64;
        var active : Bool;
        billing : {
            var expires : ?Nat64;
            var frozen : Bool;
            var last_billed : Nat64;
        };
        custom : A;
    };

    public type NodeShared<AS> = ICRC55.GetNodeResponse<AS>;

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
        var ops : Nat; // Each transaction is one op
    };

    public func Mem<A>() : Mem<A> {
        {
            nodes = Map.new<NodeId, NodeMem<A>>();
            var next_node_id : NodeId = 0;
            var thiscan = null;
            var ops = 0;
        };
    };

    public type SETTINGS = {
        TEMP_NODE_EXPIRATION_SEC : Nat64;
        ALLOW_TEMP_NODE_CREATION : Bool;
        PYLON_GOVERNED_BY : Text;
        PYLON_NAME : Text;
        PYLON_FEE_ACCOUNT : ?Account;
        MAX_INSTRUCTIONS_PER_HEARTBEAT : Nat64; // 2 billion is max on the IC, double check
    };

    public let DEFAULT_SETTINGS : SETTINGS = {
        ALLOW_TEMP_NODE_CREATION = true;
        TEMP_NODE_EXPIRATION_SEC = 3600;
        PYLON_GOVERNED_BY = "Unknown";
        PYLON_NAME = "Testing Pylon";
        MAX_INSTRUCTIONS_PER_HEARTBEAT = 500_000_000;
        PYLON_FEE_ACCOUNT = null;
    };

    public type SourceSendErr = ICRCLedger.SendError or { #AccountNotSet };

    public class Node<system, XCreateRequest, XMem, XShared, XModifyRequest>({
        settings : SETTINGS;
        mem : Mem<XMem>;
        dvf : DeVeFi.DeVeFi;

        toShared : (XMem) -> XShared;
        sourceMap : (NodeId, XMem, Principal, [Endpoint]) -> R<[Endpoint], Text>;
        destinationMap : (XMem, [DestinationEndpoint]) -> R<[DestinationEndpoint], Text>;
        modifyRequestMut : (XMem, XModifyRequest) -> R<(), Text>;
        createRequest2Mem : (XCreateRequest) -> XMem;
        meta : ([ICRC55.SupportedLedger]) -> [ICRC55.NodeMeta];
        nodeMeta : (XMem, [ICRC55.SupportedLedger]) -> ICRC55.NodeMeta;
        getDefaults : (Text, [ICRC55.SupportedLedger]) -> XCreateRequest;
        authorAccount : (XMem) -> ICRC55.Account;
    }) {

        /// Heartbeat will execute f until it uses MAX_INSTRUCTIONS_PER_HEARTBEAT or it doesn't send any transactions
        public func heartbeat(f : () -> ()) : () {
            let inst_start = Prim.performanceCounter(0); 

            while (true) {
                let ops_before = mem.ops;
                f();
                if (mem.ops == ops_before) return; // No more f calls needed
                let inst_now = Prim.performanceCounter(0);
                if (inst_now - inst_start > settings.MAX_INSTRUCTIONS_PER_HEARTBEAT) return; // We have used enough instructions
            }

        };

        public func ops() : Nat {
            mem.ops;
        };

        public class Source(
            cls : {
                endpoint : Endpoint;
                vec : NodeMem<XMem>;
            }
        ) {

            public let endpoint = U.onlyIC(cls.endpoint) : ICRC55.ICEndpoint;

            public func balance() : Nat {

                dvf.balance(endpoint.ledger, endpoint.account.subaccount);

            };

            public func fee() : Nat {

                dvf.fee(endpoint.ledger);

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
            ) : R<Nat64, SourceSendErr> {
                let to : Account = switch (location) {
                    case (#destination({ port })) {
                        let ?acc = U.onlyICDest(cls.vec.destinations[port]).account else return #err(#AccountNotSet);
                        acc;
                    };

                    case (#remote_destination({ node; port })) {
                        let ?to_vec = Map.get(mem.nodes, Map.n32hash, node) else return #err(#AccountNotSet);
                        let ?acc = U.onlyICDest(to_vec.destinations[port]).account else return #err(#AccountNotSet);
                        acc;
                    };

                    case (#remote_source({ node; port })) {
                        let ?to_vec = Map.get(mem.nodes, Map.n32hash, node) else return #err(#AccountNotSet);
                        U.onlyIC(to_vec.sources[port]).account;
                    };

                    case (#source({ port })) {
                        U.onlyIC(cls.vec.sources[port]).account;
                    };

                    case (#external_account(account)) {
                        account;
                    };
                };

                mem.ops += 1;
                
                dvf.send({
                    ledger = endpoint.ledger;
                    to;
                    amount;
                    memo = null;
                    from_subaccount = endpoint.account.subaccount;
                });
            };
        };

        public func hasDestination(vec : NodeMem<XMem>, port_idx : Nat) : Bool {
            port_idx < vec.destinations.size() and not Option.isNull(U.onlyICDest(vec.destinations[port_idx]).account);
        };

        private func sourceInfo(vid : NodeId, subaccount : ?Blob) : R<{ allowed : Bool; mine : Bool }, ()> {
            let ?ep_port = subaccount2port(subaccount) else return #err;
            if (ep_port.vid != vid) {
                // Is it remote vector
                let ?remote_vec = Map.get(mem.nodes, Map.n32hash, ep_port.vid) else return #err;
                // Check if this vector is in extractors of remote vector if the source isn't its own
                if (Option.isNull(Array.indexOf(vid, remote_vec.extractors, Nat32.equal))) return #ok({
                    mine = false;
                    allowed = false;
                }); // Doesn't have access
                return #ok({ mine = false; allowed = true });
            };
            return #ok({ mine = true; allowed = true });
        };

        public func getSource(vid : NodeId, vec : NodeMem<XMem>, port_idx : Nat) : ?Source {
            if (port_idx >= vec.sources.size()) return null;

            let #ok(sinfo) = sourceInfo(vid, U.onlyIC(vec.sources[port_idx]).account.subaccount) else return null;
            if (not sinfo.allowed) return null;

            let source = Source({
                endpoint = vec.sources[port_idx];
                vec = vec;
            });
            return ?source;
        };

        public func entries() : Iter.Iter<(NodeId, NodeMem<XMem>)> {
            Map.entries(mem.nodes);
        };

        public func getNextNodeId() : NodeId {
            mem.next_node_id;
        };

        public func icrc55_delete_node(caller : Principal, vid : NodeId) : R<(), Text> {
            // Check if caller is controller
            let ?vec = Map.get(mem.nodes, Map.n32hash, vid) else return #err("Node not found");
            if (Option.isNull(Array.indexOf(caller, vec.controllers, Principal.equal))) return #err("Not a controller");

            #ok(delete(vid));
        };

        public func get_virtual_user_account(acc : Account) : Account {
            let ?thiscanister = mem.thiscan else Debug.trap("Canister not set");
            {
                owner = thiscanister;
                subaccount = ?Principal.toLedgerAccount(acc.owner, acc.subaccount)
            };
        };

        public func delete(vid : NodeId) : () {
            let ?vec = Map.get(mem.nodes, Map.n32hash, vid) else return;
            // TODO: Don't allow deletion if there are no refund endpoints

            let meta = nodeMeta(vec.custom, get_supported_ledgers());
            let refund_acc = get_virtual_user_account(vec.refund);
            // REFUND: Send staked tokens from the node to the first controller
            do {
                let from_subaccount = port2subaccount({
                    vid;
                    flow = #payment;
                    id = 0;
                });

                let bal = dvf.balance(meta.billing.ledger, ?from_subaccount);
                if (bal > 0) {
                    label refund_payment do {
                        
                        ignore dvf.send({
                            ledger = meta.billing.ledger;
                            to = refund_acc;
                            amount = bal;
                            memo = null;
                            from_subaccount = ?from_subaccount;
                        });
                    };
                };

                dvf.unregisterSubaccount(?port2subaccount({ vid = vid; flow = #payment; id = 0 }));
            };

            label source_refund for (xsource in vec.sources.vals()) {
                let source = U.onlyIC(xsource);

                let #ok(sinfo) = sourceInfo(vid, source.account.subaccount) else continue source_refund;
                if (not sinfo.mine) return continue source_refund;

                dvf.unregisterSubaccount(source.account.subaccount);

                // RETURN tokens from all sources
                do {
                    let bal = dvf.balance(source.ledger, source.account.subaccount);
                    if (bal > 0) {
                        ignore dvf.send({
                            ledger = source.ledger;
                            to = refund_acc;
                            amount = bal;
                            memo = null;
                            from_subaccount = source.account.subaccount;
                        });
                    };
                };
            };

            ignore Map.remove(mem.nodes, Map.n32hash, vid);
        };

        public func start<system>(can : Principal) : () {
            mem.thiscan := ?can;
        };

        private func get_supported_ledgers() : [ICRC55.SupportedLedger] {
            Array.map<Principal, ICRC55.SupportedLedger>(dvf.get_ledger_ids(), func(x) = #ic(x));
        };

        public func icrc55_get_defaults(id : Text) : XCreateRequest {
            getDefaults(id, get_supported_ledgers());
        };

        public func icrc55_command(caller : Principal, cmds : [ICRC55.Command<XCreateRequest, XModifyRequest>]) : [ICRC55.CommandResponse<XShared>] {

            let res = Vector.new<ICRC55.CommandResponse<XShared>>();
            for (cmd in cmds.vals()) {
                let r : ICRC55.CommandResponse<XShared> = switch (cmd) {
                    case (#create_node(req, custom)) {
                        #create_node(icrc55_create_node(caller, req, custom));
                    };
                    case (#delete_node(vid)) {
                        #delete_node(icrc55_delete_node(caller, vid));
                    };
                    case (#modify_node(vid, nreq, custom)) {
                        #modify_node(icrc55_modify_node(caller, vid, nreq, custom));
                    };
                    case (#withdraw_node(req)) {
                        #withdraw_node(icrc55_withdraw_node(caller, req));
                    };
                    case (#withdraw_virtual(req)) {
                        #withdraw_virtual(icrc55_withdraw_virtual(caller, req));
                    };
                };
                Vector.add(res, r);
            };
            Vector.toArray(res);

        };

        public func icrc55_withdraw_virtual(caller:Principal, req: ICRC55.WithdrawVirtualRequest) : ICRC55.WithdrawVirtualResponse {
            if (caller != req.account.owner) return #err("Not owner");
            let acc = get_virtual_user_account(req.account);
            let to = switch(req.to) {
                case (#ic(to)) to;
                case (_) return #err("Ledger not supported");
            };

            switch(dvf.send({
                ledger = to.ledger;
                to = to.account;
                amount = req.amount;
                memo = null;
                from_subaccount = acc.subaccount;
            })) {
                case (#ok(id)) #ok(id);
                case (#err(e)) #err(debug_show(e));
            };

        };

        public func icrc55_virtual_balances(_caller: Principal, req: ICRC55.VirtualBalancesRequest) : ICRC55.VirtualBalancesResponse {
            let acc = get_virtual_user_account(req);
            let rez = Vector.new<(ICRC55.SupportedLedger, Nat)>();
            for (ledger in dvf.get_ledger_ids().vals()) {
                let bal = dvf.balance(ledger, acc.subaccount);
                Vector.add(rez, (#ic(ledger), bal));
            };
            Vector.toArray(rez);
        };
      

        public func icrc55_withdraw_node(caller : Principal, req : ICRC55.WithdrawNodeRequest) : ICRC55.WithdrawNodeResponse {
            let ?(vid, vec) = getNode(#id(req.id)) else return #err("Node not found");
            if (Option.isNull(Array.indexOf(caller, vec.controllers, Principal.equal))) return #err("Not a controller");

            let ?source = getSource(vid, vec, Nat8.toNat(req.source_port)) else return #err("Source not found");
            let acc = U.onlyIC(req.to).account;
            let bal = source.balance();
            if (req.amount > bal) return #err("Insufficient balance");
            ignore source.send(#external_account(acc), req.amount);
            #ok();
        };

        public func icrc55_create_node(caller : Principal, req : ICRC55.NodeRequest, custom : XCreateRequest) : CreateNodeResp<XShared> {
            let ?thiscanister = mem.thiscan else return #err("This canister not set");
            // TODO: Limit tempory node creation per hour (against DoS)

            // if (Option.isNull(dvf.get_ledger(v.ledger))) return #err("Ledger not supported");

            // Payment - If the local caller wallet has enough funds send the fee to the node payment balance
            // Once the node is deleted, we can send the fee back to the caller
            let id = mem.next_node_id;

            let node = switch (node_createRequest2Mem(req, custom, id, thiscanister)) {
                case (#ok(x)) x;
                case (#err(e)) return #err(e);
            };

            let meta = nodeMeta(node.custom, get_supported_ledgers());

            let caller_subaccount = ?Principal.toLedgerAccount(caller, null);
            let caller_balance = dvf.balance(meta.billing.ledger, caller_subaccount);
            var paid = false;
            let payment_amount = meta.billing.min_create_balance;
            if (caller_balance >= payment_amount) {
                let node_payment_account = port2subaccount({
                    vid = id;
                    flow = #payment;
                    id = 0;
                });
                ignore dvf.send({
                    ledger = meta.billing.ledger;
                    to = {
                        owner = thiscanister;
                        subaccount = ?node_payment_account;
                    };
                    amount = payment_amount;
                    memo = null;
                    from_subaccount = caller_subaccount;
                });
                paid := true;
            };

            if (not paid and not settings.ALLOW_TEMP_NODE_CREATION) return #err("Temp node creation not allowed");

            if (not paid) node.billing.expires := ?(U.now() + settings.TEMP_NODE_EXPIRATION_SEC * 1_000_000_000);

            ignore Map.put(mem.nodes, Map.n32hash, id, node);

            // Registration required because the ICP ledger is hashing owner+subaccount
            dvf.registerSubaccount(?port2subaccount({ vid = id; flow = #payment; id = 0 }));

            label source_reg for (xsource in node.sources.vals()) {
                let source = U.onlyIC(xsource);
                dvf.registerSubaccount(source.account.subaccount);
            };
            mem.next_node_id += 1;

            let ?node_shared = get_node(#id(id)) else return #err("Couldn't find after create");
            #ok(node_shared);
        };

        public func icrc55_modify_node(caller : Principal, vid : NodeId, nreq : ?ICRC55.CommonModRequest, custom : ?XModifyRequest) : ModifyNodeResp<XShared> {
            let ?thiscanister = mem.thiscan else return #err("This canister not set");
            let ?(_, vec) = getNode(#id(vid)) else return #err("Node not found");
            if (Option.isNull(Array.indexOf(caller, vec.controllers, Principal.equal))) return #err("Not a controller");

            node_modifyRequest(vid, vec, nreq, custom, thiscanister);

        };

        public func icrc55_get_pylon_meta() : ICRC55.NodeFactoryMetaResp {
            {
                name = settings.PYLON_NAME;
                governed_by = settings.PYLON_GOVERNED_BY;
                nodes = meta(get_supported_ledgers());
                temporary_nodes = {
                    allowed = settings.ALLOW_TEMP_NODE_CREATION;
                    expire_sec = settings.TEMP_NODE_EXPIRATION_SEC;
                };
                create_allowed = true;
            };
        };

        public func getNode(req : ICRC55.GetNode) : ?(NodeId, NodeMem<XMem>) {
            let (vec : NodeMem<XMem>, vid : NodeId) = switch (req) {
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

        public func get_node(req : ICRC55.GetNode) : ?NodeShared<XShared> {
            let ?(vid, vec) = getNode(req) else return null;
            return ?vecToShared(vec, vid);
        };

        public func icrc55_get_nodes(req : [ICRC55.GetNode]) : [?NodeShared<XShared>] {
            return Array.map<ICRC55.GetNode, ?NodeShared<XShared>>(req, func(x) = get_node(x));
        };

        public func vecToShared(vec : NodeMem<XMem>, vid : NodeId) : NodeShared<XShared> {
            let ?thiscanister = mem.thiscan else Debug.trap("Not initialized");
            let meta = nodeMeta(vec.custom, get_supported_ledgers());
            let billing_subaccount = ?port2subaccount({
                            vid;
                            flow = #payment;
                            id = 0;
                        });
            let current_billing_balance = dvf.balance(meta.billing.ledger, billing_subaccount);
            {
                id = vid;
                custom = toShared(vec.custom);
                created = vec.created;
                extractors = vec.extractors;
                modified = vec.modified;
                controllers = vec.controllers;
                sources = Array.map<ICRC55.Endpoint, ICRC55.SourceEndpointResp>(
                    vec.sources,
                    func(x) {
                        let s = U.onlyIC(x);
                        {
                            balance = dvf.balance(s.ledger, s.account.subaccount);
                            endpoint = x;
                        };
                    },
                );
                destinations = vec.destinations;
                refund = vec.refund;
                active = vec.active;
                billing = {
                    meta.billing with
                    frozen = vec.billing.frozen;
                    expires = vec.billing.expires;
                    current_balance = current_billing_balance;
                    account = {
                        owner = thiscanister;
                        subaccount = billing_subaccount;
                    };
                };
            };
        };

        public func icrc55_get_controller_nodes(_caller : Principal, req : ICRC55.GetControllerNodesRequest) : [NodeShared<XShared>] {
            // Unoptimised for now, but it will get it done
            let res = Vector.new<NodeShared<XShared>>();
            var cid = 0;
            label search for ((vid, vec) in entries()) {
                if (not Option.isNull(Array.indexOf(req.id, vec.controllers, Principal.equal))) {
                    if (req.start <= cid and cid < req.start + req.length) Vector.add(res, vecToShared(vec, vid));
                    if (cid >= req.start + req.length) break search;
                    cid += 1;
                };
            };
            Vector.toArray(res);
        };



        dvf.onEvent(
            func(event) {
                switch (event) {
                    case (#received(r)) {

                        let ?port = subaccount2port(r.to_subaccount) else return; // We can still recieve tokens in caller subaccounts, which we won't send back right away
                        let found = getNode(#id(port.vid));

                        // Handle payment after temporary vector was created
                        let ?(_, rvec) = found else return;
                        let from_subaccount = port2subaccount({
                            vid = port.vid;
                            flow = #payment;
                            id = 0;
                        });

                        let bal = dvf.balance(r.ledger, ?from_subaccount);
                        let meta = nodeMeta(rvec.custom, get_supported_ledgers());
                        if (bal >= meta.billing.min_create_balance) {
                            rvec.billing.expires := null;
                        };

                    };
                    case (_) ();
                };
            }
        );

 
        // Remove expired nodes
        ignore Timer.recurringTimer<system>(
            #seconds(60),
            func() : async () {
                let now = Nat64.fromNat(Int.abs(Time.now()));
                label vloop for ((vid, vec) in entries()) {
                    let ?expires = vec.billing.expires else continue vloop;
                    if (now > expires) {

                        // DELETE Node from memory
                        delete(vid);
                    };
                };
            },
        );


        private func chargeNodeFees() : () {
            
            let nowU64 = U.now();
            let now = Nat64.toNat(nowU64);
            label vloop for ((vid, vec) in entries()) {
                if (vec.billing.expires != null) continue vloop; // Not charging temp nodes

                let meta = nodeMeta(vec.custom, get_supported_ledgers());
                let billing_subaccount = ?port2subaccount({
                    vid;
                    flow = #payment;
                    id = 0;
                });

                let current_billing_balance = dvf.balance(meta.billing.ledger, billing_subaccount);

                var fee_to_charge = ((meta.billing.cost_per_day * (now - Nat64.toNat(vec.billing.last_billed):Nat)) / (60*60*24)) / 1_000_000_000;

                if (current_billing_balance < fee_to_charge) {
                    vec.billing.expires := ?(nowU64 + settings.TEMP_NODE_EXPIRATION_SEC);
                    fee_to_charge := current_billing_balance;
                };

                // Freeze nodes if bellow threshold
                let days_left = (current_billing_balance - fee_to_charge:Nat) / meta.billing.cost_per_day; 
                if (days_left <= meta.billing.freezing_threshold_days) {
                    vec.billing.frozen := true;
                };

                if (fee_to_charge > 0) {
                    ignore dvf.send({
                        ledger = meta.billing.ledger;
                        to = authorAccount(vec.custom);
                        amount = fee_to_charge;
                        memo = null;
                        from_subaccount = billing_subaccount;
                    });
                };

                vec.billing.last_billed := nowU64;

            }
        };

        private func node_createRequest2Mem(req : ICRC55.NodeRequest, creq : XCreateRequest, id : NodeId, thiscan : Principal) : Result.Result<NodeMem<XMem>, Text> {

            let custom = createRequest2Mem(creq);

            let sources = switch (portMapSources(id, custom, thiscan, req.sources)) { case (#err(e)) return #err(e); case (#ok(x)) x; };
            let destinations = switch (portMapDestinations(id, custom, req.destinations)) { case (#err(e)) return #err(e); case (#ok(x)) x; };

            let node : NodeMem<XMem> = {
                var sources = sources;
                var destinations = destinations;
                var refund = req.refund;
                var extractors = req.extractors;
                created = U.now();
                var modified = U.now();
                var controllers = req.controllers;
                var affiliate = req.affiliate;
                custom;
                billing = {
                    var expires = null;
                    var frozen = false;
                    var last_billed = U.now();
                };
                var active = true;
                
            };

            #ok(node);
        };

        

        private func node_modifyRequest(id : NodeId, vec : NodeMem<XMem>, nreq : ?ICRC55.CommonModRequest, creq : ?XModifyRequest, thiscan : Principal) : ModifyNodeResp<XShared> {

            label source_unregister for (xsource in vec.sources.vals()) {
                let source = U.onlyIC(xsource);
                dvf.unregisterSubaccount(source.account.subaccount);
            };

            ignore do ? {
                  switch (modifyRequestMut(vec.custom, creq!)) {
                        case (#err(e)) return #err(e);
                        case (#ok()) ();
                    };
            };

            // TODO: Check this - we are mutating and then returning error if source/destination fails

            ignore do ? { vec.destinations := switch(portMapDestinations(id, vec.custom, nreq!.destinations!)) {case (#err(e)) return #err(e); case (#ok(d)) d; } };
            ignore do ? { vec.sources := switch(portMapSources(id, vec.custom, thiscan, nreq!.sources!)) {case (#err(e)) return #err(e); case (#ok(d)) d; } };

            ignore do ? { vec.extractors := nreq!.extractors! };
             
            vec.modified := U.now();
            ignore do ? { vec.controllers := nreq!.controllers!};
            ignore do ? { vec.refund := nreq!.refund! };
                
            ignore do ? {vec.active := nreq!.active!};

            label source_register for (xsource in vec.sources.vals()) {
                let source = U.onlyIC(xsource);
                dvf.registerSubaccount(source.account.subaccount);
            };

            #ok(vecToShared(vec, id));

        };

        private func portMapSources(id : NodeId, custom : XMem, thiscan : Principal, sourcesProvided : [ICRC55.Endpoint]) : Result.Result<[ICRC55.Endpoint], Text> {

            // Sources
            let s_res = sourceMap(id, custom, thiscan, sourcesProvided);

            let sources = switch (s_res) {
                case (#ok(s)) s;
                case (#err(e)) return #err(e);
            };

            #ok(sources)
        };

        private func portMapDestinations(id : NodeId, custom : XMem,  destinationsProvided : [ICRC55.DestinationEndpoint]) : Result.Result<[ICRC55.DestinationEndpoint], Text> {

            // Destinations
            let d_res = destinationMap(custom, destinationsProvided);

            let destinations = switch (d_res) {
                case (#ok(d)) d;
                case (#err(e)) return #err(e);
            };

            #ok(destinations);
        };

        ignore Timer.setTimer<system>(
            #seconds(1),
            func() : async () {
                // Register the canister in pylon registry
                let reg = actor ("elgu6-jiaaa-aaaal-qkkiq-cai") : actor {
                    register_pylon : shared () -> async ();
                };
                await reg.register_pylon();
            },
        );

        ignore Timer.recurringTimer<system>(
            #seconds(10),
            func() : async () {
                chargeNodeFees();
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
