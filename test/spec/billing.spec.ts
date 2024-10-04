import { DF } from "../utils";

describe('Billing', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`Temporary vector`, async () => {


    let node = await d.u.createNode({
      'throttle': {
        'init': { 'ledger': d.ledgerCanisterId },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 10000000n }
        },
      },
    });


    expect(node.billing.expires[0]).toBeDefined();

  });
  

  it(`Expire temporary vector`, async () => {
    await d.passTimeMinute(60*3);

    let my_nodes = await d.u.listNodes();

    expect(my_nodes.length).toBe(0);

  });

  it(`Create and pay temporary vector`, async () => {

    let node = await d.u.createNode({
      'throttle': {
        'init': { 'ledger': d.ledgerCanisterId },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 10000000n }
        },
      },
    });

        
    expect(node.billing.expires[0]).toBeDefined();
    await d.u.sendToAccount(node.billing.account, 1_0000_0000n);
    await d.passTime(6);
    let node_after = await d.u.getNode(node.id);
    expect(node_after.billing.current_balance).toBe(99990000n);
    expect(node_after.billing.expires[0]).not.toBeDefined();
  });

  it(`Cost per day fee collecting`, async () => {
    let my_nodes = await d.u.listNodes();
    let node = my_nodes[0];
    expect(node.billing.current_balance).toBe(99990000n);

    await d.passTimeMinute(60*25);
    let node_after = await d.u.getNode(node.id);
    const cost_per_day = 10_0000n;
    
    expect(node_after.billing.current_balance).toBeLessThan(node.billing.current_balance);
    let actual_cost = node.billing.current_balance - node_after.billing.current_balance;
    expect(cost_per_day).toBeLessThan(actual_cost);
    expect(cost_per_day*2n).toBeGreaterThan(actual_cost);
    expect(node.billing.expires[0]).not.toBeDefined();
    expect(node.billing.frozen).toBe(false);
    
  });

  it(`Create paid vector`, async () => {

    // Send funds to dedicated user subaccount
    let billing_account = d.u.userBillingAccount();
    await d.u.sendToAccount(billing_account,  10_0000_0000n);
    await d.passTime(3);

    let node = await d.u.createNode({
      'throttle': {
        'init': { 'ledger': d.ledgerCanisterId },
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 10000000n }
        },
      },
    });

    
    expect(node.billing.expires[0]).not.toBeDefined();
    expect(node.billing.current_balance).toBe(node.billing.min_create_balance - d.ledger_fee);
    // d.inspect(node);
  });

  

});

