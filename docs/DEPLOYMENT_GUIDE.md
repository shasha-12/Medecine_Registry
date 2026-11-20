# Deployment Guide: MedicineRegistry on Ethereum Sepolia

This guide shows how to deploy the contract to the Ethereum **Sepolia** test network and use it. It takes about 20 minutes. The easiest route is Remix with MetaMask (Part 4). A Hardhat route is described at the end.

The contract used for this project is already deployed:

| Item | Value |
|---|---|
| Network | Ethereum Sepolia testnet (chain ID 11155111) |
| Contract address | `0xe16Af03E9a14705198afBE17db4DD126B86B627c` |
| Etherscan | https://sepolia.etherscan.io/address/0xe16Af03E9a14705198afBE17db4DD126B86B627c |
| Deployment transaction | `0x4c372286cc8902f2c3d17fa21226c76e6d73e1aafd37ba818cce52aad23c69f0` |

## 1. Dependencies

| What | Used for | Version |
|---|---|---|
| MetaMask browser extension | Wallet that signs and pays for transactions | Current release |
| Sepolia test ETH | Gas fees (it has no real value) | About 0.05 ETH per account |
| Remix IDE (https://remix.ethereum.org) | Compile and deploy in the browser, nothing to install | Current release |
| Solidity compiler | Compiles the contract | 0.8.24 or higher (tested with 0.8.34) |
| OpenZeppelin Contracts | `AccessControl` for roles | 5.0.2 in Remix (imported automatically), 5.x in Hardhat |
| Node.js and npm | Only for the local tests and the Hardhat route | Node.js 24 |
| Hardhat | Local compile and tests | 2.22 or higher |
| Etherscan | Viewing the deployed contract | Website |

## 2. Set up the wallet

1. Install MetaMask from https://metamask.io and create a wallet. Write the secret recovery phrase on paper and keep it private. Never type it into a website or send it to anyone.
2. Turn on test networks: MetaMask settings, Advanced, **Show test networks**. Then pick **Sepolia** in the network list.
3. Create two accounts, using **Add account, Add a new account** (not "Import account"):
   - **Regulator**: this account deploys the contract and becomes the first regulator.
   - **Manufacturer**: this account registers batches after the regulator approves it.
4. Copy the address of each account (click the address under the account name).

> **Warning.** Never use a private key from a tutorial or the default accounts of Hardhat or Anvil (for example `0xf39F...2266`). Those keys are public, and bots empty those addresses within seconds. Only use accounts created in your own MetaMask.

## 3. Get Sepolia test ETH

1. Copy your Regulator address and request test ETH from a Sepolia faucet:
   - https://cloud.google.com/application/web3/faucet/ethereum/sepolia
   - https://www.alchemy.com/faucets/ethereum-sepolia
   - https://sepolia-faucet.pk910.de (works by mining in the browser, needs no account)
2. Wait until MetaMask shows the balance on the Sepolia network.
3. Send about 0.05 ETH from the Regulator to the Manufacturer account (MetaMask, Send).

## 4. Deploy with Remix

1. Open https://remix.ethereum.org and create a new file `MedicineRegistry.sol`.
2. Paste in the contents of `remix/MedicineRegistry.sol`. It imports OpenZeppelin 5.0.2 from GitHub, so you need an internet connection.
3. Open the **Solidity Compiler** tab. Choose compiler `0.8.24` or higher, leave the EVM version at the default and the optimizer off, then click **Compile**. A green tick means success.
4. Open the **Deploy & Run Transactions** tab:
   - **Environment**: *Injected Provider - MetaMask*. Connect the **Regulator** account. Check that Remix shows the Sepolia network and your balance. If it shows "Remix VM" or 100 ETH, you are on the fake local network, so change the environment.
   - **Contract**: `MedicineRegistry`.
   - **firstRegulator**: paste the Regulator's address.
   - Click **Deploy** and confirm in MetaMask.
5. When the transaction finishes, the contract appears under **Deployed Contracts**. Copy its address, and copy the transaction hash from the Remix terminal.

## 5. Check the deployment

1. Open `https://sepolia.etherscan.io/address/<your contract address>`. You should see the contract with you as the contract creator.
2. Open the transaction hash on Etherscan. The status should be **Success**.
3. Keep the contract address and the transaction hash. They are needed for the report and for the demo page.

If you reload Remix, the Deployed Contracts list is cleared. Do **not** deploy again. Paste the address into the **At Address** box (under the Deploy button) and click **At Address**.

## 6. Interact with the contract

Expand the contract in Remix and use its buttons. Change the account in MetaMask before each call, and check that Remix shows the account you want.

| # | Account | Function and inputs | Expected |
|---|---------|---------------------|----------|
| 1 | Regulator | `approveManufacturer` (Manufacturer's address, `PharmaCo Ltd`) | Success |
| 2 | Manufacturer | `registerBatch` (`PARA-2026-001`, `Paracetamol 500mg`, `1830000000`) | Success |
| 3 | any | `verifyBatch` (`PARA-2026-001`) | status 1 = Genuine |
| 4 | any | `verifyBatch` (`FAKE-999`) | status 0 = NotFound |
| 5 | Manufacturer | `recallBatch` (any ID, any reason) | Fails: access control |
| 6 | Regulator | `recallBatch` (`PARA-2026-001`, `Contamination found`) | Success |
| 7 | any | `verifyBatch` (`PARA-2026-001`) | status 3 = Recalled |

`1830000000` is a Unix time in the year 2028, so it is in the future. Status values: 0 NotFound, 1 Genuine, 2 Expired, 3 Recalled. `verifyBatch` is read-only, so it needs no confirmation and costs nothing.

## 7. Demo page (optional)

`frontend/index.html` is a small page that registers, checks and recalls batches on the deployed contract. If the contract address changes, edit the `CONTRACT` value near the top of the script in that file.

```bash
cd frontend
python3 -m http.server 8000
```

Open http://localhost:8000. Checking works without a wallet. Registering and recalling need MetaMask on Sepolia, and the connected account must have the right role.

## 8. Run the tests locally (optional)

```bash
npm install
npx hardhat compile
npx hardhat test        # expect: 22 passing
```

## 9. Alternative: deploy with Hardhat

1. Copy `.env.example` to `.env`. Fill in `SEPOLIA_RPC_URL` (from a provider such as Infura or Alchemy) and `PRIVATE_KEY` of a **test wallet you created yourself**. Never commit `.env` and never use a wallet that holds real money.
2. Run:
```bash
npm run deploy:sepolia
npm run demo:sepolia
```
The deploy script prints the contract address and saves it under `deployments/`.

## 10. Troubleshooting

| Problem | Fix |
|---|---|
| MetaMask shows 0 ETH | Check that the network is Sepolia, then use a faucet. |
| Remix shows 100 ETH and "Remix VM" | You are on the local simulator. Set the environment to *Injected Provider - MetaMask*. |
| Compile error about the import | Check your internet connection and use compiler 0.8.24 or higher. |
| The transaction fails with `AccessControlUnauthorizedAccount` | The active account has the wrong role. Switch accounts in MetaMask and check Remix shows the new one. |
| `NotApproved` or access error when registering | Run step 1 first so the regulator approves the manufacturer. |
| `BatchAlreadyExists` | That batch ID is already registered. Use a new ID. |
| `ExpiryNotInFuture` | The expiry timestamp must be later than now. |
| Remix lost the contract after a reload | Use **At Address** with the contract address. Do not deploy again. |
| The balance in MetaMask looks old | Close and reopen MetaMask, or switch networks and back. |
