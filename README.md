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

## Quick start
```bash
npm install
npx hardhat test     # 22 passing
```

Sepolia contract address: `0xe16Af03E9a14705198afBE17db4DD126B86B627c`

Source code: https://github.com/shasha-12/Medecine_Registry

Oral presentation video: https://drive.google.com/file/d/1tjvqFOHKrak904xWQ6fdfBvVSCXmbM5A/view?usp=sharing

## Bonus: demo page
`frontend/index.html` is a small page that shows the whole idea in three steps.
1. **Register a batch** (approved manufacturer, needs MetaMask on Sepolia).
2. **Check a batch** (anyone, free, no wallet). The result is Genuine, Expired, Recalled or Not found.
3. **Recall a batch** (regulator, needs MetaMask). The batch then shows as Recalled for everyone.

Checking works by double-clicking the file. Registering and recalling need MetaMask, which does not run on local files, so serve the folder first:

```
cd frontend
python3 -m http.server 8000
```

then open http://localhost:8000. A link such as `?batch=PARA-2026-001` checks a batch straight away, which is how a QR code on a pack could open it.
