import { BaseContract } from "ethers";
import { loadFixture,/* time, SignerWithAddress, anyValue,*/ ethers, expect } from "./setup";
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
        const { rampfun, deployer, buyer } = await loadFixture(deploy);

        const _name = "TRATATA";
        const _symbol = "TRA";
        const tokenDeployTx = await rampfun.connect(deployer).deployToken(_name, _symbol);

        await tokenDeployTx.wait();

        const tokenAddress = await precomputeAddress(rampfun);

        const token = await RampToken__factory.connect(tokenAddress, deployer);

        const curveAddress = await precomputeAddress(token);

        const curve = await BondingCurve__factory.connect(curveAddress, buyer);

        const etherAmount = 0.001;
        const wei = ethers.parseEther(etherAmount.toString());
        const fee = ethers.parseEther((etherAmount/100).toString());

        const buyTx = await curve["buy()"]({value: wei});

        await expect(buyTx).to.changeEtherBalances([buyer, curve, rampfun], [-wei, wei - fee, fee]);
        await expect(buyTx).to.changeTokenBalance(token, buyer, await token.totalSupply());
        await expect(buyTx).to.emit(curve, "TokenBuy").withArgs(
            tokenAddress, buyer, await token.totalSupply()
        );
        expect(curve["buy(uint256)"](1000)).to.be.revertedWithCustomError(curve, "NotEnoughFunds")
    })

    async function precomputeAddress(rampfun : BaseContract, nonce = 1) : Promise<string> {
        return ethers.getCreateAddress({
            from: await rampfun.getAddress(),
            nonce
        })
    }
})