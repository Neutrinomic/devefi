
import { DF } from "../utils";

describe('Chained vectors', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`throttle->split`, async () => {


    let id = await d.u.createNode({
      'throttle': {
        'init': { 'ledger': d.ledgerCanisterId },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 10000000n }
        },
      },
    });

    let tid = await d.u.createNode({
      'split' : {
          'init' : {'ledger' : d.ledgerCanisterId},
          'variables' : {
              'split' : [50n,50n], 
            },
        }
    });

    await d.u.connectNodes(id, 0, tid, 0);
    await d.u.setDestination(tid, 0n, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(1)] });
    await d.u.setDestination(tid, 1n, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(2)] });

    await d.u.sendToNode(id, 0, 99990000n);

    await d.passTime(50);


    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(1)] })).toBe(49840000n);
    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(2)] })).toBe(49840000n);

  }, 600 * 1000);

});

