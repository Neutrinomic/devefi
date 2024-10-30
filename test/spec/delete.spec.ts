
import { DF } from "../utils";

describe('Delete', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`Create and delete`, async () => {


    let node = await d.u.createNode({
      'throttle': {
        'init': { },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 10000000n }
        },
      },
    });

    await d.u.deleteNode(node.id)

    await expect(d.u.getNode(node.id)).rejects.toThrow('Node not found');


  }, 600 * 1000);

  
  it(`Check refunding of sources after deletion`, async () => {

    let node = await d.u.createNode({
      'throttle': {
        'init': { },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 10000000n }
        },
      },
    });

    await d.u.sendToNode(node.id, 0, 1_0000_0000n);
    await d.passTime(5);


    await d.u.deleteNode(node.id)

    await expect(d.u.getNode(node.id)).rejects.toThrow('Node not found');
    await d.passTime(10);
    let refund_account = d.u.getRefundAccount();
    let refund_virtual = await d.u.virtualBalances(refund_account);
    let refund_bal = refund_virtual[0][1];

    expect(refund_bal).toBe(1_0000_0000n - d.ledgers[0].fee*2n);

  
  }, 600 * 1000);

  it(`Withdraw from refund account`, async () => {
    let refund_account = d.u.getRefundAccount();
    let refund_virtual = await d.u.virtualBalances(refund_account);
    let refund_bal = refund_virtual[0][1];

    let resp = await d.u.virtualTransfer(refund_account, d.u.mainAccount(), refund_bal);

    //@ts-ignore
    expect(resp.ok.commands[0].transfer.ok).toBeDefined();
  });

  it(`Check refunding of node billing account after deletion`, async () => {

    let billing_account = d.u.userBillingAccount();
    await d.u.sendToAccount(billing_account,  10_0000_0000n);
    
    await d.passTime(5);

    let node = await d.u.createNode({
      'throttle': {
        'init': {  },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 10000000n }
        },
      },
    });

    await d.u.sendToNode(node.id, 0, 1_0000_0000n);
    await d.passTime(5);


    await d.u.deleteNode(node.id)

    await expect(d.u.getNode(node.id)).rejects.toThrow('Node not found');
    await d.passTime(10);
    let refund_virtual = await d.u.virtualBalances( d.u.getRefundAccount());
    let refund_bal = refund_virtual[0][1];
    let pmeta = await d.u.getPylonMeta();
    expect(refund_bal).toBe(1_0000_0000n - d.ledgers[0].fee*4n + pmeta.billing.min_create_balance);

  }, 600 * 1000);

});

