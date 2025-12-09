import MU "mo:mosup";
import Vector "mo:vector";
import ICRCLedger "mo:devefi-icrc-ledger";
import ICPLedger "mo:devefi-icp-ledger";
import Map "mo:map/Map";
import V3 "./v3";
import Iter "mo:base/Iter";

module {
    public module Ledgers {

        public func new() : MU.MemShell<Mem> = MU.new<Mem>(
        {
            ledgers = Vector.new<Ledger>();
            var me = null;
        });

        public type Mem = {
            ledgers : Vector.Vector<Ledger>;
            var me : ?Principal;
            };

        public type Ledger = {
            id: Principal;
            mem: {
                #icrc: MU.MemShell<ICRCLedger.Mem.Ledger.V3.Mem>;
                #icp: MU.MemShell<ICPLedger.Mem.Ledger.V2.Mem>;
            };
            virtual_mem : MU.MemShell<Virtual.Mem>;
        };

        public func upgrade(from : MU.MemShell<V3.Ledgers.Mem>) : MU.MemShell<Mem> {
            
            MU.upgrade(from, func(a : V3.Ledgers.Mem) : Mem {
                {
                    ledgers = Vector.vals(a.ledgers) |> Iter.map<V3.Ledgers.Ledger, Ledger>(_,
                        func(e : V3.Ledgers.Ledger) : Ledger  {
                            let mem = switch(e.mem) {
                                case (#icrc(m)) {
                                    #icrc(ICRCLedger.Mem.Ledger.V3.upgrade(m));
                                };
                                case (#icp(m)) {
                                    #icp(m);
                                };
                            };
                            {
                            id = e.id;
                            mem = mem;
                            virtual_mem = e.virtual_mem;
                        }}) |> Vector.fromIter<Ledger>(_);
                    var me = a.me;
                };
            });
        };
    };

    public module Virtual {

        public func new() : MU.MemShell<Mem> = MU.new<Mem>({
            accounts = Map.new<Blob, AccountMem>();
            var collected_fees = 0;
            var collected_fees_withdrawn = 0;
        });

        public type Mem = {
            accounts : Map.Map<Blob, AccountMem>;
            var collected_fees : Nat;
            var collected_fees_withdrawn : Nat;
        };

        public type AccountMem = {
            var balance : Nat;
        };
        
    };
}