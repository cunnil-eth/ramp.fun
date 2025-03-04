import { loadFixture, ethers, expect } from "./setup";
import { BondingCurve__factory, RampToken__factory } from "../typechain-types";

describe("BondingCurve", function() {
    async function deploy() {
        const [owner, deployer, buyer] = await ethers.getSigners();
        const Rampfun = await ethers.getContractFactory("Rampfun");
        const rampfun = await Rampfun.deploy();
        await rampfun.waitForDeployment();
        await rampfun.deployBondingCurve();
        return { rampfun, owner, deployer, buyer };
    }

    async function deployToken() {
        const { rampfun, deployer, buyer } = await loadFixture(deploy);
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

        const token = RampToken__factory.connect(tokenAddress, buyer);
        const curveAddress = await rampfun.bondingCurve();
        const curve = BondingCurve__factory.connect(curveAddress, buyer);

        return { rampfun, token, curve, buyer };
    }

    it("allows to buy a token", async function () {
        const { rampfun, token, curve, buyer } = await deployToken();
        const etherAmount = "1";
        const wei = ethers.parseEther(etherAmount);
        const fee = wei / BigInt(100);

        const buyTx = await curve.buy(token.target, { value: wei });

        await expect(buyTx).to.changeEtherBalances([buyer, rampfun], [-wei, fee]);
        await expect(buyTx).to.changeTokenBalance(token, buyer, await token.balanceOf(buyer.address));
        await expect(buyTx).to.emit(curve, "TokenBuy").withArgs(
            token.target, buyer.address, await token.balanceOf(buyer.address)
        );
        await expect(curve.buy(token.target, { value: 0 })).to.be.revertedWithCustomError(curve, "NotEnoughFunds");
    });

    it("allows to sell a token", async function () {
        const { rampfun, token, curve, buyer } = await deployToken();
        const etherAmount = "0.001";
        const wei = ethers.parseEther(etherAmount);
        await curve.buy(token.target, { value: wei });
        const tokenBalance = await token.balanceOf(buyer.address);

        const sellTx = await curve.sell(tokenBalance, token);

        expect(await ethers.provider.getBalance(curve)).to.eq(0);
        expect(await ethers.provider.getBalance(rampfun)).to.gt(0);
        await expect(sellTx).to.changeTokenBalance(token, buyer, -tokenBalance);
        await expect(sellTx).to.emit(curve, "TokenSell").withArgs(
            token.target, buyer.address, tokenBalance
        );
        await expect(curve.sell(1, token)).to.be.revertedWithCustomError(curve, "NotEnoughFunds");
    });

    it("can be migrated", async function () {
        const { token, curve } = await deployToken();
        const etherAmount = "100"; 
        const wei = ethers.parseEther(etherAmount);

        const buyTx = await curve.buy(token.target, { value: wei });

        if (!buyTx) {
            throw new Error('Token was not deployed');
        }
        expect(await token.tokenMigrated()).to.eq(true);
        expect(await curve.awaitingForMigration(0)).to.eq(token.target);
        await expect(buyTx).to.emit(curve, "AwaitingForMigration").withArgs(
            token.target, (await ethers.provider.getBlock(await ethers.provider.getBlockNumber()))?.timestamp
        );
    });

    it("allows only factory to add token", async function () {
        const { rampfun, deployer } = await loadFixture(deploy);
        const curveAddress = await rampfun.bondingCurve();
        const curve = BondingCurve__factory.connect(curveAddress, deployer);

        await expect(curve.addToken(ethers.Wallet.createRandom().address))
            .to.be.revertedWithCustomError(curve, "UnauthorizedAccess");

        await rampfun.deployToken("TRATATA", "TRA");
        const tokenAddress = (await rampfun.queryFilter(rampfun.filters.TokenDeployed()))[0].args._token;
        expect(await curve.tokens(tokenAddress)).to.eq(1);
    });
});