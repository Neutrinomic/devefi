import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Iter "mo:base/Iter";
import I "mo:itertools/Iter";
import Array "mo:base/Array";
import DeVeFi "../src/lib";
import Time "mo:base/Time";
import Int "mo:base/Int";
import ICRC55 "../src/ICRC55";

module {

    public type NodeId = Nat32;

    public type NumVariant = {
        #fixed:Nat64;
        #rnd:{min:Nat64; max:Nat64};
    };

    public type NodeRequest = {
        ledger: Principal;
        destination: ?ICRC55.Account;
        variables : {
            interval_sec: NumVariant;
            max_amount: NumVariant;
        };
    };

    public type Node = {
        ledger : Principal;
        destination: ?ICRC55.Account;
        variables : {
            var interval_sec: NumVariant;
            var max_amount: NumVariant;
        };
        created : Nat64;
        modified: Nat64;
        controllers : [Principal];
        internals : {
            var wait_until_ts : Nat64;
        };
        var expires : ?Nat64;
    };

    public type NodeShared = ICRC55.GetNodeResponse and {
        variables: {
            interval_sec: NumVariant;
            max_amount: NumVariant;
        };
        internals : {
            wait_until_ts: Nat64;
        }
    };

    public type Port = {
        vid : NodeId; 
        flow : { #input; #output; #payment }; 
        id: Nat8;
    };

    public type CreateNode = {
        #Ok: NodeShared;
        #Err: Text;
    };

    public func port2subaccount(p: Port) : Blob {
        let whobit : Nat8 = switch (p.flow) {
            case (#input) 1;
            case (#output) 2;
            case (#payment) 3;
        };
        Blob.fromArray(Iter.toArray(I.pad(I.flattenArray<Nat8>([[whobit], [p.id], ENat32(p.vid)]), 32, 0 : Nat8)));
    };

    public func subaccount2port(subaccount : ?Blob) : ?Port {
        let ?sa = subaccount else return null;
        let array = Blob.toArray(sa);
        let whobit = array[0];
        let id = array[1];
        let ?vid = DNat32(Iter.toArray(Array.slice(array, 2, 6))) else return null;
        let flow = if (whobit == 1) #input else if (whobit == 2) #output else return null;
        ?{
            vid = vid;
            flow = flow;
            id = id;
        }
    };

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

    private func ENat32(value : Nat32) : [Nat8] {
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

}