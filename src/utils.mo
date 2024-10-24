import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Int "mo:base/Int";
import ICRC55 "./ICRC55";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Vector "mo:vector";
import Ver1 "./memory/v1";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import I "mo:itertools/Iter";
import Array "mo:base/Array";

module {

    let VM = Ver1.Core;
    type Port = VM.Port;

    public func onlyIC(ep : ICRC55.Endpoint) : ICRC55.EndpointIC {
        let #ic(x) = ep else Debug.trap("Not supported");
        x;
    };

    public func onlyICDest(ep : ICRC55.EndpointOpt) : ICRC55.EndpointOptIC {
        let #ic(x) = ep else Debug.trap("Not supported");
        x;
    };
    public func onlyICLedger(ledger : ICRC55.SupportedLedger) : Principal {
        let #ic(x) = ledger else Debug.trap("Not supported");
        x;
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
        return ?(
            Nat32.fromNat(Nat8.toNat(array[0])) << 24 | Nat32.fromNat(Nat8.toNat(array[1])) << 16 | Nat32.fromNat(Nat8.toNat(array[2])) << 8 | Nat32.fromNat(Nat8.toNat(array[3]))
        );
    };

    public func now() : Nat64 {
        Nat64.fromNat(Int.abs(Time.now()));
    };

    public func expectSourceAccount(expected_ledger : Principal, can : Principal, req : [ICRC55.Endpoint], idx : Nat) : Result.Result<?ICRC55.Account, ()> {
        if (req.size() <= idx) return #ok(null);

        let #ic(x) = req[idx] else return #err;
        if (x.ledger != expected_ledger) return #err;
        if (x.account.owner != can) return #err;
        #ok(?x.account);
    };

    public func expectDestinationAccount(expected_ledger : Principal, req : [ICRC55.EndpointOpt], idx : Nat) : Result.Result<?ICRC55.Account, ()> {
        if (req.size() <= idx) return #ok(null);

        let #ic(x) = req[idx] else return #err;
        if (x.ledger != expected_ledger) return #err;
        #ok(x.account);
    };

    public func ok_or_trap<X,A>(x : Result.Result<X,A>) : X {
        switch(x) {
            case (#err(e)) {
                Debug.trap("Expected ok, got err");
            };
            case (#ok(x)) {
                x;
            };
        };
    };

    public func not_opt<X>(x : ?X) : X {
        let ?a = x else Debug.trap("Expected not opt");
        a;
    };

    public func all_or_error<X,A,B>(arr : [X], f:(X, Nat) -> Result.Result<A,B>) : Result.Result<[A], B> {
        var res = Vector.new<A>();
        
        for (k in arr.keys()) {
            switch(f(arr[k], k)) {
                case (#err(e)) {
                    return #err(e);
                };
                case (#ok(x)) {
                    Vector.add(res, x);
                };
            };
        };
        #ok(Vector.toArray(res));
    };

    public func onlyICLedgerArr(ledgers : [ICRC55.SupportedLedger]) : [Principal] {
        var res = Vector.new<Principal>();
        for (l in ledgers.vals()) {
            Vector.add(res, onlyICLedger(l));
        };
        Vector.toArray(res);
    };

    public module Account {
        let null_account : Blob = "\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00\00";

        public func equal(a : ICRC55.Account, b : ICRC55.Account) : Bool {
            a.owner == b.owner and (
                a.subaccount == b.subaccount
                or (a.subaccount == null and b.subaccount == ?null_account)
                or (a.subaccount == ?null_account and b.subaccount == null)
            );
        };
    };

    public func port2subaccount(p : Port) : Blob {
        let whobit : Nat8 = switch (p.flow) {
            case (#input) 1;
            case (#payment) 2;
        };
        Blob.fromArray(Iter.toArray(I.pad(I.flattenArray<Nat8>([[whobit], [p.id], ENat32(p.vid)]), 32, 0 : Nat8)));
    };

    public func subaccount2port(subaccount : ?Blob) : ?Port {
        let ?sa = subaccount else return null;
        let array = Blob.toArray(sa);
        let whobit = array[0];
        let id = array[1];
        let ?vid = DNat32(Iter.toArray(Array.slice(array, 2, 6))) else return null;
        let flow = if (whobit == 1) #input else if (whobit == 2) #payment else return null;
        ?{
            vid = vid;
            flow = flow;
            id = id;
        };

    };

};
