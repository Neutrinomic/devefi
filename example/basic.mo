import Principal "mo:base/Principal";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Time "mo:base/Time";
import DeVeFi "../src/";
import Nat "mo:base/Nat";
import ICRC55 "../src/ICRC55";
import Rechain "mo:rechain";
import RT "./rechain";
import Timer "mo:base/Timer";
import U "../src/utils";
import Array "mo:base/Array";
import Nat32 "mo:base/Nat32";
import I "mo:itertools/Iter";
import Iter "mo:base/Iter";
import Blob "mo:base/Blob";
import T "./vector_modules";
import MU "mo:mosup";
import MU_sys "../src/sys";

import VecThrottle "./modules/throttle/throttle";
import VecBorrow "./modules/borrow/borrow";
import VecLend "./modules/lend/lend";
import VecExchange "./modules/exchange/exchange";
import VecEscrow "./modules/escrow/escrow";
import VecSplit "./modules/split/split";


actor class () = this {

    MU.placeholder();

    stable let chain_mem  = Rechain.Mem();

    var chain = Rechain.Chain<RT.DispatchAction, RT.DispatchActionError>({
        settings = ?{Rechain.DEFAULT_SETTINGS with supportedBlocks = [{block_type = "55vec"; url = "https://github.com/dfinity/ICRC/issues/55"}];};
        mem = chain_mem;
        encodeBlock = RT.encodeBlock;
        reducers = [];
    });
    
    ignore Timer.setTimer<system>(#seconds 0, func () : async () {
        await chain.start_timers<system>();
    });
    
    ignore Timer.setTimer<system>(#seconds 1, func () : async () {
        await chain.upgrade_archives();
    });

    stable let dvf_mem = DeVeFi.Mem();


    let dvf = DeVeFi.DeVeFi<system>({ mem = dvf_mem });

    // Components

    let vec_throttle = VecThrottle.Mod(MU.persistent("throttle"));
    let vec_lend = VecLend.Mod(MU.persistent("lend"));
    let vec_borrow = VecBorrow.Mod(MU.persistent("borrow"));
    let vec_exchange = VecExchange.Mod(MU.persistent("exchange"));
    let vec_escrow = VecEscrow.Mod(MU.persistent("escrow"));
    let vec_split = VecSplit.Mod(MU.persistent("split"));


    let vmod = T.VectorModules({
        vec_throttle;
        vec_lend;
        vec_borrow;
        vec_exchange;
        vec_escrow;
        vec_split;
    });

    
    let nodes = MU_sys.Mod<system, T.CreateRequest, T.Shared, T.ModifyRequest>({
        xmem = MU.persistent("dvf_nodes");
        dvf;
        settings = {
            MU_sys.DEFAULT_SETTINGS with
            PYLON_NAME = "Transcendence";
            PYLON_GOVERNED_BY = "Neutrinite DAO";
            PYLON_FEE_ACCOUNT = ?{ owner = Principal.fromText("eqsml-lyaaa-aaaaq-aacdq-cai"); subaccount = null };
        };
        toShared = vmod.toShared;
        nodeSources = vmod.sources;
        nodeDestinations = vmod.destinations;
        nodeCreate = vmod.create;
        nodeModify = vmod.modify;
        getDefaults = vmod.getDefaults;
        meta = vmod.meta;
        nodeMeta = vmod.nodeMeta;
        authorAccount = vmod.authorAccount;
        nodeBilling = vmod.nodeBilling;
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

                switch (vec.module_id) {
                //     case (?#exchange(ex)) {
    
                //         let pool_account = nodes.get_virtual_pool_account(vec.ledgers[0], vec.ledgers[1], 0);
                //         let pool_a = nodes.get_pool(pool_account, vec.ledgers[0]);
                //         let pool_b = nodes.get_pool(pool_account, vec.ledgers[1]);
                //         let reserve_one = pool_a.balance();
                //         let reserve_two = pool_b.balance();
                //         let request_amount = bal;

                //         let rate_fwd = (reserve_one + request_amount) / reserve_two;

                //         let afterfee_fwd = request_amount - fee:Nat;

                //         let recieve_fwd = afterfee_fwd / rate_fwd;
                //         ignore source.send(#external_account(pool_account), request_amount);
                //         ignore pool_b.send(#remote_destination({node = vid; port = 0;}), recieve_fwd);
                 

                //     };
                    case ("throttle") {
                        vec_throttle.run(vid, func(port_idx) = nodes.getSource(vid, vec, port_idx));

                    };
                    case ("split") {
                        vec_split.run(vid, func(port_idx) = nodes.getSource(vid, vec, port_idx), func(port_idx) = nodes.hasDestination(vec, port_idx));
                    };
                    case (_) ();
                };

            };
        };

    system func heartbeat() : async () {
        nodes.heartbeat(proc);
    };

    // ICRC-55

    public query func icrc55_get_pylon_meta() : async ICRC55.PylonMetaResp {
        nodes.icrc55_get_pylon_meta();
    };

    public shared ({ caller }) func icrc55_command(req : ICRC55.BatchCommandRequest<T.CreateRequest, T.ModifyRequest>) : async ICRC55.BatchCommandResponse<T.Shared> {
        nodes.icrc55_command<RT.DispatchActionError>(caller, req, func (r) {
            chain.dispatch({
                caller;
                payload = #vector(r);
                ts = U.now();
            });
        });
    };

    public query func icrc55_get_nodes(req : [ICRC55.GetNode]) : async [?MU_sys.NodeShared<T.Shared>] {
        nodes.icrc55_get_nodes(req);
    };

    public query ({ caller }) func icrc55_get_controller_nodes(req : ICRC55.GetControllerNodesRequest) : async [MU_sys.NodeShared<T.Shared>] {
        nodes.icrc55_get_controller_nodes(caller, req);
    };

    public query func icrc55_get_defaults(id : Text) : async T.CreateRequest {
        nodes.icrc55_get_defaults(id);
    };

    public query ({caller}) func icrc55_virtual_balances(req : ICRC55.VirtualBalancesRequest) : async ICRC55.VirtualBalancesResponse {
        nodes.icrc55_virtual_balances(caller, req);
    };

    // ICRC-3 


    public query func icrc3_get_blocks(args: Rechain.GetBlocksArgs): async Rechain.GetBlocksResult {
        return chain.icrc3_get_blocks(args);
    };

    public query func icrc3_get_archives(args: Rechain.GetArchivesArgs): async Rechain.GetArchivesResult {
        return chain.icrc3_get_archives(args);
    };

    public query func icrc3_supported_block_types(): async [Rechain.BlockType] {
        return chain.icrc3_supported_block_types();
    };
    public query func icrc3_get_tip_certificate() : async ?Rechain.DataCertificate {
        return chain.icrc3_get_tip_certificate();
    };

    // We need to start the vector manually once when canister is installed, because we can't init dvf from the body
    // https://github.com/dfinity/motoko/issues/4384
    // Sending tokens before starting the canister for the first time wont get processed
    public shared ({ caller }) func start() {
        assert (Principal.isController(caller));
        dvf.start<system>(Principal.fromActor(this));
        nodes.start<system>(Principal.fromActor(this));
        chain_mem.canister := ?Principal.fromActor(this);

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
