
import { DF } from "../utils";

describe('Virtual', () => {

  let d: ReturnType<typeof DF>

  beforeAll(async () => { d = DF(); await d.beforeAll(); });

  afterAll(async () => { await d.afterAll(); });


  it(`Check balances`, async () => {


    let virtual = await d.u.virtualBalances( d.u.mainAccount() );
    let bal = virtual[0][1];

    expect(bal).toBe(0n);

    // await d.u.withdrawVirtual(refund_account, d.u.mainAccount(), refund_bal);

  });

  it(`Can't open a new virtual account unless amount is 100 * fee` , async () => {
    
    await d.u.sendToAccount(d.u.virtual(d.u.mainAccount()), d.ledger_fee*20n);
    await d.passTime(5);

    let virtual = await d.u.virtualBalances( d.u.mainAccount() );
    let bal = virtual[0][1];
    expect(bal).toBe(0n);

  });

  it(`Send to virtual account` , async () => {
    await d.u.sendToAccount(d.u.virtual(d.u.mainAccount()), 1_0000_0000n);
    await d.passTime(5);

    let virtual = await d.u.virtualBalances( d.u.mainAccount() );
    let bal = virtual[0][1];
    expect(bal).toBe(1_0000_0000n - d.ledger_fee);

  });

  it(`Withdraw from virtual account` , async () => {

    let resp = await d.u.withdrawVirtual(d.u.mainAccount(), d.u.mainAccount(), 5000_0000n);

    //@ts-ignore
    expect(resp[0].withdraw_virtual.ok).toBeDefined();
    await d.passTime(5);

    let virtual = await d.u.virtualBalances( d.u.mainAccount() );
    let bal = virtual[0][1];
    expect(bal).toBe(5000_0000n - d.ledger_fee);

  });



});
