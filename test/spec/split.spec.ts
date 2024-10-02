
import { DF } from "../utils";

describe('Split', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`50/50`, async () => {

    let id = await d.u.createNode({
      'split' : {
          'init' : {'ledger' : d.ledgerCanisterId},
          'variables' : {
              'split' : [50n,50n], 
            },
        }
    });

    await d.u.sendToNode(id, 0, 99990000n);

    await d.passTime(5);

    // Nothing should happen if there are no destinations
    expect(await d.u.getSourceBalance(id, 0)).toBe(99980000n);

    await d.u.setDestination(id, 0n, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(1)] });
    await d.u.setDestination(id, 1n, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(2)] });

    await d.passTime(10);

    expect(await d.u.getSourceBalance(id, 0)).not.toBe(99980000n);

    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(1)] })).toBe(49980000n);
    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(2)] })).toBe(49980000n);

  }, 600 * 1000);

  it(`4/3/2`, async () => {

    let id = await d.u.createNode({
      'split' : {
          'init' : {'ledger' : d.ledgerCanisterId},
          'variables' : {
              'split' : [4n,3n,2n], 
            },
        }
    });

    await d.u.sendToNode(id, 0, 99990000n);

    await d.passTime(5);

    // Nothing should happen if there are no destinations
    expect(await d.u.getSourceBalance(id, 0)).toBe(99980000n);

    await d.u.setDestination(id, 0n, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(5)] });
    await d.u.setDestination(id, 1n, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(6)] });
    await d.u.setDestination(id, 2n, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(7)] });

    await d.passTime(10);

    expect(await d.u.getSourceBalance(id, 0)).not.toBe(99980000n);

    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(5)] })).toBe(44425557n);
    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(6)] })).toBe(33316666n);
    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(7)] })).toBe(22207777n);

    expect(await d.u.getSourceBalance(id, 0)).toBe(0n);

  }, 600 * 1000);
});
