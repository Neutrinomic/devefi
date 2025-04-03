import ICRCLedger "mo:devefi-icrc-ledger";
import ICRCLedgerIF "mo:devefi-icrc-ledger/icrc_ledger";

import ICPLedger "mo:devefi-icp-ledger";
import Vector "mo:vector";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
// import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Virtual "./virtual";
import U "../utils";
import MU "mo:mosup";
import Ver1 "./memory/v1";
import ICRC55 "../ICRC55";
import Chrono "mo:chronotrinite/client";
import Nat8 "mo:base/Nat8";

module {
    public module Mem {
        public module Ledgers {
            public let V1 = Ver1.Ledgers;
        };
    };

    let VM = Mem.Ledgers.V1;
    let VirtualMem = Ver1.Virtual;

    public type Account = ICRCLedgerIF.Account;
    type R<A, B> = Result.Result<A, B>;

    public type LedgerInfo = {
        id : Principal;
        info : {
            #icrc : ICRCLedger.Info;
            #icp : ICPLedger.Info;
        };
    };

    public type MixedAccount = {
        #icrc : Account;
        #icp : Blob;
    };

    public type Received = {
        ledger : Principal;
        to : Account;
        fee : ?Nat;
        from : MixedAccount;
        memo : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
        spender : ?MixedAccount;
    };

    public type Sent = {
        ledger : Principal;
        id : Nat64;
    };

    public type Send = {
        ledger : Principal;
        to : Account;
        amount : Nat;
        memo : ?Blob;
        from_subaccount : ?Blob;
    };

    public type Event = {
        #received : Virtual.TransferRecieved and { ledger : Principal };
        #sent : Sent;
    };

    public type LedgerCls = {
        id : Principal;
        cls : {
            #icrc : ICRCLedger.Ledger;
            #icp : ICPLedger.Ledger;
        };
    };

    public type LedgerMeta = {
        symbol : Text;
        name : Text;
        decimals : Nat8;
        fee : Nat;
    };

    public class Ledgers<system>({
        xmem : MU.MemShell<VM.Mem>;
        me_can : Principal;
        chrono : Chrono.ChronoClient;
    }) {
        let mem = MU.access(xmem);

        let ledgercls = Vector.new<LedgerCls>();
        let virtualcls = Vector.new<Virtual.Virtual>();

        var emitFunc : ?(Event -> ()) = null;

        public func get_ledger_idx(p : Principal) : ?Nat {
            for ((ledger, idx) in Vector.items(ledgercls)) {
                if (ledger.id == p) {
                    return ?idx;
                };
            };
            return null;
        };

        public func get_ledger_ids() : [Principal] {
            let rez = Vector.new<Principal>();
            for (ledger in Vector.vals(ledgercls)) {
                Vector.add(rez, ledger.id);
            };
            Vector.toArray(rez);
        };

        public func get_ledger_info() : [ICRC55.LedgerInfo] {
            let rez = Vector.new<ICRC55.LedgerInfo>();
            for (ledger in Vector.vals(ledgercls)) {
                let meta : ICRCLedger.Meta = switch (ledger.cls) {
                    case (#icrc(l)) l.getMeta();
                    case (#icp(l)) l.getMeta();
                };
                Vector.add(
                    rez,
                    {
                        ledger = #ic(ledger.id);
                        symbol = meta.symbol;
                        name = meta.name;
                        decimals = meta.decimals;
                        fee = meta.fee;
                    },
                );
            };
            Vector.toArray(rez);
        };

        public func get_ledger(id : Principal) : ?LedgerCls {
            for (ledger in Vector.vals(ledgercls)) {
                if (ledger.id == id) {
                    return ?ledger;
                };
            };
            return null;
        };

        public func get_virtual(id : Principal) : ?Virtual.Virtual {
            for ((ledger, idx) in Vector.items(ledgercls)) {
                if (ledger.id == id) {
                    return ?Vector.get(virtualcls, idx);
                };
            };
            return null;
        };

        public func me() : Principal {
            let ?me = mem.me else U.trap("Not initialized");
            me;
        };

        public func onEvent(fn : Event -> ()) {
            emitFunc := ?fn;
        };

        public func emit(e : Event) {
            let ?fn = emitFunc else return;
            fn(e);
        };

        public func registerSubaccount(subaccount : ?Blob) {
            for (ledger in Vector.vals(ledgercls)) {
                switch (ledger.cls) {
                    case (#icp(m)) {
                        m.registerSubaccount(subaccount);
                    };
                    case (_) ();
                };
            };
        };

        public func isRegisteredSubaccount(subaccount : ?Blob) : Bool {
            for (ledger in Vector.vals(ledgercls)) {
                switch (ledger.cls) {
                    case (#icp(m)) {
                        return m.isRegisteredSubaccount(subaccount);
                    };
                    case (_) ();
                };
            };
            true;
        };

        public func unregisterSubaccount(subaccount : ?Blob) {
            for (ledger in Vector.vals(ledgercls)) {
                switch (ledger.cls) {
                    case (#icp(m)) {
                        m.unregisterSubaccount(subaccount);
                    };
                    case (_) ();
                };
            };
        };

        public module Send {
            public type Intent = {
                virtual : Virtual.Virtual;
                tx : Send;
            };
            public func intent(t : Send) : R<Intent, ICRCLedger.SendError> {
                let ?virtual = get_virtual(t.ledger) else return U.trap("No ledger found");
                let bal = virtual.balance(t.from_subaccount);
                if (bal < t.amount) return #err(#InsufficientFunds);
                #ok({ virtual; tx = t });
            };
            public func commit(intent : Intent) : Nat64 {
                let #ok(n) = intent.virtual.send(intent.tx) else U.trap("Internal error in send intent commit");
                n;
            };
        };

        public func send(t : Send) : R<Nat64, ICRCLedger.SendError> {
            let ?virtual = get_virtual(t.ledger) else return U.trap("No ledger found");


            virtual.send(t);
        };

        public func fee(id : Principal) : Nat {
            let ?ledger = get_ledger(id) else return 0;
            switch (ledger.cls) {
                case (#icrc(l)) {
                    l.getFee();
                };
                case (#icp(l)) {
                    l.getFee();
                };
            };
        };

        public func decimals(id : Principal) : Nat {
            let ?ledger = get_ledger(id) else return U.trap("No ledger found");
            Nat8.toNat(switch (ledger.cls) {
                case (#icrc(l)) l.getMeta().decimals;
                case (#icp(l)) l.getMeta().decimals;
            });
        };

        public func balance(ledger : Principal, sa : ?Blob) : Nat {
            let ?virtual = get_virtual(ledger) else return U.trap("No ledger found");
            virtual.balance(sa);
        };

        public func getErrors() : [[Text]] {
            let rez = Vector.new<[Text]>();
            for (ledger in Vector.vals(ledgercls)) {
                switch (ledger.cls) {
                    case (#icrc(l)) {
                        Vector.add(rez, l.getErrors());
                    };
                    case (#icp(l)) {
                        Vector.add(rez, l.getErrors());
                    };
                };
            };

            Vector.toArray(rez);
        };

        public func getLedgersInfo() : [LedgerInfo] {
            let rez = Vector.new<LedgerInfo>();

            for (ledger in Vector.vals(ledgercls)) {
                switch (ledger.cls) {
                    case (#icrc(l)) {
                        Vector.add(rez, { id = ledger.id; info = #icrc(l.getInfo()) });
                    };
                    case (#icp(l)) {
                        Vector.add(rez, { id = ledger.id; info = #icp(l.getInfo()) });
                    };
                };
            };

            Vector.toArray(rez);

        };

        public func add_ledger<system>(id : Principal, ltype : { #icrc; #icp }) {
            // Check if the ledger is already added
            for (ledger in Vector.vals(mem.ledgers)) {
                if (ledger.id == id) {
                    return;
                };
            };

            let (new_mem, new_cls) = switch (ltype) {
                case (#icrc) {
                    let m = ICRCLedger.Mem.Ledger.V1.new();
                    let l = ICRCLedger.Ledger<system>(m, Principal.toText(id), #last, me_can);
                    (#icrc(m), { id; cls = #icrc(l) });
                };
                case (#icp) {
                    let m = ICPLedger.Mem.Ledger.V1.new();
                    let l = ICPLedger.Ledger<system>(m, Principal.toText(id), #last, me_can);
                    (#icp(m), { id; cls = #icp(l) });
                };
            };

            let virt_mem = VirtualMem.new();

            let virt_cls = init_virt<system>(virt_mem, new_cls);
            Vector.add(mem.ledgers, { id; mem = new_mem; virtual_mem = virt_mem });
            Vector.add(ledgercls, new_cls);
            Vector.add(virtualcls, virt_cls);
        };

        public func get_ledgers() : [Principal] {
            let rez = Vector.new<Principal>();
            for (ledger in Vector.vals(mem.ledgers)) {
                Vector.add(rez, ledger.id);
            };
            Vector.toArray(rez);
        };

        public func init_virt<system>(mem : MU.MemShell<VirtualMem.Mem>, cls : LedgerCls) : Virtual.Virtual {
            let virt = switch (cls.cls) {
                case (#icrc(l)) Virtual.Virtual<system>({xmem=mem; ledger=l; chrono; me_can; ledger_id=cls.id});
                case (#icp(l)) Virtual.Virtual<system>({xmem=mem; ledger=l; chrono; me_can; ledger_id=cls.id});
            };

            virt.onReceive(
                func(t) {
                    emit(#received({ t with
                    ledger = cls.id }));
                }
            );

            virt.onSent(
                func(id) {
                    emit(#sent({ id; ledger = cls.id }));
                }
            );

            return virt;
        };

        for (ledger in Vector.vals(mem.ledgers)) {
            switch (ledger.mem) {
                case (#icrc(m)) {
                    let cls = ICRCLedger.Ledger<system>(m, Principal.toText(ledger.id), #last, me_can);

                    Vector.add(ledgercls, { id = ledger.id; cls = #icrc(cls) });
                    Vector.add(virtualcls, init_virt<system>(ledger.virtual_mem, { id = ledger.id; cls = #icrc(cls) }));
                };
                case (#icp(m)) {
                    let cls = ICPLedger.Ledger<system>(m, Principal.toText(ledger.id), #last, me_can);

                    Vector.add(ledgercls, { id = ledger.id; cls = #icp(cls) });
                    Vector.add(virtualcls, init_virt<system>(ledger.virtual_mem, { id = ledger.id; cls = #icp(cls) }));
                };

            };
        };

    };

    public func now() : Nat64 {
        Nat64.fromNat(Int.abs(Time.now()));
    };

};
