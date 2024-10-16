import { Principal } from '@dfinity/principal';
import { resolve } from 'node:path';

import { Actor, PocketIc, createIdentity } from '@hadronous/pic';
import { IDL } from '@dfinity/candid';
import {
    _SERVICE as PylonService, idlFactory as PylonIdlFactory, init as PylonInit,
    LocalNodeId as NodeId,
    NodeRequest,
    CreateRequest,
    GetNodeResponse,
    CommandResponse,
    NodeShared,
    PylonMetaResp,
    VirtualBalancesResponse,
    BatchCommandResponse
} from './build/basic.idl.js';

import { ICRCLedgerService, ICRCLedger } from "./icrc_ledger/ledgerCanister";

import { Account, Subaccount} from './icrc_ledger/ledger.idl.js';
//@ts-ignore
import { toState } from "@infu/icblast";
import {AccountIdentifier, SubAccount} from "@dfinity/ledger-icp"
import util from 'util';
const WASM_PYLON_PATH = resolve(__dirname, "./build/basic.wasm");


export async function PylonCan(pic: PocketIc) {

    const fixture = await pic.setupCanister<PylonService>({
        idlFactory: PylonIdlFactory,
        wasm: WASM_PYLON_PATH,
        arg: IDL.encode(PylonInit({ IDL }), []),
    });

    return fixture;
};

export type Ledger = {can:Actor<ICRCLedgerService>, id:Principal, fee:bigint };

export function DF() {

    return {
        pic: undefined as PocketIc,
        // ledger: undefined as Actor<ICRCLedgerService>,
        pylon: undefined as Actor<PylonService>,
        userCanisterId: undefined as Principal,
        // ledgerCanisterId: undefined as Principal,
        ledgers : [] as Ledger[],
        pylonCanisterId: undefined as Principal,
        u: undefined as ReturnType<typeof createNodeUtils>,
        jo : undefined as ReturnType<typeof createIdentity>,

        toState : toState,

        inspect(obj: any) : void {
            console.log(util.inspect(toState(obj), { depth: null, colors: true }));
        },
        async passTime(n: number): Promise<void> {
            if (!this.pic) throw new Error('PocketIc is not initialized');
            for (let i = 0; i < n; i++) {
                await this.pic.advanceTime(3 * 1000);
                await this.pic.tick(6);
            }
        },
        async passTimeMinute(n: number): Promise<void> {
            if (!this.pic) throw new Error('PocketIc is not initialized');
            await this.pic.advanceTime(n * 60 * 1000);
            await this.pic.tick(6);
            // await this.passTime(5)
        },

        async beforeAll(): Promise<void> {
            this.jo = createIdentity('superSecretAlicePassword');

            // Initialize PocketIc
            this.pic = await PocketIc.create(process.env.PIC_URL);

            // Ledger initialization
            let TOTAL_LEDGERS = 3;
            let LEDGER_NAMES = ['tAAA', 'tBBB', 'tCCC', 'tDDD', 'tEEE'];
            for (let i=0 ; i < TOTAL_LEDGERS; i++) {
                const ledgerFixture = await ICRCLedger(this.pic, this.jo.getPrincipal(), undefined, LEDGER_NAMES[i]); // , this.pic.getSnsSubnet()?.id
                
                this.ledgers.push({
                    can: ledgerFixture.actor, 
                    id: ledgerFixture.canisterId, 
                    fee: await ledgerFixture.actor.icrc1_fee()
                });
            }

            // Pylon canister initialization
            const pylonFixture = await PylonCan(this.pic);
            this.pylon = pylonFixture.actor;
            this.pylonCanisterId = pylonFixture.canisterId;
            await this.pic.addCycles(this.pylonCanisterId, 100_000_000_000_000);
            // Setup interactions between ledger and pylon

            for (let lg of this.ledgers) {
                await this.pylon.add_supported_ledger(lg.id, { icrc: null });
                lg.can.setIdentity(this.jo);
            };

            await this.pylon.start();

            // Set the identity for ledger and pylon
            
            this.pylon.setIdentity(this.jo);

            // Initialize node utilities
            this.u = createNodeUtils({
                ledgers: this.ledgers,
                pylon: this.pylon,
                pylonCanisterId: this.pylonCanisterId,
                user: this.jo.getPrincipal()
            });

            
            // Advance time to sync with initialization
            await this.passTime(10);
        },

        async afterAll(): Promise<void> {
            if (!this.pic) throw new Error('PocketIc is not initialized');
            await this.pic.tearDown();
        }
    };
}



export function createNodeUtils({
    ledgers,
    pylon,
    pylonCanisterId,
    user
}: {
    ledgers: Ledger[],
    pylon: Actor<PylonService>,
    pylonCanisterId: Principal,
    user: Principal
}) {
    return {
        async listNodes(): Promise<NodeShared[]> {
            return await pylon.icrc55_get_controller_nodes({ id: {owner:user, subaccount:[]}, start:0n, length: 500n });
        },
        mainAccount(): Account {
            return { owner: user, subaccount: [] };
        },
        userSubaccount(id: number): Account {
            return { owner: user, subaccount: [this.subaccountFromId(id)] };
        },
        userBillingAccount() : Account {
            let aid = AccountIdentifier.fromPrincipal({principal: user});
            let sa = aid.toUint8Array();
            return { owner: pylonCanisterId, subaccount: [sa] };
        },
        async getPylonMeta() : Promise<PylonMetaResp> {
            return pylon.icrc55_get_pylon_meta();
        },
        virtual(account: Account): Account {
            let asu = account?.subaccount[0] ? SubAccount.fromBytes(new Uint8Array(account.subaccount[0])) : undefined;
            if (asu instanceof Error) {
                throw asu;
            }
            let aid = AccountIdentifier.fromPrincipal({principal: account.owner, subAccount: asu as SubAccount});
            let sa = aid.toUint8Array();
            return { owner: pylonCanisterId, subaccount: [sa]};
        },
        async sendToAccount(account: Account, amount: bigint, from_subaccount:Subaccount | undefined = undefined, from_ledger:number = 0): Promise<void> {
            let ledger = ledgers[from_ledger].can;
            ledger.setPrincipal(user);
            let txresp = await ledger.icrc1_transfer({
                from_subaccount: from_subaccount?[from_subaccount]:[],
                to: account,
                amount: amount,
                fee: [],
                memo: [],
                created_at_time: [],
            });

            if (!("Ok" in txresp)) {
                throw new Error("Transaction failed");
            }
        },

        async sendToNode(nodeId: NodeId, port: number, amount: bigint, from_ledger:number = 0): Promise<void> {
            let ledger = ledgers[from_ledger].can;

            ledger.setPrincipal(user);
            let node = await this.getNode(nodeId);
            if (node === undefined) return;

            let txresp = await ledger.icrc1_transfer({
                from_subaccount: [],
                //@ts-ignore
                to: node.sources[port].endpoint.ic.account,
                amount: amount,
                fee: [],
                memo: [],
                created_at_time: [],
            });

            if (!("Ok" in txresp)) {
                throw new Error("Transaction failed");
            }
        },

        async getLedgerBalance(account: Account, from_ledger:number = 0): Promise<bigint> {
            let ledger = ledgers[from_ledger].can;
            return await ledger.icrc1_balance_of(account);
        },

        async getSourceBalance(nodeId: NodeId, port: number): Promise<bigint> {
            let node = await this.getNode(nodeId);
            if (node === undefined) return 0n;

            return node.sources[port].balance;
        },

        async getDestinationBalance(nodeId: NodeId, port: number): Promise<bigint> {
            let node = await this.getNode(nodeId);
            if (node === undefined) return 0n;
            //@ts-ignore
            return await ledger.icrc1_balance_of(node.destinations[port].ic.account[0]);
        },
        getRefundAccount() : Account {
            return {owner: user, subaccount: [this.subaccountFromId(1000)]};
        },
        getAffiliateAccount() : Account {
            return {owner: user, subaccount: [this.subaccountFromId(100000)]};
        },
        async virtualTransfer(from: Account, to:Account, amount: bigint, from_ledger:number = 0): Promise<BatchCommandResponse> {
            let ledgerCanisterId = ledgers[from_ledger].id
            return await pylon.icrc55_command({
                expire_at : [],
                request_id : [],
                controller: from,
                signature : [],
                commands :[{
                virtual_transfer: {
                    account: from,
                    to: { ic: { ledger: ledgerCanisterId, account: to } },
                    amount
                }
            }]});
            },
        async virtualBalances(acc: Account) : Promise<VirtualBalancesResponse> {
            return await pylon.icrc55_virtual_balances(acc);
        },
        async createNode(creq: CreateRequest, ledgers_idx:number[] = [0]): Promise<GetNodeResponse> {
            
            let req: NodeRequest = {
                controllers: [{owner:user, subaccount:[]}],
                destinations: [],
                refund: this.getRefundAccount(),
                ledgers: ledgers_idx.map(idx => ({ic : ledgers[idx].id})),
                sources: [],
                extractors: [],
                affiliate: [this.getAffiliateAccount()]
            };

            let resp = await pylon.icrc55_command({
                expire_at : [],
                request_id : [],
                controller: {owner:user, subaccount:[]},
                signature : [],
                commands:[{create_node:[req, creq]}]});

            //@ts-ignore
            if (resp.ok.commands[0].create_node.err) {
                //@ts-ignore
                throw new Error(resp.ok.commands[0].create_node.err);
            };
            //@ts-ignore
            return resp.ok.commands[0].create_node.ok;
        },

        async getNode(nodeId: NodeId): Promise<GetNodeResponse> {
            let resp = await pylon.icrc55_get_nodes([{ id: nodeId }]);
            if (resp[0][0] === undefined) throw new Error("Node not found");
            return resp[0][0];
        },
        async topUpNode(nodeId: NodeId, amount: bigint): Promise<BatchCommandResponse> {
            return await pylon.icrc55_command({
                expire_at : [],
                request_id : [],
                controller : {owner:user, subaccount:[]},
                signature : [],
                commands:[{top_up_node: {id:nodeId, amount}}]});
        },
        async setControllers(nodeId: NodeId, controllers: Account[]): Promise<BatchCommandResponse> {
            return await pylon.icrc55_command({
                expire_at : [],
                request_id : [],
                controller : {owner:user, subaccount:[]},
                signature : [],
                commands:[{
                modify_node: [nodeId, [{ 
                    destinations : [],
                    refund: [],
                    sources: [],
                    extractors: [],
                    controllers : [controllers],
                    active :[]
                }], []]}]});
        },
        async setActive(nodeId: NodeId, active: boolean): Promise<void> {
            await pylon.icrc55_command({
                expire_at : [],
                request_id : [],
                controller : {owner:user, subaccount:[]},
                signature : [],
                commands:[{
                modify_node: [nodeId, [{ 
                    destinations : [],
                    refund: [],
                    sources: [],
                    extractors: [],
                    controllers : [],
                    active :[active]
                }], []]
            }]});
        },
        async deleteNode(nodeId: NodeId): Promise<BatchCommandResponse> {
            return await pylon.icrc55_command({
                expire_at : [],
                request_id : [],
                controller : {owner:user, subaccount:[]},
                signature : [],
                commands:[{delete_node: nodeId}]
            });
        },
        async sourceTransfer(nodeId : NodeId, source_port: number, amount: bigint, to: Account, to_ledger: number = 0): Promise<BatchCommandResponse> {
            let ledgerCanisterId = ledgers[to_ledger].id;
            return await pylon.icrc55_command({
                expire_at : [],
                request_id : [],
                controller : {owner:user, subaccount:[]},
                signature : [],
                commands:[{
                source_transfer: {id:nodeId, source_port, amount, to:{ic:{ ledger:ledgerCanisterId, account:to}}}
            }]});
        },
        async setDestination(nodeId: NodeId, port: number, account: Account, ledger_idx : number = 0): Promise<BatchCommandResponse> {
            let ledgerCanisterId = ledgers[ledger_idx].id;
            let node = await this.getNode(nodeId);
            let destinations = node.destinations.map(x => x.endpoint);
            destinations[port] = { ic: { ledger: ledgerCanisterId, account: [account] } };
            return await pylon.icrc55_command({
                expire_at : [],
                request_id : [],
                controller : {owner:user, subaccount:[]},
                signature : [],
                commands:[{
                modify_node: [nodeId, [{ 
                    destinations : [destinations],
                    refund: [],
                    sources: [],
                    extractors: [],
                    controllers : [],
                    active :[]
                }], []]
            }]});
        },
        async setSource(nodeId: NodeId, port: number, account: Account, ledger_idx : number = 0): Promise<BatchCommandResponse> {
            let ledgerCanisterId = ledgers[ledger_idx].id;
            let node = await this.getNode(nodeId);
            let sources = node.sources.map(x=> x.endpoint);
            sources[port] = { ic: { ledger: ledgerCanisterId, account: account } };
            return await pylon.icrc55_command({
                expire_at : [],
                request_id : [],
                controller : {owner:user, subaccount:[]},
                signature : [],
                commands:[{
                modify_node: [nodeId, [{ 
                    destinations : [],
                    refund: [],
                    sources: [sources],
                    extractors: [],
                    controllers : [],
                    active :[]
                }], []]
            }]});
        },

        async addExtractor(from: NodeId, to: NodeId): Promise<BatchCommandResponse> {
            let node = await this.getNode(from);
            let extractors = [...node.extractors, to];
            return await pylon.icrc55_command({
                expire_at : [],
                request_id : [],
                controller : {owner:user, subaccount:[]},
                signature : [],
                commands:[{
                modify_node: [from, [{ 
                    destinations : [],
                    refund: [],
                    sources: [],
                    extractors: [extractors],
                    controllers : [],
                    active :[]
                }], []]
            }]});
        },


        async connectNodes(from: NodeId, fromPort: number, to: NodeId, toPort: number): Promise<CommandResponse[]> {
            let to_node = await this.getNode(to);

            //@ts-ignore
            return await this.setDestination(from, fromPort, to_node.sources[toPort].endpoint.ic.account);
        },


        async connectNodeSource(extractor: NodeId, extractorPort: number, sourceFrom: NodeId, sourcePort: number): Promise<CommandResponse[]> {
            let from_node = await this.getNode(sourceFrom);

            //@ts-ignore
            return await this.setSource(extractor, extractorPort, from_node.sources[sourcePort].endpoint.ic.account);

        },

        subaccountFromId(id: number): Subaccount {
            // create 32 byte uint8array and put the id in the first 4 bytes
            let subaccount = new Uint8Array(32);
            let view = new DataView(subaccount.buffer);
            view.setUint32(0, id, true);
            return subaccount;
        }
    };
}
