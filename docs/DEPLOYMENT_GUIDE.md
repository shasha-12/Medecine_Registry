# Deployment Guide — MedicineRegistry on Ethereum Sepolia

## Prerequisites
- A browser with the MetaMask extension.
- Two MetaMask accounts on the **Sepolia** test network:
  - Account A = regulator (deploys the contract)
  - Account B = manufacturer
- Free Sepolia test ETH in both accounts (from a Sepolia faucet; about 0.05 ETH each is enough).
- For local testing only: Node.js 24, then `npm install` in the project folder.

## Part 1 — Run the tests locally (optional but recommended)
```bash
cd medicine-verifier
npm install
npx hardhat compile
npx hardhat test        # expect: 22 passing
```

## Part 2 — Deploy with Remix
1. Open https://remix.ethereum.org and create a file `MedicineRegistry.sol`.
2. Paste the contents of `remix/MedicineRegistry.sol` (it imports OpenZeppelin 5.0.2 from GitHub).
3. **Solidity Compiler** tab: compiler `0.8.24`, EVM version `cancun`, optimizer on (200 runs), then **Compile**.
4. **Deploy & Run** tab:
   - Environment: *Injected Provider – MetaMask*; select Account A on Sepolia.
   - Contract: `MedicineRegistry`.
   - `firstRegulator`: paste Account A's address.
   - Click **Deploy** and confirm in MetaMask.
5. Copy the deployed contract address and open it on https://sepolia.etherscan.io.

## Part 3 — Interact
Use the deployed contract's buttons in Remix. Switch the MetaMask account between calls.

| # | Account | Function and inputs | Expected |
|---|---------|---------------------|----------|
| 1 | A | `approveManufacturer` (B's address, `PharmaCo Ltd`) | Success |
| 2 | B | `registerBatch` (`PARA-2026-001`, `Paracetamol 500mg`, `1830000000`) | Success |
| 3 | any | `verifyBatch` (`PARA-2026-001`) | status 1 = Genuine |
| 4 | any | `verifyBatch` (`FAKE-999`) | status 0 = NotFound |
| 5 | A | `recallBatch` (`PARA-2026-001`, `Contamination found`) | Success |
| 6 | any | `verifyBatch` (`PARA-2026-001`) | status 3 = Recalled |
| 7 | B | `recallBatch` (any ID, any reason) | Fails: access control |

`1830000000` is a Unix timestamp in January 2028, so it is in the future.
Status values: 0 NotFound, 1 Genuine, 2 Expired, 3 Recalled.

## Alternative: deploy with Hardhat
Copy `.env.example` to `.env` and fill in `SEPOLIA_RPC_URL` and `PRIVATE_KEY` (a test wallet only; never commit `.env`), then:
```bash
npm run deploy:sepolia
npm run demo:sepolia
```
