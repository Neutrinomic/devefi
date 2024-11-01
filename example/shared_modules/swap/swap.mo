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

            public func get(ledgers : [Principal], start_amount: Nat) : IntentPath {
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