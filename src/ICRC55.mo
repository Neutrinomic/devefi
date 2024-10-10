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
        create_allowed: Bool;
    };
    public type Version = {#production; #beta; #alpha};
    public type NodeMeta = {
        id : Text;
        name : Text;
        description : Text;
        supported_ledgers : [SupportedLedger];
        billing : Billing;
        split : BillingFeeSplit;
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

    public type ICEndpointRaw = {
        ledger : Principal;
        account : Account;
    };

    public type RemoteEndpointRaw = {
        platform : Nat64;
        ledger : Blob;
        account : Blob;
    };

    public type EndpointRaw = {
        #ic : ICEndpointRaw;
        #remote : RemoteEndpointRaw;
    };


    public type Billing = {
        ledger : Principal;
        min_create_balance : Nat; // Min balance required to create a node
        cost_per_day: Nat; 
        operation_cost: Nat; // Cost incurred per operation (Ex: modify, withdraw)        
        freezing_threshold_days: Nat; // Min days left to freeze the node if it has insufficient balance
        one_time_payment: ?Nat; // Balance threshold that exempts from cost deduction
        transaction_fee: {
            #none;
            #flat_fee_multiplier: Nat;
            #transaction_percentage_fee: Nat // 8 decimal places
        }
    };

    public type BillingFeeSplit = {
        pylon : Nat; // Ratio
        author : Nat; // Ratio
        affiliate: Nat; // Ratio
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
        refund: Account;
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
        refund: Account;
        controllers : [Principal];
        affiliate: ?Account
    };

    public type CommonModRequest = {
        sources: ?[Endpoint];
        destinations : ?[DestinationEndpoint];
        extractors : ?[LocalNodeId];
        refund: ?Account;
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

    public type Port = Nat8;


    public type WithdrawNodeRequest = {
        id : LocalNodeId;
        source_port : Port;
        to: Endpoint;
        amount: Nat;
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


    public type WithdrawVirtualRequest = {
        account : Account;
        to: EndpointRaw;
        amount: Nat;
    };

    public type WithdrawVirtualResponse = {
        #ok : Nat64;
        #err : Text;
    };

    public type Command<C,M> = {
        #create_node : CreateNodeRequest<C>;
        #delete_node : LocalNodeId;
        #modify_node : ModifyNodeRequest<M>;
        #withdraw_node: WithdrawNodeRequest;
        #withdraw_virtual: WithdrawVirtualRequest;
       
    };

    public type CommandResponse<A> = {
        #create_node : CreateNodeResponse<A>;
        #delete_node : DeleteNodeResp;
        #modify_node : ModifyNodeResponse<A>;
        #withdraw_node: WithdrawNodeResponse;
        #withdraw_virtual: WithdrawVirtualResponse;
    };

    public type VirtualBalancesRequest = Account;
    public type VirtualBalancesResponse = [(SupportedLedger, Nat)];

    public type Self = actor {
        icrc55_get_controller_nodes : shared query GetControllerNodesRequest -> async GetControllerNodes<Any>;
        
        icrc55_command : shared ([Command<Any, Any>]) -> async [CommandResponse<Any>];

        icrc55_get_nodes : shared query [GetNode] -> async [?GetNodeResponse<Any>];
        icrc55_get_pylon_meta : shared query () -> async NodeFactoryMetaResp;

        icrc55_virtual_balances : shared query (VirtualBalancesRequest) -> async VirtualBalancesResponse;
    };
};
