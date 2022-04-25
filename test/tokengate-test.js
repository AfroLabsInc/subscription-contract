/* eslint-disable no-unused-expressions */
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const ContractObj = {
  TokenGate: null,
  proxyAddress: "0xF838415B7D3607682F2BeA1A479523A16e0cEd35",
  testToken721: "",
  testToken1155: "",
  testToken20: "",
};
const initialize = async () => {
  ContractObj.TokenGate = await ethers.getContractFactory("TokenGate");
  const contracts = await upgrades.deployProxy(ContractObj.TokenGate);
  await contracts.deployed();
  ContractObj.proxyAddress = contracts.address;

  // ERC721 Test Token
  const TestToken721 = await ethers.getContractFactory("TestToken721");
  const testToken721 = await TestToken721.deploy();
  await testToken721.deployed();
  ContractObj.testToken721 = testToken721.address;

  // ERC1155 Test Token
  const TestToken1155 = await ethers.getContractFactory("TestToken1155");
  const testToken1155 = await TestToken1155.deploy();
  await testToken1155.deployed();
  ContractObj.testToken1155 = testToken1155.address;

  // ERC20 Test Token
  const TestToken20 = await ethers.getContractFactory("TestToken20");
  const testToken20 = await TestToken20.deploy();
  await testToken20.deployed();
  ContractObj.testToken20 = testToken20.address;
};
before(async function () {
  await initialize();
});
describe("TokenGate", function () {
  it("Deployer can grant sub-roles to accounts", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    await expect(
      TokenGateContract.grantRole(
        ethers.utils.formatBytes32String("TOKEN_MODERATORS"),
        "0xf7F8DCf8962872421373FF5cf2C4bB06357b7133"
      )
    )
      .to.emit(TokenGateContract, "RoleGranted")
      .withArgs(
        ethers.utils.formatBytes32String("TOKEN_MODERATORS").toString(),
        "0xf7F8DCf8962872421373FF5cf2C4bB06357b7133",
        owner.address
      );
    expect(
      await TokenGateContract.hasRole(
        ethers.utils.formatBytes32String("TOKEN_MODERATORS"),
        "0xf7F8DCf8962872421373FF5cf2C4bB06357b7133"
      )
    ).to.be.true;
  });
  it("Deployer has admin role", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    expect(
      await TokenGateContract.hasRole(
        ethers.utils.formatBytes32String(0x00),
        owner.address
      )
    ).to.be.true;
  });
  it("Deployer is a TOKEN MODERATOR", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    expect(
      await TokenGateContract.hasRole(
        ethers.utils.formatBytes32String("TOKEN_MODERATORS"),
        owner.address
      )
    ).to.be.true;
  });

  it("Should return false, user does not own access token or subscribed (ERC721, ERC20 and ERC1155)  ", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    expect(
      await TokenGateContract.checkAccess(
        ContractObj.testToken721,
        owner.address
      )
    ).to.be.false;
    expect(
      await TokenGateContract.checkAccess(
        ContractObj.testToken20,
        owner.address
      )
    ).to.be.false;
    expect(
      await TokenGateContract.checkAccess(
        ContractObj.testToken1155,
        owner.address
      )
    ).to.be.false;
  });

  it("Add Access token (ERC721)", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    // ethers.Contract.
    // const addr = (await ethers.getSigners())[1];
    await expect(
      TokenGateContract.initializeAccessToken([
        ContractObj.testToken721, // contract address
        ethers.utils.formatBytes32String("ERC721").toString(), // typeOfcontract bytes32
        -1, // no specific id
        [ethers.utils.parseEther("0.1"), 2592000], // lifetime access
        1, // amount (owns >= 1)
      ])
    )
      .to.emit(TokenGateContract, "AddedAccessToken")
      .withArgs(
        ContractObj.testToken721,
        ethers.utils.formatBytes32String("ERC721").toString(),
        "-1",
        "1",
        ethers.utils.parseEther("0.1").toString(),
        "2592000"
      );
    // expect(TokenGateContract.setFee);
  });
  it("Add Access token. user must own at least 20 Tokens to get access (ERC20 and ERC1155)", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    // ethers.Contract.
    // const addr = (await ethers.getSigners())[1];
    await expect(
      TokenGateContract.initializeAccessToken([
        ContractObj.testToken20, // contract address
        ethers.utils.formatBytes32String("ERC20").toString(), // typeOfcontract bytes32
        -1, // no specific id
        [ethers.utils.parseEther("0.1"), 2592000], // pay 0.1ETH monthly as an alternative to token
        20, // amount (owns >= 20)
      ])
    )
      .to.emit(TokenGateContract, "AddedAccessToken")
      .withArgs(
        ContractObj.testToken20,
        ethers.utils.formatBytes32String("ERC20").toString(),
        "-1",
        "20",
        ethers.utils.parseEther("0.1").toString(),
        "2592000"
      );
    await expect(
      TokenGateContract.initializeAccessToken([
        ContractObj.testToken1155, // contract address
        ethers.utils.formatBytes32String("ERC1155").toString(), // typeOfcontract bytes32
        0, // no specific id
        [ethers.utils.parseEther("0.1"), 2592000], // pay 0.1ETH monthly as an alternative to token
        20, // amount (owns >= 20)
      ])
    )
      .to.emit(TokenGateContract, "AddedAccessToken")
      .withArgs(
        ContractObj.testToken1155,
        ethers.utils.formatBytes32String("ERC1155").toString(),
        "0",
        "20",
        ethers.utils.parseEther("0.1").toString(),
        "2592000"
      );
    // expect(TokenGateContract.setFee);
  });

  it(`Checking Access Should return true, user owns this access token: ERC721, ERC20 and ERC1155`, async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    expect(
      await TokenGateContract.checkAccess(
        ContractObj.testToken721,
        owner.address
      )
    ).to.be.true;
    expect(
      await TokenGateContract.checkAccess(
        ContractObj.testToken1155,
        owner.address
      )
    ).to.be.true;
    expect(
      await TokenGateContract.checkAccess(
        ContractObj.testToken20,
        owner.address
      )
    ).to.be.true;
  });

  /** Subscription **/
  it("Set Subscription Fee for  users without TestToken (ERC721) token", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    // ethers.Contract.
    // const addr = (await ethers.getSigners())[1];
    await expect(
      TokenGateContract.setFee(
        ContractObj.testToken721,
        ethers.utils.parseEther("0.05"),
        7 // 7days
      )
    )
      .to.emit(TokenGateContract, "SetFee")
      .withArgs(
        ContractObj.testToken721,
        ethers.utils.parseEther("0.05").toString(),
        "604800"
      );
  });
  it("Set Subscription Fee for  users without TestToken (ERC20) token", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    // ethers.Contract.
    // const addr = (await ethers.getSigners())[1];
    await expect(
      TokenGateContract.setFee(
        ContractObj.testToken20,
        ethers.utils.parseEther("0.05"),
        7 // 7days
      )
    )
      .to.emit(TokenGateContract, "SetFee")
      .withArgs(
        ContractObj.testToken20,
        ethers.utils.parseEther("0.05").toString(),
        "604800"
      );
  });
  it("Set Subscription Fee for  users without TestToken (ERC1155) token", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    // ethers.Contract.
    // const addr = (await ethers.getSigners())[1];
    await expect(
      TokenGateContract.setFee(
        ContractObj.testToken1155,
        ethers.utils.parseEther("0.05"),
        7 // 7days
      )
    )
      .to.emit(TokenGateContract, "SetFee")
      .withArgs(
        ContractObj.testToken1155,
        ethers.utils.parseEther("0.05").toString(),
        "604800"
      );
  });
  it("Instead of acquiring TestTokens (ERC721), User can Subscribe periodically by paying the Fee", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    // const [owner] = await ethers.getSigners();
    // expect(await TokenGateContract.checkIfSubscribed(owner.address)).to.be.false;
    let fee = await TokenGateContract.getFeeForTokenAccess(
      ContractObj.testToken721
    );
    fee = ethers.utils.formatEther(fee.price);
    const options = { value: ethers.utils.parseEther(fee) };
    await expect(
      TokenGateContract.subscribe(ContractObj.testToken721, options)
    ).to.emit(TokenGateContract, "Subscribed");
  });
  it("Instead of acquiring TestTokens (ERC11155), User can Subscribe periodically by paying the Fee", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    // const [owner] = await ethers.getSigners();
    // expect(await TokenGateContract.checkIfSubscribed(owner.address)).to.be.false;
    let fee = await TokenGateContract.getFeeForTokenAccess(
      ContractObj.testToken1155
    );
    fee = ethers.utils.formatEther(fee.price);
    const options = { value: ethers.utils.parseEther(fee) };
    await expect(
      TokenGateContract.subscribe(ContractObj.testToken1155, options)
    ).to.emit(TokenGateContract, "Subscribed");
  });
  it("Checking Access for TestToken (ERC721) should return true, user paid for subscription,", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    const [owner] = await ethers.getSigners();
    // console.log(owner.address);
    expect(
      await TokenGateContract.checkAccess(
        ContractObj.testToken721,
        owner.address
      )
    ).to.be.true;
    // expect(TokenGateContract.setFee);
  });
  it("Disable Test Tokens (ERC721, ERC20 and ERC1155) from access tokens", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    await expect(TokenGateContract.disableTokenAccess(ContractObj.testToken721))
      .to.emit(TokenGateContract, "DisableTokenAccess")
      .withArgs(ContractObj.testToken721, owner.address);
    await expect(
      TokenGateContract.disableTokenAccess(ContractObj.testToken1155)
    )
      .to.emit(TokenGateContract, "DisableTokenAccess")
      .withArgs(ContractObj.testToken1155, owner.address);
    await expect(TokenGateContract.disableTokenAccess(ContractObj.testToken20))
      .to.emit(TokenGateContract, "DisableTokenAccess")
      .withArgs(ContractObj.testToken20, owner.address);
  });
  it("Disable Tokens: Checking Access for TestTokens (ERC721, ERC20 and ERC1155) should return false, no access token initialized and user is not subscribed", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    const [owner] = await ethers.getSigners();
    // console.log(owner.address);
    expect(
      await TokenGateContract.checkAccess(
        ContractObj.testToken721,
        owner.address
      )
    ).to.be.false;
    expect(
      await TokenGateContract.checkAccess(
        ContractObj.testToken20,
        owner.address
      )
    ).to.be.false;
    expect(
      await TokenGateContract.checkAccess(
        ContractObj.testToken1155,
        owner.address
      )
    ).to.be.false;
    // expect(TokenGateContract.setFee);
  });
  it("Withdraw ETH paid for Test-Token721", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    const [owner] = await ethers.getSigners();
    const balance = await TokenGateContract.ethBalancePaidForTokenAccess(
      ContractObj.testToken721
    );
    await expect(
      TokenGateContract.withdrawBalancePaidForToken(ContractObj.testToken721)
    )
      .to.emit(TokenGateContract, "WithdrawBalancePaidForToken")
      .withArgs(ContractObj.testToken721, balance.toString(), owner.address);
  });
  it("Withdraw ETH paid for Test-Token1155", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    const [owner] = await ethers.getSigners();
    const balance = await TokenGateContract.ethBalancePaidForTokenAccess(
      ContractObj.testToken1155
    );
    await expect(
      TokenGateContract.withdrawBalancePaidForToken(ContractObj.testToken1155)
    )
      .to.emit(TokenGateContract, "WithdrawBalancePaidForToken")
      .withArgs(ContractObj.testToken1155, balance.toString(), owner.address);
  });
});
