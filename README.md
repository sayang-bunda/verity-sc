# Verity Smart Contracts

> **Solidity smart contracts for the Verity prediction market protocol — secured by Chainlink CRE & Price Feeds**

Verity is a decentralized prediction market protocol built on **Base Sepolia**. Markets are created, monitored, and resolved autonomously through **Chainlink CRE (Compute Runtime Environment)** workflows, with crypto price markets resolved deterministically via **Chainlink Price Feeds**.

---

## Architecture

```
                    Chainlink Keystone Forwarder
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│                      Verity.sol                         │
│                     (Main Entry)                        │
│  ┌───────────────┐  ┌──────────────┐  ┌─────────────┐  │
│  │  CREAdapter   │  │ MarketFactory│  │ Settlement  │  │
│  │ (Oracle Hub)  │  │ (PF Validate)│  │ Engine      │  │
│  └───────┬───────┘  └──────────────┘  └─────────────┘  │
│          │                                              │
│  ┌───────┴───────┐  ┌──────────────┐  ┌─────────────┐  │
│  │ AccessManager │  │  RiskEngine  │  │  DataTypes   │  │
│  │ (CRE_ROLE)    │  │              │  │ (PriceFeed)  │  │
│  └───────────────┘  └──────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## Deployed Contracts (Base Sepolia)

| Contract | Address |
|---|---|
| **Verity Core** | `0xfb726Eb9F3620dd6a2351fa1121D2127f6Af2929` |
| **PositionToken** | `0x02df90A46453F02Bc78Cd7793bb1E3344481b42c` |
| **MockUSDC** | `0x9643419d69363278Bf74aA1494c3394aBF9E25da` |

### Chainlink Price Feeds Used (Base Sepolia)

| Pair | Address | Decimals |
|---|---|---|
| **ETH/USD** | `0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1` | 8 |
| **BTC/USD** | `0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298` | 8 |

---

## Files that use Chainlink

| File | Chainlink Usage |
|---|---|
| [`src/adapters/CREAdapter.sol`](src/adapters/CREAdapter.sol) | Core Chainlink integration layer. Routes incoming CRE reports (delivered via Keystone Forwarder) to internal handlers: market creation (ACTION=1), manipulation reporting (ACTION=2), and market resolution (ACTION=3). Strips the 109-byte CRE header envelope before ABI-decoding payloads. |
| [`src/modules/MarketFactory.sol`](src/modules/MarketFactory.sol) | Validates Chainlink Price Feed addresses for `CryptoPrice` category markets. Requires non-zero `targetValue` and valid `priceFeedAddress` — these are stored on-chain so CRE-3 can deterministically resolve the market via `latestRoundData()`. |
| [`src/libraries/DataTypes.sol`](src/libraries/DataTypes.sol) | Defines `MarketCategory.CryptoPrice` (category 0 — resolved via Chainlink Price Feed) and the `ResolutionMeta` struct containing `int256 targetValue` (Chainlink 8-decimal format) and `address priceFeedAddress`. |
| [`src/Verity.sol`](src/Verity.sol) | Main contract that inherits `CREAdapter`. Receives oracle callbacks from Chainlink CRE workflows through the Keystone Forwarder. Exposes `proposeMarket()`, `placeBet()`, `requestSettlement()`, and `claimPayout()`. |
| [`src/security/AccessManager.sol`](src/security/AccessManager.sol) | Manages `CRE_ROLE` — the role granted to Chainlink oracle/forwarder addresses authorized to invoke CRE adapter functions. Only addresses with this role can deliver CRE reports. |
| [`src/mocks/MockKeystoneForwarder.sol`](src/mocks/MockKeystoneForwarder.sol) | Mock of the Chainlink Keystone Forwarder for local/hackathon testing. Simulates report delivery without requiring the actual Chainlink DON infrastructure. |

---

## CRE Action Types

The `CREAdapter` routes three action types from Chainlink CRE workflows:

| Action | Value | CRE Workflow | Description |
|---|---|---|---|
| `ACTION_CREATE_MARKET` | 1 | CRE-1 | AI-analyzed market passes risk check → create market on-chain |
| `ACTION_REPORT_MANIPULATION` | 2 | CRE-2 | Manipulation detected → pause market |
| `ACTION_RESOLVE_MARKET` | 3 | CRE-3 | Market deadline reached → resolve with outcome (YES/NO) |

---

## Project Structure

```
verity-sc/
├── src/
│   ├── Verity.sol                    # Main contract (entry point)
│   ├── adapters/
│   │   └── CREAdapter.sol            # Chainlink CRE report routing
│   ├── core/
│   │   └── VerityStorage.sol          # Storage layout
│   ├── libraries/
│   │   ├── DataTypes.sol              # Structs, enums (MarketCategory, ResolutionMeta)
│   │   ├── Errors.sol                 # Custom errors
│   │   └── Events.sol                 # Event definitions
│   ├── modules/
│   │   ├── MarketFactory.sol          # Market creation + Price Feed validation
│   │   ├── RiskEngine.sol             # Risk scoring
│   │   └── SettlementEngine.sol       # Payout logic
│   ├── security/
│   │   └── AccessManager.sol          # CRE_ROLE management
│   └── mocks/
│       └── MockKeystoneForwarder.sol  # Local Keystone Forwarder mock
├── script/                            # Deployment & interaction scripts
├── test/                              # Forge tests
├── DEPLOYED_ADDRESSES.md
└── foundry.toml
```

---

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/)

### Build

```bash
forge install
forge build
```

### Test

```bash
forge test
```

### Deploy

```bash
forge script script/Deploy.s.sol --rpc-url <BASE_SEPOLIA_RPC> --private-key <PRIVATE_KEY> --broadcast
```

---

## License

MIT
