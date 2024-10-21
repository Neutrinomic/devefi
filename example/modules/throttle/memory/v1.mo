import Map "mo:map/Map";

module {
    public type Mem = {
        main : Map.Map<Nat32, VMem>;
    };
    public func DefaultMem() : Mem {
        {
            main = Map.new<Nat32, VMem>();
        };
    };

   // Internal vector state
    public type VMem = {
        init : {
        };
        variables : {
            var interval_sec : NumVariant;
            var max_amount : NumVariant;
        };
        internals : {
            var wait_until_ts : Nat64;
        };
    };

    // Create request
    public type CreateRequest = {
        init : {
        };
        variables : {
            interval_sec : NumVariant;
            max_amount : NumVariant;
        };
    };


    // Modify request
    public type ModifyRequest = {
        interval_sec : NumVariant;
        max_amount : NumVariant;
    };

    // Public shared state
    public type Shared = {
        init : {
        };
        variables : {
            interval_sec : NumVariant;
            max_amount : NumVariant;
        };
        internals : {
            wait_until_ts : Nat64;
        };
    };


    // Other custom types
    public type NumVariant = {
        #fixed : Nat64;
        #rnd : { min : Nat64; max : Nat64 };
    };

}