import { BaseContract } from "ethers";
import { loadFixture, ethers, expect } from "./setup";
import { BondingCurve__factory, RampToken__factory } from "../typechain-types";


describe("Rampfun", function() {
    async function deploy() {
        const [ owner, deployer, buyer ] = await ethers.getSigners();
        
        const Rampfun = await ethers.getContractFactory("Rampfun");

        const rampfun = await Rampfun.deploy();

        await rampfun.waitForDeployment();

        return { rampfun, owner, deployer, buyer };
    }

    it("allows to deploy a token", async function () {
        const { rampfun, deployer } = await loadFixture(deploy);

        const _name = "TRATATA";
        const _symbol = "TRA";
        const tokenDeployer = rampfun.connect(deployer);
        const tokenDeployTx = await tokenDeployer.deployToken(_name, _symbol);

        await tokenDeployTx.wait();

        const tokenAddress = await precomputeAddress(rampfun);

        const token = await RampToken__factory.connect(tokenAddress, deployer);
        
        expect(_name).to.eq(await token.name());
        expect(_symbol).to.eq(await token.symbol());
        await expect(tokenDeployTx).to.emit(rampfun, "TokenDeployed").withArgs(
            deployer, tokenAddress, _name, _symbol
        );
    })

    it("should deploy a bonding curve", async function () {
        const { rampfun, deployer } = await loadFixture(deploy);

        const _name = "TRATATA";
        const _symbol = "TRA";
        const tokenDeployTx = await rampfun.connect(deployer).deployToken(_name, _symbol);

        await tokenDeployTx.wait();

        const tokenAddress = await precomputeAddress(rampfun);

        const token = await RampToken__factory.connect(tokenAddress, deployer);

        const curveAddress = await precomputeAddress(token);

        const curve = await BondingCurve__factory.connect(curveAddress, deployer);

        expect(curveAddress).to.eq(await curve.getAddress());
    })
    //@audit initial buy doesn't work
    /*it("allows a token deployer to make initial buy", async function () {
        const { rampfun, deployer } = await loadFixture(deploy);

        const _name = "TRATATA";
        const _symbol = "TRA";
        const etherAmount = ethers.parseEther("0.001");
        const tokenDeployTx = await rampfun.connect(deployer).deployToken(_name, _symbol, {value: etherAmount});

        await tokenDeployTx.wait();

        const tokenAddress = await precomputeAddress(rampfun);

        const token = await RampToken__factory.connect(tokenAddress, deployer);

        const curveAddress = await precomputeAddress(token);

        const curve = await BondingCurve__factory.connect(curveAddress, deployer);
        
        await expect(tokenDeployTx).to.emit(rampfun, "TokenDeployed").withArgs(
            deployer, tokenAddress, _name, _symbol
        );
        await expect(tokenDeployTx).to.emit(curve, "TokenBuy").withArgs(
            tokenAddress, deployer, 990
        );
        //await expect(tokenDeployTx).to.changeEtherBalance(deployer, -etherAmount);
    })*/

    it("should withdraw for owner", async function () {
        const { rampfun, owner, deployer } = await loadFixture(deploy);

        const etherAmount = ethers.parseEther("1");
        await owner.sendTransaction({
            to: rampfun,
            value: etherAmount,
        })

        expect(rampfun.connect(deployer).withdraw()).to.be.revertedWithCustomError(rampfun, "OwnableUnauthorizedAccount");
        expect(await rampfun.withdraw()).to.changeEtherBalances([owner, rampfun], [etherAmount, -etherAmount]);
    })

    async function precomputeAddress(rampfun : BaseContract, nonce = 1) : Promise<string> {
        return ethers.getCreateAddress({
            from: await rampfun.getAddress(),
            nonce
        })
    }
})