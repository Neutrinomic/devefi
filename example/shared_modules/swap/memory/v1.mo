import Map "mo:map/Map";
import MU "mo:mosup";

module {
    public type Mem = {
        main : Map.Map<PoolSubaccount, Pool>;
    };

    public func new() : MU.MemShell<Mem> = MU.new<Mem>(
        {
            main = Map.new<PoolSubaccount, Pool>();
        }
    );

    public type Pool = {
        var total: Nat;
        balances: Map.Map<ClientSubaccount, Share>
    };

    public type Share = Nat;
    public type PoolSubaccount = Blob;
    public type ClientSubaccount = Blob;

   
}