// Deploys MedicineRegistry. The deploying wallet becomes the first regulator.
const fs = require("fs");
const path = require("path");
const { ethers, network } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Network:   ${network.name}`);
  console.log(`Regulator: ${deployer.address}`);

  const registry = await (await ethers.getContractFactory("MedicineRegistry")).deploy(deployer.address);
  await registry.waitForDeployment();
  const address = await registry.getAddress();
  console.log(`MedicineRegistry deployed to: ${address}`);

  const out = path.join(__dirname, "..", "deployments");
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(
    path.join(out, `${network.name}.json`),
    JSON.stringify({ network: network.name, address, regulator: deployer.address }, null, 2)
  );
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
