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
import Rechain "mo:rechain";
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


    public type SourceSendErr = ICRCLedger.SendError or { #AccountNotSet };

    public module VectorModule {
        public type Meta = ICRC55.ModuleMeta;
        public type NodeId = VM.NodeId;
        public type Create =  Result.Result<ModuleId, Text>;
        public type Modify = Result.Result<(), Text>;
        public type Get<Shared> = R<Shared, Text>;
        public type Endpoints = EndpointsDescription;
        public type NodeCoreMem = VM.NodeMem;
        public type Class<CreateRequest, ModifyRequest, Shared> = {
            meta : () -> ICRC55.ModuleMeta;
            create : (NodeId, CreateRequest) -> Create;
            defaults : () -> CreateRequest;
            get : (NodeId) -> R<Shared, Text>;
            modify : (NodeId, ModifyRequest) -> Modify;
            sources : (NodeId) -> EndpointsDescription;
            destinations : (NodeId) -> EndpointsDescription;
            delete : (NodeId) -> ();
        };
        
    };

    public type SETTINGS = {
        TEMP_NODE_EXPIRATION_SEC : Nat64;
        ALLOW_TEMP_NODE_CREATION : Bool;
        PYLON_GOVERNED_BY : Text;
        PYLON_NAME : Text;
        PYLON_FEE_ACCOUNT : ?Account;
        MAX_INSTRUCTIONS_PER_HEARTBEAT : Nat64; // 2 billion is max on the IC, double check;
        BILLING : ?ICRC55.BillingPylon;
        PLATFORM_ACCOUNT : ?Account;
        REQUEST_MAX_EXPIRE_SEC : Nat64;
    };

    public let DEFAULT_SETTINGS : SETTINGS = {
        ALLOW_TEMP_NODE_CREATION = true;
        TEMP_NODE_EXPIRATION_SEC = 3600;
        PYLON_GOVERNED_BY = "Unknown";
        PYLON_NAME = "Testing Pylon";
        MAX_INSTRUCTIONS_PER_HEARTBEAT = 300_000_000;
        PYLON_FEE_ACCOUNT = null;
        BILLING = null;
        PLATFORM_ACCOUNT = null;
        REQUEST_MAX_EXPIRE_SEC = 3600;
    };

    public class Mod<system>({
        settings : SETTINGS;
        dvf : DeVeFi.DeVeFi;
        xmem : MU.MemShell<Mem>;
    }) {

        public let pylon_billing : ICRC55.BillingPylon = switch(settings.BILLING) {
            case (null) {
                {
                ledger = Principal.fromText("lxzze-o7777-77777-aaaaa-cai"); //f54if-eqaaa-aaaaq-aacea-cai
                min_create_balance = 3000000;
                operation_cost = 1000;
                freezing_threshold_days = 10;
                exempt_daily_cost_balance = null;
                split = {
                    platform = 200;
                    pylon = 200; 
                    author = 400;
                    affiliate = 200;
                }}};
            case (?x) x;
        };

        public let platform_account : Account = switch(settings.PLATFORM_ACCOUNT) {
            case (null) {{
                owner = Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai");
                subaccount = null;
            }};
            case (?x) x;
        };

        public let _settings = settings;
        let mem = MU.access(xmem);

        public func get_supported_ledgers() : [ICRC55.SupportedLedger] {
            Array.map<Principal, ICRC55.SupportedLedger>(dvf.get_ledger_ids(), func(x) = #ic(x));
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

        public func getSource(vid : NodeId, vec : NodeMem, port_idx : Nat) : ?Source {
            if (port_idx >= vec.sources.size()) return null;

            let #ok(sinfo) = sourceInfo(vid, U.onlyIC(vec.sources[port_idx].endpoint).account.subaccount) else return null;
            if (not sinfo.allowed) return null;

            let source = Source(
                {
                    endpoint = vec.sources[port_idx].endpoint;
                    vec;
                    vid;
                },
                dvf,
                func(x) = Map.get(mem.nodes, Map.n32hash, x),
                func(x) = mem.ops += x,
                get_virtual_account,
            );

            return ?source;
        };

        public func chargeOpCost(vid : NodeId, vec : NodeMem, number_of_fees : Nat) : () {
            let ?pylonAccount = mem.pylon_fee_account else Debug.trap("Pylon account not set");
            let billing = vec.meta.billing;
            let fee_to_charge = pylon_billing.operation_cost * number_of_fees;
            let ?virtual = dvf.get_virtual(pylon_billing.ledger) else Debug.trap("Virtual ledger not found");
            let billing_subaccount = ?U.port2subaccount({
                vid;
                flow = #payment;
                id = 0;
            });

            ignore virtual.send({
                to = pylonAccount;
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
            let ?thiscanister = mem.thiscan else Debug.trap("Canister not set");
            {
                owner = thiscanister;
                subaccount = ?Principal.toLedgerAccount(acc.owner, acc.subaccount);
            };
        };

        public func get_virtual_pool_account(la : ICRC55.SupportedLedger, lb : ICRC55.SupportedLedger, pool_idx : Nat8) : Account {
            let a = U.onlyICLedger(la);
            let b = U.onlyICLedger(lb);

            let ledger_idx = Array.sort<Nat>([U.not_opt(dvf.get_ledger_idx(a)), U.not_opt(dvf.get_ledger_idx(b))], Nat.compare);
            let ?thiscanister = mem.thiscan else Debug.trap("Canister not set");
            {
                owner = thiscanister;
                subaccount = ?Blob.fromArray(Iter.toArray(I.pad(I.flattenArray<Nat8>([[100, pool_idx], U.ENat32(Nat32.fromNat(ledger_idx[0])), U.ENat32(Nat32.fromNat(ledger_idx[1]))]), 32, 0 : Nat8)));
            };
        };

        public func start<system>(can : Principal) : () {
            mem.thiscan := ?can;

            let ?acc = do ? { get_virtual_account(settings.PYLON_FEE_ACCOUNT!) } else Debug.trap("PYLON_FEE_ACCOUNT required");
            mem.pylon_fee_account := ?acc;
        };

        public func delete(vid : NodeId) : () {
            let ?vec = Map.get(mem.nodes, Map.n32hash, vid) else return;
            
            let billing = vec.meta.billing;
            let refund_acc = get_virtual_account(vec.refund);
            // REFUND: Send staked tokens from the node to the first controller
            do {
                let from_subaccount = U.port2subaccount({
                    vid;
                    flow = #payment;
                    id = 0;
                });

                let bal = dvf.balance(pylon_billing.ledger, ?from_subaccount);
                if (bal > 0) {
                    label refund_payment do {

                        ignore dvf.send({
                            ledger = pylon_billing.ledger;
                            to = refund_acc;
                            amount = bal;
                            memo = null;
                            from_subaccount = ?from_subaccount;
                        });
                    };
                };

                dvf.unregisterSubaccount(?U.port2subaccount({ vid = vid; flow = #payment; id = 0 }));
            };

            label source_refund for (xsource in vec.sources.vals()) {
                let source = U.onlyIC(xsource.endpoint);

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

        public class Pool(
            poolacc : Account,
            ledger_i55 : ICRC55.SupportedLedger,
        ) {

            let ledger = U.onlyICLedger(ledger_i55);

            public func balance() : Nat {
                dvf.balance(ledger, poolacc.subaccount);
            };

            public func fee() : Nat {
                dvf.fee(ledger);
            };

            public func send(
                location : {
                    #remote_destination : { node : NodeId; port : Nat };
                    #remote_source : { node : NodeId; port : Nat };
                    #external_account : Account;
                },
                amount : Nat,
            ) : R<Nat64, SourceSendErr> {

                let ledger_fee = dvf.fee(ledger);

                let to : Account = switch (location) {
                    case (#remote_destination({ node; port })) {
                        let ?to_vec = Map.get(mem.nodes, Map.n32hash, node) else return #err(#AccountNotSet);
                        let ?acc = U.onlyICDest(to_vec.destinations[port].endpoint).account else return #err(#AccountNotSet);
                        acc;
                    };

                    case (#remote_source({ node; port })) {
                        let ?to_vec = Map.get(mem.nodes, Map.n32hash, node) else return #err(#AccountNotSet);
                        U.onlyIC(to_vec.sources[port].endpoint).account;
                    };

                    case (#external_account(account)) {
                        account;
                    };
                };

                mem.ops += 1;
                if (ledger_fee >= amount) return #err(#InsufficientFunds);

                dvf.send({
                    ledger = ledger;
                    to;
                    amount = amount;
                    memo = null;
                    from_subaccount = poolacc.subaccount;
                });
            };
        };

        public func get_pool(poolacc : Account, ledger_i55 : ICRC55.SupportedLedger) : Pool {
            Pool(poolacc, ledger_i55);
        };

        public func hasDestination(vec : NodeMem, port_idx : Nat) : Bool {
            port_idx < vec.destinations.size() and not Option.isNull(U.onlyICDest(vec.destinations[port_idx].endpoint).account);
        };

        private func sourceInfo(vid : NodeId, subaccount : ?Blob) : R<{ allowed : Bool; mine : Bool }, ()> {
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

        public func sourceMap(ledgers : [Principal], id : NodeId, thiscan : Principal, sources : [?ICRC55.InputAddress], portdesc : EndpointsDescription) : Result.Result<[EndpointStored], Text> {

            let accounts = switch (
                U.all_or_error<(Nat, Text), ?Account, ()>(
                    portdesc,
                    func(port, idx) = U.expectSourceAccount(thiscan, sources, idx),
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
                                        owner = thiscan;
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
            let ?pylonAccount = mem.pylon_fee_account else Debug.trap("Pylon account not set");

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

                let current_billing_balance = dvf.balance(pylon_billing.ledger, billing_subaccount);

                var fee_to_charge = ((billing.cost_per_day * (now - Nat64.toNat(vec.billing.last_billed) : Nat)) / (60 * 60 * 24)) / 1_000_000_000;

                if (current_billing_balance < fee_to_charge) {
                    vec.billing.expires := ?(nowU64 + settings.TEMP_NODE_EXPIRATION_SEC);
                    fee_to_charge := current_billing_balance;
                };

                // Freeze nodes if bellow threshold
                let days_left = (current_billing_balance - fee_to_charge : Nat) / billing.cost_per_day;
                if (days_left <= pylon_billing.freezing_threshold_days) {
                    vec.billing.frozen := true;
                };

                if (fee_to_charge > 0) {
                    let ?virtual = dvf.get_virtual(pylon_billing.ledger) else Debug.trap("Virtual account not found");
                    ignore virtual.send({
                        to = platform_account;
                        amount = fee_to_charge * pylon_billing.split.platform / 1000;
                        memo = null;
                        from_subaccount = billing_subaccount;
                    });
                    ignore virtual.send({
                        to = vec.meta.author_account;
                        amount = fee_to_charge * pylon_billing.split.author / 1000;
                        memo = null;
                        from_subaccount = billing_subaccount;
                    });
                    ignore virtual.send({
                        to = pylonAccount;
                        amount = fee_to_charge * pylon_billing.split.pylon / 1000;
                        memo = null;
                        from_subaccount = billing_subaccount;
                    });
                    ignore do ? {
                        ignore virtual.send({
                            to = get_virtual_account(vec.affiliate!);
                            amount = fee_to_charge * pylon_billing.split.affiliate / 1000;
                            memo = null;
                            from_subaccount = billing_subaccount;
                        });
                    };

                };

                vec.billing.last_billed := nowU64;

            };
        };

        public class Source(
            cls : {
                endpoint : Endpoint;
                vec : NodeMem;
                vid : NodeId;
            },
            dvf : DeVeFi.DeVeFi,
            getNode : (NodeId) -> ?NodeMem,
            incrementOps : (Nat) -> (),
            get_virtual_account : (Account) -> Account,
        ) {

            public let endpoint = U.onlyIC(cls.endpoint) : ICRC55.EndpointIC;

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
                let ?pylonAccount = mem.pylon_fee_account else Debug.trap("Pylon account not set");
                let billing = cls.vec.meta.billing;
                let ledger_fee = dvf.fee(endpoint.ledger);
                let tx_fee : Nat = switch (location) {
                    case (#destination(_) or #remote_destination(_)) {

                        switch (billing.transaction_fee) {
                            case (#none) 0;
                            case (#flat_fee_multiplier(m)) {
                                ledger_fee * m;
                            };
                            case (#transaction_percentage_fee(p)) {
                                amount * p / 1_0000_0000;
                            };
                        };
                    };
                    case (_) 0;
                };

                let to : Account = switch (location) {
                    case (#destination({ port })) {
                        let ?acc = U.onlyICDest(cls.vec.destinations[port].endpoint).account else return #err(#AccountNotSet);
                        acc;
                    };

                    case (#remote_destination({ node; port })) {
                        let ?to_vec = getNode(node) else return #err(#AccountNotSet);
                        let ?acc = U.onlyICDest(to_vec.destinations[port].endpoint).account else return #err(#AccountNotSet);
                        acc;
                    };

                    case (#remote_source({ node; port })) {
                        let ?to_vec = getNode(node) else return #err(#AccountNotSet);
                        U.onlyIC(to_vec.sources[port].endpoint).account;
                    };

                    case (#source({ port })) {
                        U.onlyIC(cls.vec.sources[port].endpoint).account;
                    };

                    case (#external_account(account)) {
                        account;
                    };
                };

                incrementOps(1);
                if (tx_fee + ledger_fee >= amount) return #err(#InsufficientFunds);
                let amount_to_send = amount - tx_fee : Nat;

                let ?virtual = dvf.get_virtual(pylon_billing.ledger) else Debug.trap("Virtual account not found");

                if (tx_fee > 0) {
                    let billing_subaccount = ?U.port2subaccount({
                        vid = cls.vid;
                        flow = #payment;
                        id = 0;
                    });

                    ignore virtual.send({
                        to = platform_account;
                        amount = tx_fee * pylon_billing.split.platform / 1000;
                        memo = null;
                        from_subaccount = billing_subaccount;
                    });
                    ignore virtual.send({
                        to = cls.vec.meta.author_account;
                        amount = tx_fee * pylon_billing.split.author / 1000;
                        memo = null;
                        from_subaccount = billing_subaccount;
                    });
                    ignore virtual.send({
                        to = pylonAccount;
                        amount = tx_fee * pylon_billing.split.pylon / 1000;
                        memo = null;
                        from_subaccount = billing_subaccount;
                    });
                    ignore do ? {
                        ignore virtual.send({
                            to = get_virtual_account(cls.vec.affiliate!);
                            amount = tx_fee * pylon_billing.split.affiliate / 1000;
                            memo = null;
                            from_subaccount = billing_subaccount;
                        });
                    };
                };

                dvf.send({
                    ledger = endpoint.ledger;
                    to;
                    amount = amount_to_send;
                    memo = null;
                    from_subaccount = endpoint.account.subaccount;
                });
            };
        };

        public func ops() : Nat {
            mem.ops;
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

        dvf.onEvent(
            func(event) {
                switch (event) {
                    case (#received(r)) {

                        let ?port = U.subaccount2port(r.to_subaccount) else return; // We can still recieve tokens in caller subaccounts, which we won't send back right away
                        let found = getNode(#id(port.vid));

                        // Handle payment after temporary vector was created
                        let ?(_, rvec) = found else return;
                        let billing = rvec.meta.billing;

                        let from_subaccount = U.port2subaccount({
                            vid = port.vid;
                            flow = #payment;
                            id = 0;
                        });

                        let bal = dvf.balance(r.ledger, ?from_subaccount);
                        if (bal >= pylon_billing.min_create_balance) {
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
                chargeTimeBasedFees();
            },
        );

    };

};
