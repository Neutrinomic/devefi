import Timer "mo:base/Timer";
import ICRCLedger "mo:devefi-icrc-ledger";
import ICRCLedgerIF "mo:devefi-icrc-ledger/icrc_ledger";

import ICPLedger "mo:devefi-icp-ledger";
import Vector "mo:vector";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Result "mo:base/Result";

module {
    public type Account = ICRCLedgerIF.Account;
    type R<A,B> = Result.Result<A,B>;

    public type LedgerInfo = {
            id:Principal;
            info: {
                #icrc: ICRCLedger.Info;
                #icp: ICPLedger.Info;
            }
        };

    public type Ledger = {
        id: Principal;
        mem: {
            #icrc: ICRCLedger.Mem;
            #icp: ICPLedger.Mem;
        }
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
        to : MixedAccount;
        fee : ?Nat;
        from : MixedAccount;
        memo : ?Blob;
        created_at_time : ?Nat64;
        amount : Nat;
        spender : ?MixedAccount;
    };

    public type Send = {
        ledger : Principal;
        to : Account;
        amount : Nat;
        memo : ?Blob;
        from_subaccount : ?Blob;
    };

    public type Event = {
        #received: Received;
        #sent: Sent;
    };


    public type Mem = {
        ledgers : Vector.Vector<Ledger>;
        var me : ?Principal;
    };

    public func Mem() : Mem {
        {
        ledgers = Vector.new<Ledger>();
        var me = null;
        };
    };

    

    public type LedgerCls = {
        id : Principal;
        cls : {
            #icrc: ICRCLedger.Ledger;
            #icp: ICPLedger.Ledger;
        }
    };

    public class DeVeFi<system>({mem : Mem}) {

        let ledgercls = Vector.new<LedgerCls>();
        var emitFunc : ?(Event -> ()) = null;

        

        public func get_ledger(id: Principal) : ?LedgerCls {
            for (ledger in Vector.vals(ledgercls)) {
                if (ledger.id == id) {
                    return ?ledger;
                };
            };
            return null;
        };

        public func me() : Principal {
            let ?me = mem.me else Debug.trap("Not initialized");
            me;
        };

        public func onEvent(fn: Event -> ()) {
            emitFunc := ?fn;
        };

        public func emit(e: Event) {
            let ?fn = emitFunc else return;
            fn(e);
        };

        public func start<system>(me: Principal) {
            mem.me := ?me;
 
            for (ledger in Vector.vals(ledgercls)) {
                switch(ledger.cls) {
                    case (#icrc(l)) {
                        l.setOwner(me);
                    };
                    case (#icp(l)) {
                        l.setOwner(me);
                    };
                };
            };
        };

        public func registerSubaccount(subaccount: ?Blob) {
            for (ledger in Vector.vals(ledgercls)) {
                switch(ledger.cls) {
                    case (#icp(m)) {
                        m.registerSubaccount(subaccount);
                    };
                    case (_) ();
                };
            };
        };

        public func unregisterSubaccount(subaccount: ?Blob) {
            for (ledger in Vector.vals(ledgercls)) {
                switch(ledger.cls) {
                    case (#icp(m)) {
                        m.unregisterSubaccount(subaccount);
                    };
                    case (_) ();
                };
            };
        };

        public func send(t: Send) : R<Nat64, ICRCLedger.SendError> {
   
            let ?ledger = get_ledger(t.ledger) else return Debug.trap("No ledger found");
          
            switch(ledger.cls) {
                case (#icrc(l)) {
                    l.send(t);
                };
                case (#icp(l)) {
                    l.send(t);
                };
            };
        };

        public func fee(id:Principal): Nat {
            let ?ledger = get_ledger(id) else return 0;
            switch(ledger.cls) {
                case (#icrc(l)) {
                    l.getFee();
                };
                case (#icp(l)) {
                    l.getFee();
                };
            };
        };

        public func balance(id:Principal, sa: ?Blob) : Nat {
            let ?ledger = get_ledger(id) else return 0;
            switch(ledger.cls) {
                case (#icrc(l)) {
                    l.balance(sa);
                };
                case (#icp(l)) {
                    l.balance(sa);
                };
            };

        };


        public func getErrors() : [[Text]] {
            let rez = Vector.new<[Text]>();
            for (ledger in Vector.vals(ledgercls)) {
                switch(ledger.cls) {
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
                  switch(ledger.cls) {
                    case (#icrc(l)) {
                        Vector.add(rez, {id = ledger.id; info=#icrc(l.getInfo())});
                    };
                    case (#icp(l)) {
                        Vector.add(rez, {id = ledger.id; info=#icp(l.getInfo())});
                    };
                  };
            };

            Vector.toArray(rez);
            
        };

        public func add_ledger<system>(id: Principal, ltype: {#icrc; #icp}) {
            // Check if the ledger is already added
            for (ledger in Vector.vals(mem.ledgers)) {
                if (ledger.id == id) {
                    return;
                };
            };

            let (new_mem, new_cls) = switch(ltype) {
                case (#icrc) {
                    let m = ICRCLedger.LMem();
                    let l = init_ledger<system>({mem=#icrc(m); id});
                    (#icrc(m), l);
                    };
                case (#icp) {
                    let m = ICPLedger.LMem();
                    let l = init_ledger<system>({mem=#icp(m); id});
                    (#icp(m), l);
                    };
            };

            Vector.add(mem.ledgers, {id; mem=new_mem});
            Vector.add(ledgercls, new_cls);
        };

        public func get_ledgers() : [Principal] {
            let rez = Vector.new<Principal>();
            for (ledger in Vector.vals(mem.ledgers)) {
                Vector.add(rez, ledger.id);
            };
            Vector.toArray(rez);
        };

        private func init_ledger<system>(lg : Ledger) : LedgerCls {
            switch(lg.mem) {
                case (#icrc(m)) {
                    let cls = ICRCLedger.Ledger<system>(m, Principal.toText(lg.id), #last);

                    cls.onReceive(func (t) {
                        emit(#received(
                            {t with 
                            ledger= lg.id;
                            from = #icrc(t.from);
                            spender = do ? {#icrc(t.spender!)}}
                            ));
                    });

                    cls.onMint(func (t) {
                        let ?minter = cls.getMinter() else return;
                        let mt : Received = {
                            ledger = lg.id;
                            to = t.to;
                            fee = null;
                            from = #icrc(minter);
                            memo = t.memo;
                            created_at_time = t.created_at_time;
                            amount = t.amount;
                            spender = null;
                        };
                        emit(#received(mt));
                    });

                    cls.onSent(func (t) {
                        let mt : Sent = {
                            ledger = lg.id;
                            to = #icrc(t.to);
                            fee = t.fee;
                            from = #icrc(t.from);
                            memo = t.memo;
                            created_at_time = t.created_at_time;
                            amount = t.amount;
                            spender = do ? { #icrc(t.spender!) };
                        };
                        emit(#sent(mt));
                    });

                    cls.onBurn(func (t) {
                        let ?minter = cls.getMinter() else return;

                        let mt : Sent = {
                            ledger = lg.id;
                            to = #icrc(minter);
                            fee = null;
                            from = #icrc(t.from);
                            memo = t.memo;
                            created_at_time = t.created_at_time;
                            amount = t.amount;
                            spender = null;
                        };
                        emit(#sent(mt));
                    });

                    {id=lg.id; cls = #icrc(cls)};
                };
                case (#icp(m)) {
                    let cls = ICPLedger.Ledger<system>(m, Principal.toText(lg.id), #last);

                    cls.onReceive(func (t) {
                        let ?owner = mem.me else return;

                        let mt : Received = {
                            ledger = lg.id;
                            to = {owner; subaccount = t.to_subaccount};
                            fee = ?t.fee;
                            from = #icp(t.from);
                            memo = t.memo;
                            created_at_time = ?t.created_at_time;
                            amount = t.amount;
                            spender = do ? { #icp(t.spender!) };
                        };
                        emit(#received(mt));
                    });

                    cls.onMint(func (t) {
                        let ?owner = mem.me else return;
                        let meta = cls.getMeta();
                        let mt : Received = {
                            ledger = lg.id;
                            to = {owner; subaccount = t.to_subaccount};
                            fee = null;
                            from = #icrc(meta.minter);
                            memo = t.memo;
                            created_at_time = ?t.created_at_time;
                            amount = t.amount;
                            spender = null;
                        };
                        emit(#received(mt));
                    });

                    cls.onSent(func (t) {
                        let ?owner = mem.me else return;
                        let mt : Sent = {
                            ledger = lg.id;
                            to = #icp(t.to);
                            fee = ?t.fee;
                            from = #icrc({owner; subaccount = t.from_subaccount});
                            memo = t.memo;
                            created_at_time = ?t.created_at_time;
                            amount = t.amount;
                            spender = do ? { #icp(t.spender!) };
                        };
                        emit(#sent(mt));
                    });

                    cls.onBurn(func (t) {
                        let ?owner = mem.me else return;
                        let meta = cls.getMeta();
                        let mt : Sent = {
                            ledger = lg.id;
                            to = #icrc(meta.minter);
                            fee = null;
                            from = #icrc({owner; subaccount = t.from_subaccount});
                            memo = t.memo;
                            created_at_time = ?t.created_at_time;
                            amount = t.amount;
                            spender = null;
                        };
                        emit(#sent(mt));
                    });
                    {id=lg.id; cls = #icp(cls)};
                };
            };
        };

        for (ledger in Vector.vals(mem.ledgers)) {
            switch(ledger.mem) {
                case (#icrc(m)) {
                    let cls = init_ledger<system>({mem=#icrc(m); id=ledger.id});
                    Vector.add(ledgercls, cls);
                };
                case (#icp(m)) {
                    let cls = init_ledger<system>({mem=#icp(m); id=ledger.id});
                    Vector.add(ledgercls, cls);
                };
            };
        };



    };



    public func now() : Nat64 {
        Nat64.fromNat(Int.abs(Time.now()))
    };
  

    
}