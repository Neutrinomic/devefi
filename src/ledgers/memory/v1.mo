import MU "mo:mosup";
import Vector "mo:vector";
import ICRCLedger "mo:devefi-icrc-ledger";
import ICPLedger "mo:devefi-icp-ledger";
import Map "mo:map/Map";

module {
    public module Ledgers {

        public func new() : MU.MemShell<Mem> = MU.new<Mem>(
        {
            ledgers = Vector.new<Ledger>();
            virtual = Vector.new<Virtual.Mem>();
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
                #icp: MU.MemShell<ICPLedger.Mem.Ledger.V1.Mem>;
            };
            virtual_mem : MU.MemShell<Virtual.Mem>;
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