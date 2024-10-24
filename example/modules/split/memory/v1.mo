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
        init : {};
        variables : {
            var split : [Nat];
        };
        internals : {};
    };

    // Create request
    public type CreateRequest = {
        init : {};
        variables : {
            split : [Nat];
        };
    };
    // Modify request
    public type ModifyRequest = {
        split : [Nat];
    };
    // Public shared state
    public type Shared = {
        init : {};
        variables : {
            split : [Nat];
        };
        internals : {};
    };
}