import ICRC55 "../../../src/ICRC55";
import Sys "../../../src/sys";
import Result "mo:base/Result";
import U "../../../src/utils";
import Billing "../../billing_all";
import MU "mo:mosup";
import VM "./memory/v1";
import Map "mo:map/Map";


module {
    public let ID ="exchange";
    public type CreateRequest = VM.CreateRequest;
    public type ModifyRequest = VM.ModifyRequest;
    public type Shared = VM.Shared;
   
    public class Mod(xmem : MU.MemShell<VM.Mem>) : Sys.VectorClass<VM.VMem, VM.CreateRequest, VM.ModifyRequest, VM.Shared> {

        let mem = MU.access(xmem, VM.DefaultMem);

        public func meta() : ICRC55.NodeMeta {
            {
                id = ID; // This has to be same as the variant in vec.custom
                name = "Exchange";
                author = "Neutrinite";
                description = "Exchange X tokens for Y";
                supported_ledgers = [];
                version = #alpha([0, 0, 1]);
                create_allowed = true;
                ledger_slots = [
                    "From",
                    "To",
                ];
                billing = billing();
                sources = sources(0);
                destinations = destinations(0);
            };
        };

        public func billing() : ICRC55.Billing {
            Billing.get();
        };

        public func authorAccount() : ICRC55.Account {
            Billing.authorAccount();
        };

        // Create state from request
        public func create(id: Sys.NodeId, t : VM.CreateRequest) : Result.Result<Sys.ModuleId, Text> {
            
            let obj:VM.VMem = {
                init = t.init;
                variables = {
                    var interest = t.variables.interest;
                };
                internals = {};
            };
            ignore Map.put(mem.main, Map.n32hash, id, obj);
            #ok(ID);
        };

        public func defaults() : VM.CreateRequest {

            {
                init = {

                };
                variables = {
                    interest = 20;
                };
            };
        };

        // How does the modify request change memory
        public func modify(id: Sys.NodeId, m : VM.ModifyRequest) : Result.Result<(), Text> {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

            t.variables.interest := m.interest;
            #ok();
        };

        // Convert memory to shared
        public func toShared(id: Sys.NodeId) : Result.Result<VM.Shared, Text> {
            let ?t = Map.get(mem.main, Map.n32hash, id) else return #err("Not found");

            #ok {
                init = t.init;
                variables = {
                    interest = t.variables.interest;
                };
                internals = {};
            };
        };

        public func sources(_id: Sys.NodeId) : Sys.PortsDescription {
            [(0, "From")];
        };

        public func destinations(_id: Sys.NodeId) : Sys.PortsDescription {
            [(1, "To")];
        };

    };


};
