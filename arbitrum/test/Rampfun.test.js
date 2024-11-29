const { loadFixture, anyValue, ethers, expect } = require("./setup");

describe("Rampfun", function() {
    async function deploy() {
        const Rampfun = await ethers.getContractFactory("Rampfun");

        const rampfun = await Rampfun.deploy();

        await rampfun.waitForDeployment();

        return { rampfun };
    }

    it("should deploy token", async function () {
        const { rampfun } = await loadFixture(deploy);

        const tokenDeployTx = await rampfun.deployToken("TRATATA", "TRA");

        await tokenDeployTx.wait()
    })
})