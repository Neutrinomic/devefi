
import { DF } from "../utils";

describe('Extractors', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`two throttles sharing a source`, async () => {


    let node = await d.u.createNode({
      'throttle': {
        'init': { },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 1000_0000n }
        },
      },
    });

    let node2 = await d.u.createNode({
      'throttle': {
        'init': { },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 1000_0000n }
        },
      },
    });

    await d.u.connectNodeSource(node2.id, 0, node.id, 0);
    await d.u.addExtractor(node.id, node2.id);

    await d.u.setDestination(node.id, 0, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(1)] });
    await d.u.setDestination(node2.id, 0, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(2)] });

    await d.u.sendToNode(node.id, 0, 1_0000_0000n);

    await d.passTime(70);


    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(1)] })).toBe(49950000n);
    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(2)] })).toBe(49940000n);

  }, 600 * 1000);

  it(`Connecting to a source without being allowed in extractors`, async () => {


    let node = await d.u.createNode({
      'throttle': {
        'init': { },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 1_0000_0000n }
        },
      },
    });

    let node2 = await d.u.createNode({
      'throttle': {
        'init': { },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 1_0000_0000n }
        },
      },
    });

    await d.u.connectNodeSource(node2.id, 0, node.id, 0);

    await d.u.setDestination(node.id, 0, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(10)] });
    await d.u.setDestination(node2.id, 0, { owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(11)] });

    await d.u.sendToNode(node.id, 0, 10_0000_0000n);

    await d.passTime(70);


    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(10)] })).toBe(999890000n);
    expect(await d.u.getLedgerBalance({ owner: d.jo.getPrincipal(), subaccount: [d.u.subaccountFromId(11)] })).toBe(0n);

  }, 600 * 1000);

});

