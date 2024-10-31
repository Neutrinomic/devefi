module {
    
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