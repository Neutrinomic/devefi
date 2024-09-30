import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Int "mo:base/Int";
import ICRC55 "./ICRC55";
import Result "mo:base/Result";

module {

    public func ENat64(value : Nat64) : [Nat8] {
        return [
            Nat8.fromNat(Nat64.toNat(value >> 56)),
            Nat8.fromNat(Nat64.toNat((value >> 48) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 40) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 32) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 24) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 16) & 255)),
            Nat8.fromNat(Nat64.toNat((value >> 8) & 255)),
            Nat8.fromNat(Nat64.toNat(value & 255)),
        ];
    };

    public func DNat64(array : [Nat8]) : ?Nat64 {
        if (array.size() != 8) return null;
        return ?(Nat64.fromNat(Nat8.toNat(array[0])) << 56 | Nat64.fromNat(Nat8.toNat(array[1])) << 48 | Nat64.fromNat(Nat8.toNat(array[2])) << 40 | Nat64.fromNat(Nat8.toNat(array[3])) << 32 | Nat64.fromNat(Nat8.toNat(array[4])) << 24 | Nat64.fromNat(Nat8.toNat(array[5])) << 16 | Nat64.fromNat(Nat8.toNat(array[6])) << 8 | Nat64.fromNat(Nat8.toNat(array[7])));
    };

    public func ENat32(value : Nat32) : [Nat8] {
        return [
            Nat8.fromNat(Nat32.toNat(value >> 24)),
            Nat8.fromNat(Nat32.toNat((value >> 16) & 255)),
            Nat8.fromNat(Nat32.toNat((value >> 8) & 255)),
            Nat8.fromNat(Nat32.toNat(value & 255)),
        ];
    };

    public func DNat32(array : [Nat8]) : ?Nat32 {
        if (array.size() != 4) return null;
        return ?(Nat32.fromNat(Nat8.toNat(array[0])) << 24 | 
                Nat32.fromNat(Nat8.toNat(array[1])) << 16 | 
                Nat32.fromNat(Nat8.toNat(array[2])) << 8  | 
                Nat32.fromNat(Nat8.toNat(array[3])));
    };

    public func now() : Nat64 {
        Nat64.fromNat(Int.abs(Time.now()))
    };

    public func expectSourceAccount(expected_ledger: Principal, can:Principal, req : [ICRC55.Endpoint], idx : Nat) : Result.Result<?ICRC55.Account, ()> {
        if (req.size() <= idx) return #ok(null);
      
        let #ic(x) = req[idx] else return #err;
        if (x.ledger != expected_ledger) return #err;
        if (x.account.owner != can) return #err; 
        #ok(?x.account);
    };

    public func expectDestinationAccount(expected_ledger: Principal, req : [ICRC55.DestinationEndpoint], idx : Nat) : Result.Result<?ICRC55.Account, ()> {
        if (req.size() <= idx) return #ok(null);
        
        let #ic(x) = req[idx] else return #err;
        if (x.ledger != expected_ledger) return #err;
        #ok(x.account);
    };
}