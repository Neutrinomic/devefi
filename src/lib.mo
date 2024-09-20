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
import Virtual "mo:devefi-icrc-ledger/virtual"

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
        #received: Virtual.TransferRecieved and {ledger: Principal};
        #sent: Sent;
    };


    public type Mem = {
        ledgers : Vector.Vector<Ledger>;
        virtual : Vector.Vector<Virtual.Mem>;
        var me : ?Principal;
    };

    public func Mem() : Mem {
        {
        ledgers = Vector.new<Ledger>();
        virtual = Vector.new<Virtual.Mem>();
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
        let virtualcls = Vector.new<Virtual.Virtual>();

        var emitFunc : ?(Event -> ()) = null;

        

        public func get_ledger(id: Principal) : ?LedgerCls {
            for (ledger in Vector.vals(ledgercls)) {
                if (ledger.id == id) {
                    return ?ledger;
                };
            };
            return null;
        };

        public func get_virtual(id: Principal) : ?Virtual.Virtual {
            for ((ledger, idx) in Vector.items(ledgercls)) {
                if (ledger.id == id) {
                    return ?Vector.get(virtualcls, idx);
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
            let ?virtual = get_virtual(t.ledger) else return Debug.trap("No ledger found");
            virtual.send(t);
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

        public func balance(ledger:Principal, sa: ?Blob) : Nat {
            let ?virtual = get_virtual(ledger) else return Debug.trap("No ledger found");
            virtual.balance(sa);
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
                    let l =  ICRCLedger.Ledger<system>(m, Principal.toText(id), #last);
                    (#icrc(m), {id; cls=#icrc(l)});
                    };
                case (#icp) {
                    let m = ICPLedger.LMem();
                    let l =  ICPLedger.Ledger<system>(m, Principal.toText(id), #last);
                    (#icp(m), {id; cls=#icp(l)});
                    };
            };

            let virt_mem = Virtual.Mem();
            
            init_virt<system>(virt_mem, new_cls);

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

        public func init_virt<system>(mem: Virtual.Mem, cls: LedgerCls) {
            let virt = switch(cls.cls) {
                case (#icrc(l)) Virtual.Virtual<system>(mem, l);
                case (#icp(l)) Virtual.Virtual<system>(mem, l);
            };

            virt.onReceive(func (t) {
                emit(#received(
                    {t with 
                    ledger= cls.id;
                    }));
            });


            virt.onSent(func (id) {
                emit(#sent({id; ledger=cls.id}));
            });
        };
            


        for (ledger in Vector.vals(mem.ledgers)) {
            switch(ledger.mem) {
                case (#icrc(m)) {
                    let cls = ICRCLedger.Ledger<system>(m, Principal.toText(ledger.id), #last);

                    Vector.add(ledgercls, {id=ledger.id; cls=#icrc(cls)});
                };
                case (#icp(m)) {
                    let cls = ICPLedger.Ledger<system>(m, Principal.toText(ledger.id), #last);
                    
                    Vector.add(ledgercls, {id=ledger.id; cls=#icp(cls)});
                };

            };
        };



    };



    public func now() : Nat64 {
        Nat64.fromNat(Int.abs(Time.now()))
    };
  

    
}