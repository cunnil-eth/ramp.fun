import { BaseContract, ContractTransactionResponse } from "ethers";
import { loadFixture, anyValue, ethers, expect } from "./setup";


describe("Rampfun", function() {
    async function deploy() {
        const Rampfun = await ethers.getContractFactory("Rampfun");

        const rampfun = await Rampfun.deploy();

        await rampfun.waitForDeployment();

        return { rampfun };
    }

    it("should deploy token", async function () {
        const { rampfun } = await loadFixture(deploy);
        const [owner] = await ethers.getSigners();

        const tokenDeployTx = await rampfun.deployToken("TRATATA", "TRA");

        await tokenDeployTx.wait();

        const tokenAddress = precomputeAddress(rampfun);
    })

    async function precomputeAddress(rampfun : BaseContract, nonce = 1) : Promise<string> {
        return await ethers.getCreateAddress({
            from: await rampfun.getAddress(),
            nonce
        })
    }
})