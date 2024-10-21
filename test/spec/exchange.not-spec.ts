
import { DF } from "../utils";

describe('Exchange', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`Exchange`, async () => {


    let node = await d.u.createNode({
      'exchange': {
        'init': { },
        'variables': {
          'max_per_sec': 100000n,
        },
      },
    }, [0, 1]);


    await d.u.sendToNode(node.id, 0, 99990000n);

    await d.passTime(5);

    expect(await d.u.getSourceBalance(node.id, 0)).toBe(99980000n);

    await d.u.setDestination(node.id, 0, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(1)] }, 1);
    await d.passTime(10);

    expect(await d.u.getSourceBalance(node.id, 0)).not.toBe(99980000n);

    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(1)] }, 1)).toBe(89910000n);

  }, 600 * 1000);

});

