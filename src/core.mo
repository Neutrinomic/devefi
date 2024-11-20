import Map "mo:map/Map";
import Ledgers "./ledgers/lib";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Result "mo:base/Result";
import U "./utils";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import ICRC55 "./ICRC55";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Timer "mo:base/Timer";
import Nat64 "mo:base/Nat64";

import Debug "mo:base/Debug";
import Nat32 "mo:base/Nat32";
import ICRCLedger "mo:devefi-icrc-ledger";
import Prim "mo:⛔";
import Ver1 "./memory/v1";
import MU "mo:mosup";

module {

    public module Mem {
        public module Core {
            public let V1 = Ver1.Core;
        }
    };

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
    public type CommonCreateRequest = ICRC55.CommonCreateRequest;
    public type SupportedLedger = ICRC55.SupportedLedger;
    public type SourceReq = {
        vec : NodeMem;
        vid : NodeId;
        endpoint_idx : Nat
    };

    public type SourceSendErr = ICRCLedger.SendError or { 
        #AccountNotSet;
        #RemoteNodeNotFound
        };

    public module VectorModule {
        public type Source = SourceReq;
        public type Meta = ICRC55.ModuleMeta;
        public type NodeId = VM.NodeId;
        public type Create =  Result.Result<ModuleId, Text>;
        public type Modify = Result.Result<(), Text>;
        public type Delete = Result.Result<(), Text>;
        public type Get<Shared> = R<Shared, Text>;
        public type Endpoints = EndpointsDescription;
        public type NodeCoreMem = VM.NodeMem;
        public type CommonCreateRequest = ICRC55.CommonCreateRequest;
        public type Class<CreateRequest, ModifyRequest, Shared> = {
            meta : () -> ICRC55.ModuleMeta;
            create : (NodeId, CommonCreateRequest, CreateRequest) -> Create;
            defaults : () -> CreateRequest;
            get : (NodeId, NodeMem) -> R<Shared, Text>;
            modify : (NodeId, ModifyRequest) -> Modify;
            sources : (NodeId) -> EndpointsDescription;
            destinations : (NodeId) -> EndpointsDescription;
            delete : (NodeId) -> Delete;
        };
        
    };

    public type SETTINGS = {
        TEMP_NODE_EXPIRATION_SEC : Nat64;
        ALLOW_TEMP_NODE_CREATION : Bool;
        PYLON_GOVERNED_BY : Text;
        PYLON_NAME : Text;
        MAX_INSTRUCTIONS_PER_HEARTBEAT : Nat64; // 2 billion is max on the IC, double check;
        BILLING : ICRC55.BillingPylon;
        REQUEST_MAX_EXPIRE_SEC : Nat64;
    };

    public class Mod<system>({
        settings : SETTINGS;
        dvf : Ledgers.Ledgers;
        xmem : MU.MemShell<Mem>;
        me_can : Principal;
    }) {


        public let _settings = settings;
        let mem = MU.access(xmem);

        public func get_supported_ledgers() : [ICRC55.SupportedLedger] {
            Array.map<Principal, ICRC55.SupportedLedger>(dvf.get_ledger_ids(), func(x) = #ic(x));
        };

        public func get_supported_ledgers_info() : [ICRC55.LedgerInfo] {
            dvf.get_ledger_info();
        };

        public func get_ledger_cls(id: Principal) : ?Ledgers.LedgerCls {
            return dvf.get_ledger(id);
        };

        public func getNodeById(vid : NodeId) : ?NodeMem {
            Map.get(mem.nodes, Map.n32hash, vid);
        };

        public func getNode(req : ICRC55.GetNode) : ?(NodeId, NodeMem) {
            let (vec : NodeMem, vid : NodeId) = switch (req) {
                case (#id(id)) {
                    let ?v = Map.get(mem.nodes, Map.n32hash, id) else return null;
                    (v, id);
                };
                case (#endpoint(ep)) {
                    let ic_ep = U.onlyIC(ep);
                    let ?port = U.subaccount2port(ic_ep.account.subaccount) else return null;
                    let ?v = Map.get(mem.nodes, Map.n32hash, port.vid) else return null;
                    (v, port.vid);
                };
            };

            return ?(vid, vec);
        };

        public func chargeOpCost(vid : NodeId, _vec : NodeMem, number_of_fees : Nat) : () {
            let fee_to_charge = settings.BILLING.operation_cost * number_of_fees;
            let ?virtual = dvf.get_virtual(settings.BILLING.ledger) else U.trap("Virtual ledger not found");
            let billing_subaccount = ?U.port2subaccount({
                vid;
                flow = #payment;
                id = 0;
            });

            ignore virtual.send({
                to = settings.BILLING.pylon_account;
                amount = fee_to_charge;
                memo = null;
                from_subaccount = billing_subaccount;
            });
        };

        public func entries() : Iter.Iter<(NodeId, NodeMem)> {
            Map.entries(mem.nodes);
        };

        public func getNextNodeId() : NodeId {
            mem.next_node_id;
        };

        public func get_virtual_account(acc : Account) : Account {
            {
                owner = me_can;
                subaccount = ?Principal.toLedgerAccount(acc.owner, acc.subaccount);
            };
        };

        public func hasDestination(vec : NodeMem, port_idx : Nat) : Bool {
            port_idx < vec.destinations.size() and not Option.isNull(U.onlyICDest(vec.destinations[port_idx].endpoint).account);
        };

        public func getDestinationAccountIC(vec: NodeMem, port_idx : Nat) : ?Account {
            if (port_idx >= vec.destinations.size()) return null;
            U.onlyICDest(vec.destinations[port_idx].endpoint).account
        };

        public func getSourceAccountIC(vec : NodeMem, port_idx : Nat) : ?Account {
            if (port_idx >= vec.sources.size()) return null;
            ?U.onlyIC(vec.sources[port_idx].endpoint).account
        };

        public func sourceInfo(vid : NodeId, subaccount : ?Blob) : R<{ allowed : Bool; mine : Bool }, ()> {
            let ?ep_port = U.subaccount2port(subaccount) else return #err;
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

        public func getThisCan() : Principal {
            me_can;
        };

        public func sourceMap(ledgers : [Principal], id : NodeId, sources : [?ICRC55.InputAddress], portdesc : EndpointsDescription) : Result.Result<[EndpointStored], Text> {

            let accounts = switch (
                U.all_or_error<(Nat, Text), ?Account, ()>(
                    portdesc,
                    func(port, idx) = U.expectSourceAccount(me_can, sources, idx),
                )
            ) {
                case (#err) return #err("Invalid account");
                case (#ok(x)) x;
            };

            #ok(
                Array.mapEntries<(Nat, Text), EndpointStored>(
                    portdesc,
                    func(port, idx) {
                        {
                            endpoint = #ic({
                                ledger = ledgers[port.0];
                                account = Option.get(
                                    accounts[idx],
                                    {
                                        owner = me_can;
                                        subaccount = ?U.port2subaccount({
                                            vid = id;
                                            flow = #input;
                                            id = Nat8.fromNat(idx);
                                        });
                                    },
                                );
                            });
                            name = port.1;
                        };
                    },
                )
            );

        };

        public func destinationMap(ledgers : [Principal], destinations : [?ICRC55.InputAddress], portdesc : EndpointsDescription) : Result.Result<[EndpointOptStored], Text> {
            let accounts = switch (
                U.all_or_error<(Nat, Text), ?Account, ()>(
                    portdesc,
                    func(port, idx) = U.expectDestinationAccount(destinations, idx),
                )
            ) {
                case (#err) return #err("Invalid account");
                case (#ok(x)) x;
            };

            #ok(
                Array.mapEntries<(Nat, Text), EndpointOptStored>(
                    portdesc,
                    func(port, idx) {
                        {
                            endpoint = #ic({
                                ledger = ledgers[port.0];
                                account = accounts[idx];
                            });
                            name = port.1;
                        };
                    },
                )
            );
        };

        private func chargeTimeBasedFees() : () {

            let nowU64 = U.now();
            let now = Nat64.toNat(nowU64);
            label vloop for ((vid, vec) in entries()) {
                if (vec.billing.expires != null) continue vloop; // Not charging temp nodes

                let billing = vec.meta.billing;
                let billing_subaccount = ?U.port2subaccount({
                    vid;
                    flow = #payment;
                    id = 0;
                });

                let current_billing_balance = dvf.balance(settings.BILLING.ledger, billing_subaccount);

                var fee_to_charge = ((billing.cost_per_day * (now - Nat64.toNat(vec.billing.last_billed) : Nat)) / (60 * 60 * 24)) / 1_000_000_000;

                if (current_billing_balance < fee_to_charge) {
                    vec.billing.expires := ?(nowU64 + settings.TEMP_NODE_EXPIRATION_SEC);
                    fee_to_charge := current_billing_balance;
                };

                // Freeze nodes if bellow threshold
                let days_left = (current_billing_balance - fee_to_charge : Nat) / billing.cost_per_day;
                if (days_left <= settings.BILLING.freezing_threshold_days) {
                    vec.billing.frozen := true;
                };

                if (fee_to_charge > 0) {
                    
                    let ?virtual = dvf.get_virtual(settings.BILLING.ledger) else U.trap("Virtual ledger not found");
                    let fee_subaccount = ?U.port2subaccount({
                        vid = vid;
                        flow = #fee;
                        id = 0;
                    });
                    ignore virtual.send({
                        to = {owner = me_can; subaccount=fee_subaccount};
                        amount = fee_to_charge;
                        memo = null;
                        from_subaccount = billing_subaccount;
                    });
  

                };

                vec.billing.last_billed := nowU64;

            };
        };

   
        public func getSource(vid : NodeId, vec : NodeMem, endpoint_idx : Nat) : ?SourceReq {
            
            if (endpoint_idx >= vec.sources.size()) return null;

            let #ok(sinfo) = sourceInfo(vid, U.onlyIC(vec.sources[endpoint_idx].endpoint).account.subaccount) else return null;
            if (not sinfo.allowed) return null;

            ?{
                vec;
                vid;
                endpoint_idx;
            };
        };

        public module Source {

            public func balance(req: SourceReq) : Nat {
                
                let endpoint = U.onlyIC(req.vec.sources[req.endpoint_idx].endpoint);
                dvf.balance(endpoint.ledger, endpoint.account.subaccount);
            };

            public func fee(req: SourceReq) : Nat {
                let endpoint = U.onlyIC(req.vec.sources[req.endpoint_idx].endpoint);
                dvf.fee(endpoint.ledger);
            };

            public func getAccount(req: SourceReq) : ?Account {
                if (req.endpoint_idx >= req.vec.sources.size()) return null;
                ?U.onlyIC(req.vec.sources[req.endpoint_idx].endpoint).account
            };

            public module Send {

                public type Intent = {
                    req: SourceReq;
                    location : Location;
                    amount : Nat;
                    endpoint : ICRC55.EndpointIC;
                    amount_to_send : Nat;
                    tx_fee : Nat;
                    ledger_fee : Nat;
                    to: Account;
                };
                public func commit(intent: Intent) : Nat64 {

                    let ?virtual = dvf.get_virtual(intent.endpoint.ledger) else U.trap("Virtual ledger not found");

                    incrementOps(1);

                    if (intent.tx_fee > 0) {
                        let fee_subaccount = ?U.port2subaccount({
                            vid = intent.req.vid;
                            flow = #fee;
                            id = 0;
                        });

                        ignore virtual.send({
                            to = {owner = me_can; subaccount=fee_subaccount};
                            amount = intent.tx_fee;
                            memo = null;
                            from_subaccount = intent.endpoint.account.subaccount;
                        });

                    };

                    let #ok(bid) = dvf.send({
                        ledger = intent.endpoint.ledger;
                        to = intent.to;
                        amount = intent.amount_to_send;
                        memo = null;
                        from_subaccount = intent.endpoint.account.subaccount;
                    }) else U.trap("Internal error in source send commit");
                    bid;
                };

                public type Location = {
                        #destination : { port : Nat };
                        #source : { port : Nat };
                        #remote_destination : { node : NodeId; port : Nat };
                        #remote_source : { node : NodeId; port : Nat };
                        #external_account : Account;
                    };

                public func intent(
                    req: SourceReq,
                    location : Location,
                    amount : Nat,
                ) : R<Intent, SourceSendErr> {
                    let endpoint = U.onlyIC(req.vec.sources[req.endpoint_idx].endpoint);

                    let billing = req.vec.meta.billing;
                    let ledger_fee = dvf.fee(endpoint.ledger);
                    let tx_fee : Nat = switch (location) {
                        case (#destination(_) or #remote_destination(_)) {
                            switch (billing.transaction_fee) {
                                case (#none) 0;
                                case (#flat_fee_multiplier(m)) {
                                    ledger_fee * m;
                                };
                                case (#transaction_percentage_fee_e8s(p)) {
                                    amount * p / 1_0000_0000;
                                };
                            };
                        };
                        case (_) 0;
                    };

                    let to : Account = switch (location) {
                        case (#destination({ port })) {
                            let ?acc = U.onlyICDest(req.vec.destinations[port].endpoint).account else return #err(#AccountNotSet);
                            acc;
                        };

                        case (#remote_destination({ node; port })) {
                            let ?to_vec = getNodeById(node) else return #err(#AccountNotSet);
                            let ?acc = U.onlyICDest(to_vec.destinations[port].endpoint).account else return #err(#AccountNotSet);
                            acc;
                        };

                        case (#remote_source({ node; port })) {
                            let ?to_vec = getNodeById(node) else return #err(#AccountNotSet);
                            U.onlyIC(to_vec.sources[port].endpoint).account;
                        };

                        case (#source({ port })) {
                            U.onlyIC(req.vec.sources[port].endpoint).account;
                        };

                        case (#external_account(account)) {
                            account;
                        };
                    };

                    if (tx_fee + ledger_fee >= amount) return #err(#InsufficientFunds);
                    let amount_to_send = amount - tx_fee : Nat;


                    #ok({
                        req;
                        location;
                        amount;
                        endpoint;
                        tx_fee;
                        ledger_fee;
                        amount_to_send;
                        to;
                    });
                };

            };
        };

        public func ops() : Nat {
            mem.ops;
        };

        public func incrementOps(n : Nat) : () {
            mem.ops += n;
        };

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

        private func distributeFees() : () {
            
            let now = U.now();
            let MINIMUM_TIME_BETWEEN_DISTRIBUTION :Nat64 = 60 * 60 * 6 * 1_000_000_000; // 6 hours
            let min_ts = now - MINIMUM_TIME_BETWEEN_DISTRIBUTION;
            let ledgers = dvf.get_ledgers();

            
            label vloop for ((vid, vec) in entries()) {
                if (vec.billing.last_fee_distribution > min_ts) continue vloop;
                let fee_subaccount = ?U.port2subaccount({
                        vid;
                        flow = #fee;
                        id = 0;
                    });

                label ledgerloop for (ledger in ledgers.vals()) {
                    let ?virtual = dvf.get_virtual(ledger) else continue ledgerloop;

                    let balance_collected = virtual.balance(fee_subaccount);
                    let ledger_fee = dvf.fee(ledger);
                    // U.log("balance_collected " # debug_show(balance_collected));
                    // Minimum distribution is 1000x ledger_fee
                    if (balance_collected / 100 < ledger_fee) continue ledgerloop; // TODO make it 1000
                    // U.log("Distributing balance " # debug_show(balance_collected));

                    ignore virtual.send({
                        to = settings.BILLING.platform_account;
                        amount = balance_collected * settings.BILLING.split.platform / 100;
                        memo = null;
                        from_subaccount = fee_subaccount;
                    });
                    ignore virtual.send({
                        to = vec.meta.author_account;
                        amount = balance_collected * settings.BILLING.split.author / 100;
                        memo = null;
                        from_subaccount = fee_subaccount;
                    });
                    ignore virtual.send({
                        to = settings.BILLING.pylon_account;
                        amount = balance_collected * settings.BILLING.split.pylon / 100;
                        memo = null;
                        from_subaccount = fee_subaccount;
                    });
                    ignore do ? {
                        ignore virtual.send({
                            to = get_virtual_account(vec.affiliate!);
                            amount = balance_collected * settings.BILLING.split.affiliate / 100;
                            memo = null;
                            from_subaccount = fee_subaccount;
                        });
                    };
                };
            };
        };

        dvf.onEvent(
            func(event) {
                switch (event) {
                    case (#received(r)) {

                        let ?port = U.subaccount2port(r.to_subaccount) else return; // We can still recieve tokens in caller subaccounts, which we won't send back right away
                        let found = getNode(#id(port.vid));

                        // Handle payment after temporary vector was created
                        let ?(_, rvec) = found else return;

                        let from_subaccount = U.port2subaccount({
                            vid = port.vid;
                            flow = #payment;
                            id = 0;
                        });

                        let bal = dvf.balance(r.ledger, ?from_subaccount);
                        if (bal >= settings.BILLING.min_create_balance) {
                            rvec.billing.expires := null;
                        };

                    };
                    case (_) ();
                };
            }
        );


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
            #seconds(10), func() : async () { chargeTimeBasedFees(); },
        );

        ignore Timer.recurringTimer<system>(
            #seconds(600), func() : async () { distributeFees(); }
        );

    };

};
