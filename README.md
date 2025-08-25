# 🛣️ Transparent Road Tax Tracker

A blockchain-based smart contract for transparent collection and allocation of road usage fees, enabling communities to see exactly where their tax dollars go.

## 🎯 Overview

The Transparent Road Tax Tracker creates an on-chain pool where road usage fees are collected and transparently allocated to infrastructure projects. Communities can propose projects, vote on allocations, and track every penny spent on road improvements.

## ✨ Features

- 💰 **Tax Collection**: Pay road usage fees directly to the on-chain pool
- 🏗️ **Project Proposals**: Submit infrastructure projects for funding consideration  
- 🗳️ **Community Voting**: Taxpayers vote on which projects should receive funding
- 📊 **Fund Allocation**: Transparent distribution of collected taxes to approved projects
- 👥 **Representative System**: Community representatives help manage the process
- 📈 **Usage Tracking**: Calculate taxes based on miles driven
- 📋 **Allocation History**: Complete audit trail of all fund distributions

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Installation
```bash
git clone https://github.com/yourusername/Transparent-Road-Tax-Tracker
cd Transparent-Road-Tax-Tracker
clarinet check
```

## 📖 Usage

### 💳 Paying Road Tax
```clarity
(contract-call? .transparent-road-tax-tracker pay-road-tax u1000)
```

### 🏗️ Proposing a Project
```clarity
(contract-call? .transparent-road-tax-tracker propose-project 
  "Highway Bridge Repair" 
  "Repair the damaged bridge on Route 101" 
  u50000)
```

### 🗳️ Voting for Projects
```clarity
(contract-call? .transparent-road-tax-tracker vote-for-project u1)
```

### 📊 Checking Pool Balance
```clarity
(contract-call? .transparent-road-tax-tracker get-pool-balance)
```

### 🔍 Getting Project Details
```clarity
(contract-call? .transparent-road-tax-tracker get-project u1)
```

## 🔧 Administrative Functions

### 💰 Allocating Funds (Owner Only)
```clarity
(contract-call? .transparent-road-tax-tracker allocate-funds u1 u25000)
```

### 👤 Managing Representatives (Owner Only)
```clarity
(contract-call? .transparent-road-tax-tracker add-community-representative 'SP123...)
```

### ⚙️ Updating Tax Rate (Owner Only)
```clarity
(contract-call? .transparent-road-tax-tracker update-tax-rate u150)
```

## 📋 Read-Only Functions

- `get-pool-balance` - Current total in the tax pool
- `get-taxpayer-contribution` - Individual taxpayer's total contributions
- `get-project` - Full project details by ID
- `get-project-votes` - Vote count for a specific project
- `has-voted` - Check if address has voted on a project
- `get-allocation-history` - Details of fund allocations
- `is-community-representative` - Check representative status
- `get-tax-rate` - Current tax rate per mile
- `calculate-tax` - Calculate tax for given mileage
- `get-contract-info` - Overview of contract state
- `get-top-voted-projects` - Projects ranked by votes

## 🏗️ Contract Structure

### Data Variables
- `total-pool-balance` - Total STX collected in taxes
- `next-project-id` - Counter for project IDs
- `tax-rate` - STX per mile driven (in microSTX)

### Maps
- `taxpayers` - Track individual contributions
- `projects` - Store project proposals and details
- `project-votes` - Record voting participation
- `community-representatives` - Authorized community members
- `allocation-history` - Complete audit trail

## 🔒 Security Features

- Owner-only administrative functions
- Vote validation (taxpayers only)
- Double-voting prevention
- Fund allocation controls
- Emergency withdrawal capability

## 🎛️ Error Codes

- `u100` - Owner only
- `u101` - Insufficient funds
- `u102` - Invalid amount
- `u103` - Project not found
- `u104` - Already voted
- `u105` - Voting period ended
- `u106` - Not authorized

## 🧪 Testing

```bash
clarinet test
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🌟 Roadmap

- [ ] Mobile app integration
- [ ] Automated mileage tracking
- [ ] Multi-jurisdiction support
- [ ] Advanced reporting dashboard
- [ ] Integration with existing tax systems
