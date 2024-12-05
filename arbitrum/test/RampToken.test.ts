import { BaseContract } from "ethers";
import { loadFixture,/* time, SignerWithAddress, anyValue,*/ ethers, expect } from "./setup";
import { RampToken__factory } from "../typechain-types";

describe("RampToken", function() {
    async function deploy() {
        const [ owner, deployer, buyer ] = await ethers.getSigners();
        
        const Rampfun = await ethers.getContractFactory("Rampfun");

        const rampfun = await Rampfun.deploy();

        await rampfun.waitForDeployment();

        return { rampfun, owner, deployer, buyer };
    }

    it("allows minting for the bonding curve", async function() {
        const {rampfun, deployer} = await loadFixture(deploy);

        const _name = "TRATATA";
        const _symbol = "TRA";
        const tokenDeployer = rampfun.connect(deployer);
        const tokenDeployTx = await tokenDeployer.deployToken(_name, _symbol);

        await tokenDeployTx.wait();

        const tokenAddress = await precomputeAddress(rampfun);

        const token = await RampToken__factory.connect(tokenAddress, deployer);

        await expect(token.mint(deployer, 10000)).to.be.revertedWithCustomError(token, "UnauthorizedAccess");
        await expect(token.burn(deployer, 10000)).to.be.revertedWithCustomError(token, "UnauthorizedAccess");
    })

    async function precomputeAddress(rampfun : BaseContract, nonce = 1) : Promise<string> {
        return ethers.getCreateAddress({
            from: await rampfun.getAddress(),
            nonce
        })
    }
})