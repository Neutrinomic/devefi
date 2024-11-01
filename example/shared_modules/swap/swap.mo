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

            public func getShare(pool: VM.Pool, client: Core.Account) : VM.Share {
                let ?subaccount = client.subaccount else Debug.trap("Client account subaccount is missing");
                let ?share = Map.get(pool.balances, Map.bhash, subaccount) else return 0;
                share;
            };

            public func setShare(pool: VM.Pool, client: Core.Account, share: VM.Share) : () {
                let ?subaccount = client.subaccount else Debug.trap("Client account subaccount is missing");
                ignore Map.put(pool.balances, Map.bhash, subaccount, share);
            };

            public func accountFromVid(vid: Core.NodeId, acc_idx: Nat8) : Core.Account {
                {
                    owner = core.getThisCan();
                    subaccount = ?Blob.fromArray(Iter.toArray(IT.pad(IT.flattenArray<Nat8>([ [101], [acc_idx], U.ENat32(vid)]), 32, 0 : Nat8)));
                };
            };
        };

        

        type LiquidityIntentRemove = {
            pool_account: Core.Account;
            asset_a: LedgerAccount;
            asset_b: LedgerAccount;
            to_a: AccountAmount;      // Account to receive token A
            to_b: AccountAmount;      // Account to receive token B
            amount_a: Nat;            // Amount of token A to return
            amount_b: Nat;            // Amount of token B to return
            new_total: Nat;           // New total liquidity in the pool after removal
            remove_tokens: Nat;       // Amount of liquidity tokens being removed
            from_account: Core.Account;
        };

        public module LiquidityIntentRemove {
            public func get(
                from_account: Core.Account,
                to_a: {ledger: Principal; account: Core.Account},
                to_b: {ledger: Principal; account: Core.Account},
                remove_tokens: Nat
            ) : R<LiquidityIntentRemove, Text> {
                
                let pool_account = getPoolAccount(to_a.ledger, to_b.ledger, 0);
                let pool = Pool.get(pool_account);
                let asset_a = LedgerAccount.get(pool_account, to_a.ledger);
                let asset_b = LedgerAccount.get(pool_account, to_b.ledger);
                let reserve_A = LedgerAccount.balance(asset_a);
                let reserve_B = LedgerAccount.balance(asset_b);
                let total = pool.total;

                // Ensure user has enough tokens to remove
                if (Pool.getShare(pool, from_account) < remove_tokens) {
                    return #err("Insufficient liquidity tokens for removal");
                };

                // Calculate the proportional amounts of tokens A and B to return
                let amount_a = reserve_A * remove_tokens / total;
                let amount_b = reserve_B * remove_tokens / total;

                // Ensure the removal results in at least the ledger fee amounts to avoid dust
                let ledger_a_fee = dvf.fee(to_a.ledger);
                let ledger_b_fee = dvf.fee(to_b.ledger);
                if (amount_a < 100 * ledger_a_fee or amount_b < 100 * ledger_b_fee) {
                    return #err("Removal must result in at least 100x ledger fee for each token");
                };

                // Calculate the new total liquidity after removal
                let new_total = total - remove_tokens:Nat;

                // Construct and return the LiquidityIntentRemove type
                #ok({
                    pool_account = pool_account;
                    asset_a = asset_a;
                    asset_b = asset_b;
                    to_a = { ledger = to_a.ledger; account = to_a.account; amount = amount_a };
                    to_b = { ledger = to_b.ledger; account = to_b.account; amount = amount_b };
                    amount_a = amount_a;
                    amount_b = amount_b;
                    new_total = new_total;
                    remove_tokens = remove_tokens;
                    from_account;
                });
            };

            public func quote(liq: LiquidityIntentRemove) : (Nat, Nat) {
                // Returns a quote of the amounts of token A and token B that will be returned to the user
                (liq.amount_a, liq.amount_b)
            };

            public func commit(liq: LiquidityIntentRemove) : () {
                let pool = Pool.get(liq.pool_account);

                // Transfer tokens back to the user based on their removed liquidity share
                ignore dvf.send({
                    ledger = liq.asset_a.ledger;
                    to = liq.to_a.account;
                    amount = liq.amount_a;
                    memo = null;
                    from_subaccount = liq.asset_a.account.subaccount;
                });
                ignore dvf.send({
                    ledger = liq.asset_b.ledger;
                    to = liq.to_b.account;
                    amount = liq.amount_b;
                    memo = null;
                    from_subaccount = liq.asset_b.account.subaccount;
                });
                
                // Remove the user's liquidity share from the pool
                Pool.setShare(pool, liq.from_account, Pool.getShare(pool, liq.from_account) - liq.remove_tokens);

                // Update the pool total after removal
                pool.total := liq.new_total;
            };
        };




        type AccountAmount = {
            ledger : Principal;
            account : Core.Account;
            amount : Nat;
        };

        type LiquidityIntentAdd = {
            pool_account : Core.Account;
            asset_a : LedgerAccount;
            asset_b : LedgerAccount;
            from_a : AccountAmount;
            from_b : AccountAmount;
            new_total: Nat;
            minted_tokens : Nat;
            to_account: Core.Account;
        };

        public module LiquidityIntentAdd {
            public func get(to_account: Core.Account, from_a: {ledger: Principal; account: Core.Account; amount: Nat}, from_b : {ledger:Principal; account:Core.Account; amount: Nat}) : R<LiquidityIntentAdd, Text> {

                let pool_account = getPoolAccount(from_a.ledger, from_b.ledger, 0);
                let pool = Pool.get(pool_account);
                let asset_a = LedgerAccount.get(pool_account, from_a.ledger);
                let asset_b = LedgerAccount.get(pool_account, from_b.ledger);
                let reserve_A = LedgerAccount.balance(asset_a);
                let reserve_B = LedgerAccount.balance(asset_b);
                
                let ledger_a_fee = dvf.fee(from_a.ledger);
                let ledger_b_fee = dvf.fee(from_b.ledger);

                // Too Small Additions
                if (from_a.amount < 100*ledger_a_fee or from_b.amount < 100*ledger_b_fee) {
                    return #err("Pool addition must be at least 100xledger fee for each token");
                };
            
                // Check if local accounts
                if (from_a.account.owner != core.getThisCan() or from_b.account.owner != core.getThisCan()) {
                    return #err("Only local accounts can add liquidity");
                };

                // Check if accounts have enough balance
                if (dvf.balance(from_a.ledger, from_a.account.subaccount) < from_a.amount) {
                    return #err("Insufficient balance in account A");
                };
                if (dvf.balance(from_b.ledger, from_b.account.subaccount) < from_b.amount) {
                    return #err("Insufficient balance in account B");
                };

                let input_a = from_a.amount - ledger_a_fee:Nat;
                let input_b = from_b.amount - ledger_b_fee:Nat;


                // Disproportionate Liquidity Additions
                let expected_amount_b = input_a * reserve_B / reserve_A;
                let deviation = if (expected_amount_b > input_b) {
                    (expected_amount_b - input_b:Nat) * 100 / expected_amount_b;
                } else {
                    (input_b - expected_amount_b:Nat) * 100 / expected_amount_b;
                };                
                if (deviation > 5) return #err("Liquidity amounts must be within 5% of pool ratio");


                let total = pool.total;

                let scaling_factor : Nat = 100000;  // Precision multiplier (choose a factor based on desired precision)

                let minted_liquidity = sqrt(input_a * input_b);

                let new_total = total + minted_liquidity;

                let fee_coef = sqrt( (input_a + reserve_A) * (input_b + reserve_B) * scaling_factor) / (new_total+1);
                
                let max_fee_coef = 10 * scaling_factor;
                if (fee_coef > max_fee_coef) return #err("Fee coefficient too high");

                let minted_tokens = minted_liquidity * scaling_factor / fee_coef;
                    
                #ok{
                    pool_account;
                    asset_a;
                    asset_b;
                    from_a;
                    from_b;
                    new_total;
                    minted_tokens;
                    to_account;
                };
            };

            public func quote(liq: LiquidityIntentAdd) : Nat {
                liq.minted_tokens;
            };

            public func commit(liq: LiquidityIntentAdd) : () {
                let pool = Pool.get(liq.pool_account);

                ignore dvf.send({
                    ledger = liq.asset_a.ledger;
                    to = liq.pool_account;
                    amount = liq.from_a.amount;
                    memo = null;
                    from_subaccount = liq.from_a.account.subaccount;
                });
                ignore dvf.send({
                    ledger = liq.asset_b.ledger;
                    to = liq.pool_account;
                    amount = liq.from_b.amount;
                    memo = null;
                    from_subaccount = liq.from_b.account.subaccount;
                });

                // Add liquidity tokens to the user's account
                Pool.setShare(pool, liq.to_account, Pool.getShare(pool, liq.to_account) + liq.minted_tokens);

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