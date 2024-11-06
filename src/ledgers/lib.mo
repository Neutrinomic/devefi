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

module {
    public module Mem {
        public module Ledgers {
            public let V1 = Ver1.Ledgers;
        }
    };

    let VM = Mem.Ledgers.V1;
    let VirtualMem = Ver1.Virtual;

    public type Account = ICRCLedgerIF.Account;
    type R<A,B> = Result.Result<A,B>;

    public type LedgerInfo = {
        id:Principal;
        info: {
            #icrc: ICRCLedger.Info;
            #icp: ICPLedger.Info;
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

    public type LedgerCls = {
        id : Principal;
        cls : {
            #icrc: ICRCLedger.Ledger;
            #icp: ICPLedger.Ledger;
        }
    };

    public class Ledgers<system>({xmem : MU.MemShell<VM.Mem>; me_can: Principal}) {
        let mem = MU.access(xmem);

        let ledgercls = Vector.new<LedgerCls>();
        let virtualcls = Vector.new<Virtual.Virtual>();

        var emitFunc : ?(Event -> ()) = null;

        public func get_ledger_idx(p: Principal) : ?Nat {
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
            let ?me = mem.me else U.trap("Not initialized");
            me;
        };

        public func onEvent(fn: Event -> ()) {
            emitFunc := ?fn;
        };

        public func emit(e: Event) {
            let ?fn = emitFunc else return;
            fn(e);
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
            let ?virtual = get_virtual(t.ledger) else return U.trap("No ledger found");
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
            let ?virtual = get_virtual(ledger) else return U.trap("No ledger found");
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
                    let m = ICRCLedger.Mem.Ledger.V1.new();
                    let l =  ICRCLedger.Ledger<system>(m, Principal.toText(id), #last, me_can);
                    (#icrc(m), {id; cls=#icrc(l)});
                    };
                case (#icp) {
                    let m = ICPLedger.Mem.Ledger.V1.new();
                    let l =  ICPLedger.Ledger<system>(m, Principal.toText(id), #last, me_can);
                    (#icp(m), {id; cls=#icp(l)});
                    };
            };

            let virt_mem = VirtualMem.new();
            
            let virt_cls = init_virt<system>(virt_mem, new_cls);
            Vector.add(mem.ledgers, {id; mem=new_mem; virtual_mem = virt_mem});
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

        public func init_virt<system>(mem: MU.MemShell<VirtualMem.Mem>, cls: LedgerCls) : Virtual.Virtual {
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


            return virt;
        };
            


        for (ledger in Vector.vals(mem.ledgers)) {
            switch(ledger.mem) {
                case (#icrc(m)) {
                    let cls = ICRCLedger.Ledger<system>(m, Principal.toText(ledger.id), #last, me_can);

                    Vector.add(ledgercls, {id=ledger.id; cls=#icrc(cls)});
                    Vector.add(virtualcls, init_virt<system>(ledger.virtual_mem, {id=ledger.id; cls=#icrc(cls)}));
                };
                case (#icp(m)) {
                    let cls = ICPLedger.Ledger<system>(m, Principal.toText(ledger.id), #last, me_can);
                    
                    Vector.add(ledgercls, {id=ledger.id; cls=#icp(cls)});
                    Vector.add(virtualcls, init_virt<system>(ledger.virtual_mem, {id=ledger.id; cls=#icp(cls)}));
                };

            };
        };

    };



    public func now() : Nat64 {
        Nat64.fromNat(Int.abs(Time.now()))
    };
  

    
}