import { Principal } from '@dfinity/principal';
import { resolve } from 'node:path';
import { Actor, PocketIc, createIdentity } from '@hadronous/pic';
import { IDL } from '@dfinity/candid';
// import { _SERVICE as TestService, idlFactory as TestIdlFactory, init as TestInit} from './build/basic.idl.js';
import { _SERVICE as NodeService, idlFactory as NodeIdlFactory, init as NodeInit, 
         NodeId,        
         NodeRequest,
         CreateRequest,
        } from './build/basic.idl.js';

//import {ICRCLedgerService, ICRCLedger} from "./icrc_ledger/ledgerCanister";
import {ICRCLedgerService, ICRCLedger} from "./icrc_ledger/ledgerCanister";
//@ts-ignore
import {toState} from "@infu/icblast";
// Jest can't handle multi threaded BigInts o.O That's why we use toState

const WASM_NODE_PATH = resolve(__dirname, "./build/basic.wasm");

export async function NodeCan(pic:PocketIc) {
    
  const fixture = await pic.setupCanister<NodeService>({
      idlFactory: NodeIdlFactory,
      wasm: WASM_NODE_PATH,
      arg: IDL.encode(NodeInit({ IDL }), []),
  });

  return fixture;
};

describe('Basic', () => {
    let pic: PocketIc;
    let ledger: Actor<ICRCLedgerService>;
    let node: Actor<NodeService>;
    let userCanisterId: Principal;
    let ledgerCanisterId: Principal;
    let nodeCanisterId: Principal;

    const jo = createIdentity('superSecretAlicePassword');
    const bob = createIdentity('superSecretBobPassword');
    const ali = createIdentity('superSecretAliPassword');
    const ali2 = createIdentity('superSecretAli2Password');

  
    beforeAll(async () => {

      pic = await PocketIc.create(process.env.PIC_URL);

      // Ledger
      const ledgerfixture = await ICRCLedger(pic, jo.getPrincipal(), pic.getSnsSubnet()?.id);
      ledger = ledgerfixture.actor;
      ledgerCanisterId = ledgerfixture.canisterId;
      

      // Node canister
      const nodefixture = await NodeCan(pic);
      node = nodefixture.actor;
      nodeCanisterId = nodefixture.canisterId;

      ledger.setIdentity(jo);
      node.add_supported_ledger(ledgerCanisterId, {icrc:null});
      node.start();

      await passTime(10);
    });
  
    afterAll(async () => {
      await pic.tearDown();  //ILDE: this means "it removes the replica"
    });   


    it(`Check (minter) balance`  , async () => {
      const result = await ledger.icrc1_balance_of({owner: jo.getPrincipal(), subaccount: []});
      // console.log("jo balance:",result)
      const result2 = await ledger.icrc1_balance_of({owner: bob.getPrincipal(), subaccount: []});
      // console.log("bob balance:",result2)
      expect(toState(result)).toBe("100000000000")
      expect(toState(result2)).toBe("0")
    });

  
    it(`configure node`, async () => {

      let gna_args: NodeId = 0;
      let ret_gna = await node.get_node_addr(gna_args);


      let req : NodeRequest = {
        'controllers' : [jo.getPrincipal()],
        'destinations' : [{'ic' : {        
          'name' : 'bob',
          'ledger' : ledgerCanisterId,
          'account' : [{'owner': bob.getPrincipal(), subaccount:[]}],        
          }
        }],
        'refund' : [{'ic' : {
          'name' : 'jo',
          'ledger' :  ledgerCanisterId,
          'account' : {'owner': jo.getPrincipal(), subaccount:[]}
          }
        }],
        'sources' : [],
        'extractors' : [],
      };

      let creq : CreateRequest = {
        'throttle' : {
          'init' : {'ledger' : ledgerCanisterId},
          'variables' : {
              'interval_sec' : {'fixed' : 2n}, 
              'max_amount' : {'fixed' : 10000000n}
            },
        },
      };

      await passTime(3);


      ledger.setIdentity(jo);
      
      await passTime(30);

      let cnr_ret = await node.icrc55_create_node(req, creq);

      //console.log("cnr_ret: ", cnr_ret);
      if ('ok' in cnr_ret) {
        const aux = cnr_ret.ok;
        // console.log("sources:",aux.sources[0]);
        if ('ic' in aux.sources[0].endpoint) {
          const aux2 = aux.sources[0].endpoint.ic;
          let source_principal = aux2.account.owner;
          let source_principal_sub = aux2.account.subaccount;
         
          const res_bob = await ledger.icrc1_balance_of({owner: bob.getPrincipal(), subaccount: []});
                
          expect(res_bob).toBe(0n)
        
          // load some tokens in the source address:
          const res_tx = await ledger.icrc1_transfer({
            to: {owner: source_principal, subaccount:source_principal_sub},
            from_subaccount: [],
            amount: 3_0000_0000n,
            fee: [],
            memo: [],
            created_at_time: [],
          });


          await passTime(10);

          const res_bobaa = await ledger.icrc1_balance_of({owner: bob.getPrincipal(), subaccount: []});

          expect(res_bobaa>0).toBe(true)

        }
      }

    },600*1000);


    it(`split test`, async () => {   

      let req : NodeRequest = {
        'controllers' : [jo.getPrincipal()],
        'destinations' : [
          {'ic' : {        
            'name' : 'ali',
            'ledger' : ledgerCanisterId,
            'account' : [{'owner': ali.getPrincipal(), subaccount:[]}],        
          }},
          {'ic' : {        
          'name' : 'ali2',
          'ledger' : ledgerCanisterId,
          'account' : [{'owner': ali2.getPrincipal(), subaccount:[]}],        
          }},
        ],
        'refund' : [{'ic' : {
          'name' : 'jo',
          'ledger' :  ledgerCanisterId,
          'account' : {'owner': jo.getPrincipal(), subaccount:[]}
          }
        }],
        'sources' : [],
        'extractors' : [],
      };

      let creq_split : CreateRequest = {
        'split' : {
          'init' : {'ledger' : ledgerCanisterId},
          'variables' : {
              'split' : [50n,50n], // [50,50] is the default in "split.mo" 
            },
        },
      };
      


      await passTime(3);
      
      ledger.setIdentity(jo);
      
      await passTime(30);

      let cnr_ret = await node.icrc55_create_node(req, creq_split);
      // console.log("second test: cnr_ret:", cnr_ret);

      if ('ok' in cnr_ret) {
        const aux = cnr_ret.ok;
        // console.log("sources[0].endpoint:", aux.sources[0].endpoint);
 
        if ('ic' in aux.sources[0].endpoint) {
          const aux2 = aux.sources[0].endpoint.ic;
          // console.log("aux2:",aux2);
          let source_principal = aux2.account.owner;
          let source_principal_sub = aux2.account.subaccount;

          const resa = await ledger.icrc1_balance_of({owner: source_principal, subaccount: source_principal_sub});
          // console.log("before source:",resa);

          const res_ali = await ledger.icrc1_balance_of({owner: ali.getPrincipal(), subaccount: []});
          // console.log("balance ali:",res_ali);

          const res_bob = await ledger.icrc1_balance_of({owner: ali2.getPrincipal(), subaccount: []});
          // console.log("balance ali2:",res_bob);
                
          expect(resa).toBe(0n)
          expect(res_ali).toBe(0n)
        
          //load some tokens in the source address:
          const res_tx = await ledger.icrc1_transfer({
            to: {owner: source_principal, subaccount:source_principal_sub},
            from_subaccount: [],
            amount: 3_0000_0000n,
            fee: [],
            memo: [],
            created_at_time: [],
          });

          await passTime(1);

          const resaaa = await ledger.icrc1_balance_of({owner: source_principal, subaccount: source_principal_sub});
          // console.log("after source:",resaaa);

          // node.start();

          await passTime(10);

          // console.log("res_tx:",res_tx);

          const resaa = await ledger.icrc1_balance_of({owner: source_principal, subaccount: source_principal_sub});
          // console.log("after source:",resaa);
          
          const res_alia = await ledger.icrc1_balance_of({owner: ali.getPrincipal(), subaccount: []});
          // console.log("ali balance:",res_alia)

          const res_bobaa = await ledger.icrc1_balance_of({owner: ali2.getPrincipal(), subaccount: []});
          // console.log("ali2 balance:",res_bobaa);

          expect(res_alia>0).toBe(true)
          expect(res_bobaa>0).toBe(true)

        }
      }

    });

    it(`throttle->split test`, async () => {     
      
      let req_split : NodeRequest = {
        'controllers' : [jo.getPrincipal()],
        'destinations' : [
          {'ic' : {        
            'name' : 'ali',
            'ledger' : ledgerCanisterId,
            'account' : [{'owner': ali.getPrincipal(), subaccount:[]}],        
          }},
          {'ic' : {        
          'name' : 'ali2',
          'ledger' : ledgerCanisterId,
          'account' : [{'owner': ali2.getPrincipal(), subaccount:[]}],        
          }},
        ],
        'refund' : [{'ic' : {
          'name' : 'jo',
          'ledger' :  ledgerCanisterId,
          'account' : {'owner': jo.getPrincipal(), subaccount:[]}
          }
        }],
        'sources' : [],
        'extractors' : [],
      };

      let creq_split : CreateRequest = {
        'split' : {
          'init' : {'ledger' : ledgerCanisterId},
          'variables' : {
              'split' : [50n,50n], // [50,50] is the default in "split.mo" 
            },
        },
      };

      //await passTime(30);

      //let cnr_trt = await node.icrc55_create_node(req_throttle, creq_throttle);
      let cnr_spt = await node.icrc55_create_node(req_split, creq_split);

      if ('ok' in cnr_spt) {//<--- IM here
        // I need to source of split = bob (destination of throttle)
        // I need to transfer token to source of throtle
        const aux_spt = cnr_spt.ok;
        //console.log("souaux_spt.sources[0]);
        if ('ic' in aux_spt.sources[0].endpoint) {
          const aux2 = aux_spt.sources[0].endpoint.ic;
          const source_principal = aux2.account.owner;
          const source_principal_sub = aux2.account.subaccount

          let req_throttle : NodeRequest = {
            'controllers' : [jo.getPrincipal()],
            'destinations' : [{'ic' : {        
              'name' : 'bob',
              'ledger' : ledgerCanisterId,
              'account' : [{'owner': source_principal, subaccount:source_principal_sub}],        
              }
            }],
            'refund' : [{'ic' : {
              'name' : 'jo',
              'ledger' :  ledgerCanisterId,
              'account' : {'owner': jo.getPrincipal(), subaccount:[]}
              }
            }],
            'sources' : [],
            'extractors' : [],
          };
  
          let creq_throttle : CreateRequest = {
            'throttle' : {
              'init' : {'ledger' : ledgerCanisterId},
              'variables' : {
                  'interval_sec' : {'fixed' : 2n}, 
                  'max_amount' : {'fixed' : 10000000n}
                },
            },
          };

          let cnr_trt = await node.icrc55_create_node(req_throttle, creq_throttle);
        
          if ('ok' in cnr_trt) {
            const aux = cnr_trt.ok;
            //console.log("sources:",aux.sources[0]);
            if ('ic' in aux.sources[0].endpoint) {
              const aux2 = aux.sources[0].endpoint.ic;
              let source_trt_principal = aux2.account.owner;
              let source_trt_principal_sub = aux2.account.subaccount
    
              const resb = await ledger.icrc1_balance_of({owner: source_trt_principal, subaccount: source_trt_principal_sub});
              // console.log("before source trt:",resb);
                                
              //load some tokens in the trt source address:
              const res_tx = await ledger.icrc1_transfer({
                to: {owner: source_trt_principal, subaccount:source_trt_principal_sub},
                from_subaccount: [],
                amount: 13_0000_0000n,
                fee: [],
                memo: [],
                created_at_time: [],
              });

              await passTime(150);
            
              const res_alia = await ledger.icrc1_balance_of({owner: ali.getPrincipal(), subaccount: []});
              // console.log("ali balance:",res_alia)

              const res_bobaa = await ledger.icrc1_balance_of({owner: ali2.getPrincipal(), subaccount: []});
              // console.log("ali2 balance:",res_bobaa);

              expect(res_alia+res_bobaa>12_0000_0000).toBe(true)
            };
          };
        };
      };
    });


    async function passTime(n:number) {
    for (let i=0; i<n; i++) {
        await pic.advanceTime(3*1000);
        await pic.tick(2);
      }
    }

});