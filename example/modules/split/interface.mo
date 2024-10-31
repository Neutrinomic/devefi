module {
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