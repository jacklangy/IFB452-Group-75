# IFB452 Group 75 — Smart Energy Connect (SEC)

A decentralised peer-to-peer energy trading platform built on Ethereum for Assessment Task 3 of IFB452 (Blockchain Development).

---

## Overview

Smart Energy Connect (SEC) is a blockchain-based application that enables verified energy producers and consumers to trade surplus renewable energy directly without a central intermediary. Membership is managed on-chain by regulators, energy listings are posted to a smart contract marketplace, bids are matched and locked in escrow, and payments are released only after oracle-verified delivery confirmation.

---

## System Architecture

The platform is composed of four interdependent smart contracts and a four-page frontend:

```
SC1  authentication.sol   — Role management (regulators, members, applications)
SC2  EnergyTrading.sol    — Energy listing marketplace
SC3  TradeMatching.sol    — Bid placement, escrow, and match locking
SC4  Settlement.sol       — Delivery confirmation and ETH release
```

Each contract communicates with others through Solidity interfaces, keeping concerns separated and each contract independently auditable.

---

## Smart Contract Flow

```
1. Regulator deploys SC1 and becomes the first regulator
2. Users apply for membership via SC1 → regulator approves on-chain
3. Approved members list surplus energy on SC2 (kWh, price in Wei)
4. Other members place ETH bids on listings via SC3 (ETH locked in escrow)
5. The producer accepts a bid → SC3 locks the match and deactivates the SC2 listing
6. Regulator acts as oracle, confirms energy delivery via SC4
7. SC4 calls SC3.confirmSettlement() → ETH released to producer's wallet
```

---

## Frontend Pages

| Page | Contract | Purpose |
|---|---|---|
| `index.html` | SC1 | Connect wallet, apply for membership, regulator approval queue |
| `energylisting.html` | SC2 | Browse listings, post surplus energy, cancel listings |
| `tradematching.html` | SC3 | Place bids, accept incoming bids, view match status |
| `settlement.html` | SC4 | Confirm delivery, raise disputes, view energy account ledger |

---

## Technology Stack

- **Solidity** `^0.8.x` — Smart contract development
- **Remix IDE** — Contract compilation and deployment
- **Ethereum (Sepolia Testnet)** — Deployment network
- **ethers.js v6** — Frontend blockchain interaction
- **MetaMask** — Wallet connection and transaction signing
- **HTML / CSS / JavaScript** — Frontend (no framework)
- **lite-server** — Local development server

---

## Deployment Order

Contracts must be deployed in this order. Each step requires the previous contract's address.

```
1. Deploy authentication.sol
         ↓ copy address (SC1)

2. Deploy EnergyTrading.sol(SC1_address)
         ↓ copy address (SC2)

3. Deploy TradeMatching.sol(SC1_address, SC2_address)
         ↓ copy address (SC3)
         ↓ call SC2.setTradeMatchingContract(SC3_address)

4. Deploy Settlement.sol(SC1_address, SC3_address)
         ↓ copy address (SC4)
         ↓ call SC3.setSettlementContract(SC4_address)
```

---

## Frontend Configuration

After deployment, update the contract addresses in each HTML file:

```js
// index.html
AUTH_CONTRACT_ADDRESS = "0x..."              // SC1

// energylisting.html
AUTH_CONTRACT_ADDRESS   = "0x..."            // SC1
ENERGY_CONTRACT_ADDRESS = "0x..."            // SC2

// tradematching.html
AUTH_CONTRACT_ADDRESS   = "0x..."            // SC1
ENERGY_CONTRACT_ADDRESS = "0x..."            // SC2
TRADE_CONTRACT_ADDRESS  = "0x..."            // SC3

// settlement.html
AUTH_CONTRACT_ADDRESS       = "0x..."        // SC1
TRADE_CONTRACT_ADDRESS      = "0x..."        // SC3
SETTLEMENT_CONTRACT_ADDRESS = "0x..."        // SC4
```

Serve the frontend with:

```bash
lite-server
```

---

## Project Structure

```
IFB452-Group-75/
├── contracts/
│   ├── authentication.sol
│   ├── EnergyTrading.sol
│   ├── TradeMatching.sol
│   └── Settlement.sol
├── frontend/
│   ├── index.html
│   ├── energylisting.html
│   ├── tradematching.html
│   └── settlement.html
├── package.json
└── README.md
```

---

## Group Members

| Name | Student Number |
|---|---|
| Jack Langdon | n11251395 |
| Oscar Li | n12421731 |

---

## Subject

**IFB452 — Blockchain Development**
Queensland University of Technology (QUT)
Semester 1, 2026
