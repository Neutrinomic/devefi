import { DF } from "../utils";

describe('Billing', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`Temporary vector`, async () => {


    let node = await d.u.createNode({
      'throttle': {
        'init': {  },
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
        'init': {},
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
    const cost_per_day = node.billing.cost_per_day;
    
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
        'init': {},
        'variables': {
          'interval_sec': { 'fixed': 1n },
          'max_amount': { 'fixed': 10000000n }
        },
      },
    });

    let pmeta = await d.u.getPylonMeta();
    expect(node.billing.expires[0]).not.toBeDefined();
    expect(node.billing.current_balance).toBe(pmeta.billing.min_create_balance - d.ledgers[0].fee);
    expect(node.id).toBe(2);
  });

  it(`Wait for freeze of paid vector`, async () => {
    let node = await d.u.getNode(2);

    let days_to_exp = node.billing.current_balance / node.billing.cost_per_day ;

    let pmeta = await d.u.getPylonMeta();


    let days_to_freeze = days_to_exp - pmeta.billing.freezing_threshold_days + 0n;

    expect(node.billing.frozen).toBe(false);
    expect(node.billing.expires[0]).not.toBeDefined();

    // Wait for freeze
    await d.passTimeMinute(60*24*Number(days_to_freeze));
    let node_frozen = await d.u.getNode(2);
    expect(node_frozen.billing.frozen).toBe(true);
    expect(node_frozen.billing.expires[0]).not.toBeDefined();

    // Wait for expiration
    await d.passTimeMinute(60*24*Number(days_to_exp - days_to_freeze + 1n));
    let node_expiring = await d.u.getNode(2);

    expect(node_expiring.billing.expires[0]).toBeDefined();
    expect(node_expiring.billing.current_balance).toBe(0n);
    
    // Wait for deletion
    let meta = await d.u.getPylonMeta();
    
    await d.passTimeMinute(Number(meta.temporary_nodes.expire_sec) / 60 + 1);

    await expect(d.u.getNode(2)).rejects.toThrow('Node not found');
    
  });

});

