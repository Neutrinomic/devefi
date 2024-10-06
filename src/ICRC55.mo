import Principal "mo:base/Principal";
import Text "mo:base/Text";

module {

    public type LocalNodeId = Nat32;
    public type NodeFactoryMetaResp = {
        name: Text;
        governed_by : Text;
        nodes: [NodeMeta];
        temporary_nodes: {
            allowed : Bool;
            expire_sec: Nat64;
        };
    };
    public type Version = {#production; #beta; #alpha};
    public type NodeMeta = {
        id : Text;
        name : Text;
        description : Text;
        supported_ledgers : [SupportedLedger];
        billing : Billing;
        billing_fee_collecting : BillingFeeCollecting;
        version: Version; //TODO: each node should have different princing token
    };

    public type SupportedLedger = {
        #ic : Principal;
        #remote : {
            platform : Nat64;
            ledger : Blob;
        };
    };

    public type GetNode = {
        #id : LocalNodeId;
        #subaccount : ?Blob;
    };

    public type Account = {
        owner : Principal;
        subaccount : ?Blob;
    };

    public type SourceEndpointResp = {
        endpoint : Endpoint;
        balance : Nat;
    };

    public type DestICEndpoint = {
        ledger : Principal;
        account : ?Account;
        name: Text
    };

    public type DestRemoteEndpoint = {
        platform : Nat64;
        ledger : Blob;
        account : ?Blob;
        name: Text;
    };
    
    public type DestinationEndpoint = {
        #ic : DestICEndpoint;
        #remote : DestRemoteEndpoint;
    };

    public type ICEndpoint = {
        ledger : Principal;
        account : Account;
        name :Text;
    };

    public type RemoteEndpoint = {
        platform : Nat64;
        ledger : Blob;
        account : Blob;
        name:Text;
    };

    public type Endpoint = {
        #ic : ICEndpoint;
        #remote : RemoteEndpoint;
    };

    public type Billing = {
        ledger : Principal;
        min_create_balance : Nat; // Min balance required to create a node
        cost_per_day: Nat; // Cost deducted per hour of node operation
        operation_cost: Nat; // Cost incurred per operation        
        freezing_threshold_days: Nat; // Min days operational cost left to freeze the node
        exempt_balance: ?Nat; // Balance threshold that exempts from hourly cost deduction
    };

    public type BillingFeeCollecting = {
        pylon : Nat; // Ratio
        author : Nat; // Ratio
        author_account : Account;
    };

    public type BillingInternal = {
        frozen: Bool;
        current_balance: Nat;
        account : Account;
        expires : ?Nat64;
    }; 

    public type GetNodeResponse<A> = {
        id : LocalNodeId;
        sources : [SourceEndpointResp];
        destinations : [DestinationEndpoint];
        extractors: [LocalNodeId];
        refund: [Endpoint];
        controllers : [Principal];
        created : Nat64;
        modified : Nat64;
        billing : Billing and BillingInternal;
        active : Bool;
        custom : A;
    };

    public type GetControllerNodesRequest = {
        id : Principal;
        start : Nat;
        length : Nat;
    };
    
    public type GetControllerNodes<A> = [GetNodeResponse<A>];

    public type CreateNodeResponse<A> = {
        #ok : GetNodeResponse<A>;
        #err : Text;
    };


    public type NodeRequest = {
        sources:[Endpoint];
        extractors : [LocalNodeId];
        destinations : [DestinationEndpoint];
        refund: [Endpoint];
        controllers : [Principal];
    };

    public type CommonModRequest = {
        sources: ?[Endpoint];
        destinations : ?[DestinationEndpoint];
        extractors : ?[LocalNodeId];
        refund: ?[Endpoint];
        controllers : ?[Principal];
        active: ?Bool;
    };

    public type DeleteNodeResp = {
        #ok : ();
        #err : Text;
    };

    public type CreateNodeRequest<A> = (NodeRequest, A);
    public type ModifyNodeRequest<A> = (LocalNodeId, ?CommonModRequest, ?A);
    public type ModifyNodeResponse<A> = {
        #ok : GetNodeResponse<A>;
        #err : Text;
    };

    public type WithdrawNodeRequest = {
        id : LocalNodeId;
        source_port : Nat;
        to: Endpoint;
    };
    public type WithdrawNodeResponse = {
        #ok : ();
        #err : Text;
    };
    public type ChangeActiveNodeRequest = {
        id : LocalNodeId;
        active : Bool;
    };
    public type ChangeActiveNodeResponse = {
        #ok : ();
        #err : Text;
    };



    public type Command<C,M> = {
        #create_node : CreateNodeRequest<C>;
        #delete_node : LocalNodeId;
        #modify_node : ModifyNodeRequest<M>;
        #withdraw_node: WithdrawNodeRequest;
       
    };

    public type CommandResponse<A> = {
        #create_node : CreateNodeResponse<A>;
        #delete_node : DeleteNodeResp;
        #modify_node : ModifyNodeResponse<A>;
        #withdraw_node: WithdrawNodeResponse;

    };

    public type Self = actor {
        icrc55_get_controller_nodes : shared query GetControllerNodesRequest -> async GetControllerNodes<Any>;
        
        icrc55_command : shared ([Command<Any, Any>]) -> async [CommandResponse<Any>];

        icrc55_create_node : shared CreateNodeRequest<Any> -> async CreateNodeResponse<Any>;
        icrc55_delete_node : shared (LocalNodeId) -> async DeleteNodeResp;
        icrc55_modify_node : shared ModifyNodeRequest<Any> -> async ModifyNodeResponse<Any>;

        icrc55_get_node : shared query GetNode -> async ?GetNodeResponse<Any>;
        icrc55_get_nodefactory_meta : shared query () -> async NodeFactoryMetaResp;
    };
};
