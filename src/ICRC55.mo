import Principal "mo:base/Principal";
module {

    public type LocalNodeId = Nat32;
    public type NodeFactoryMeta = {
        name: Text;
        description: Text;
        governed_by: Text;
        supported_ledgers: [Principal];
        pricing: Text;
    };

    public type GetNode = {
        #id: LocalNodeId;
        #subaccount: ?Blob;
    };

    public type Account = {
        owner: Principal;
        subaccount: ?Blob
    };

    public type SourceEndpoint = {
        ledger: Principal;
        account: Account;
        balance: Nat;
    };

    public type DestinationEndpoint = {
        ledger: Principal;
        account: Account;
    };

    public type GetNodeResponse = {
        id: LocalNodeId;
        sources: [SourceEndpoint];
        destinations: [DestinationEndpoint];
        controllers: [Principal];
        created : Nat64;
        modified: Nat64;
        expires: ?Nat64;
        // Each different canister can add additional fields here
    };

    public type GetControllerNodes = [LocalNodeId];

    public type CreateNode = {
        #Ok: GetNodeResponse;
        #Err: Text;
    };

    public type NodeCreateFee = {
        amount: Nat;
        ledger: Principal;
        subaccount: Blob;
    };

    public type Self = actor {
        icrc55_get_controller_nodes : shared query GetControllerNodes -> async GetControllerNodes;
        icrc55_get_node : shared query GetNode -> async ?GetNodeResponse;
        icrc55_create_node : shared (Any) -> async CreateNode;
        icrc55_create_node_get_fee : shared query (Principal, Any) -> async NodeCreateFee;
        icrc55_get_nodefactory_meta : shared query () -> async NodeFactoryMeta;
    }
}