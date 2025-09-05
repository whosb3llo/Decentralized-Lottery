# 🎰 Decentralized Lottery (Lotto)

A transparent, on-chain lottery system built on Stacks blockchain where tickets and winning numbers are generated and verified by smart contracts.

## 🎯 Features

- 🎫 **Buy Lottery Tickets**: Purchase tickets with STX tokens
- 🎲 **Provably Fair Drawing**: Uses block hash randomness for winner selection
- 💰 **Automatic Prize Distribution**: Winners claim prizes directly from the contract
- 📊 **Complete Transparency**: All lottery data stored on-chain
- 🔄 **Multiple Rounds**: Start new lotteries after each draw
- 💸 **Bulk Ticket Purchase**: Buy up to 10 tickets at once
- 🎯 **Referral System**: Earn 10% rewards from referred users' ticket purchases
- 🛡️ **Emergency Controls**: Owner can stop lottery if needed

## 🏗️ Contract Overview

- **Ticket Price**: 1 STX (1,000,000 microSTX)
- **Minimum Tickets**: 10 tickets required before drawing
- **Winner Prize**: 80% of total prize pool
- **Owner Fee**: 5% of total prize pool
- **Maximum Tickets per User**: 20 per lottery round

## 🚀 Usage Instructions

### Starting a Lottery
```clarity
(contract-call? .Lotto start-lottery)
```

### Buying Tickets
```clarity
;; Buy single ticket
(contract-call? .Lotto buy-ticket)

;; Buy multiple tickets (1-10)
(contract-call? .Lotto buy-multiple-tickets u3)
```

### Drawing Winner
```clarity
(contract-call? .Lotto draw-winner)
```

### Claiming Prize
```clarity
(contract-call? .Lotto claim-prize)
```

### Referral System
```clarity
;; Set a referrer (one-time only)
(contract-call? .Lotto set-referrer 'SP1234567890...)

;; Claim referral rewards (minimum 0.05 STX)
(contract-call? .Lotto claim-referral-rewards)
```

### Getting Lottery Information
```clarity
;; Current lottery status
(contract-call? .Lotto get-lottery-info)

;; Your tickets for current lottery
(contract-call? .Lotto get-user-tickets tx-sender (var-get lottery-id))

;; Check if you can draw
(contract-call? .Lotto can-draw)

;; Current odds (total tickets)
(contract-call? .Lotto get-odds)

;; Referral information
(contract-call? .Lotto get-referral-info tx-sender)
(contract-call? .Lotto get-user-referrer tx-sender)
(contract-call? .Lotto get-referral-stats)
```

## 📋 Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-lottery-info` | Current lottery status and details |
| `get-user-tickets` | User's tickets for specific lottery |
| `get-ticket-owner` | Owner of specific ticket |
| `get-current-winner` | Current lottery winner info |
| `get-lottery-history` | Historical lottery data |
| `get-winning-details` | Winning number and draw details |
| `can-draw` | Whether lottery can be drawn |
| `calculate-potential-winnings` | Current potential prize amount |
| `get-odds` | Current odds (total tickets sold) |
| `is-ticket-winner` | Check if specific ticket won |
| `get-user-winning-status` | Check if user won specific lottery |
| `get-referral-info` | Get referrer's reward stats |
| `get-user-referrer` | Get user's referrer information |
| `get-referral-stats` | Global referral system statistics |
| `calculate-referral-earnings` | Calculate potential referral earnings |
| `has-referrer` | Check if user has set a referrer |

## 🔧 Development Setup

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js for development dependencies

### Running Tests
```bash
clarinet check
clarinet test
```

### Local Development
```bash
clarinet console
```

## 🎮 Example Workflow

1. **🎬 Start Lottery**: Owner calls `start-lottery`
2. **🎯 Set Referrer**: New players can set a referrer with `set-referrer` (optional, one-time only)
3. **🎫 Buy Tickets**: Players call `buy-ticket` or `buy-multiple-tickets` (referrers earn 10% rewards)
4. **⏳ Wait for Minimum**: Need at least 10 tickets sold
5. **🎲 Draw Winner**: Owner calls `draw-winner` (uses block hash for randomness)
6. **💰 Claim Prize**: Winner calls `claim-prize` to receive 80% of prize pool
7. **🎁 Claim Referral Rewards**: Referrers call `claim-referral-rewards` (minimum 0.05 STX)
8. **🔄 Repeat**: Start new lottery for next round

## 🔐 Security Features

- 🛡️ **Owner Controls**: Only contract owner can start lottery and draw winners
- 💳 **Payment Validation**: Automatic STX transfer validation
- 🎯 **Fair Randomness**: Uses Stacks block hash for unpredictable results
- 🚫 **Double-Claim Prevention**: Winners can only claim once
- 🔒 **Referral Protection**: Users can only set one referrer, no self-referrals
- ⛔ **Emergency Stop**: Owner can halt lottery if needed

## 📊 Prize Distribution

- **80%** → Winner
- **15%** → Next lottery prize pool (automatic rollover)
- **5%** → Contract owner (maintenance fee)

## 🏆 Lottery Stats

Each completed lottery stores:
- Total tickets sold
- Final prize pool amount
- Winning ticket number
- Block height of draw
- Winner address and claim status

## 🛠️ Error Codes

| Code | Description |
|------|-------------|
| `u100` | Unauthorized access |
| `u101` | Invalid amount |
| `u102` | Lottery not active |
| `u103` | Lottery already active |
| `u104` | Insufficient tickets sold |
| `u105` | Winner already drawn |
| `u106` | Not the winner |
| `u107` | Prize already claimed |
| `u108` | Invalid ticket |
| `u109` | Invalid referrer |
| `u110` | Cannot refer yourself |
| `u111` | Referrer already set |

---

Built with ❤️ on Stacks blockchain for transparent and fair lottery gaming.
