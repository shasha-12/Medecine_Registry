const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

// numbers verifyBatch returns for each status
const Status = { NotFound: 0n, Genuine: 1n, Expired: 2n, Recalled: 3n };
const DAY = 24 * 60 * 60;

describe("MedicineRegistry", function () {
  let registry, regulator, manufacturer, stranger, other;
  let REGULATOR_ROLE, MANUFACTURER_ROLE;
  let expiry;

  beforeEach(async function () {
    [regulator, manufacturer, stranger, other] = await ethers.getSigners();
    registry = await (await ethers.getContractFactory("MedicineRegistry")).deploy(regulator.address);
    REGULATOR_ROLE = await registry.REGULATOR_ROLE();
    MANUFACTURER_ROLE = await registry.MANUFACTURER_ROLE();
    expiry = (await time.latest()) + 365 * DAY;
  });

  const approve = () => registry.connect(regulator).approveManufacturer(manufacturer.address, "PharmaCo Ltd");
  const register = (id = "PARA-2026-001") =>
    registry.connect(manufacturer).registerBatch(id, "Paracetamol 500mg", expiry);

  describe("Deployment", function () {
    it("T1 gives the first regulator the regulator role", async function () {
      expect(await registry.hasRole(REGULATOR_ROLE, regulator.address)).to.equal(true);
    });
    it("T2 rejects the zero address as first regulator", async function () {
      const f = await ethers.getContractFactory("MedicineRegistry");
      await expect(f.deploy(ethers.ZeroAddress)).to.be.revertedWithCustomError(registry, "ZeroAddress");
    });
  });

  describe("Manufacturer approval", function () {
    it("T3 regulator approves a manufacturer and emits an event", async function () {
      await expect(approve()).to.emit(registry, "ManufacturerApproved").withArgs(manufacturer.address, "PharmaCo Ltd");
      expect(await registry.hasRole(MANUFACTURER_ROLE, manufacturer.address)).to.equal(true);
      expect(await registry.manufacturerName(manufacturer.address)).to.equal("PharmaCo Ltd");
    });
    it("T4 non-regulator cannot approve a manufacturer", async function () {
      await expect(
        registry.connect(stranger).approveManufacturer(stranger.address, "Fake Pharma")
      ).to.be.revertedWithCustomError(registry, "AccessControlUnauthorizedAccount");
    });
    it("T5 cannot approve the same manufacturer twice", async function () {
      await approve();
      await expect(approve()).to.be.revertedWithCustomError(registry, "AlreadyApproved");
    });
    it("T6 regulator can remove a manufacturer, who then cannot register", async function () {
      await approve();
      await expect(registry.removeManufacturer(manufacturer.address)).to.emit(registry, "ManufacturerRemoved");
      await expect(register()).to.be.revertedWithCustomError(registry, "AccessControlUnauthorizedAccount");
    });
    it("T7 removing someone who is not a manufacturer reverts", async function () {
      await expect(registry.removeManufacturer(stranger.address)).to.be.revertedWithCustomError(registry, "NotApproved");
    });
  });

  describe("Registering batches", function () {
    beforeEach(approve);

    it("T8 approved manufacturer registers a batch", async function () {
      await expect(register()).to.emit(registry, "BatchRegistered");
      expect(await registry.totalBatches()).to.equal(1n);
    });
    it("T9 unapproved address cannot register a batch", async function () {
      await expect(
        registry.connect(stranger).registerBatch("FAKE-1", "Fake pills", expiry)
      ).to.be.revertedWithCustomError(registry, "AccessControlUnauthorizedAccount");
    });
    it("T10 duplicate batch ID is rejected", async function () {
      await register();
      await expect(register()).to.be.revertedWithCustomError(registry, "BatchAlreadyExists");
    });
    it("T11 expiry date in the past is rejected", async function () {
      const past = (await time.latest()) - DAY;
      await expect(
        registry.connect(manufacturer).registerBatch("OLD-1", "Old pills", past)
      ).to.be.revertedWithCustomError(registry, "ExpiryNotInFuture");
    });
    it("T12 empty batch ID or drug name is rejected", async function () {
      await expect(
        registry.connect(manufacturer).registerBatch("", "Paracetamol", expiry)
      ).to.be.revertedWithCustomError(registry, "EmptyInput");
      await expect(
        registry.connect(manufacturer).registerBatch("X-1", "", expiry)
      ).to.be.revertedWithCustomError(registry, "EmptyInput");
    });
  });

  describe("Verification", function () {
    beforeEach(async function () {
      await approve();
      await register();
    });

    it("T13 a registered batch verifies as Genuine with manufacturer details", async function () {
      const [status, batch, label] = await registry.verifyBatch("PARA-2026-001");
      expect(status).to.equal(Status.Genuine);
      expect(batch.drugName).to.equal("Paracetamol 500mg");
      expect(batch.manufacturer).to.equal(manufacturer.address);
      expect(label).to.equal("PharmaCo Ltd");
    });
    it("T14 an unknown batch ID returns NotFound", async function () {
      const [status] = await registry.verifyBatch("DOES-NOT-EXIST");
      expect(status).to.equal(Status.NotFound);
    });
    it("T15 a batch past its expiry date returns Expired", async function () {
      await time.increaseTo(expiry + 1);
      const [status] = await registry.verifyBatch("PARA-2026-001");
      expect(status).to.equal(Status.Expired);
    });
    it("T16 anyone (even with no role) can verify", async function () {
      const [status] = await registry.connect(stranger).verifyBatch("PARA-2026-001");
      expect(status).to.equal(Status.Genuine);
    });
  });

  describe("Recalls", function () {
    beforeEach(async function () {
      await approve();
      await register();
    });

    it("T17 regulator recalls a batch and verification reports Recalled with the reason", async function () {
      await expect(registry.recallBatch("PARA-2026-001", "Contamination found")).to.emit(registry, "BatchRecalled");
      const [status, batch] = await registry.verifyBatch("PARA-2026-001");
      expect(status).to.equal(Status.Recalled);
      expect(batch.recallReason).to.equal("Contamination found");
    });
    it("T18 non-regulator (even the manufacturer) cannot recall", async function () {
      await expect(
        registry.connect(manufacturer).recallBatch("PARA-2026-001", "oops")
      ).to.be.revertedWithCustomError(registry, "AccessControlUnauthorizedAccount");
    });
    it("T19 cannot recall an unknown batch", async function () {
      await expect(registry.recallBatch("NOPE", "reason")).to.be.revertedWithCustomError(registry, "BatchDoesNotExist");
    });
    it("T20 cannot recall twice, and a reason is required", async function () {
      await expect(registry.recallBatch("PARA-2026-001", "")).to.be.revertedWithCustomError(registry, "EmptyInput");
      await registry.recallBatch("PARA-2026-001", "Bad batch");
      await expect(registry.recallBatch("PARA-2026-001", "Again")).to.be.revertedWithCustomError(registry, "AlreadyRecalled");
    });
    it("T21 a recalled batch stays Recalled even after it expires", async function () {
      await registry.recallBatch("PARA-2026-001", "Bad batch");
      await time.increaseTo(expiry + 1);
      const [status] = await registry.verifyBatch("PARA-2026-001");
      expect(status).to.equal(Status.Recalled);
    });
  });

  describe("Regulator management", function () {
    it("T22 a regulator can add another regulator; a stranger cannot", async function () {
      await registry.grantRole(REGULATOR_ROLE, other.address);
      expect(await registry.hasRole(REGULATOR_ROLE, other.address)).to.equal(true);
      await expect(
        registry.connect(stranger).grantRole(REGULATOR_ROLE, stranger.address)
      ).to.be.revertedWithCustomError(registry, "AccessControlUnauthorizedAccount");
    });
  });
});
