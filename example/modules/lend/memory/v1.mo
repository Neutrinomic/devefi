import Map "mo:map/Map";
import MU "mo:mosup";

module {
    public type Mem = {
        main : Map.Map<Nat32, VMem>;
    };
    public func new() : MU.MemShell<Mem> = MU.new<Mem>(
        {
            main = Map.new<Nat32, VMem>();
        }
    );


    public type VMem = {
        init : {

        };
        variables : {
            var interest : Nat;
        };
        internals : {};
    };

    public type CreateRequest = {
        init : {

        };
        variables : {
            interest : Nat;
        };
    };

    public type ModifyRequest = {
        interest : Nat;
    };

    public type Shared = {
        init : {

        };
        variables : {
            interest : Nat;
        };
        internals : {};
    };
}