
import { DF } from "../utils";

describe('Payment', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`Temporary vector`, async () => {


    let id = await d.u.createNode({
      'throttle': {
        'init': { 'ledger': d.ledgerCanisterId },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 10000000n }
        },
      },
    });

    let node = await d.u.getNode(id);

    expect(node.expires[0]).toBeDefined();

  });

  it(`Pay temporary vector`, async () => {
    // let my_nodes = await d.u.listNodes();
    // let node = my_nodes[0];

    // await d.u.sendToAccount(node.)
  });

});

