// End-to-end demo against a deployed registry (the signer must be the regulator).
// For simplicity the regulator also acts as the manufacturer in the demo.
const fs = require("fs");
const path = require("path");
const { ethers, network } = require("hardhat");

const STATUS = ["NotFound", "Genuine", "Expired", "Recalled"];

async function show(registry, id) {
  const [status, batch, maker] = await registry.verifyBatch(id);
  console.log(`  verify("${id}") -> ${STATUS[status]}${status === 0n ? "" : ` | ${batch.drugName} | ${maker}`}${batch.recallReason ? ` | reason: ${batch.recallReason}` : ""}`);
}

async function main() {
  const file = path.join(__dirname, "..", "deployments", `${network.name}.json`);
  const { address } = JSON.parse(fs.readFileSync(file));
  const [signer] = await ethers.getSigners();
  const registry = await ethers.getContractAt("MedicineRegistry", address, signer);
  const tag = Date.now().toString().slice(-6);
  const good = `PARA-${tag}`, bad = `FAKE-${tag}`;
  const expiry = Math.floor(Date.now() / 1000) + 365 * 24 * 3600;

  console.log("1. Regulator approves a manufacturer");
  if (!(await registry.hasRole(await registry.MANUFACTURER_ROLE(), signer.address))) {
    await (await registry.approveManufacturer(signer.address, "PharmaCo Ltd")).wait();
  }
  console.log("2. Manufacturer registers two batches");
  await (await registry.registerBatch(good, "Paracetamol 500mg", expiry)).wait();
  await (await registry.registerBatch(bad, "Amoxicillin 250mg", expiry)).wait();
  console.log("3. Anyone verifies");
  await show(registry, good);
  await show(registry, "NOT-IN-REGISTRY");
  console.log("4. Regulator recalls a batch");
  await (await registry.recallBatch(bad, "Contamination found in lab test")).wait();
  await show(registry, bad);
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
