import { Principal } from '@dfinity/principal';
import { resolve } from 'node:path';

import { Actor, PocketIc, createIdentity } from '@hadronous/pic';
import { IDL } from '@dfinity/candid';
import {
    _SERVICE as PylonService, idlFactory as PylonIdlFactory, init as PylonInit,
    NodeId,
    NodeRequest,
    CreateRequest,
    GetNodeResponse
} from './build/basic.idl.js';

import { ICRCLedgerService, ICRCLedger } from "./icrc_ledger/ledgerCanister";

import { Account } from './icrc_ledger/ledger.idl.js';
//@ts-ignore
import { toState } from "@infu/icblast";

const WASM_PYLON_PATH = resolve(__dirname, "./build/basic.wasm");


export async function PylonCan(pic: PocketIc) {

    const fixture = await pic.setupCanister<PylonService>({
        idlFactory: PylonIdlFactory,
        wasm: WASM_PYLON_PATH,
        arg: IDL.encode(PylonInit({ IDL }), []),
    });

    return fixture;
};

export function DF() {

    return {
        pic: undefined as PocketIc,
        ledger: undefined as Actor<ICRCLedgerService>,
        pylon: undefined as Actor<PylonService>,
        userCanisterId: undefined as Principal,
        ledgerCanisterId: undefined as Principal,
        pylonCanisterId: undefined as Principal,
        u: undefined as ReturnType<typeof createNodeUtils>,
        jo : undefined as ReturnType<typeof createIdentity>,

        async passTime(n: number): Promise<void> {
            if (!this.pic) throw new Error('PocketIc is not initialized');
            for (let i = 0; i < n; i++) {
                await this.pic.advanceTime(3 * 1000);
                await this.pic.tick(2);
            }
        },

        async beforeAll(): Promise<void> {
            this.jo = createIdentity('superSecretAlicePassword');

            // Initialize PocketIc
            this.pic = await PocketIc.create(process.env.PIC_URL);

            // Ledger initialization
            const ledgerFixture = await ICRCLedger(this.pic, this.jo.getPrincipal(), this.pic.getSnsSubnet()?.id);
            this.ledger = ledgerFixture.actor;
            this.ledgerCanisterId = ledgerFixture.canisterId;

            // Pylon canister initialization
            const pylonFixture = await PylonCan(this.pic);
            this.pylon = pylonFixture.actor;
            this.pylonCanisterId = pylonFixture.canisterId;

            // Setup interactions between ledger and pylon
            this.pylon.add_supported_ledger(this.ledgerCanisterId, { icrc: null });
            this.pylon.start();

            // Set the identity for ledger and pylon
            this.ledger.setIdentity(this.jo);
            this.pylon.setIdentity(this.jo);

            // Initialize node utilities
            this.u = createNodeUtils({
                ledger: this.ledger,
                pylon: this.pylon,
                ledgerCanisterId: this.ledgerCanisterId,
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
    ledger,
    pylon,
    ledgerCanisterId,
    user
}: {
    ledger: Actor<ICRCLedgerService>,
    pylon: Actor<PylonService>,
    ledgerCanisterId: Principal,
    user: Principal
}) {
    return {
        async sendToNode(nodeId: NodeId, port: number, amount: bigint): Promise<void> {
            ledger.setPrincipal(user);
            let resp = await pylon.icrc55_get_node({ id: nodeId });
            let node = resp[0];
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

        async getLedgerBalance(account: Account): Promise<bigint> {
            return await ledger.icrc1_balance_of(account);
        },

        async getSourceBalance(nodeId: NodeId, port: number): Promise<bigint> {
            let resp = await pylon.icrc55_get_node({ id: nodeId });
            let node = resp[0];
            if (node === undefined) return 0n;

            return node.sources[port].balance;
        },

        async getDestinationBalance(nodeId: NodeId, port: number): Promise<bigint> {
            let resp = await pylon.icrc55_get_node({ id: nodeId });
            let node = resp[0];
            if (node === undefined) return 0n;
            //@ts-ignore
            return await ledger.icrc1_balance_of(node.destinations[port].ic.account[0]);
        },

        async createNode(creq: CreateRequest): Promise<NodeId> {
            let req: NodeRequest = {
                controllers: [user],
                destinations: [],
                refund: [],
                sources: [],
                extractors: [],
            };

            let resp = await pylon.icrc55_create_node(req, creq);
            return toState(resp).ok.id;
        },

        async getNode(nodeId: NodeId): Promise<GetNodeResponse> {
            let resp = await pylon.icrc55_get_node({ id: nodeId });
            if (resp[0] === undefined) throw new Error("Node not found");
            return resp[0];
        },

        async setDestination(nodeId: NodeId, port: bigint, account: Account): Promise<void> {
            await pylon.icrc55_command([{
                change_destination: {
                    id: nodeId,
                    port: port,
                    to: { ic: { name: '', ledger: ledgerCanisterId, account: [account] } }
                }
            }]);
        },

        async connectNodes(from: NodeId, fromPort: number, to: NodeId, toPort: number): Promise<void> {
            let to_node = await this.getNode(to);

            //@ts-ignore
            this.setDestination(from, fromPort, to_node.sources[toPort].endpoint.ic.account);
        },

        subaccountFromId(id: number): Uint8Array {
            // create 32 byte uint8array and put the id in the first 4 bytes
            let subaccount = new Uint8Array(32);
            let view = new DataView(subaccount.buffer);
            view.setUint32(0, id, true);
            return subaccount;
        }
    };
}