import L "mo:devefi-icrc-ledger";
import Map "mo:map/Map";
import Blob "mo:base/Blob";
import IcrcSender "mo:devefi-icrc-ledger/sender";
import Result "mo:base/Result";
import ICRCLedger "mo:devefi-icrc-ledger/icrc_ledger";
import Option "mo:base/Option";
import Iter "mo:base/Iter";
import MU "mo:mosup";
import Ver1 "./memory/v1";
import Ver2 "./memory/v2";
import U "../utils";
import Chrono "mo:chronotrinite/client";
import AccountLib "mo:account";
import ChronoIF "../chrono";
import IT "mo:itertools/Iter";
import Nat "mo:base/Nat";
// import Debug "mo:base/Debug";

module {

    public module Mem {
        public module Virtual {
            public let V1 = Ver1.Virtual;
            public let V2 = Ver2.Virtual;
        };
    };

    let VM = Mem.Virtual.V2;

    type R<A, B> = Result.Result<A, B>;

    public type SendError = L.SendError;

    public type TransferRecieved = {
        amount : Nat;
        to_subaccount : ?Blob;
    };

    public type AccountMixed = {
        #icrc : ICRCLedger.Account;
        #icp : Blob;
    };

    public type Transfer = {
        to : ICRCLedger.Account;
        fee : ?Nat;
        from : AccountMixed;
        memo : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
        spender : ?AccountMixed;
    };

    // We need to make it work for ICP and ICRC
    public type ExpectedLedger = {
        accounts : () -> Iter.Iter<(Blob, Nat)>;
        balance : ?Blob -> Nat;
        genNextSendId : (?Nat64) -> Nat64;
        getErrors : () -> [Text];
        getFee : () -> Nat;
        isSent : Nat64 -> Bool;
        me : () -> Principal;
        onReceive : (<system>L.Transfer -> ()) -> ();
        onSent : ((Nat64, Nat) -> ()) -> ();
        send : IcrcSender.TransactionInput -> R<Nat64, L.SendError>;
        getRegisteredAccount : Blob -> ?ICRCLedger.Account;
    };

    public class Virtual<system>({
        xmem : MU.MemShell<VM.Mem>;
        ledger : ExpectedLedger;
        chrono : Chrono.ChronoClient;
        ledger_id : Principal;
        me_can : Principal;
        getNextChronoId : () -> Nat64;
    }) {
        let mem = MU.access(xmem);

        var callback_onReceive : ?((TransferRecieved) -> ()) = null;
        var callback_onSent : ?((Nat64,Nat) -> ()) = null;
        var callback_onRecieveShouldVirtualize : ?((Transfer) -> Bool) = null;

        public func onReceive(fn : (TransferRecieved) -> ()) : () {
            assert (Option.isNull(callback_onReceive));
            callback_onReceive := ?fn;
        };

        public func onSent(fn : (Nat64,Nat) -> ()) : () {
            assert (Option.isNull(callback_onSent));
            callback_onSent := ?fn;
        };

        public func onRecieveShouldVirtualize(fn : (Transfer) -> Bool) : () {
            assert (Option.isNull(callback_onRecieveShouldVirtualize));
            callback_onRecieveShouldVirtualize := ?fn;
        };

        public func registerSubaccount(_subaccount : ?Blob) : () {
            // Only used in the ICP version
        };

        public func unregisterSubaccount(_subaccount : ?Blob) : () {
            // Only used in the ICP version
        };

        /// Virtual balance
        public func balance(subaccount : ?Blob) : Nat {
            let ?acc = Map.get(mem.accounts, Map.bhash, L.subaccountToBlob(subaccount)) else return 0;
            acc.balance;
        };

        public func top_accounts() : [(Blob, Nat)] {
            // Go over all accounts and pick top 100 by balance
            let sorted = IT.sort<(Blob, VM.AccountMem)>(Map.entries<Blob, VM.AccountMem>(mem.accounts), func((a, b)) { Nat.compare(b.1.balance, a.1.balance) });
            let top = IT.take<(Blob, VM.AccountMem)>(sorted, 100);
            let top_accounts = Iter.toArray<(Blob, Nat)>(Iter.map<(Blob, VM.AccountMem), (Blob, Nat)>(top, func(a) { (a.0, a.1.balance) }));
            top_accounts;
        };

        public func getRegisteredAccount(aid : Blob) : ?ICRCLedger.Account {
           ledger.getRegisteredAccount(aid);
        };

        /// Send from virtual address
        public func send(tr : IcrcSender.TransactionInput) : R<Nat64, SendError> {
            // The amount we send includes the fee. meaning recepient will get the amount -
            let ?acc = Map.get(mem.accounts, Map.bhash, L.subaccountToBlob(tr.from_subaccount)) else return #err(#InsufficientFunds);
            if (acc.balance : Nat < tr.amount) return #err(#InsufficientFunds);

            let fee = ledger.getFee();
            if (tr.amount <= fee) return #err(#InsufficientFunds);

            

            let { amount; to; from_subaccount } = tr;
            // If local just move the tokens in pooled ledger

            let to_local_account : ?ICRCLedger.Account = switch(to) {
                case (#icrc(x)) {
                    if (x.owner == ledger.me()) {
                        ?x;
                    } else {
                        null;
                    };
                };
                case (#icp(x)) {
                    ledger.getRegisteredAccount(x);
                };
            };

            switch(to_local_account) {
                case (?to_account) {
                    chrono_insert_recieved({
                        id=getNextChronoId();
                        from = #icrc({
                            owner = me_can;
                            subaccount = from_subaccount;
                        });
                        to = to_account.subaccount;
                        amount = amount;
                    });
                    chrono_insert_sent({
                        id=getNextChronoId();
                        to = #icrc(to_account);
                        from = from_subaccount;
                        amount = amount;
                    });
                    handle_outgoing_amount(from_subaccount, amount);
                    handle_incoming_amount(to_account.subaccount, amount - fee);
                    mem.collected_fees += fee;
                    ignore do ? {
                        // This will cause recursion if onRecieve sends (as intended) so be careful with it
                        callback_onReceive!({
                            amount = amount - fee;
                            to_subaccount = to_account.subaccount;
                        });
                    };
                    #ok(1);
                };
                case (null) {
                    switch(ledger.send({
                        from_subaccount = null; // pool account
                        to = to;
                        amount = amount;
                        memo = tr.memo;
                    })) {
                        case (#ok(id)) {
                            handle_outgoing_amount(from_subaccount, amount);
                            chrono_insert_sent({
                                    id=getNextChronoId();
                                    to = to;
                                    from = from_subaccount;
                                    amount = amount;
                                });
 
                            // If remote, send tokens from pool to remote account
                            #ok(id);
                        };
                        case (#err(e)) {
                            #err(e);
                        };
                    }

                };
            }

        };

        private func chrono_insert_recieved({
            id : Nat64;
            from : AccountMixed;
            to : ?Blob;
            amount : Nat;
        }) : () {
            chrono.insert_one(
                "/a/" # AccountLib.toText({
                    owner = ledger.me();
                    subaccount = to;
                }),
                U.now_tid(id),
                #CANDID(
                    to_candid (
                        #account(#received({
                            ledger = ledger_id;
                            from = from;
                            amount = amount;
                        })) : ChronoIF.ChronoRecord
                    ),
                ),
            );
        };

        private func chrono_insert_sent({
            id : Nat64;
            to : AccountMixed;
            from : ?Blob;
            amount : Nat;
        }) : () {
            chrono.insert_one(
                "/a/" # AccountLib.toText({
                    owner = ledger.me();
                    subaccount = from;
                }),
                U.now_tid(id),
                #CANDID(
                    to_candid (
                        #account(#sent({
                            ledger = ledger_id;
                            to = to;
                            amount = amount;
                        })) : ChronoIF.ChronoRecord
                    ),
                ),
            );
        };

        private func handle_incoming_amount(subaccount : ?Blob, amount : Nat) : () {
            switch (Map.get<Blob, VM.AccountMem>(mem.accounts, Map.bhash, L.subaccountToBlob(subaccount))) {
                case (?acc) {
                    acc.balance += amount : Nat;
                };
                case (null) {
                    Map.set(
                        mem.accounts,
                        Map.bhash,
                        L.subaccountToBlob(subaccount),
                        {
                            var balance = amount;
                            var in_transit = 0;
                        },
                    );
                };
            };

        };

        private func handle_outgoing_amount(subaccount : ?Blob, amount : Nat) : () {
            let ?acc = Map.get(mem.accounts, Map.bhash, L.subaccountToBlob(subaccount)) else return;
            acc.balance -= amount : Nat;

            if (acc.balance == 0) {
                ignore Map.remove<Blob, VM.AccountMem>(mem.accounts, Map.bhash, L.subaccountToBlob(subaccount));
            };

        };

        /// Get Iter of all accounts owned by the canister (except dust < fee)
        public func accounts() : Iter.Iter<(Blob, Nat)> {
            Iter.map<(Blob, VM.AccountMem), (Blob, Nat)>(Map.entries<Blob, VM.AccountMem>(mem.accounts), func((k, v)) { (k, v.balance) });
        };

        ledger.onSent(
            func(id, block_id) {
                ignore do ? { callback_onSent!(id, block_id) };
            }
        );

        ledger.onReceive(
            func<system>(tx : L.Transfer) {
                // If we are sending from a subaccount to the pool it will always have from = #icrc and not #icp
                switch (tx.from) {
                    case (#icrc(from)) {
                        if (from.owner == ledger.me() and from.subaccount != null and tx.to.subaccount == null) {
                            // a subaccount is sending tokens to the pool
                            handle_incoming_amount(from.subaccount, tx.amount);
                            ignore do ? {
                                callback_onReceive! ({
                                    amount = tx.amount;
                                    to_subaccount = from.subaccount;
                                });
                            };
                            return;
                        } else {
                            if (from.owner != ledger.me() and tx.to.subaccount == null) {
                                // Someone from outside is sending to the pool
                                handle_incoming_amount(tx.to.subaccount, tx.amount);
                                ignore do ? {
                                    callback_onReceive! ({
                                        amount = tx.amount;
                                        to_subaccount = null;
                                    });
                                };
                                return;
                            };
                        };
                    };
                    case (#icp(_)) ();
                };

                // External transfer to a subaccount
                let pass = do ? { callback_onRecieveShouldVirtualize! (tx) };

                // Ignore dust
                if (tx.amount < ledger.getFee() * 2) return;

                // Check if account was created
                let exists = Map.has(mem.accounts, Map.bhash, L.subaccountToBlob(tx.to.subaccount));

                // Won't open new account in memory if dust is sent
                if (not exists and tx.amount < ledger.getFee() * 20) return;

                if (Option.isNull(pass) or pass == ?true) {

                    let #ok(id) = ledger.send({
                        from_subaccount = tx.to.subaccount;
                        to = #icrc({
                            owner = ledger.me();
                            subaccount = null; // pool account
                        });
                        amount = tx.amount;
                        memo = null;
                    }) else return;


                    chrono_insert_recieved({
                        id=getNextChronoId();
                        from = tx.from;
                        to = tx.to.subaccount;
                        amount = tx.amount - ledger.getFee();
                    });

                }

            }
        );

    };

};
