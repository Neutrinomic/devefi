import Principal "mo:base/Principal";
module {

    public type LocalNodeId = Nat32;
    public type NodeFactoryMeta = [{
        id : Text;
        name : Text;
        description : Text;
        governed_by : Text;
        supported_ledgers : [SupportedLedger];
        pricing : Text;
    }];

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

    public type DestinationEndpoint = Endpoint;

    public type ICEndpoint = {
        ledger : Principal;
        account : Account;
    };

    public type RemoteEndpoint = {
        platform : Nat64;
        ledger : Blob;
        account : Blob;
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

    public type GetControllerNodes = [LocalNodeId];

    public type CreateNode = {
        #ok : GetNodeResponse;
        #err : Text;
    };

    public type NodeCreateFee = {
        amount : Nat;
        ledger : Principal;
        subaccount : Blob;
    };

    public type NodeRequest = {
        destinations : [Endpoint];
        refund: [Endpoint];
        controllers : [Principal];
    };

    public type Self = actor {
        icrc55_get_controller_nodes : shared query GetControllerNodes -> async GetControllerNodes;
        icrc55_get_node : shared query GetNode -> async ?GetNodeResponse;
        icrc55_create_node : shared (NodeRequest, Any) -> async CreateNode;
        icrc55_create_node_get_fee : shared query (Principal, Any) -> async NodeCreateFee;
        icrc55_get_nodefactory_meta : shared query () -> async NodeFactoryMeta;
    };
};
