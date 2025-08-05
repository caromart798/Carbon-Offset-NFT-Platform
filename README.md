# 🌱 Carbon Offset NFT Platform

A blockchain-based platform for trading verified carbon offset credits as NFTs, enabling transparent and auditable carbon footprint reduction.

## 🌍 Overview

This smart contract platform allows users and companies to purchase, trade, and retire carbon offset NFTs that represent verified carbon credits. Each NFT is backed by real environmental projects and can be traced throughout its lifecycle.

## ✨ Features

- 🏭 **Project Registration**: Certified verifiers can register carbon offset projects
- 🎫 **NFT Minting**: Create tradeable NFTs representing carbon credits
- 💰 **Marketplace**: Buy and sell carbon offset NFTs
- ♻️ **Retirement System**: Permanently retire offsets to claim environmental impact
- 📊 **Analytics**: Track platform and user statistics
- 🔐 **Verification**: Only certified verifiers can create projects

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
clarinet new carbon-offset-platform
cd carbon-offset-platform
```

Copy the contract code into `contracts/Carbon-Offset-NFT-Platform.clar`

### Testing

```bash
clarinet console
```

## 📋 Usage

### For Platform Administrators

#### Register a Verifier
```clarity
(contract-call? .Carbon-Offset-NFT-Platform register-verifier 'ST1VERIFIER "EcoVerify Corp")
```

#### Update Platform Fee
```clarity
(contract-call? .Carbon-Offset-NFT-Platform update-platform-fee u200)
```

### For Verifiers

#### Register a Carbon Project
```clarity
(contract-call? .Carbon-Offset-NFT-Platform register-project "FOREST-001" u10000)
```

#### Mint Carbon Offset NFT
```clarity
(contract-call? .Carbon-Offset-NFT-Platform mint-offset-nft 
  'ST1BUYER 
  "FOREST-001" 
  u100 
  "VCS" 
  u2023 
  "Reforestation" 
  "Brazil" 
  u1000000)
```

### For Users

#### Purchase Carbon Offset
```clarity
(contract-call? .Carbon-Offset-NFT-Platform purchase-offset u1)
```

#### Retire Carbon Offset
```clarity
(contract-call? .Carbon-Offset-NFT-Platform retire-offset u1)
```

#### Transfer NFT
```clarity
(contract-call? .Carbon-Offset-NFT-Platform transfer u1 tx-sender 'ST1RECIPIENT)
```

## 📊 Data Queries

### Get Offset Details
```clarity
(contract-call? .Carbon-Offset-NFT-Platform get-offset-details u1)
```

### Get User Statistics
```clarity
(contract-call? .Carbon-Offset-NFT-Platform get-user-stats 'ST1USER)
```

### Get Platform Statistics
```clarity
(contract-call? .Carbon-Offset-NFT-Platform get-platform-stats)
```

### Get Project Information
```clarity
(contract-call? .Carbon-Offset-NFT-Platform get-project-info "FOREST-001")
```

## 🏗️ Contract Structure

### Data Storage
- **NFT Collection**: `carbon-offset-nft`
- **Offset Details**: Project info, carbon amount, verification standard
- **Project Registry**: Verified projects and available credits
- **User Statistics**: Purchase and retirement history
- **Verifier Registry**: Certified verification entities

### Key Functions
- `mint-offset-nft`: Create new carbon offset NFTs
- `purchase-offset`: Buy existing offsets from marketplace
- `retire-offset`: Permanently retire offsets for environmental claims
- `register-project`: Add new verified carbon projects
- `register-verifier`: Authorize new verification entities

## 🔒 Security Features

- Owner-only administrative functions
- Verifier certification requirements
- Credit availability validation
- Double-retirement prevention
- Transfer authorization checks

## 💡 Use Cases

- 🏢 **Corporate ESG**: Companies offsetting their carbon footprint
- 🌿 **Individual Impact**: Personal carbon neutrality goals
- 📈 **Carbon Trading**: Marketplace for carbon credit speculation
- 🎯 **Project Funding**: Direct funding for environmental projects
- 📋 **Compliance**: Meeting regulatory carbon requirements

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

---

*Building a sustainable future, one NFT at a time* 🌍💚
```

**Git Commit Message:**
```
feat: implement carbon offset NFT platform with verifiable credits and retirement system
```

**GitHub Pull Request Title:**
```
🌱 Add Carbon Offset NFT Platform Smart Contract
```

**GitHub Pull Request Description:**
```
## 🌍 Carbon Offset NFT Platform Implementation

This PR introduces a comprehensive smart contract platform for trading verified carbon offset credits as NFTs
