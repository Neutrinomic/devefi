import Map "mo:map/Map";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import ICRC55 "../ICRC55";
import Nat8 "mo:base/Nat8";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import MU "mo:mosup";

module {

    public module Core {

    public func new() : MU.MemShell<Mem> = MU.new<Mem>(
        {
            nodes = Map.new<NodeId, NodeMem>();
            var next_node_id : NodeId = 0;
            var ops = 0;
        }
    );

    public type Mem = {
        nodes : Map.Map<NodeId, NodeMem>;
        var next_node_id : NodeId;
        var ops : Nat; // Each transaction is one op
    };

    public type Endpoint = ICRC55.Endpoint;
    public type EndpointOpt = ICRC55.EndpointOpt;

    public type NodeId = Nat32;
    public type Account = {
        owner : Principal;
        subaccount : ?Blob;
    };
    public type Flow = { #input; #payment; #fee };
    public type Port = {
        vid : NodeId;
        flow : Flow;
        id : Nat8;
    };

    public type PortInfo = {
        balance : Nat;
        fee : Nat;
        ledger : Principal;
    };

    public type LedgerIdx = Nat;
    public type EndpointsDescription = ICRC55.EndpointsDescription;

    public type EndpointStored = {
        endpoint: Endpoint;
        name: Text;
    };

    public type EndpointOptStored = {
        endpoint: EndpointOpt;
        name: Text;
    };

    public type ModuleId = Text;

    public type NodeMem = {
        var sources : [EndpointStored];
        var extractors : [NodeId];
        var destinations : [EndpointOptStored];
        var refund : Account;
        var controllers : [Account];
        var affiliate : ?Account;
        var ledgers : [ICRC55.SupportedLedger];
        created : Nat64;
        var modified : Nat64;
        var active : Bool;
        billing : {
            var expires : ?Nat64;
            var frozen : Bool;
            var last_billed : Nat64;
            var last_fee_distribution : Nat64;
            var billing_option : Nat;
        };
        module_id : ModuleId;
        var meta : MetaSlice;
    };

    public type MetaSlice = {
        billing : ICRC55.Billing;
        create_allowed: Bool;
        ledger_slots : [Text];
        author_account: Account;
        temporary_allowed: Bool;
    }

    }
}