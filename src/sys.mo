import Map "mo:map/Map";
import DeVeFi "./lib";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Result "mo:base/Result";
import U "./utils";

import Array "mo:base/Array";
import ICRC55 "./ICRC55";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";

import Vector "mo:vector";
import Debug "mo:base/Debug";

import Ver1 "./memory/v1";
import MU "mo:mosup";
import Core "./core";

module {

    let VM = Ver1.Core;

    public type R<A, B> = Result.Result<A, B>;

    public type Account = VM.Account;
    public type Flow = VM.Flow;
    public type Port = VM.Port;
    public type PortInfo = VM.PortInfo;
    public type LedgerIdx = VM.LedgerIdx;
    public type EndpointsDescription = VM.EndpointsDescription;
    public type Endpoint = VM.Endpoint;
    public type EndpointOpt = VM.EndpointOpt;
    public type NodeId = VM.NodeId;
    public type Mem = VM.Mem;
    public type EndpointStored = VM.EndpointStored;
    public type EndpointOptStored = VM.EndpointOptStored;
    public type NodeMem = VM.NodeMem;
    public type ModuleId = VM.ModuleId;

    public type CreateNodeResp<A> = ICRC55.CreateNodeResponse<A>;
    public type ModifyNodeResp<A> = ICRC55.ModifyNodeResponse<A>;
    public type NodeShared<AS> = ICRC55.GetNodeResponse<AS>;


    public class Mod<system, XCreateRequest, XShared, XModifyRequest>({
        xmem : MU.MemShell<Mem>;
        dvf : DeVeFi.DeVeFi;
        core : Core.Mod;
        vmod : {
            toShared : (ModuleId, NodeId) -> R<XShared, Text>;
            sources : (ModuleId, NodeId) -> EndpointsDescription;
            destinations : (ModuleId, NodeId) -> EndpointsDescription;    
            modify : (ModuleId, NodeId, XModifyRequest) -> R<(), Text>;
            create : (NodeId, XCreateRequest) -> R<ModuleId, Text>;
            meta : () -> [ICRC55.NodeMeta];
            nodeMeta : (ModuleId) -> ICRC55.NodeMeta;
            getDefaults : (ModuleId) -> XCreateRequest;
        }
        
    }) {
        let mem = MU.access(xmem);


        public func icrc55_delete_node(caller : Account, vid : NodeId) : R<(), Text> {
            // Check if caller is controller
            let ?vec = Map.get(mem.nodes, Map.n32hash, vid) else return #err("Node not found");
            if (Option.isNull(Array.indexOf(caller, vec.controllers, U.Account.equal))) return #err("Not a controller");

            #ok(core.delete(vid));
        };




        public func icrc55_get_defaults(id : Text) : XCreateRequest {
            vmod.getDefaults(id);
        };

        public func icrc55_command<DispatchErr>(caller : Principal, req : ICRC55.BatchCommandRequest<XCreateRequest, XModifyRequest>, dispatch: (ICRC55.BatchCommandRequest<XCreateRequest, XModifyRequest>) -> {#Ok:Nat; #Err:DispatchErr}) : ICRC55.BatchCommandResponse<XShared> {
            ignore do ? { if (req.expire_at! < U.now()) return #err(#expired) };
            if (caller != req.controller.owner) return #err(#access_denied);
            let res = Vector.new<ICRC55.CommandResponse<XShared>>();
            for (cmd in req.commands.vals()) {
                let r : ICRC55.CommandResponse<XShared> = switch (cmd) {
                    case (#create_node(nreq, custom)) {
                        #create_node(icrc55_create_node(req.controller, nreq, custom));
                    };
                    case (#delete_node(vid)) {
                        #delete_node(icrc55_delete_node(req.controller, vid));
                    };
                    case (#modify_node(vid, nreq, custom)) {
                        #modify_node(icrc55_modify_node(req.controller, vid, nreq, custom));
                    };
                    case (#source_transfer(nreq)) {
                        #source_transfer(icrc55_source_transfer(req.controller, nreq));
                    };
                    case (#virtual_transfer(nreq)) {
                        #virtual_transfer(icrc55_virtual_transfer(req.controller, nreq));
                    };
                    case (#top_up_node(nreq)) {
                        #top_up_node(icrc55_top_up_node(req.controller, nreq));
                    }
                };
                Vector.add(res, r);
            };
            
            let res_command_only_ok = Vector.new<ICRC55.Command<XCreateRequest, XModifyRequest>>();
            for (r in Vector.keys(res)) {
                Vector.add(res_command_only_ok, req.commands[r]);
            };  

            // For now we won't use other reducers so that is fine
            let #Ok(id) = dispatch({req with commands = Vector.toArray(res_command_only_ok)}) else return #err(#other("Dispatch failed"));
            

            #ok({id; commands=Vector.toArray(res)});

        };

        public func icrc55_top_up_node(caller : Account, req : ICRC55.TopUpNodeRequest) : ICRC55.TopUpNodeResponse {
            let ?(vid, vec) = core.getNode(#id(req.id)) else return #err("Node not found");
            if (Option.isNull(Array.indexOf(caller, vec.controllers, U.Account.equal))) return #err("Not a controller");

            let billing = vec.meta.billing;

            let caller_subaccount = ?Principal.toLedgerAccount(caller.owner, caller.subaccount);
            let caller_balance = dvf.balance(core.pylon_billing.ledger, caller_subaccount);

            let payment_account = U.port2subaccount({
                vid;
                flow = #payment;
                id = 0;
            });

            if (caller_balance < req.amount) return #err("Insufficient balance");
            let ?thiscanister = mem.thiscan else return #err("This canister not set");

            ignore dvf.send({
                ledger = core.pylon_billing.ledger;
                to = {
                    owner = thiscanister;
                    subaccount = ?payment_account;
                };
                amount = req.amount;
                memo = null;
                from_subaccount = caller_subaccount;
            });

            #ok();
        };  

        public func icrc55_virtual_transfer(caller:Account, req: ICRC55.VirtualTransferRequest) : ICRC55.VirtualTransferResponse {
            if (caller != req.account) return #err("Not owner");
            let acc = core.get_virtual_account(req.account);
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
            let acc = core.get_virtual_account(req);
            let rez = Vector.new<(ICRC55.SupportedLedger, Nat)>();
            for (ledger in dvf.get_ledger_ids().vals()) {
                let bal = dvf.balance(ledger, acc.subaccount);
                Vector.add(rez, (#ic(ledger), bal));
            };
            Vector.toArray(rez);
        };
      

        public func icrc55_source_transfer(caller : Account, req : ICRC55.SourceTransferRequest) : ICRC55.SourceTransferResponse {
            let ?(vid, vec) = core.getNode(#id(req.id)) else return #err("Node not found");
            if (Option.isNull(Array.indexOf(caller, vec.controllers, U.Account.equal))) return #err("Not a controller");

            let ?source = core.getSource(vid, vec, Nat8.toNat(req.source_idx)) else return #err("Source not found");
            let #ic(acc) = req.to else return #err("Ledger not supported");
            let bal = source.balance();
            if (req.amount > bal) return #err("Insufficient balance");
            ignore source.send(#external_account(acc), req.amount);
            core.chargeOpCost(vid, vec, 1);
            #ok();
        };

        public func icrc55_create_node(caller : Account, req : ICRC55.CommonCreateRequest, custom : XCreateRequest) : CreateNodeResp<XShared> {
            let ?thiscanister = mem.thiscan else return #err("This canister not set");
            // TODO: Limit tempory node creation per hour (against DoS)

            // if (Option.isNull(dvf.get_ledger(v.ledger))) return #err("Ledger not supported");

            // Payment - If the local caller wallet has enough funds send the fee to the node payment balance
            // Once the node is deleted, we can send the fee back to the caller
            let id = mem.next_node_id;

            let node = switch (node_create(req, custom, id, thiscanister)) {
                case (#ok(x)) x;
                case (#err(e)) return #err(e);
            };

            let billing = node.meta.billing;

            let caller_subaccount = ?Principal.toLedgerAccount(caller.owner, caller.subaccount);
            let caller_balance = dvf.balance(core.pylon_billing.ledger, caller_subaccount);
            var paid = false;
            let payment_amount = core.pylon_billing.min_create_balance;
            if (caller_balance >= payment_amount) {
                let node_payment_account = U.port2subaccount({
                    vid = id;
                    flow = #payment;
                    id = 0;
                });
                ignore dvf.send({
                    ledger = core.pylon_billing.ledger;
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

            if (not paid and not core._settings.ALLOW_TEMP_NODE_CREATION) return #err("Temp node creation not allowed");

            if (not paid) node.billing.expires := ?(U.now() + core._settings.TEMP_NODE_EXPIRATION_SEC * 1_000_000_000);

            ignore Map.put(mem.nodes, Map.n32hash, id, node);

            // Registration required because the ICP ledger is hashing owner+subaccount
            dvf.registerSubaccount(?U.port2subaccount({ vid = id; flow = #payment; id = 0 }));

            label source_reg for (xsource in node.sources.vals()) {
                let source = U.onlyIC(xsource.endpoint);
                dvf.registerSubaccount(source.account.subaccount);
            };
            mem.next_node_id += 1;

            let ?node_shared = get_node(#id(id)) else return #err("Couldn't find after create");
            #ok(node_shared);
        };

        public func icrc55_modify_node(caller : Account, vid : NodeId, nreq : ?ICRC55.CommonModRequest, custom : ?XModifyRequest) : ModifyNodeResp<XShared> {
            let ?thiscanister = mem.thiscan else return #err("This canister not set");
            let ?(_, vec) = core.getNode(#id(vid)) else return #err("Node not found");
            if (Option.isNull(Array.indexOf(caller, vec.controllers, U.Account.equal))) return #err("Not a controller");
            core.chargeOpCost(vid, vec, 1);
            node_modifyRequest(vid, vec, nreq, custom, thiscanister);
            
        };

        public func icrc55_get_pylon_meta() : ICRC55.PylonMetaResp {
            let ?pylon_account = core._settings.PYLON_FEE_ACCOUNT else Debug.trap("Pylon account not set");
            {
                name = core._settings.PYLON_NAME;
                governed_by = core._settings.PYLON_GOVERNED_BY;
                nodes = vmod.meta();
                temporary_nodes = {
                    allowed = core._settings.ALLOW_TEMP_NODE_CREATION;
                    expire_sec = core._settings.TEMP_NODE_EXPIRATION_SEC;
                };
                create_allowed = true;
                supported_ledgers = core.get_supported_ledgers();
                billing = core.pylon_billing;
                pylon_account;
                platform_account = core.platform_account;
            };
        };
    

       

        public func get_node(req : ICRC55.GetNode) : ?NodeShared<XShared> {
            let ?(vid, vec) = core.getNode(req) else return null;
            return ?vecToShared(vec, vid);
        };

        public func icrc55_get_nodes(req : [ICRC55.GetNode]) : [?NodeShared<XShared>] {
            return Array.map<ICRC55.GetNode, ?NodeShared<XShared>>(req, func(x) = get_node(x));
        };

        // TODO: should return err
        public func vecToShared(vec : NodeMem, vid : NodeId) : NodeShared<XShared> {
            let ?thiscanister = mem.thiscan else Debug.trap("Not initialized");
            let billing = vec.meta.billing;
            let billing_subaccount = ?U.port2subaccount({
                            vid;
                            flow = #payment;
                            id = 0;
                        });
            let current_billing_balance = dvf.balance(core.pylon_billing.ledger, billing_subaccount);
            {
                id = vid;
                custom = ?U.ok_or_trap(vmod.toShared(vec.module_id, vid));
                created = vec.created;
                extractors = vec.extractors;
                modified = vec.modified;
                controllers = vec.controllers;
                sources = Array.map<EndpointStored, ICRC55.SourceEndpointResp>(
                    vec.sources,
                    func(x) {
                        let s = U.onlyIC(x.endpoint);
                        {
                            balance = dvf.balance(s.ledger, s.account.subaccount);
                            endpoint = x.endpoint;
                            name = x.name;
                        };
                    },
                );
                destinations = vec.destinations;
                refund = vec.refund;
                active = vec.active;
                billing = {
                    billing with
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
            label search for ((vid, vec) in core.entries()) {
                if (not Option.isNull(Array.indexOf(req.id, vec.controllers, U.Account.equal))) {
                    if (req.start <= cid and cid < req.start + req.length) Vector.add(res, vecToShared(vec, vid));
                    if (cid >= req.start + req.length) break search;
                    cid += 1;
                };
            };
            Vector.toArray(res);
        };




    
        private func node_create(req : ICRC55.CommonCreateRequest, creq : XCreateRequest, id : NodeId, thiscan : Principal) : Result.Result<NodeMem, Text> {

            let module_id = switch(vmod.create(id, creq)) {
                case (#ok(x)) x;
                case (#err(e)) return #err(e);
            };
            let ic_ledgers = U.onlyICLedgerArr(req.ledgers);

            let meta = vmod.nodeMeta(module_id);
            if (meta.ledger_slots.size() != ic_ledgers.size()) return #err("Ledgers required mismatch");

            let sources = switch (portMapSources(ic_ledgers, id, module_id, thiscan, req.sources)) { case (#err(e)) return #err(e); case (#ok(x)) x; };
            let destinations = switch (portMapDestinations(ic_ledgers, id, module_id, req.destinations)) { case (#err(e)) return #err(e); case (#ok(x)) x; };

            let node : NodeMem = {
                var sources = sources;
                var destinations = destinations;
                var refund = req.refund;
                var ledgers = req.ledgers;
                var extractors = req.extractors;
                created = U.now();
                var modified = U.now();
                var controllers = req.controllers;
                var affiliate = req.affiliate;
                billing = {
                    var expires = null;
                    var frozen = false;
                    var last_billed = U.now();
                };
                var active = true;
                module_id;
                var meta = meta;
            };

            #ok(node);
        };

        private func portMapSources(ledgers : [Principal], id : NodeId, v_m : ModuleId, thiscan : Principal, sourcesProvided : [?ICRC55.Address]) : Result.Result<[EndpointStored], Text> {

            // Sources
            let s_res = core.sourceMap(ledgers, id, thiscan, sourcesProvided, vmod.sources(v_m, id));

            let sources = switch (s_res) {
                case (#ok(s)) s;
                case (#err(e)) return #err(e);
            };

            #ok(sources);
        };


        private func portMapDestinations(ledgers : [Principal], id : NodeId, v_m : ModuleId, destinationsProvided : [?ICRC55.Address]) : Result.Result<[EndpointOptStored], Text> {

            // Destinations
            let d_res = core.destinationMap(ledgers, destinationsProvided, vmod.destinations(v_m, id));

            let destinations = switch (d_res) {
                case (#ok(d)) d;
                case (#err(e)) return #err(e);
            };

            #ok(destinations);
        };

        private func node_modifyRequest(id : NodeId, vec : NodeMem, nreq : ?ICRC55.CommonModRequest, creq : ?XModifyRequest, thiscan : Principal) : ModifyNodeResp<XShared> {
            
            let old_sources = vec.sources;

            ignore do ? {
                  switch (vmod.modify(vec.module_id, id, creq!)) {
                        case (#err(e)) return #err(e);
                        case (#ok()) ();
                    };
            };
            vec.modified := U.now();

            let ic_ledgers = U.onlyICLedgerArr(vec.ledgers);

            ignore do ? { vec.destinations := switch(portMapDestinations(ic_ledgers, id, vec.module_id, nreq!.destinations!)) {case (#err(e)) return #err(e); case (#ok(d)) d; } };
            ignore do ? { vec.sources := switch(portMapSources(ic_ledgers, id, vec.module_id, thiscan, nreq!.sources!)) {case (#err(e)) return #err(e); case (#ok(d)) d; } };

            ignore do ? { vec.extractors := nreq!.extractors! };
             
            ignore do ? { vec.controllers := nreq!.controllers!};
            ignore do ? { vec.refund := nreq!.refund! };
                
            ignore do ? {vec.active := nreq!.active!};

            label source_unregister for (xsource in old_sources.vals()) {
                let source = U.onlyIC(xsource.endpoint);
                dvf.unregisterSubaccount(source.account.subaccount);
            };

            label source_register for (xsource in vec.sources.vals()) {
                let source = U.onlyIC(xsource.endpoint);
                dvf.registerSubaccount(source.account.subaccount);
            };

            #ok(vecToShared(vec, id));

        };

        
    };



};
