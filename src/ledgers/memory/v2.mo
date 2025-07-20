import MU "mo:mosup";
import Vector "mo:vector";
import ICRCLedger "mo:devefi-icrc-ledger";
import ICPLedger "mo:devefi-icp-ledger";
import Map "mo:map/Map";
import V1 "./v1";
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
                #icrc: MU.MemShell<ICRCLedger.Mem.Ledger.V1.Mem>;
                #icp: MU.MemShell<ICPLedger.Mem.Ledger.V2.Mem>;
            };
            virtual_mem : MU.MemShell<Virtual.Mem>;
        };

        public func upgrade(from : MU.MemShell<V1.Ledgers.Mem>) : MU.MemShell<Mem> {
            
            MU.upgrade(from, func(a : V1.Ledgers.Mem) : Mem {
                {
                    ledgers = Vector.vals(a.ledgers) |> Iter.map<V1.Ledgers.Ledger, Ledger>(_,
                        func(e : V1.Ledgers.Ledger) : Ledger  {
                            let mem = switch(e.mem) {
                                case (#icrc(m)) {
                                    #icrc(m);
                                };
                                case (#icp(m)) {
                                    #icp(ICPLedger.Mem.Ledger.V2.upgrade(m));
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