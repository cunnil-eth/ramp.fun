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
        expect(deployer).to.eq(await token.deployer());
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

        expect(curveAddress).to.eq(await token.bondingCurve());
    })
    //@todo check in remix whether token balance changes
    it("allows a token deployer to make initial buy", async function () {
        const { rampfun, deployer } = await loadFixture(deploy);

        const _name = "TRATATA";
        const _symbol = "TRA";
        const etherAmount = 0.001;
        const wei = ethers.parseEther(etherAmount.toString());
        const fee = ethers.parseEther((etherAmount/100).toString());
        const tokenDeployTx = await rampfun.connect(deployer).deployToken(_name, _symbol, {value: wei});

        await tokenDeployTx.wait();

        const tokenAddress = await precomputeAddress(rampfun);

        const token = await RampToken__factory.connect(tokenAddress, deployer);

        const curveAddress = await precomputeAddress(token);

        const curve = await BondingCurve__factory.connect(curveAddress, deployer);
        
        await expect(tokenDeployTx).to.changeEtherBalances([deployer, curve, rampfun], [-wei, wei - fee, fee]);
        //await expect(tokenDeployTx).to.changeTokenBalance(token, deployer, await token.totalSupply());
        await expect(tokenDeployTx).to.emit(rampfun, "TokenDeployed").withArgs(
            deployer, tokenAddress, _name, _symbol
        );
        await expect(tokenDeployTx).to.emit(curve, "TokenBuy").withArgs(
            tokenAddress, deployer, await token.totalSupply()
        );
    })

    it("allows withdrawal for the owner", async function () {
        const { rampfun, owner, deployer } = await loadFixture(deploy);

        const etherAmount = ethers.parseEther("1");
        await owner.sendTransaction({
            to: rampfun,
            value: etherAmount,
        })

        await expect(rampfun.connect(deployer).withdraw()).to.be.revertedWithCustomError(rampfun, "OwnableUnauthorizedAccount");
        await expect(await rampfun.withdraw()).to.changeEtherBalances([owner, rampfun], [etherAmount, -etherAmount]);
    })

    it("should add a bonding curve to a mapping", async function () {
        const { rampfun, deployer } = await loadFixture(deploy);

        const _name = "TRATATA";
        const _symbol = "TRA";
        const tokenDeployTx = await rampfun.connect(deployer).deployToken(_name, _symbol);

        await tokenDeployTx.wait();

        const tokenAddress = await precomputeAddress(rampfun);

        const token = await RampToken__factory.connect(tokenAddress, deployer);

        expect(await rampfun.bondingCurves(await token.bondingCurve())).to.eq(1);
    })

    async function precomputeAddress(rampfun : BaseContract, nonce = 1) : Promise<string> {
        return ethers.getCreateAddress({
            from: await rampfun.getAddress(),
            nonce
        })
    }
})