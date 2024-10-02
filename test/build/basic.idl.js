export const idlFactory = ({ IDL }) => {
  const Info = IDL.Record({
    'pending' : IDL.Nat,
    'last_indexed_tx' : IDL.Nat,
    'errors' : IDL.Nat,
    'lastTxTime' : IDL.Nat64,
    'accounts' : IDL.Nat,
    'actor_principal' : IDL.Opt(IDL.Principal),
    'reader_instructions_cost' : IDL.Nat64,
    'sender_instructions_cost' : IDL.Nat64,
  });
  const Info__1 = IDL.Record({
    'pending' : IDL.Nat,
    'last_indexed_tx' : IDL.Nat,
    'errors' : IDL.Nat,
    'lastTxTime' : IDL.Nat64,
    'accounts' : IDL.Nat,
    'actor_principal' : IDL.Opt(IDL.Principal),
    'reader_instructions_cost' : IDL.Nat64,
    'sender_instructions_cost' : IDL.Nat64,
  });
  const LedgerInfo = IDL.Record({
    'id' : IDL.Principal,
    'info' : IDL.Variant({ 'icp' : Info, 'icrc' : Info__1 }),
  });
  const NodeId = IDL.Nat32;
  const LocalNodeId = IDL.Nat32;
  const Account = IDL.Record({
    'owner' : IDL.Principal,
    'subaccount' : IDL.Opt(IDL.Vec(IDL.Nat8)),
  });
  const DestICEndpoint = IDL.Record({
    'name' : IDL.Text,
    'ledger' : IDL.Principal,
    'account' : IDL.Opt(Account),
  });
  const DestRemoteEndpoint = IDL.Record({
    'name' : IDL.Text,
    'platform' : IDL.Nat64,
    'ledger' : IDL.Vec(IDL.Nat8),
    'account' : IDL.Opt(IDL.Vec(IDL.Nat8)),
  });
  const DestinationEndpoint = IDL.Variant({
    'ic' : DestICEndpoint,
    'remote' : DestRemoteEndpoint,
  });
  const ICEndpoint = IDL.Record({
    'name' : IDL.Text,
    'ledger' : IDL.Principal,
    'account' : Account,
  });
  const RemoteEndpoint = IDL.Record({
    'name' : IDL.Text,
    'platform' : IDL.Nat64,
    'ledger' : IDL.Vec(IDL.Nat8),
    'account' : IDL.Vec(IDL.Nat8),
  });
  const Endpoint = IDL.Variant({
    'ic' : ICEndpoint,
    'remote' : RemoteEndpoint,
  });
  const CommonModRequest = IDL.Record({
    'controllers' : IDL.Vec(IDL.Principal),
    'extractors' : IDL.Vec(LocalNodeId),
    'destinations' : IDL.Vec(DestinationEndpoint),
    'sources' : IDL.Vec(Endpoint),
    'refund' : IDL.Vec(Endpoint),
  });
  const ModifyRequest__4 = IDL.Record({ 'interest' : IDL.Nat });
  const ModifyRequest__5 = IDL.Record({});
  const ModifyRequest__1 = IDL.Record({ 'interest' : IDL.Nat });
  const ModifyRequest__6 = IDL.Record({ 'split' : IDL.Vec(IDL.Nat) });
  const NumVariant = IDL.Variant({
    'rnd' : IDL.Record({ 'max' : IDL.Nat64, 'min' : IDL.Nat64 }),
    'fixed' : IDL.Nat64,
  });
  const ModifyRequest__7 = IDL.Record({
    'interval_sec' : NumVariant,
    'max_amount' : NumVariant,
  });
  const ModifyRequest__3 = IDL.Record({ 'max_per_sec' : IDL.Nat });
  const ModifyRequest__2 = IDL.Record({});
  const ModifyRequest = IDL.Variant({
    'lend' : ModifyRequest__4,
    'mint' : ModifyRequest__5,
    'borrow' : ModifyRequest__1,
    'split' : ModifyRequest__6,
    'throttle' : ModifyRequest__7,
    'exchange' : ModifyRequest__3,
    'escrow' : ModifyRequest__2,
  });
  const ModifyNodeRequest = IDL.Tuple(
    LocalNodeId,
    IDL.Opt(CommonModRequest),
    IDL.Opt(ModifyRequest),
  );
  const WithdrawNodeRequest = IDL.Record({
    'id' : LocalNodeId,
    'to' : Endpoint,
    'source_port' : IDL.Nat,
  });
  const ChangeDestinationRequest = IDL.Record({
    'id' : LocalNodeId,
    'to' : DestinationEndpoint,
    'port' : IDL.Nat,
  });
  const NodeRequest = IDL.Record({
    'controllers' : IDL.Vec(IDL.Principal),
    'extractors' : IDL.Vec(LocalNodeId),
    'destinations' : IDL.Vec(DestinationEndpoint),
    'sources' : IDL.Vec(Endpoint),
    'refund' : IDL.Vec(Endpoint),
  });
  const CreateRequest__4 = IDL.Record({
    'init' : IDL.Record({
      'ledger_collateral' : IDL.Principal,
      'ledger_lend' : IDL.Principal,
    }),
    'variables' : IDL.Record({ 'interest' : IDL.Nat }),
  });
  const CreateRequest__5 = IDL.Record({
    'init' : IDL.Record({
      'ledger_mint' : IDL.Principal,
      'ledger_for' : IDL.Principal,
    }),
    'variables' : IDL.Record({}),
  });
  const CreateRequest__1 = IDL.Record({
    'init' : IDL.Record({
      'ledger_collateral' : IDL.Principal,
      'ledger_borrow' : IDL.Principal,
    }),
    'variables' : IDL.Record({ 'interest' : IDL.Nat }),
  });
  const CreateRequest__6 = IDL.Record({
    'init' : IDL.Record({ 'ledger' : IDL.Principal }),
    'variables' : IDL.Record({ 'split' : IDL.Vec(IDL.Nat) }),
  });
  const CreateRequest__7 = IDL.Record({
    'init' : IDL.Record({ 'ledger' : IDL.Principal }),
    'variables' : IDL.Record({
      'interval_sec' : NumVariant,
      'max_amount' : NumVariant,
    }),
  });
  const CreateRequest__3 = IDL.Record({
    'init' : IDL.Record({
      'ledger_to' : IDL.Principal,
      'ledger_from' : IDL.Principal,
    }),
    'variables' : IDL.Record({ 'max_per_sec' : IDL.Nat }),
  });
  const CreateRequest__2 = IDL.Record({
    'init' : IDL.Record({ 'ledger' : IDL.Principal }),
    'variables' : IDL.Record({}),
  });
  const CreateRequest = IDL.Variant({
    'lend' : CreateRequest__4,
    'mint' : CreateRequest__5,
    'borrow' : CreateRequest__1,
    'split' : CreateRequest__6,
    'throttle' : CreateRequest__7,
    'exchange' : CreateRequest__3,
    'escrow' : CreateRequest__2,
  });
  const CreateNodeRequest = IDL.Tuple(NodeRequest, CreateRequest);
  const ChangeActiveNodeRequest = IDL.Record({
    'id' : LocalNodeId,
    'active' : IDL.Bool,
  });
  const Command = IDL.Variant({
    'modify_node' : ModifyNodeRequest,
    'withdraw_node' : WithdrawNodeRequest,
    'change_destination' : ChangeDestinationRequest,
    'create_node' : CreateNodeRequest,
    'change_active_node' : ChangeActiveNodeRequest,
    'delete_node' : LocalNodeId,
  });
  const Shared__4 = IDL.Record({
    'internals' : IDL.Record({}),
    'init' : IDL.Record({
      'ledger_collateral' : IDL.Principal,
      'ledger_lend' : IDL.Principal,
    }),
    'variables' : IDL.Record({ 'interest' : IDL.Nat }),
  });
  const Shared__5 = IDL.Record({
    'internals' : IDL.Record({}),
    'init' : IDL.Record({
      'ledger_mint' : IDL.Principal,
      'ledger_for' : IDL.Principal,
    }),
    'variables' : IDL.Record({}),
  });
  const Shared__1 = IDL.Record({
    'internals' : IDL.Record({}),
    'init' : IDL.Record({
      'ledger_collateral' : IDL.Principal,
      'ledger_borrow' : IDL.Principal,
    }),
    'variables' : IDL.Record({ 'interest' : IDL.Nat }),
  });
  const Shared__6 = IDL.Record({
    'internals' : IDL.Record({}),
    'init' : IDL.Record({ 'ledger' : IDL.Principal }),
    'variables' : IDL.Record({ 'split' : IDL.Vec(IDL.Nat) }),
  });
  const Shared__7 = IDL.Record({
    'internals' : IDL.Record({ 'wait_until_ts' : IDL.Nat64 }),
    'init' : IDL.Record({ 'ledger' : IDL.Principal }),
    'variables' : IDL.Record({
      'interval_sec' : NumVariant,
      'max_amount' : NumVariant,
    }),
  });
  const Shared__3 = IDL.Record({
    'internals' : IDL.Record({}),
    'init' : IDL.Record({
      'ledger_to' : IDL.Principal,
      'ledger_from' : IDL.Principal,
    }),
    'variables' : IDL.Record({ 'max_per_sec' : IDL.Nat }),
  });
  const Shared__2 = IDL.Record({
    'internals' : IDL.Record({}),
    'init' : IDL.Record({ 'ledger' : IDL.Principal }),
    'variables' : IDL.Record({}),
  });
  const Shared = IDL.Variant({
    'lend' : Shared__4,
    'mint' : Shared__5,
    'borrow' : Shared__1,
    'split' : Shared__6,
    'throttle' : Shared__7,
    'exchange' : Shared__3,
    'escrow' : Shared__2,
  });
  const SourceEndpointResp = IDL.Record({
    'balance' : IDL.Nat,
    'endpoint' : Endpoint,
  });
  const GetNodeResponse = IDL.Record({
    'id' : LocalNodeId,
    'created' : IDL.Nat64,
    'active' : IDL.Bool,
    'modified' : IDL.Nat64,
    'controllers' : IDL.Vec(IDL.Principal),
    'expires' : IDL.Opt(IDL.Nat64),
    'custom' : Shared,
    'extractors' : IDL.Vec(LocalNodeId),
    'destinations' : IDL.Vec(DestinationEndpoint),
    'sources' : IDL.Vec(SourceEndpointResp),
    'refund' : IDL.Vec(Endpoint),
  });
  const ModifyNodeResponse = IDL.Variant({
    'ok' : GetNodeResponse,
    'err' : IDL.Text,
  });
  const WithdrawNodeResponse = IDL.Variant({
    'ok' : IDL.Null,
    'err' : IDL.Text,
  });
  const ChangeDestinationResp = IDL.Variant({
    'ok' : IDL.Null,
    'err' : IDL.Text,
  });
  const CreateNodeResponse = IDL.Variant({
    'ok' : GetNodeResponse,
    'err' : IDL.Text,
  });
  const ChangeActiveNodeResponse = IDL.Variant({
    'ok' : IDL.Null,
    'err' : IDL.Text,
  });
  const DeleteNodeResp = IDL.Variant({ 'ok' : IDL.Null, 'err' : IDL.Text });
  const CommandResponse = IDL.Variant({
    'modify_node' : ModifyNodeResponse,
    'withdraw_node' : WithdrawNodeResponse,
    'change_destination' : ChangeDestinationResp,
    'create_node' : CreateNodeResponse,
    'change_active_node' : ChangeActiveNodeResponse,
    'delete_node' : DeleteNodeResp,
  });
  const CreateNodeResp = IDL.Variant({
    'ok' : GetNodeResponse,
    'err' : IDL.Text,
  });
  const NodeCreateFee = IDL.Record({
    'subaccount' : IDL.Vec(IDL.Nat8),
    'ledger' : IDL.Principal,
    'amount' : IDL.Nat,
  });
  const NodeCreateFeeResp = IDL.Variant({
    'ok' : NodeCreateFee,
    'err' : IDL.Text,
  });
  const GetControllerNodesRequest = IDL.Record({
    'id' : IDL.Principal,
    'start' : IDL.Nat,
    'length' : IDL.Nat,
  });
  const NodeShared = IDL.Record({
    'id' : LocalNodeId,
    'created' : IDL.Nat64,
    'active' : IDL.Bool,
    'modified' : IDL.Nat64,
    'controllers' : IDL.Vec(IDL.Principal),
    'expires' : IDL.Opt(IDL.Nat64),
    'custom' : Shared,
    'extractors' : IDL.Vec(LocalNodeId),
    'destinations' : IDL.Vec(DestinationEndpoint),
    'sources' : IDL.Vec(SourceEndpointResp),
    'refund' : IDL.Vec(Endpoint),
  });
  const GetNode = IDL.Variant({
    'id' : LocalNodeId,
    'subaccount' : IDL.Opt(IDL.Vec(IDL.Nat8)),
  });
  const SupportedLedger = IDL.Variant({
    'ic' : IDL.Principal,
    'remote' : IDL.Record({
      'platform' : IDL.Nat64,
      'ledger' : IDL.Vec(IDL.Nat8),
    }),
  });
  const Version = IDL.Variant({
    'alpha' : IDL.Null,
    'production' : IDL.Null,
    'beta' : IDL.Null,
  });
  const NodeMeta = IDL.Record({
    'id' : IDL.Text,
    'name' : IDL.Text,
    'description' : IDL.Text,
    'supported_ledgers' : IDL.Vec(SupportedLedger),
    'pricing' : IDL.Text,
    'version' : Version,
  });
  const NodeFactoryMetaResp = IDL.Record({
    'name' : IDL.Text,
    'nodes' : IDL.Vec(NodeMeta),
    'governed_by' : IDL.Text,
  });
  const ModifyNodeResp = IDL.Variant({
    'ok' : GetNodeResponse,
    'err' : IDL.Text,
  });
  const _anon_class_16_1 = IDL.Service({
    'add_supported_ledger' : IDL.Func(
        [IDL.Principal, IDL.Variant({ 'icp' : IDL.Null, 'icrc' : IDL.Null })],
        [],
        ['oneway'],
      ),
    'get_ledger_errors' : IDL.Func([], [IDL.Vec(IDL.Vec(IDL.Text))], ['query']),
    'get_ledgers_info' : IDL.Func([], [IDL.Vec(LedgerInfo)], ['query']),
    'get_node_addr' : IDL.Func([NodeId], [IDL.Opt(IDL.Text)], ['query']),
    'icrc55_command' : IDL.Func(
        [IDL.Vec(Command)],
        [IDL.Vec(CommandResponse)],
        [],
      ),
    'icrc55_create_node' : IDL.Func(
        [NodeRequest, CreateRequest],
        [CreateNodeResp],
        [],
      ),
    'icrc55_create_node_get_fee' : IDL.Func(
        [NodeRequest, CreateRequest],
        [NodeCreateFeeResp],
        ['query'],
      ),
    'icrc55_delete_node' : IDL.Func([LocalNodeId], [DeleteNodeResp], []),
    'icrc55_get_controller_nodes' : IDL.Func(
        [GetControllerNodesRequest],
        [IDL.Vec(NodeShared)],
        ['query'],
      ),
    'icrc55_get_defaults' : IDL.Func([IDL.Text], [CreateRequest], ['query']),
    'icrc55_get_node' : IDL.Func([GetNode], [IDL.Opt(NodeShared)], ['query']),
    'icrc55_get_nodefactory_meta' : IDL.Func(
        [],
        [NodeFactoryMetaResp],
        ['query'],
      ),
    'icrc55_modify_node' : IDL.Func(
        [LocalNodeId, IDL.Opt(CommonModRequest), IDL.Opt(ModifyRequest)],
        [ModifyNodeResp],
        [],
      ),
    'start' : IDL.Func([], [], ['oneway']),
  });
  return _anon_class_16_1;
};
export const init = ({ IDL }) => { return []; };
