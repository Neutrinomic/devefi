import Principal "mo:base/Principal";
import Text "mo:base/Text";
module {

    public type LocalNodeId = Nat32;
    public type NodeFactoryMetaResp = [NodeMeta];
    public type NodeMeta = {
        id : Text;
        name : Text;
        description : Text;
        governed_by : Text;
        supported_ledgers : [SupportedLedger];
        pricing : Text;
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

    public type GetNodeResponse = {
        id : LocalNodeId;
        sources : [SourceEndpointResp];
        destinations : [DestinationEndpoint];
        refund: [Endpoint];
        controllers : [Principal];
        created : Nat64;
        modified : Nat64;
        expires : ?Nat64;
    };

    public type GetControllerNodesRequest = {
        id : Principal;
        start : Nat;
        length : Nat;
    };
    
    public type GetControllerNodes = [GetNodeResponse];

    public type CreateNode = {
        #ok : GetNodeResponse;
        #err : Text;
    };

    public type NodeCreateFeeResp = {
        #ok : NodeCreateFee;
        #err : Text;
    };

    public type NodeCreateFee = {
        amount : Nat;
        ledger : Principal;
        subaccount : Blob;
    };

    public type NodeRequest = {
        destinations : [DestinationEndpoint];
        refund: [Endpoint];
        controllers : [Principal];
    };

    public type NodeModifyRequest = {
        destinations : [DestinationEndpoint];
        refund: [Endpoint];
        controllers : [Principal];
    };

    public type NodeModifyResponse = {
        #ok : GetNodeResponse;
        #err : Text;
    };

    public type DeleteNodeResp = {
        #ok : ();
        #err : Text;
    };

    public type Self = actor {
        icrc55_get_controller_nodes : shared query GetControllerNodesRequest -> async GetControllerNodes;
        icrc55_delete_node : shared (LocalNodeId) -> async DeleteNodeResp;
        icrc55_get_node : shared query GetNode -> async ?GetNodeResponse;
        icrc55_create_node : shared (NodeRequest, Any) -> async CreateNode;
        icrc55_create_node_get_fee : shared query (Principal, Any) -> async NodeCreateFeeResp;
        icrc55_modify_node : shared (LocalNodeId, ?NodeModifyRequest, ?Any) -> async NodeModifyResponse;
        icrc55_get_nodefactory_meta : shared query () -> async NodeFactoryMetaResp;
    };
};
