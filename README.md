 **EcoTrack – Smart Waste Management Token System**

##  Overview

**EcoTrack** is a decentralized smart contract designed to encourage proper waste management using blockchain transparency and token incentives.
Users submit waste reports, verifiers validate them, and the system rewards environmentally responsible behavior with **ECO tokens**.

This project demonstrates how blockchain can support sustainability by promoting community participation and data integrity.

---

##  Features

###  **User Features**

* Create a user profile
* Submit waste reports including type & weight
* Earn ECO tokens for verified submissions
* Track ECO balance and submission history

###  **Verifier Features**

* Approve or reject waste submissions
* Award ECO tokens based on weight (reward-per-kg)
* Prevent duplicate or fraudulent verifications

###  **Admin Features**

* Add/remove verifiers
* Transfer admin role
* Configure verification authority

###  **ECO Token**

* Minted when a submission is verified
* Transparent reward mechanism
* Tracks ecological contribution

---

##  Contract Architecture

### **Core Data Maps**

| Map                | Purpose                              |
| ------------------ | ------------------------------------ |
| `users`            | Stores user profiles & ECO balance   |
| `verifiers`        | Registered verification authorities  |
| `submissions`      | Waste entries with status & metadata |
| `user-submissions` | Links users to their submission IDs  |

### **Important Constants**

* `ERR-NOT-ADMIN`
* `ERR-NOT-VERIFIER`
* `ERR-NOT-REGISTERED`
* `ERR-SUBMISSION-NOT-FOUND`
* `ERR-ALREADY-VERIFIED`

---

## Project Structure

```
EcoTrack/
│
├── contracts/
│   └── EcoTrack.clar
│
├── tests/
│   └── eco-track_test.ts
│
├── Clarinet.toml
└── README.md
```

---

## Installation & Setup

### **1. Install Clarinet**

```
npm install -g @hirosystems/clarinet
```

### **2. Initialize project**

```
clarinet new ecotrack
```

### **3. Add contract**

Place `EcoTrack.clar` in the `contracts/` folder.

### **4. Run tests**

```
clarinet test
```

### **5. Check contract syntax**

```
clarinet check
```

---

##  Test Scenarios

Recommended test cases include:

* User registration
* Waste submission
* Verifier approves submission
* Verifier rejects submission
* ECO tokens mint correctly
* Error handling (invalid verifier, duplicate verification, etc.)

---

##  On-Chain Events

EcoTrack emits events for full transparency:

* `submission-created`
* `submission-verified`
* `submission-rejected`
* `verifier-added`
* `verifier-removed`
* `admin-changed`

---

##  Smart Contract Highlights

* Clean, readable Clarity code
* Well-structured functions
* Secure access control
* Professional error handling
* Fully optimized for Clarinet

---

## Contributing

Pull requests are welcome!

Please ensure your PR includes:

* Clear title
* Description of changes
* Relevant test updates


##  License

This project is licensed under the **MIT License**.
