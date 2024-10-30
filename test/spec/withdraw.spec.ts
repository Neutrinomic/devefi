
import { DF } from "../utils";

describe('Withdraw', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`Withdraw`, async () => {

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


    await d.u.sourceTransfer(node.id, 0, 100_0000n, d.u.userSubaccount(10));
    await d.passTime(5);
    let bal = await d.u.getLedgerBalance(d.u.userSubaccount(10));

    expect(bal).toBe(100_0000n - d.ledgers[0].fee);

    await d.u.sourceTransfer(node.id, 0, 100_0000n, d.u.userSubaccount(10));
    await d.passTime(5);
    let bal2 = await d.u.getLedgerBalance(d.u.userSubaccount(10));

    expect(bal2).toBe(200_0000n - d.ledgers[0].fee*2n);

  }, 600 * 1000);

  it(`Withdraw more than source balance`, async () => {
    let node = await d.u.getNode(0);
   
    // make sure the pylon has enough in other nodes
    let node_another = await d.u.createNode({
      'throttle': {
        'init': {},
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 10000000n }
        },
      },
    });
    await d.u.sendToNode(node_another.id, 0, 100_0000_0000n);
    await d.passTime(10);


    let resp = await d.u.sourceTransfer(0, 0, node.sources[0].balance + 1000_0000n, d.u.userSubaccount(10));

    //@ts-ignore
    expect(resp.ok.commands[0].transfer.err).toBe('Insufficient balance');
  });

  it(`Withdraw non existing node`, async () => {
    let resp = await d.u.sourceTransfer(3, 0, 100_0000n, d.u.userSubaccount(10));

    //@ts-ignore
    expect(resp.ok.commands[0].transfer?.err).toBe('Node not found');
  });

  it(`Withdraw non existing source port`, async () => {
    let resp = await d.u.sourceTransfer(0, 3, 100_0000n, d.u.userSubaccount(10));
    //@ts-ignore
    expect(resp.ok.commands[0].transfer.err).toBe('Source not found');
  });

  it(`Withdraw non controlled source`, async () => {
    await d.u.setControllers(0, []);
    let node = await d.u.getNode(0);
    expect(node.controllers).toEqual([]);
    let resp = await d.u.sourceTransfer(0, 0, 100_0000n, d.u.userSubaccount(10));
    //@ts-ignore
    expect(resp.ok.commands[0].transfer.err).toBe('Not a controller');
  });



  it(`Withdraw from node extracting from another source`, async () => {


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

    await d.u.sendToNode(node.id, 0, 10_0000_0000n);

    await d.passTime(5);

    let resp = await d.u.sourceTransfer(node2.id, 0, 100_0000n, d.u.userSubaccount(10));

    //@ts-ignore
    expect(resp.ok.commands[0].transfer.ok).toBeDefined();

    let resp2 = await d.u.sourceTransfer(node.id, 0, 100_0000n, d.u.userSubaccount(10));
    
    //@ts-ignore
    expect(resp2.ok.commands[0].transfer.ok).toBeDefined();

  });

});

