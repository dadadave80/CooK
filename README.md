# CooK: Uniswap V4 Hook for Atomic Market Purchases & Privacy

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Solidity](https://img.shields.io/badge/Solidity-0.8.26-blue)
![Uniswap V4](https://img.shields.io/badge/Uniswap-V4-pink)
![Fhenix](https://img.shields.io/badge/Fhenix-FHE-green)

**CooK** is a cutting-edge experiment in decentralized verified commerce, combining **Uniswap V4 Hooks** with **Fully Homomorphic Encryption (FHE)** to create a seamless, private, and atomic "Swap-to-Buy" marketplace experience.

---

## Contract Addresses
- PotatoHook - https://sepolia.uniscan.xyz/address/0xe04441507ae1175cfbd8eba0a9389b0126ebe0cc#code
- Market - https://sepolia.uniscan.xyz/address/0x95e8136a95eDD41EEE8d2b2Eb9FA4E6216927378#code
- MockUSDC - https://sepolia.uniscan.xyz/address/0xE1B4C15D27Ae552FAF14A08C3b27DD46E780EA0F#code

## 📖 Table of Contents

- [Project Overview](#-project-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Technical Deep Dive](#-technical-deep-dive)
- [Installation & Setup](#-installation--setup)
- [Usage](#-usage)
- [Deployment](#-deployment)
- [Security Considerations](#-security-considerations)
- [Testing](#-testing)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🔭 Project Overview

### The Problem
Traditional NFT marketplaces require users to:
1. Hold the specific payment token (e.g., USDC).
2. Approve the marketplace contract.
3. Execute a separate transaction to purchase.

This creates friction and exposes users to price volatility during the process. Furthermore, on-chain asset ownership is typically entirely public, revealing user purchasing habits and holdings to the world.

### The Solution
**CooK** leverages:
1. **Uniswap V4 Hooks** (`PotatoHook.sol`): Enables users to purchase items *atomically* during a token swap. You can pay with *any* token (ETH, PEPE, WBTC), and the hook handles the conversion to USDC and settlement with the marketplace in a single transaction.
2. **Fhenix FHE** (`Listing.sol`): Provides *encrypted* privacy for item ownership. Balances can be private, allowing users to hold digital goods without revealing their inventory to the public ledger.

### Value Proposition
*   **Atomic "Swap-to-Buy"**: Buy real-world assets or digital goods with any liquid token in one click.
*   **Privacy by Default**: Option to wrap assets into a privacy-preserving FHE layer.
*   **Modular Marketplace**: Independent listings created via a factory pattern.

---

## ✨ Features

### 🥔 PotatoHook (Swap-to-Buy)
A specialized Uniswap V4 Hook that intercepts swaps.
*   **Integration**: Attaches to liquidity pools (e.g., ETH/USDC or PEPE/USDC).
*   **Logic**: If checks pass, it re-routes the swap output (USDC) directly to the marketplace to fund a purchase, instead of sending it to the user.
*   **Efficiency**: Gas-optimized settlement within the `afterSwap` lifecycle.

### 🏪 Market Core
A robust marketplace contract (`Market.sol`) allowing creators to sell goods.
*   **Listing Factory**: Deploys minimal proxy clones for each new listing item to save gas.
*   **USDC Standard**: All prices are denominated in USDC for stability.
*   **Role-Based Access**: Fine-grained control over listing management.

### 🕵️ FHE Privacy Listings
Listings are ERC1155 tokens enhanced with Fhenix.
*   **Encrypted Balances**: Users can `wrap` tokens to hide their balance.
*   **Private Transfers**: Transfer assets without revealing amounts or receiver holdings (if fully private).
*   **Selective Disclosure**: Users can view their own decrypted balances via permissioned view functions.

---

## 🏗 Architecture

The system consists of three main layers: The **Liquidity Layer** (Uniswap V4), the **Orchestration Layer** (Hook & Market), and the **Asset Layer** (Listings).

```mermaid
flowchart LR
    User[User] -- "1. Swap(ETH -> USDC) + HookData" --> Router[Uniswap Router]
    
    subgraph Uniswap V4
        PM[PoolManager] -- "2. swap()" --> Hook[PotatoHook]
    end
    
    subgraph CooK System
        Hook -- "3. validate & pull USDC" --> Market[Market.sol]
        Market -- "4. mint()" --> Listing[Listing.sol (ERC1155 + FHE)]
    end
    
    Router --> PM
    Hook -. "5. Purchase Settlement" .- PM
```

### Critical Flow: Swap-to-Buy
1.  **Initiation**: User calls `router.swap()` with `hookData` encoding the `listingId` and `recipient`.
2.  **Execution**: Uniswap executes the swap (e.g., ETH -> USDC).
3.  **Interception**: `PotatoHook.afterSwap` detects the `hookData`.
    *   Verifies the swap output (USDC) covers the item price.
    *   Takes the USDC from the PoolManager.
    *   Approves the Market contract.
4.  **Purchase**: Hook calls `Market.purchase()`.
5.  **Settlement**: Market transfers USDC to the Seller and mints the Item (NFT) to the User.
6.  **Finalization**: The User receives the Item instead of the USDC they swapped for.

---

## 🔬 Technical Deep Dive

### Smart Contracts

#### `PotatoHook.sol`
*   **Type**: `BaseHook`
*   **Key Delta**: `beforeSwap` validates intents. `afterSwap` handles the movement of funds. It uses `poolManager.take()` to seize the USDC output of a swap before it reaches the user, effectively "spending" the swap result immediately.

#### `Market.sol`
*   **Pattern**: Clones Factory (Solady `LibClone`).
*   **Functionality**:
    *   `createListing`: Deploys a new `Listing` contract deterministically (CREATE2).
    *   `purchase`: Handles the secure transfer of USDC from Buyer -> Seller and calls `mint` on the Listing.
    *   `purchaseWithToken`: A helper to route swaps from the Market interface itself.

#### `Listing.sol`
*   **Standards**: ERC1155, AccessControl.
*   **Privacy**: Uses `FHE.euint128` to store private balances.
    *   `wrap(uint256 id, uint256 amount)`: Burn public token -> Mint private encrypted balance.
    *   `unwrap(uint256 id, inEuint128 amount)`: Burn private encrypted balance -> Mint public token.

### Security Assumptions
*   **Stablecoin Validity**: The system enforces checks to ensure the pool involves a valid USDC token defined at deployment.
*   **Price Solvency**: The Hook verifies `delta.amount` (swap output) >= `listing.price * quantity` before execution.
*   **Access Control**: Listings are `Ownable` by the Market, ensuring only the Market can mint tokens upon confirmed payment.

---

## 🛠 Installation & Setup

### Prerequisites
*   [Foundry](https://getfoundry.sh/) (Forge, Cast, Anvil)
*   [Git](https://git-scm.com/)

### Setup
1.  **Clone the Repository**
    ```bash
    git clone https://github.com/dadadave80/cook.git
    cd cook
    ```

2.  **Install Dependencies**
    ```bash
    forge install
    ```

3.  **Build Project**
    ```bash
    forge build
    ```

---

## 🚀 Usage

### Local Development / Testing
Run the test suite to verify core functionality:

```bash
# Run all tests
forge test

# Run specific integration test
forge test --match-contract PotatoHookTest -vv
```

### Integration Example (Solidity)
If integrating via a Router or smart contract:

```solidity
// Prepare Hook Data
PurchaseData memory data = PurchaseData({
    listingId: 1,
    quantity: 1,
    recipient: msg.sender
});
bytes memory hookData = abi.encode(data);

// Execute Swap via Router
// The router will pass hookData to the Pool/Hook
router.swap(
    key,
    params,
    testSettings,
    hookData // <--- Triggers the Purchase
);
```

---

## 🚢 Deployment

Deployment scripts are located in `script/`. You need to set up your environment variables first.

1.  **Configure Environment**
    Create a `.env` file:
    ```ini
    PRIVATE_KEY=0x...
    RPC_URL=https://...
    USDC_ADDRESS=0x...
    ```

2.  **Deploy System**
    ```bash
    forge script script/00_DeployHook.s.sol \
        --rpc-url $RPC_URL \
        --broadcast
    ```

This script will:
*   Deploy the `Market` logic.
*   Mine a salt for `PotatoHook` to ensure valid hook address flags.
*   Deploy `PotatoHook` via `HookMiner`.

---

## 🛡 Security Considerations

*   **Slippage**: Users must set appropriate slippage on their ETH->USDC swap. If the swap returns less USDC than the item price, the transaction REVERTS to protect the user from failed purchases.
*   **Reentrancy**: The Market follows Checks-Effects-Interactions. `safeTransferFrom` (USDC) is called before the external call to `mint`.
*   **Hook Malice**: The Hook has `ACCESS_CONTROL`. Only the admin can pause/unpause. Ensure you trust the hook deployer or that ownership is renounced.

---

## 🧪 Testing

The codebase includes comprehensive Foundry tests covering:

*   `Listing.t.sol`: FHE wrapping/unwrapping, access control.
*   `Market.t.sol`: Listing creation, direct purchasing, routing.
*   `PotatoHook.t.sol`: The complex swap-to-purchase flow, validating deltas and solvency checks.

To run FHE tests, you may need a local Fhenix devnet or mock environment if strictly testing logic without encryption pre-compiles.

```bash
forge test
```

---

## 🤝 Contributing

Contributions are welcome!

1.  One-line fixes: Submit a PR directly.
2.  Major features: Open an ISSUE first to discuss the design.
3.  Please ensure `forge test` passes before submitting.
4.  Follow existing Solidity style guides (naming conventions, layout).

---

## 📄 License

This project is licensed under the **MIT License**.
