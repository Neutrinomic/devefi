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
        var refund : [Endpoint];
        var controllers : [Principal];
        created : Nat64;
        var modified : Nat64;
        var expires : ?Nat64;
        var active : Bool;
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
        PYLON_GOVERNED_BY : Text;
        PYLON_NAME : Text;
        
    };

    public let DEFAULT_SETTINGS : SETTINGS = {
        ALLOW_TEMP_NODE_CREATION = true;
        TEMP_NODE_EXPIRATION_SEC = 3600;
        PYLON_GOVERNED_BY = "Unknown";
        PYLON_NAME = "Testing Pylon";
    };

    public type SourceSendErr = ICRCLedger.SendError or {#AccountNotSet};
 

    public class Node<system, XCreateRequest, XMem, XShared, XModifyRequest>({
        settings : SETTINGS;
        mem : Mem<XMem>;
        dvf : DeVeFi.DeVeFi;
        nodeCreateFee : (NodeMem<XMem>) -> {
            amount : Nat;
            ledger : Principal;
        };
        
        toShared : (XMem) -> XShared;
        sourceMap : (NodeId, XMem, Principal, [Endpoint]) -> R<[Endpoint], Text>;
        destinationMap : (XMem, [DestinationEndpoint]) -> R<[DestinationEndpoint], Text>;
        modifyRequestMut : (XMem, XModifyRequest) -> R<(), Text>;
        createRequest2Mem : (XCreateRequest) -> XMem;
        meta : ([ICRC55.SupportedLedger]) -> [ICRC55.NodeMeta];
        getDefaults : (Text, [ICRC55.SupportedLedger]) -> XCreateRequest;
    }) {


        private func onlyIC(ep : Endpoint) : ICRC55.ICEndpoint {
            let #ic(x) = ep else Debug.trap("Not supported");
            x;
        };

        // TODO : Disallow one node taking from the source of another without being in extractors
        public class Source(
            cls : {
                endpoint : Endpoint;
                vec : NodeMem<XMem>;
            }
        ) {

            public let endpoint = onlyIC(cls.endpoint) : ICRC55.ICEndpoint;


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
            ) :  R<Nat64, SourceSendErr>  {
                let to : Account = switch (location) {
                    case (#destination({ port })) {
                        let ?acc = onlyICDest(cls.vec.destinations[port]).account else return #err(#AccountNotSet);
                        acc;
                    };

                    case (#remote_destination({ node; port })) {
                        let ?to_vec = Map.get(mem.nodes, Map.n32hash, node) else return #err(#AccountNotSet);
                        let ?acc = onlyICDest(to_vec.destinations[port]).account else return #err(#AccountNotSet);
                        acc;
                    };

                    case (#remote_source({ node; port })) {
                        let ?to_vec = Map.get(mem.nodes, Map.n32hash, node) else return #err(#AccountNotSet);
                        onlyIC(to_vec.sources[port]).account;
                    };

                    case (#source({ port })) {
                        onlyIC(cls.vec.sources[port]).account;
                    };

                    case (#external_account(account)) {
                        account;
                    };
                };


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
            port_idx < vec.destinations.size() and not Option.isNull(onlyICDest(vec.destinations[port_idx]).account);
        };

        private func sourceInfo(vid: NodeId, subaccount: ?Blob ) : R<{allowed: Bool; mine: Bool}, ()> {
            let ?ep_port = subaccount2port(subaccount) else return #err;
            if (ep_port.vid != vid) { // Is it remote vector
                let ?remote_vec = Map.get(mem.nodes, Map.n32hash, ep_port.vid) else return #err;
                // Check if this vector is in extractors of remote vector if the source isn't its own
                if (Option.isNull(Array.indexOf(vid, remote_vec.extractors, Nat32.equal))) return #ok({mine=false; allowed=false}); // Doesn't have access
                return #ok({mine=false; allowed=true});
            };
            return #ok({mine=true; allowed=true});
        };

        public func getSource(vid: NodeId, vec : NodeMem<XMem>, port_idx : Nat) : ?Source {
            if (port_idx >= vec.sources.size()) return null;

            let #ok(sinfo) = sourceInfo(vid, onlyIC(vec.sources[port_idx]).account.subaccount) else return null;
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
        public func delete(vid : NodeId) : () {
            let ?vec = Map.get(mem.nodes, Map.n32hash, vid) else return;
            // TODO: Don't allow deletion if there are no refund endpoints

            let fee = nodeCreateFee(vec);
            // REFUND: Send staked tokens from the node to the first controller
            do {
                let from_subaccount = port2subaccount({
                    vid;
                    flow = #payment;
                    id = 0;
                });

                let bal = dvf.balance(fee.ledger, ?from_subaccount);
                if (bal > 0) {
                    label refund_payment do { 
                        let ?xf = Array.find<ICRC55.Endpoint>(vec.refund, func(x) = onlyIC(x).ledger == fee.ledger) else break refund_payment;
                        let refund = onlyIC(xf);

                        ignore dvf.send({
                            ledger = fee.ledger;
                            to = refund.account;
                            amount = bal;
                            memo = null;
                            from_subaccount = ?from_subaccount;
                        });
                    }
                };

                dvf.unregisterSubaccount(?port2subaccount({ vid = vid; flow = #payment; id = 0 }));
            };

            label source_refund for (xsource in vec.sources.vals()) {
                let source = onlyIC(xsource);

                let #ok(sinfo) = sourceInfo(vid, source.account.subaccount) else continue source_refund;
                if (not sinfo.mine) return continue source_refund;

                dvf.unregisterSubaccount(source.account.subaccount);

                // RETURN tokens from all sources
                do {
                    let bal = dvf.balance(source.ledger, source.account.subaccount);
                    if (bal > 0) {
                        // try to find refund endpoint for that ledger source
                        let ?xf = Array.find<ICRC55.Endpoint>(vec.refund, func(x) = onlyIC(x).ledger == source.ledger) else continue source_refund;
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

        public func start<system>(can : Principal) : () {
            mem.thiscan := ?can;
        };

        private func get_supported_ledgers() : [ICRC55.SupportedLedger] {
            Array.map<Principal, ICRC55.SupportedLedger>( dvf.get_ledger_ids(), func(x) = #ic(x));
        };

        public func icrc55_get_defaults(id:Text) : XCreateRequest {
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
                    case (#change_active_node(req)) {
                        #change_active_node(icrc55_change_active_node(caller, req));
                    };
                };
                Vector.add(res, r);
            };
            Vector.toArray(res);

        };
        public func icrc55_change_active_node(caller : Principal, req : ICRC55.ChangeActiveNodeRequest) : ICRC55.ChangeActiveNodeResponse {
            let ?(_, vec) = getNode(#id(req.id)) else return #err("Node not found");
            if (Option.isNull(Array.indexOf(caller, vec.controllers, Principal.equal))) return #err("Not a controller");

            vec.active := req.active;
            #ok();
        };

        public func icrc55_withdraw_node(caller : Principal, req : ICRC55.WithdrawNodeRequest) : ICRC55.WithdrawNodeResponse {
            let ?(vid, vec) = getNode(#id(req.id)) else return #err("Node not found");
            if (Option.isNull(Array.indexOf(caller, vec.controllers, Principal.equal))) return #err("Not a controller");

            let ?source = getSource(vid, vec, req.source_port) else return #err("Source not found");
            let acc = onlyIC(req.to).account;
            ignore source.send(#external_account(acc), source.balance());
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
            dvf.registerSubaccount(?port2subaccount({ vid = id; flow = #payment; id = 0 }));

            label source_reg for (xsource in node.sources.vals()) {
                let source = onlyIC(xsource);
                dvf.registerSubaccount(source.account.subaccount);
            };
            mem.next_node_id += 1;

            let ?node_shared = icrc55_get_node(#id(id)) else return #err("Couldn't find after create");
            #ok(node_shared);
        };

        public func icrc55_modify_node(caller : Principal, vid : NodeId, nreq : ?ICRC55.CommonModRequest, custom : ?XModifyRequest) : ModifyNodeResp<XShared> {
            let ?thiscanister = mem.thiscan else return #err("This canister not set");
            let ?(_, vec) = getNode(#id(vid)) else return #err("Node not found");
            if (Option.isNull(Array.indexOf(caller, vec.controllers, Principal.equal))) return #err("Not a controller");

           
            node_modifyRequest(vid, vec, nreq, custom, thiscanister);
             
        };

        public func icrc55_get_nodefactory_meta() : ICRC55.NodeFactoryMetaResp {
            {
                name = settings.PYLON_NAME;
                governed_by = settings.PYLON_GOVERNED_BY;
                nodes = meta(get_supported_ledgers())
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

        public func icrc55_get_node(req : ICRC55.GetNode) : ?NodeShared<XShared> {
            let ?(vid, vec) = getNode(req) else return null;
            return ?vecToShared(vec, vid);
        };

        public func vecToShared(vec : NodeMem<XMem>, vid : NodeId) : NodeShared<XShared> {
            {
                id = vid;
                custom = toShared(vec.custom);
                created = vec.created;
                extractors = vec.extractors;
                modified = vec.modified;
                controllers = vec.controllers;
                expires = vec.expires;
                sources = Array.map<ICRC55.Endpoint, ICRC55.SourceEndpointResp>(vec.sources, func (x) {
                    let s = onlyIC(x);
                    {balance = dvf.balance(s.ledger, s.account.subaccount); endpoint = x};   
                });
                destinations = vec.destinations;
                refund = vec.refund;
                active = vec.active;
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

        public func icrc55_create_node_get_fee(creator : Principal, req : ICRC55.NodeRequest, custom : XCreateRequest) : ICRC55.NodeCreateFeeResp {
            let ?thiscanister = mem.thiscan else Debug.trap("Not initialized");
            let { ledger; amount } = nodeCreateFee(switch (node_createRequest2Mem(req, custom, 0, thiscanister)) { case (#ok(x)) x; case (#err(e)) return #err(e) });
            #ok({
                ledger;
                amount;
                subaccount = Principal.toLedgerAccount(creator, null);
            });
        };

        dvf.onEvent(
            func(event) {
                switch (event) {
                    case (#received(r)) {

                        let ?port = subaccount2port(r.to_subaccount) else return; // We can still recieve tokens in caller subaccounts, which we won't send back right away
                        let found = getNode(#id(port.vid));

                        // RETURN tokens: If no node is found send tokens back (perhaps it was deleted)
                        // if (Option.isNull(found)) {
                        //     let #icrc(addr) = r.from else return; // Can only send to icrc accounts for now
                        //     ignore dvf.send({
                        //         ledger = r.ledger;
                        //         to = addr;
                        //         amount = r.amount;
                        //         memo = null;
                        //         from_subaccount = r.to.subaccount;
                        //     });
                        //     return;
                        // };

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

        private func onlyICDest(ep : ICRC55.DestinationEndpoint) : ICRC55.DestICEndpoint {
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

        private func node_createRequest2Mem(req : ICRC55.NodeRequest, creq : XCreateRequest, id : NodeId, thiscan : Principal) : Result.Result<NodeMem<XMem>, Text> {

            let custom = createRequest2Mem(creq);

            

            let { sources; destinations } = switch (portMap(id, custom, thiscan, req.destinations, req.sources)) {
                case (#err(e)) return #err(e); 
                case (#ok(x)) x;
            };

            let node : NodeMem<XMem> = {
                var sources = sources;
                var destinations = destinations;
                var refund = req.refund;
                var extractors = req.extractors;
                created = U.now();
                var modified = U.now();
                var controllers = req.controllers;
                custom;
                var expires = null;
                var active = true;
            };

            #ok(node);
        };

        private func node_modifyRequest(id : NodeId, vec : NodeMem<XMem>, nreq : ?ICRC55.CommonModRequest, creq : ?XModifyRequest, thiscan : Principal) : ModifyNodeResp<XShared> {
            
            label source_unregister for (xsource in vec.sources.vals()) {
                let source = onlyIC(xsource);
                dvf.unregisterSubaccount(source.account.subaccount);
            };
            
            switch (creq) {
                case (?cr) {
                    switch (modifyRequestMut(vec.custom, cr)) {
                        case (#err(e)) return #err(e);
                        case (#ok()) ();
                    };
                };
                case (null) ();
            };

            let provided_destinations = switch (nreq) {
                case (?r) r.destinations;
                case (null) vec.destinations;
            };

            let provided_sources = switch (nreq) {
                case (?r) r.sources;
                case (null) vec.sources;
            };
            // TODO: Check this - we are mutating and then returning error if source/destination fails
            let { sources; destinations } = switch (portMap(id, vec.custom, thiscan, provided_destinations, provided_sources)) {
                case (#err(e)) return #err(e);
                case (#ok(x)) x;
            };

     
            // Modify if no errors
            vec.destinations := destinations;
            vec.sources := sources;
            vec.extractors := switch (nreq) {
                case (?r) r.extractors;
                case (null) vec.extractors;
            };
            vec.modified := U.now();
            ignore do ? {
                vec.controllers := nreq!.controllers;
                vec.refund := nreq!.refund;
            };
            
            label source_register for (xsource in vec.sources.vals()) {
                let source = onlyIC(xsource);
                dvf.registerSubaccount(source.account.subaccount);
            };
            
            #ok(vecToShared(vec, id));

        };

        private func portMap(id : NodeId, custom : XMem, thiscan : Principal, destinationsProvided : [ICRC55.DestinationEndpoint], sourcesProvided: [ICRC55.Endpoint]) : Result.Result<{ sources : [ICRC55.Endpoint]; destinations : [ICRC55.DestinationEndpoint] }, Text> {

            // Sources
            let s_res = sourceMap(id, custom, thiscan, sourcesProvided);

          

            let sources = switch (s_res) {
                case (#ok(s)) s;
                case (#err(e)) return #err(e);
            };

            // Destinations
            let d_res = destinationMap(custom, destinationsProvided);

            let destinations = switch (d_res) {
                case (#ok(d)) d;
                case (#err(e)) return #err(e);
            };

            #ok({
                sources = sources;
                destinations = destinations;
            });
        };

         ignore Timer.setTimer<system>(#seconds(1), func() : async () {
            // Register the canister in pylon registry
            let reg = actor("elgu6-jiaaa-aaaal-qkkiq-cai") : actor {
                register_pylon : shared () -> async ();
            };
            await reg.register_pylon();
        });
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
