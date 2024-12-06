import { BaseContract } from "ethers";
import { loadFixture, ethers, expect } from "./setup";
import { BondingCurve__factory, RampToken__factory } from "../typechain-types";

describe("BondingCurve", function() {
    async function deploy() {
        const [ owner, deployer, buyer ] = await ethers.getSigners();
        
        const Rampfun = await ethers.getContractFactory("Rampfun");

        const rampfun = await Rampfun.deploy();

        await rampfun.waitForDeployment();

        return { rampfun, owner, deployer, buyer };
    }

    it("allows to buy a token", async function () {
        const { rampfun, token, curve, buyer } = await deployToken();

        const etherAmount = 1;
        const wei = ethers.parseEther(etherAmount.toString());
        const fee = ethers.parseEther((etherAmount/100).toString());

        const buyTx = await curve.buy({value: wei});
        
        await expect(buyTx).to.changeEtherBalances([buyer, curve, rampfun], [-wei, wei - fee, fee]);
        await expect(buyTx).to.changeTokenBalance(token, buyer, await token.totalSupply());
        await expect(buyTx).to.emit(curve, "TokenBuy").withArgs(
            token.getAddress(), buyer, await token.totalSupply()
        );
        await expect(curve.buy({value: 0})).to.be.revertedWithCustomError(curve, "NotEnoughFunds")
    })

    it("allows to sell a token", async function () {
        const { rampfun, token, curve, buyer } = await deployToken();

        const initialBalance = await ethers.provider.getBalance(buyer);
        const etherAmount = 0.001;
        const wei = ethers.parseEther(etherAmount.toString());

        await curve.buy({value: wei});

        const tokenBalance = await token.totalSupply();

        const sellTx = await curve.sell(await token.totalSupply());

        expect(await ethers.provider.getBalance(buyer)).to.lt(initialBalance);
        expect(await ethers.provider.getBalance(rampfun)).to.gt(0);
        expect(await ethers.provider.getBalance(curve)).to.eq(0);
        await expect(sellTx).to.changeTokenBalance(token, buyer, -tokenBalance);
        await expect(sellTx).to.emit(curve, "TokenSell").withArgs(
            token.getAddress(), buyer, tokenBalance
        );
        await expect(curve.sell(1)).to.be.revertedWithCustomError(curve, "NotEnoughFunds");
    })

    it("can be migrated", async function () {
        const { rampfun, token, curve } = await deployToken();

        const etherAmount = 100;
        const wei = ethers.parseEther(etherAmount.toString());

        const buyTx = await curve.buy({value: wei});
        
        // eslint-disable-next-line @typescript-eslint/no-unused-expressions
        expect(await curve.tokenMigrated()).to.be.true;
        expect(await rampfun.awaitingForMigration(0)).to.eq(curve);
        expect(await ethers.provider.getBalance(curve)).to.not.eq(wei);
        await expect(buyTx).to.emit(curve, "AwaitingForMigration").withArgs(
            token, (await ethers.provider.getBlock(await ethers.provider.getBlockNumber()))?.timestamp
        )
    })

    async function deployToken() {
        const { rampfun, deployer, buyer } = await loadFixture(deploy);

        const _name = "TRATATA";
        const _symbol = "TRA";
        const tokenDeployTx = await rampfun.connect(deployer).deployToken(_name, _symbol);

        await tokenDeployTx.wait();

        const tokenAddress = await precomputeAddress(rampfun);

        const token = await RampToken__factory.connect(tokenAddress, deployer);

        const curveAddress = await precomputeAddress(token);

        const curve = await BondingCurve__factory.connect(curveAddress, buyer);

        return { rampfun, token, curve, buyer }
    }

    async function precomputeAddress(rampfun : BaseContract, nonce = 1) : Promise<string> {
        return ethers.getCreateAddress({
            from: await rampfun.getAddress(),
            nonce
        })
    }
        
})