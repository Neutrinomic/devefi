
import { DF } from "../utils";

describe('Active', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`Active`, async () => {


    let node = await d.u.createNode({
      'throttle': {
        'init': {  },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 10000000n }
        },
      },
    });

    await d.u.sendToNode(node.id, 0, 99990000n);

    await d.passTime(5);

    expect(await d.u.getSourceBalance(node.id, 0)).toBe(99980000n);

    await d.u.setDestination(node.id, 0, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(1)] });

    await d.u.setActive(node.id, false);
    await d.passTime(10);
    let bal1 = await d.u.getSourceBalance(node.id, 0);
    expect(bal1).toBe(99980000n);

    await d.u.setActive(node.id, true);
    await d.passTime(2);
    let bal2 = await d.u.getSourceBalance(node.id, 0);
    expect(bal2).toBeLessThan(bal1);

    await d.u.setActive(node.id, false);
    await d.passTime(2);
    expect(await d.u.getSourceBalance(node.id, 0)).toBe(bal2);

    await d.u.setActive(node.id, true);
    await d.passTime(2);
    expect(await d.u.getSourceBalance(node.id, 0)).toBeLessThan(bal2);

  }, 600 * 1000);

});

