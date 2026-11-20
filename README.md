# MedicineRegistry: blockchain medicine verification

Healthcare solution on Ethereum (Sepolia). Approved manufacturers register medicine batches; regulators can recall them; anyone can verify a batch for free.

Author: Anitha Uwimpuhwe · Blockchain and Applications · Summative Assessment

## Deliverables
| Deliverable | File |
|---|---|
| Project report | `docs/Project_Report.docx` (source: `docs/REPORT.md`) |
| Smart contract | `contracts/MedicineRegistry.sol` (Remix copy: `remix/MedicineRegistry.sol`) |
| Deployment guide | `docs/DEPLOYMENT_GUIDE.md` |
| Test cases | `docs/TEST_CASES.md`, `test/MedicineRegistry.test.js`, `docs/test-output.txt` |
| Presentation | `docs/Presentation.pptx` |
| Oral prep | `docs/ORAL_QA.md` |

## Quick start
```bash
npm install
npx hardhat test     # 22 passing
```

Sepolia contract address: `0xe16Af03E9a14705198afBE17db4DD126B86B627c`

## Bonus: verification page
`frontend/index.html` is a small read-only page for the demo. Open it in a browser (double-click the file), type a batch ID and it calls `verifyBatch` on the Sepolia contract. No wallet or install needed; the ethers library is embedded in the file. It also accepts a link such as `index.html?batch=PARA-2026-001`, which is how a QR code on a pack could open it.
