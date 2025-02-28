import { loadFixture, ethers, expect } from "./setup";
import { BondingCurve__factory, RampToken__factory } from "../typechain-types";

describe("Rampfun", function() {
    async function deploy() {
        const [owner, deployer, buyer] = await ethers.getSigners();
        const Rampfun = await ethers.getContractFactory("Rampfun");
        const rampfun = await Rampfun.deploy();
        await rampfun.waitForDeployment();
        return { rampfun, owner, deployer, buyer };
    }

    it("allows only owner to deploy bonding curve", async function () {
        const { rampfun, owner, deployer } = await loadFixture(deploy);
        await expect(rampfun.connect(deployer).deployBondingCurve())
            .to.be.revertedWithCustomError(rampfun, "OwnableUnauthorizedAccount");
        await rampfun.connect(owner).deployBondingCurve();
        expect(await rampfun.bondingCurve()).to.not.eq(ethers.ZeroAddress);
    });

    it("allows to deploy a token", async function () {
        const { rampfun, deployer } = await loadFixture(deploy);
        await rampfun.deployBondingCurve();
        const _name = "TRATATA";
        const _symbol = "TRA";
        const tokenDeployTx = await rampfun.connect(deployer).deployToken(_name, _symbol);
        const receipt = await tokenDeployTx.wait();
        
        if (!receipt) {
            throw new Error('Token was not deployed');
        }
        const event = receipt.logs
            .map(log => rampfun.interface.parseLog(log))
            .find(e => e?.name === "TokenDeployed");
        if (!event) {
            throw new Error('Event is missing');
        }
        const tokenAddress = event.args._token;

        const token = RampToken__factory.connect(tokenAddress, deployer);

        expect(await token.name()).to.eq(_name);
        expect(await token.symbol()).to.eq(_symbol);
        expect(await token.deployer()).to.eq(deployer.address);
        await expect(tokenDeployTx).to.emit(rampfun, "TokenDeployed").withArgs(
            deployer.address, tokenAddress, _name, _symbol
        );
    });

    it("allows a token deployer to make initial buy", async function () {
        const { rampfun, deployer } = await loadFixture(deploy);
        await rampfun.deployBondingCurve();
        const _name = "TRATATA";
        const _symbol = "TRA";
        const etherAmount = "0.001";
        const wei = ethers.parseEther(etherAmount);
        const fee = wei / BigInt(100);

        const tokenDeployTx = await rampfun.connect(deployer).deployToken(_name, _symbol, { value: wei });
        const receipt = await tokenDeployTx.wait();

        if (!receipt) {
            throw new Error('Token was not deployed');
        }
        const event = receipt.logs
            .map(log => rampfun.interface.parseLog(log))
            .find(e => e?.name === "TokenDeployed");
        if (!event) {
            throw new Error('Event is missing');
        }
        const tokenAddress = event.args._token;

        const token = RampToken__factory.connect(tokenAddress, deployer);
        const curveAddress = await rampfun.bondingCurve();
        const curve = BondingCurve__factory.connect(curveAddress, deployer);

        await expect(tokenDeployTx).to.changeEtherBalances([deployer, rampfun], [-wei, fee]);
        await expect(tokenDeployTx).to.emit(rampfun, "TokenDeployed").withArgs(
            deployer.address, tokenAddress, _name, _symbol
        );
        await expect(tokenDeployTx).to.emit(curve, "TokenBuy").withArgs(
            tokenAddress, deployer.address, await token.totalSupply()
        );
    });

    it("allows withdrawal for the owner", async function () {
        const { rampfun, owner, deployer } = await loadFixture(deploy);
        const etherAmount = ethers.parseEther("1");
        await owner.sendTransaction({
            to: rampfun.target,
            value: etherAmount,
        });

        await expect(rampfun.connect(deployer).withdraw()).to.be.revertedWithCustomError(rampfun, "OwnableUnauthorizedAccount");
        await expect(rampfun.withdraw()).to.changeEtherBalances([owner, rampfun], [etherAmount, -etherAmount]);
    });

    it("allows ERC721 to be received", async function () {
        const { rampfun } = await loadFixture(deploy);
        expect(await rampfun.onERC721Received(ethers.ZeroAddress, ethers.ZeroAddress, 0, ethers.ZeroHash))
            .to.eq(ethers.id("onERC721Received(address,address,uint256,bytes)").slice(0, 10));
    });
});