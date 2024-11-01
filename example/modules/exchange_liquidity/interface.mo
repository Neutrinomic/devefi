module {
    


    public type CreateRequest = {
        init : {

        };
        variables : {
            flow : Flow;
        };
    };

    public type ModifyRequest = {
        flow : Flow;
    };

    public type Shared = {
        init : {

        };
        variables : {
            flow : Flow;
        };
        internals : {};
    };

    public type Flow = {
        #hold; // Hold at source
        #add; // Add from source
        #remove; // Remove from source
        #pass_through; // Pass from source to destination
    };
}