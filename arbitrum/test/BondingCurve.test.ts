import { BaseContract } from "ethers";
import { loadFixture,/* time, SignerWithAddress, anyValue,*/ ethers, expect } from "./setup";
import { BondingCurve__factory, RampToken__factory } from "../typechain-types";

describe("Rampfun", function() {
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

        const etherAmount = ethers.parseEther("50");
        const fee = ethers.parseEther("0.00001");

        const buyTx = await curve["buy()"]({value: etherAmount});

        await expect(buyTx).to.changeEtherBalances([buyer, curve, rampfun], [-etherAmount, etherAmount - fee, fee])
        await expect(buyTx).to.changeTokenBalance(token, buyer, 800000000)
        await expect(buyTx).to.emit(curve, "TokenBuy").withArgs(
            tokenAddress, buyer, 800000000
        )
        expect(curve["buy(uint256)"](1000)).to.be.revertedWithCustomError(curve, "NotEnoughFunds")
    })

    async function precomputeAddress(rampfun : BaseContract, nonce = 1) : Promise<string> {
        return ethers.getCreateAddress({
            from: await rampfun.getAddress(),
            nonce
        })
    }
})