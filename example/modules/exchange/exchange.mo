import Billing "../../billing_all";
import MU "mo:mosup";
import Ver1 "./memory/v1";
import Map "mo:map/Map";
import Core "../../../src/core";
import I "./interface";
import U "../../../src/utils";
import Result "mo:base/Result";
import DeVeFi "../../../src/lib";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import IT "mo:itertools/Iter";
import Nat32 "mo:base/Nat32";

module {
    let T = Core.VectorModule;
    public let Interface = I;
    type R<A,B> = Result.Result<A,B>;

    public module Mem {
        public module Vector {
            public let V1 = Ver1;
        };
    };
    let VM = Mem.Vector.V1;

    public let ID = "exchange";

    public class Mod({
        xmem : MU.MemShell<VM.Mem>;
        core : Core.Mod;
        dvf : DeVeFi.DeVeFi;
    }) : T.Class<I.CreateRequest, I.ModifyRequest, I.Shared> {

        let mem = MU.access(xmem);

        public func meta() : T.Meta {
            {
                id = ID; // This has to be same as the variant in vec.custom
                name = "Exchange";
                author = "Neutrinite";
                description = "Exchange X tokens for Y";
                supported_ledgers = [];
                version = #alpha([0, 0, 1]);
                create_allowed = true;
                ledger_slots = [
                    "From",
                    "To",
                ];
                billing = Billing.get();
                sources = sources(0);
                destinations = destinations(0);
                author_account = Billing.authorAccount();
            };
        };

        public func create(id : T.NodeId, t : I.CreateRequest) : T.Create {

            let obj : VM.NodeMem = {
                init = t.init;
                variables = {
                    var interest = t.variables.interest;
                };
                internals = {};
            };
            ignore Map.put(mem.main, Map.n32hash, id, obj);
            #ok(ID);
        };

        public func defaults() : I.CreateRequest {
            {
                init = {

                };
                variables = {
                    interest = 20;
                };
            };
        };

        public func delete(id : T.NodeId) : () {
            ignore Map.remove(mem.main, Map.n32hash, id);
        };

        public func modify(id : T.NodeId, m : I.ModifyRequest) : T.Modify {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

            t.variables.interest := m.interest;
            #ok();
        };

        public func get(id : T.NodeId) : T.Get<I.Shared> {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

            #ok {
                init = t.init;
                variables = {
                    interest = t.variables.interest;
                };
                internals = {};
            };
        };

        public func sources(_id : T.NodeId) : T.Endpoints {
            [(0, "From")];
        };

        public func destinations(_id : T.NodeId) : T.Endpoints {
            [(1, "To")];
        };


        public func run(vid : T.NodeId, vec : T.NodeCoreMem) : () {
            let ?th = Map.get(mem.main, Map.n32hash, vid) else return;
            let now = U.now();
            let source = {vid;vec;endpoint_idx=0;};
            let bal = core.Source.balance(source);
            let fee = core.Source.fee(source);

            // let pool_account = get_virtual_pool_account(vec.ledgers[0], 0);

            // let pool_a = get_pool(pool_account, vec.ledgers[0]);
            // let pool_b = get_pool(pool_account, vec.ledgers[1]);
            // let reserve_one = pool_a.balance();
            // let reserve_two = pool_b.balance();
            // let request_amount = bal;

            // let rate_fwd = (reserve_one + request_amount) / reserve_two;

            // let afterfee_fwd = request_amount - fee:Nat;

            // let recieve_fwd = afterfee_fwd / rate_fwd;
            // ignore source.send(#external_account(pool_account), request_amount);
            // ignore pool_b.send(#remote_destination({node = vid; port = 0;}), recieve_fwd);
        
        };

        /// 

        public func get_virtual_pool_account(a : Core.SupportedLedger, pool_idx : Nat8) : Core.Account {
            let ledger_idx = U.not_opt(dvf.get_ledger_idx(U.onlyICLedger(a)));
            {
                owner =  core.getThisCan();
                subaccount = ?Blob.fromArray(Iter.toArray(IT.pad(IT.flattenArray<Nat8>([[100, pool_idx], U.ENat32(Nat32.fromNat(ledger_idx))]), 32, 0 : Nat8)));
            };
        };

  

        public module Pool {
 
            public func balance(ledger_i55: Core.SupportedLedger, poolacc: Core.Account) : Nat {
                let ledger = U.onlyICLedger(ledger_i55);
                dvf.balance(ledger, poolacc.subaccount);
            };

            public func fee(ledger_i55: Core.SupportedLedger) : Nat {
                let ledger = U.onlyICLedger(ledger_i55);
                dvf.fee(ledger);
            };

            public func send(
                ledger_i55: Core.SupportedLedger, 
                poolacc: Core.Account,
                location : {
                    #remote_destination : { node : T.NodeId; port : Nat };
                    #remote_source : { node : T.NodeId; port : Nat };
                    #external_account : Core.Account;
                },
                amount : Nat,
            ) : R<Nat64, Core.SourceSendErr> {
                let ledger = U.onlyICLedger(ledger_i55);

                let ledger_fee = dvf.fee(ledger);

                let to : Core.Account = switch (location) {
                    case (#remote_destination({ node; port })) {
                        let ?(_vid, to_vec) = core.getNode(#id(node)) else return #err(#RemoteNodeNotFound);
                        let ?acc = core.getDestinationAccountIC(to_vec, port) else return #err(#AccountNotSet);
                        acc
                    };

                    case (#remote_source({ node; port })) {
                        let ?(_vid, to_vec) = core.getNode(#id(node)) else return #err(#RemoteNodeNotFound);
                        let ?acc = core.getSourceAccountIC(to_vec, port) else return #err(#AccountNotSet);
                        acc
                    };

                    case (#external_account(account)) {
                        account;
                    };
                };

                core.incrementOps(1);
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

    };




};
