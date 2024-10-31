module {

    public type CreateRequest = {
        init : {
        };
        variables : {
            interval_sec : NumVariant;
            max_amount : NumVariant;
        };
    };

    public type ModifyRequest = {
        interval_sec : NumVariant;
        max_amount : NumVariant;
    };

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

    public type NumVariant = {
        #fixed : Nat64;
        #rnd : { min : Nat64; max : Nat64 };
    };

}