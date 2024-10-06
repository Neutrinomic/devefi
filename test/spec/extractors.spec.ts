
import { DF } from "../utils";

describe('Extractors', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`two throttles sharing a source`, async () => {


    let node = await d.u.createNode({
      'throttle': {
        'init': { 'ledger': d.ledgerCanisterId },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 1000_0000n }
        },
      },
    });

    let node2 = await d.u.createNode({
      'throttle': {
        'init': { 'ledger': d.ledgerCanisterId },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 1000_0000n }
        },
      },
    });

    await d.u.connectNodeSource(node2.id, 0, node.id, 0);
    await d.u.setDestination(node.id, 0, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(1)] });
    await d.u.setDestination(node2.id, 0, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(2)] });

    await d.u.sendToNode(node.id, 0, 10_0000_0000n);

    await d.passTime(70);


    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(1)] })).toBe(499500000n);
    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(2)] })).toBe(499490000n);

  }, 600 * 1000);

});

