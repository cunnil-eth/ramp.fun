import { loadFixture, ethers, expect } from "./setup";
import { RampToken__factory } from "../typechain-types";

describe("RampToken", function() {
    async function deploy() {
        const [owner, deployer, buyer] = await ethers.getSigners();
        const Rampfun = await ethers.getContractFactory("Rampfun");
        const rampfun = await Rampfun.deploy();
        await rampfun.waitForDeployment();
        await rampfun.deployBondingCurve();
        return { rampfun, owner, deployer, buyer };
    }

    it("allows minting and burning only for the bonding curve", async function() {
        const { rampfun, deployer } = await loadFixture(deploy);
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

        await expect(token.mint(deployer.address, 10000)).to.be.revertedWithCustomError(token, "UnauthorizedAccess");
        await expect(token.burn(deployer.address, 10000)).to.be.revertedWithCustomError(token, "UnauthorizedAccess");
    });

    it("allows only bonding curve to set migration on", async function () {
        const { rampfun, deployer } = await loadFixture(deploy);
        const _name = "TRATATA";
        const _symbol = "TRA";
        const wei = ethers.parseEther("100");
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

        await expect(token.setMigrationOn()).to.be.revertedWithCustomError(token, "UnauthorizedAccess");
        expect(await token.tokenMigrated()).to.eq(true);
    });
});