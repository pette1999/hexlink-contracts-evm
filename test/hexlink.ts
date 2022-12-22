import {expect} from "chai";
import {ethers, deployments, artifacts} from "hardhat";

const sender = "mailto:sender@gmail.com";
const receiver = "mailto:receiver@gmail.com";

const getContract = async function(name: string) {
  const deployment = await deployments.get(name);
  return await ethers.getContractAt(name, deployment.address);
};

describe("Hexlink", function() {
  beforeEach(async function() {
    await deployments.fixture(["ORACLE", "ACCOUNT", "HEXLINK"]);
  });

  it("Should deploy account contract", async function() {
    const admin = await getContract("Hexlink");
    const [deployer] = await ethers.getSigners();
    const base = await admin.accountBase();
    const initCodeHash = ethers.utils.keccak256(ethers.utils.concat([
      ethers.utils.arrayify("0x363d3d373d3d3d363d73"),
      ethers.utils.arrayify(base),
      ethers.utils.arrayify("0x5af43d82803e903d91602b57fd5bf3"),
    ]));
    const nameHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(sender));

    // deploy account contract
    expect(await admin.version(nameHash)).to.eq(0);
    const account1 = await admin.addressOfName(nameHash)
    await expect(admin.connect(deployer).deploy(nameHash))
        .to.emit(admin, "SetAccount")
        .withArgs(nameHash, account1);
    expect(await admin.addressOfName(nameHash)).to.eq(account1);

    // check owner
    const accountContract1 = await ethers.getContractAt("HexlinkAccount", account1);
    expect(await accountContract1.owner()).to.eq(deployer.address);

    // redeploy should throw    
    await expect(admin.connect(deployer).deploy(nameHash))
      .to.be.reverted;

    // reset should success 
    const tx = await admin.connect(deployer).reset(nameHash);
    const receipt = await tx.wait();
    const args = receipt.events[0].args;
    expect(nameHash).to.eq(args.nameHash);
    expect(await admin.addressOfName(nameHash)).to.eq(args.account);
    expect(await admin.version(nameHash)).to.eq(1);
    // check owner
    const accountContract2 = await ethers.getContractAt("HexlinkAccount", args.account);
    expect(await accountContract2.owner()).to.eq(deployer.address);
  });
});
