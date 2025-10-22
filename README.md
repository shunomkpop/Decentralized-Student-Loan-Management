# 🎓 LoanChain - Decentralized Student Loan Management

> A trustless blockchain system for managing and tracking student loans with immutable repayment records 📚💰

## 🚀 Overview

LoanChain revolutionizes student loan management by providing a transparent, decentralized platform where borrowers and lenders can interact directly without traditional financial intermediaries. Every transaction is recorded immutably on the Stacks blockchain.

## ✨ Features

- 🎯 **Direct Loan Applications** - Students apply directly to lenders
- ✅ **Transparent Approval Process** - Clear approval/rejection workflow
- 💳 **Flexible Repayment System** - Monthly payment tracking with interest calculation
- 📊 **Credit Score Integration** - Built-in credit scoring and user verification
- 📈 **Loan Health Monitoring** - Real-time tracking of payment performance
- ⏸️ **Emergency Controls** - Pause/resume functionality for exceptional circumstances
- 📚 **Complete Payment History** - Immutable record of all transactions

## 🛠️ Installation & Setup

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Node.js](https://nodejs.org/) for testing

### Setup
```bash
git clone <repository-url>
cd Decentralized-Student-Loan-Management
clarinet check
```

## 📖 Usage Guide

### 🎓 For Borrowers

#### 1. Create a Loan Application
```clarity
(contract-call? .LoanChain create-loan-application 
    'SP1LENDER123...  ;; lender address
    u50000           ;; $500.00 principal amount
    u800             ;; 8% annual interest rate
    u48              ;; 48 month term
)
```

#### 2. Make Monthly Payments
```clarity
(contract-call? .LoanChain make-payment 
    u1      ;; loan ID
    u1250   ;; payment amount
)
```

#### 3. Check Your Loans
```clarity
(contract-call? .LoanChain get-borrower-loans tx-sender)
```

### 🏦 For Lenders

#### 1. Approve a Loan Application
```clarity
(contract-call? .LoanChain approve-loan u1)
```

#### 2. Reject a Loan Application
```clarity
(contract-call? .LoanChain reject-loan u1)
```

#### 3. Monitor Your Portfolio
```clarity
(contract-call? .LoanChain get-lender-loans tx-sender)
```

### 🔍 Monitoring & Analytics

#### Get Loan Details
```clarity
(contract-call? .LoanChain get-loan u1)
```

#### Check Payment History
```clarity
(contract-call? .LoanChain get-payment-history u1 u5)
```

#### Monitor Loan Health
```clarity
(contract-call? .LoanChain calculate-loan-health u1)
```

#### Platform Statistics
```clarity
(contract-call? .LoanChain get-platform-metrics)
```

## 📊 Data Structure

### Loan Object
```clarity
{
    borrower: principal,
    lender: principal,
    principal-amount: uint,
    interest-rate: uint,        ;; Basis points (800 = 8%)
    term-months: uint,
    monthly-payment: uint,
    amount-paid: uint,
    created-at: uint,
    status: string-ascii,       ;; "pending", "active", "completed", "paused", "rejected"
    last-payment: uint
}
```

### User Profile
```clarity
{
    total-borrowed: uint,
    total-lent: uint,
    credit-score: uint,         ;; 300-850 range
    verified: bool
}
```

## 🎛️ Admin Functions

### Update Credit Scores
```clarity
(contract-call? .LoanChain update-credit-score 
    'SP1USER123...  ;; user address
    u750            ;; new credit score
)
```

### Verify Users
```clarity
(contract-call? .LoanChain verify-user 'SP1USER123...)
```

## 🚨 Emergency Controls

### Pause a Loan
```clarity
(contract-call? .LoanChain emergency-pause-loan u1)
```

### Resume a Loan
```clarity
(contract-call? .LoanChain resume-loan u1)
```

## 🧮 Interest Calculation

The contract uses compound interest calculation with the formula:
```
Monthly Payment = P × [r(1+r)^n] / [(1+r)^n - 1]
```

Where:
- **P** = Principal amount
- **r** = Monthly interest rate (annual rate / 12)
- **n** = Number of months

## 🔒 Security Features

- ✅ Principal validation and authorization checks
- ✅ Input sanitization and bounds checking
- ✅ Overflow protection in calculations
- ✅ Status-based access control
- ✅ Emergency pause mechanism

## 📝 Error Codes

| Code | Description |
|------|-------------|
| u400 | Insufficient Funds |
| u401 | Unauthorized Access |
| u402 | Payment Too Low |
| u403 | Loan Not Active |
| u404 | Loan Not Found |
| u409 | Loan Already Exists |
| u410 | Loan Fully Paid |
| u422 | Invalid Amount |

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

Check contract syntax:
```bash
clarinet check
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Run `clarinet check` to verify syntax
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

---

*Built with ❤️ for the decentralized future of education financing* 🎓🌟
