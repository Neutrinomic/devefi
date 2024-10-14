import Principal "mo:base/Principal";
import Text "mo:base/Text";

module {

    public type LocalNodeId = Nat32;
    public type PylonMetaResp = {
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
        version: Version;
        create_allowed: Bool;
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


    public module Endpoint {
        public module IC {
            public type Ledger = {
                ledger : Principal;
            };
            public type WithAccount = {
                account : Account;
            };
            public type Name = {
                name : Text;
            };
            public type OptAccount = {
                account : ?Account;
            }
        };
        public module Remote {
            public type Ledger = {
                platform : Nat64;
                ledger : Blob;
            };
            public type WithAccount = {
                account : Blob;
            };
            public type OptAccount = {
                account : ?Blob;
            };
            public type Name = {
                name : Text;
            };
        }
    };

    //--
    public type EndpointOpt = {
        #ic : EndpointOptIC;
        #remote : EndpointOptRemote;
    };

    public type EndpointOptIC = Endpoint.IC.Ledger and Endpoint.IC.OptAccount and Endpoint.IC.Name;
    public type EndpointOptRemote = Endpoint.Remote.Ledger and Endpoint.Remote.OptAccount and Endpoint.Remote.Name;
    
    //--
    public type EndpointOptNameless = {
        #ic : EndpointOptNamelessIC;
        #remote : EndpointOptNamelessRemote;
    };

    public type EndpointOptNamelessIC = Endpoint.IC.Ledger and Endpoint.IC.WithAccount;
    public type EndpointOptNamelessRemote = Endpoint.Remote.Ledger and Endpoint.Remote.WithAccount;
    

    //--
    public type Endpoint = {
        #ic : EndpointIC;
        #remote : EndpointRemote;
    };

    public type EndpointIC = Endpoint.IC.Ledger and Endpoint.IC.WithAccount and Endpoint.IC.Name;
 
    public type EndpointRemote = Endpoint.Remote.Ledger and Endpoint.Remote.WithAccount and Endpoint.Remote.Name;
  


    //--
    public type EndpointNameless = {
        #ic : EndpointNamelessIC;
        #remote : EndpointNamelessRemote;
    };

    public type EndpointNamelessIC = Endpoint.IC.Ledger and Endpoint.IC.WithAccount;
    
    public type EndpointNamelessRemote = Endpoint.Remote.Ledger and Endpoint.Remote.WithAccount;




    public type Billing = { // The billing parameters need to make sure author, pylon and affiliate get paid.
        ledger : Principal;
        min_create_balance : Nat; // Min balance required to create a node
        freezing_threshold_days: Nat; // Min days left to freeze the node if it has insufficient balance. Frozen nodes can't do transactions, but can be modified or deleted

        cost_per_day: Nat; // Split to all
        exempt_daily_cost_balance: ?Nat; // Balance threshold that exempts from cost per day deduction

        operation_cost: Nat; // Cost incurred per operation (Ex: modify, withdraw). Has to be at least 4 * ledger fee. Paid to the pylon only since the costs are incurred by the pylon

        // Transaction fees apply only to transactions sent to destination addresses
        // These are split to all
        transaction_fee: BillingTransactionFee;

        split: BillingFeeSplit;
    };

    public type BillingTransactionFee = { 
            #none;
            #flat_fee_multiplier: Nat; // On top of that the pylon always gets 1 fee for virtual transfers and 4 fees for external transfers to cover its costs
            #transaction_percentage_fee: Nat // 8 decimal places
        };

    public type BillingFeeSplit = { /// Ratios, their sum has to be 1000
        pylon : Nat; 
        author : Nat; 
        affiliate: Nat; 
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
        destinations : [EndpointOpt];
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
        destinations : [EndpointOpt];
        refund: Account;
        controllers : [Principal];
        affiliate: ?Account
    };

    public type CommonModRequest = {
        sources: ?[Endpoint];
        destinations : ?[EndpointOpt];
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



    public type WithdrawVirtualRequest = {
        account : Account;
        to: EndpointNameless;
        amount: Nat;
    };

    public type WithdrawVirtualResponse = {
        #ok : Nat64;
        #err : Text;
    };

    public type TopUpNodeRequest = {
        id : LocalNodeId;
        amount: Nat;
    };

    public type TopUpNodeResponse = {
        #ok : ();
        #err : Text;
    };

    public type Command<C,M> = {
        #create_node : CreateNodeRequest<C>;
        #delete_node : LocalNodeId;
        #modify_node : ModifyNodeRequest<M>;
        #withdraw_node: WithdrawNodeRequest;
        #withdraw_virtual: WithdrawVirtualRequest;
        #top_up_node : TopUpNodeRequest;
    };

    public type CommandResponse<A> = {
        #create_node : CreateNodeResponse<A>;
        #delete_node : DeleteNodeResp;
        #modify_node : ModifyNodeResponse<A>;
        #withdraw_node: WithdrawNodeResponse;
        #withdraw_virtual: WithdrawVirtualResponse;
        #top_up_node : TopUpNodeResponse;
    };

    public type VirtualBalancesRequest = Account;
    public type VirtualBalancesResponse = [(SupportedLedger, Nat)];

    public type Self = actor {
        icrc55_get_controller_nodes : shared query GetControllerNodesRequest -> async GetControllerNodes<Any>;
        
        icrc55_command : shared ([Command<Any, Any>]) -> async [CommandResponse<Any>];

        icrc55_get_nodes : shared query [GetNode] -> async [?GetNodeResponse<Any>];
        icrc55_get_pylon_meta : shared query () -> async PylonMetaResp;

        icrc55_virtual_balances : shared query (VirtualBalancesRequest) -> async VirtualBalancesResponse;
    };
};
