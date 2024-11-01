import MU "mo:mosup";
import Ver1 "./memory/v1";
import Map "mo:map/Map";
import Core "../../../src/core";
import U "../../../src/utils";
import Result "mo:base/Result";
import DeVeFi "../../../src/lib";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import IT "mo:itertools/Iter";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Vector "mo:vector";
import Float "mo:base/Float";
import Debug "mo:base/Debug";

module {
        
        public module Mem {
            public module Swap {
                public let V1 = Ver1;
            };
        };
        
        let VM = Mem.Swap.V1;
        type R<A,B> = Result.Result<A,B>;

        public type LedgerAccount = {
            ledger: Principal;
            account: Core.Account
        };

        type Intent = {
            pool_account : Core.Account;
            asset_in : LedgerAccount;
            asset_out : LedgerAccount;
            amount_in : Nat;
            amount_out : Nat;
            swap_fee : Nat;
        };
        type IntentPath = [Intent];

        public class Mod({
            xmem : MU.MemShell<VM.Mem>;
            core : Core.Mod;
            dvf : DeVeFi.DeVeFi;
            primary_ledger : Principal;
            swap_fee : Nat; // 8 decimals
        }) {

        let mem = MU.access(xmem);

        type LiquidityIntent = {
            pool_account : Core.Account;
            asset_a : LedgerAccount;
            asset_b : LedgerAccount;
            amount_a : Nat;
            amount_b : Nat;
            new_total: Nat;
            minted_tokens : Nat;
        };

        public module Price = {
            public func get(ledger_a: Principal, ledger_b: Principal) : Nat {
                let pool_account = getPoolAccount(ledger_a, ledger_b, 0);
                let asset_a = LedgerAccount.get(pool_account, ledger_a);
                let asset_b = LedgerAccount.get(pool_account, ledger_b);
                let reserve_A = LedgerAccount.balance(asset_a);
                let reserve_B = LedgerAccount.balance(asset_b);
                let rate = reserve_B / reserve_A;
                rate
            };
        };

        public module Pool {
            public func get(pool_account: Core.Account) : VM.Pool {
                let ?subaccount = pool_account.subaccount else Debug.trap("Pool account subaccount is missing");
                switch(Map.get(mem.main, Map.bhash, subaccount)) {
                    case (?pool) pool;
                    case (null) {
                        let pool:VM.Pool = {
                            var total = 0;
                            balances = Map.new<VM.ClientSubaccount, VM.Share>();
                        };
                        ignore Map.put(mem.main, Map.bhash, subaccount, pool);
                        pool;
                    }
                }
            };


        };

        public module LiquidityIntent {
            public func get(ledger_a: Principal, ledger_b: Principal, amount_a: Nat, amount_b: Nat) : LiquidityIntent {

                let pool_account = getPoolAccount(ledger_a, ledger_b, 0);
                let pool = Pool.get(pool_account);
                let asset_a = LedgerAccount.get(pool_account, ledger_a);
                let asset_b = LedgerAccount.get(pool_account, ledger_b);
                let reserve_A = LedgerAccount.balance(asset_a);
                let reserve_B = LedgerAccount.balance(asset_b);
                
                let total = pool.total;

                let minted_liquidity = sqrt(amount_a * amount_b);

                let new_total = total + minted_liquidity;

                let fee_coef = sqrt( reserve_A * reserve_B ) / new_total;

                let minted_tokens = minted_liquidity / fee_coef;
                    
                {
                    pool_account;
                    asset_a;
                    asset_b;
                    amount_a;
                    amount_b;
                    new_total;
                    minted_tokens;
                };
            };

            public func quote(liq: LiquidityIntent) : Nat {
                liq.minted_tokens;
            };

            public func commit(liq: LiquidityIntent) : () {
                let pool = Pool.get(liq.pool_account);

                ignore dvf.send({
                    ledger = liq.asset_a.ledger;
                    to = liq.pool_account;
                    amount = liq.amount_a;
                    memo = null;
                    from_subaccount = liq.asset_a.account.subaccount;
                });
                ignore dvf.send({
                    ledger = liq.asset_b.ledger;
                    to = liq.pool_account;
                    amount = liq.amount_b;
                    memo = null;
                    from_subaccount = liq.asset_b.account.subaccount;
                });

                pool.total := liq.new_total;
            };

            public func sqrt(x: Nat) : Nat {
                if (x == 0) return 0;
                
                // Initial estimate for the square root
                var z : Nat = (x + 1) / 2;
                var y : Nat = x;

                // Babylonian method: iterate until convergence
                while (z < y) {
                    y := z;
                    z := (x / z + z) / 2;
                };

                return y;
            };
        };

        public module Intent {
            
            public func quote(path: IntentPath) : Nat {
                let last = path[path.size() - 1];
                last.amount_out;
            };

            public func commit(path: IntentPath) : () {
                for (intent in path.vals()) {
                    ignore dvf.send({
                        ledger = intent.asset_in.ledger;
                        to = intent.pool_account;
                        amount = intent.amount_in;
                        memo = null;
                        from_subaccount = intent.asset_in.account.subaccount;
                    });
                };
            };

            public func get(from:Principal, to:Principal, start_amount: Nat) : IntentPath {
                if (to == primary_ledger or from == primary_ledger) {
                    getExact([from, to], start_amount);
                } else {
                    getExact([from, primary_ledger, to], start_amount);
                };
            };

            public func getExact(ledgers : [Principal], start_amount: Nat) : IntentPath {
                let path = Vector.new<Intent>();
                var acc_bal = start_amount;
                for (i in Iter.range(0, ledgers.size() - 2)) {
                    let ledger = ledgers[i];
                    let next_ledger = ledgers[i + 1];
                    
                    let ledger_fee = dvf.fee(ledger);
                    
                    let amount_fwd = acc_bal - ledger_fee:Nat;

                    let swap_fee_fwd = amount_fwd * swap_fee / 1_0000_0000;

                    let pool_account = getPoolAccount(ledger, next_ledger, 0);

                    let asset_A = LedgerAccount.get(pool_account, ledger); 
                    let asset_B = LedgerAccount.get(pool_account, next_ledger); 

                    let reserve_A = LedgerAccount.balance(asset_A);
                    let reserve_B = LedgerAccount.balance(asset_B);

                    let request_amount = acc_bal;

                    let rate_fwd = (reserve_A + request_amount) / reserve_B;

                    let afterfee_fwd = request_amount - swap_fee_fwd:Nat;

                    let recieve_fwd = afterfee_fwd / rate_fwd;
                    Vector.add(path, {
                        pool_account = pool_account;
                        asset_in = asset_A;
                        asset_out = asset_B;
                        amount_in = request_amount;
                        amount_out = recieve_fwd;
                        swap_fee = swap_fee_fwd;
                    });

                    acc_bal := recieve_fwd;
                };
                Vector.toArray(path);
            };

        };

        public func getPoolAccount(a : Principal, b : Principal, pool_idx : Nat8) : Core.Account {
            let ledger_idx = Array.sort<Nat>([U.not_opt(dvf.get_ledger_idx(a)), U.not_opt(dvf.get_ledger_idx(b))], Nat.compare);
            {
                owner = core.getThisCan();
                subaccount = ?Blob.fromArray(Iter.toArray(IT.pad(IT.flattenArray<Nat8>([[100, pool_idx], U.ENat32(Nat32.fromNat(ledger_idx[0])), U.ENat32(Nat32.fromNat(ledger_idx[1]))]), 32, 0 : Nat8)));
            };
        };


        public module LedgerAccount {
            
            public func get(account: Core.Account, ledger: Principal) : LedgerAccount {
                {
                    ledger;
                    account;
                };
            };

            public func balance(asset: LedgerAccount) : Nat {
                dvf.balance(asset.ledger, asset.account.subaccount);
            };

            public func fee(asset: LedgerAccount) : Nat {
                dvf.fee(asset.ledger);
            };

        };
        
    };
}