import Map "mo:map/Map";
import MU "mo:mosup";

module {
    public type Mem = {
        main : Map.Map<Nat32, NodeMem>;
    };
    public func new() : MU.MemShell<Mem> = MU.new<Mem>(
        {
            main = Map.new<Nat32, NodeMem>();
        }
    );

    public type NodeMem = {
        init : {

        };
        variables : {
            var flow : Flow;
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