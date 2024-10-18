import ICRC55 "../src/ICRC55";
import T "./vector_modules";
import Rechain "mo:rechain";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Array "mo:base/Array";

module {

    public type DispatchAction = {
        ts : Nat64;
        caller : Principal;
        payload : {
            #vector : ICRC55.BatchCommandRequest<T.CreateRequest, T.ModifyRequest>;
        };
    };

    public type DispatchActionError = { ok : Nat; err : Text };

    public func encodeBlock(b : DispatchAction) : ?[Rechain.ValueMap] {
        switch(b.payload) {
            case (#vector(v)) {
                ?[
                    ("btype", #Text("55vec")),
                    ("b",#Blob(to_candid(b))),
                ];
            };
        }
    };


};
