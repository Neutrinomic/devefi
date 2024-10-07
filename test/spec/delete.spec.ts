
import { DF } from "../utils";

describe('Delete', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`Create and delete`, async () => {


    let node = await d.u.createNode({
      'throttle': {
        'init': { 'ledger': d.ledgerCanisterId },
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
        'init': { 'ledger': d.ledgerCanisterId },
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
    let refund_bal = await d.u.getLedgerBalance( refund_account )

    expect(refund_bal).toBe(1_0000_0000n - d.ledger_fee*2n);
    await d.u.sendToAccount( d.u.mainAccount(), refund_bal - d.ledger_fee, refund_account.subaccount[0] );
  }, 600 * 1000);

  it(`Check refunding of node billing account after deletion`, async () => {

    let billing_account = d.u.userBillingAccount();
    await d.u.sendToAccount(billing_account,  10_0000_0000n);
    
    await d.passTime(5);

    let node = await d.u.createNode({
      'throttle': {
        'init': { 'ledger': d.ledgerCanisterId },
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
    let refund_source_bal = await d.u.getLedgerBalance( d.u.getRefundAccount())

    expect(refund_source_bal).toBe(1_0000_0000n - d.ledger_fee*3n + node.billing.min_create_balance);

  }, 600 * 1000);

});

