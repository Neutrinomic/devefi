import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface Account {
  'owner' : Principal,
  'subaccount' : [] | [Uint8Array | number[]],
}
export interface ChangeActiveNodeRequest {
  'id' : LocalNodeId,
  'active' : boolean,
}
export type ChangeActiveNodeResponse = { 'ok' : null } |
  { 'err' : string };
export interface ChangeDestinationRequest {
  'id' : LocalNodeId,
  'to' : DestinationEndpoint,
  'port' : bigint,
}
export type ChangeDestinationResp = { 'ok' : null } |
  { 'err' : string };
export type Command = { 'modify_node' : ModifyNodeRequest } |
  { 'withdraw_node' : WithdrawNodeRequest } |
  { 'change_destination' : ChangeDestinationRequest } |
  { 'create_node' : CreateNodeRequest } |
  { 'change_active_node' : ChangeActiveNodeRequest } |
  { 'delete_node' : LocalNodeId };
export type CommandResponse = { 'modify_node' : ModifyNodeResponse } |
  { 'withdraw_node' : WithdrawNodeResponse } |
  { 'change_destination' : ChangeDestinationResp } |
  { 'create_node' : CreateNodeResponse } |
  { 'change_active_node' : ChangeActiveNodeResponse } |
  { 'delete_node' : DeleteNodeResp };
export interface CommonModRequest {
  'controllers' : Array<Principal>,
  'extractors' : Uint32Array | number[],
  'destinations' : Array<DestinationEndpoint>,
  'sources' : Array<Endpoint>,
  'refund' : Array<Endpoint>,
}
export type CreateNodeRequest = [NodeRequest, CreateRequest];
export type CreateNodeResp = { 'ok' : GetNodeResponse } |
  { 'err' : string };
export type CreateNodeResponse = { 'ok' : GetNodeResponse } |
  { 'err' : string };
export type CreateRequest = { 'lend' : CreateRequest__4 } |
  { 'mint' : CreateRequest__5 } |
  { 'borrow' : CreateRequest__1 } |
  { 'split' : CreateRequest__6 } |
  { 'throttle' : CreateRequest__7 } |
  { 'exchange' : CreateRequest__3 } |
  { 'escrow' : CreateRequest__2 };
export interface CreateRequest__1 {
  'init' : { 'ledger_collateral' : Principal, 'ledger_borrow' : Principal },
  'variables' : { 'interest' : bigint },
}
export interface CreateRequest__2 {
  'init' : { 'ledger' : Principal },
  'variables' : {},
}
export interface CreateRequest__3 {
  'init' : { 'ledger_to' : Principal, 'ledger_from' : Principal },
  'variables' : { 'max_per_sec' : bigint },
}
export interface CreateRequest__4 {
  'init' : { 'ledger_collateral' : Principal, 'ledger_lend' : Principal },
  'variables' : { 'interest' : bigint },
}
export interface CreateRequest__5 {
  'init' : { 'ledger_mint' : Principal, 'ledger_for' : Principal },
  'variables' : {},
}
export interface CreateRequest__6 {
  'init' : { 'ledger' : Principal },
  'variables' : { 'split' : Array<bigint> },
}
export interface CreateRequest__7 {
  'init' : { 'ledger' : Principal },
  'variables' : { 'interval_sec' : NumVariant, 'max_amount' : NumVariant },
}
export type DeleteNodeResp = { 'ok' : null } |
  { 'err' : string };
export interface DestICEndpoint {
  'name' : string,
  'ledger' : Principal,
  'account' : [] | [Account],
}
export interface DestRemoteEndpoint {
  'name' : string,
  'platform' : bigint,
  'ledger' : Uint8Array | number[],
  'account' : [] | [Uint8Array | number[]],
}
export type DestinationEndpoint = { 'ic' : DestICEndpoint } |
  { 'remote' : DestRemoteEndpoint };
export type Endpoint = { 'ic' : ICEndpoint } |
  { 'remote' : RemoteEndpoint };
export interface GetControllerNodesRequest {
  'id' : Principal,
  'start' : bigint,
  'length' : bigint,
}
export type GetNode = { 'id' : LocalNodeId } |
  { 'subaccount' : [] | [Uint8Array | number[]] };
export interface GetNodeResponse {
  'id' : LocalNodeId,
  'created' : bigint,
  'active' : boolean,
  'modified' : bigint,
  'controllers' : Array<Principal>,
  'expires' : [] | [bigint],
  'custom' : Shared,
  'extractors' : Uint32Array | number[],
  'destinations' : Array<DestinationEndpoint>,
  'sources' : Array<SourceEndpointResp>,
  'refund' : Array<Endpoint>,
}
export interface ICEndpoint {
  'name' : string,
  'ledger' : Principal,
  'account' : Account,
}
export interface Info {
  'pending' : bigint,
  'last_indexed_tx' : bigint,
  'errors' : bigint,
  'lastTxTime' : bigint,
  'accounts' : bigint,
  'actor_principal' : [] | [Principal],
  'reader_instructions_cost' : bigint,
  'sender_instructions_cost' : bigint,
}
export interface Info__1 {
  'pending' : bigint,
  'last_indexed_tx' : bigint,
  'errors' : bigint,
  'lastTxTime' : bigint,
  'accounts' : bigint,
  'actor_principal' : [] | [Principal],
  'reader_instructions_cost' : bigint,
  'sender_instructions_cost' : bigint,
}
export interface LedgerInfo {
  'id' : Principal,
  'info' : { 'icp' : Info } |
    { 'icrc' : Info__1 },
}
export type LocalNodeId = number;
export type ModifyNodeRequest = [
  LocalNodeId,
  [] | [CommonModRequest],
  [] | [ModifyRequest],
];
export type ModifyNodeResp = { 'ok' : GetNodeResponse } |
  { 'err' : string };
export type ModifyNodeResponse = { 'ok' : GetNodeResponse } |
  { 'err' : string };
export type ModifyRequest = { 'lend' : ModifyRequest__4 } |
  { 'mint' : ModifyRequest__5 } |
  { 'borrow' : ModifyRequest__1 } |
  { 'split' : ModifyRequest__6 } |
  { 'throttle' : ModifyRequest__7 } |
  { 'exchange' : ModifyRequest__3 } |
  { 'escrow' : ModifyRequest__2 };
export interface ModifyRequest__1 { 'interest' : bigint }
export type ModifyRequest__2 = {};
export interface ModifyRequest__3 { 'max_per_sec' : bigint }
export interface ModifyRequest__4 { 'interest' : bigint }
export type ModifyRequest__5 = {};
export interface ModifyRequest__6 { 'split' : Array<bigint> }
export interface ModifyRequest__7 {
  'interval_sec' : NumVariant,
  'max_amount' : NumVariant,
}
export interface NodeCreateFee {
  'subaccount' : Uint8Array | number[],
  'ledger' : Principal,
  'amount' : bigint,
}
export type NodeCreateFeeResp = { 'ok' : NodeCreateFee } |
  { 'err' : string };
export interface NodeFactoryMetaResp {
  'name' : string,
  'nodes' : Array<NodeMeta>,
  'governed_by' : string,
}
export type NodeId = number;
export interface NodeMeta {
  'id' : string,
  'name' : string,
  'description' : string,
  'supported_ledgers' : Array<SupportedLedger>,
  'pricing' : string,
  'version' : Version,
}
export interface NodeRequest {
  'controllers' : Array<Principal>,
  'extractors' : Uint32Array | number[],
  'destinations' : Array<DestinationEndpoint>,
  'sources' : Array<Endpoint>,
  'refund' : Array<Endpoint>,
}
export interface NodeShared {
  'id' : LocalNodeId,
  'created' : bigint,
  'active' : boolean,
  'modified' : bigint,
  'controllers' : Array<Principal>,
  'expires' : [] | [bigint],
  'custom' : Shared,
  'extractors' : Uint32Array | number[],
  'destinations' : Array<DestinationEndpoint>,
  'sources' : Array<SourceEndpointResp>,
  'refund' : Array<Endpoint>,
}
export type NumVariant = { 'rnd' : { 'max' : bigint, 'min' : bigint } } |
  { 'fixed' : bigint };
export interface RemoteEndpoint {
  'name' : string,
  'platform' : bigint,
  'ledger' : Uint8Array | number[],
  'account' : Uint8Array | number[],
}
export type Shared = { 'lend' : Shared__4 } |
  { 'mint' : Shared__5 } |
  { 'borrow' : Shared__1 } |
  { 'split' : Shared__6 } |
  { 'throttle' : Shared__7 } |
  { 'exchange' : Shared__3 } |
  { 'escrow' : Shared__2 };
export interface Shared__1 {
  'internals' : {},
  'init' : { 'ledger_collateral' : Principal, 'ledger_borrow' : Principal },
  'variables' : { 'interest' : bigint },
}
export interface Shared__2 {
  'internals' : {},
  'init' : { 'ledger' : Principal },
  'variables' : {},
}
export interface Shared__3 {
  'internals' : {},
  'init' : { 'ledger_to' : Principal, 'ledger_from' : Principal },
  'variables' : { 'max_per_sec' : bigint },
}
export interface Shared__4 {
  'internals' : {},
  'init' : { 'ledger_collateral' : Principal, 'ledger_lend' : Principal },
  'variables' : { 'interest' : bigint },
}
export interface Shared__5 {
  'internals' : {},
  'init' : { 'ledger_mint' : Principal, 'ledger_for' : Principal },
  'variables' : {},
}
export interface Shared__6 {
  'internals' : {},
  'init' : { 'ledger' : Principal },
  'variables' : { 'split' : Array<bigint> },
}
export interface Shared__7 {
  'internals' : { 'wait_until_ts' : bigint },
  'init' : { 'ledger' : Principal },
  'variables' : { 'interval_sec' : NumVariant, 'max_amount' : NumVariant },
}
export interface SourceEndpointResp {
  'balance' : bigint,
  'endpoint' : Endpoint,
}
export type SupportedLedger = { 'ic' : Principal } |
  { 'remote' : { 'platform' : bigint, 'ledger' : Uint8Array | number[] } };
export type Version = { 'alpha' : null } |
  { 'production' : null } |
  { 'beta' : null };
export interface WithdrawNodeRequest {
  'id' : LocalNodeId,
  'to' : Endpoint,
  'source_port' : bigint,
}
export type WithdrawNodeResponse = { 'ok' : null } |
  { 'err' : string };
export interface _anon_class_16_1 {
  'add_supported_ledger' : ActorMethod<
    [Principal, { 'icp' : null } | { 'icrc' : null }],
    undefined
  >,
  'get_ledger_errors' : ActorMethod<[], Array<Array<string>>>,
  'get_ledgers_info' : ActorMethod<[], Array<LedgerInfo>>,
  'get_node_addr' : ActorMethod<[NodeId], [] | [string]>,
  'icrc55_command' : ActorMethod<[Array<Command>], Array<CommandResponse>>,
  'icrc55_create_node' : ActorMethod<
    [NodeRequest, CreateRequest],
    CreateNodeResp
  >,
  'icrc55_create_node_get_fee' : ActorMethod<
    [NodeRequest, CreateRequest],
    NodeCreateFeeResp
  >,
  'icrc55_delete_node' : ActorMethod<[LocalNodeId], DeleteNodeResp>,
  'icrc55_get_controller_nodes' : ActorMethod<
    [GetControllerNodesRequest],
    Array<NodeShared>
  >,
  'icrc55_get_defaults' : ActorMethod<[string], CreateRequest>,
  'icrc55_get_node' : ActorMethod<[GetNode], [] | [NodeShared]>,
  'icrc55_get_nodefactory_meta' : ActorMethod<[], NodeFactoryMetaResp>,
  'icrc55_modify_node' : ActorMethod<
    [LocalNodeId, [] | [CommonModRequest], [] | [ModifyRequest]],
    ModifyNodeResp
  >,
  'start' : ActorMethod<[], undefined>,
}
export interface _SERVICE extends _anon_class_16_1 {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: ({ IDL }: { IDL: IDL }) => IDL.Type[];
