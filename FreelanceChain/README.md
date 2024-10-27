# Freelance Escrow Smart Contract Documentation

## Overview
This smart contract facilitates secure freelance work arrangements by implementing a milestone-based escrow system. It ensures fair transactions between clients and freelancers while maintaining payment security through smart contract automation.

## Key Features
- Milestone-based payment release
- Built-in platform fee mechanism (5%)
- Secure fund holding
- Automated payment distribution
- Deadline tracking per milestone

## Use Case Scenario: Web Development Project

### Initial Setup
Alice (Client) wants to hire Bob (Freelancer) for a web development project with the following details:
- Total Budget: 10,000 STX
- Number of Milestones: 4
- Platform Fee: 500 STX (5% of 10,000 STX)

### Step-by-Step Workflow

1. **Project Creation**
```clarity
;; Alice creates the job
(contract-call? .freelance-escrow create-job 
    u1                  ;; job-id
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; Bob's address
    u4                  ;; 4 milestones
    u10000             ;; 10,000 STX total amount
)
```
- Alice deposits 10,500 STX (project amount + platform fee)
- Contract creates job record with status "active"
- Funds are securely held in the contract

2. **Milestone Setup**
```clarity
;; Alice sets up milestones
(contract-call? .freelance-escrow set-milestone
    u1                  ;; job-id
    u0                  ;; first milestone
    u2500              ;; 2,500 STX for first milestone
    u1682899200        ;; deadline timestamp
)
```
Milestone breakdown:
- Milestone 1 (2,500 STX): Initial design and wireframes
- Milestone 2 (2,500 STX): Frontend development
- Milestone 3 (2,500 STX): Backend integration
- Milestone 4 (2,500 STX): Testing and deployment

3. **Work Progress and Completion**
- Bob works on each milestone
- Upon milestone completion, Bob notifies Alice
- Alice reviews the work and if satisfied:
```clarity
;; Alice approves milestone completion
(contract-call? .freelance-escrow complete-milestone
    u1                  ;; job-id
    u0                  ;; milestone-id
)
```
- Smart contract automatically transfers 2,500 STX to Bob
- Milestone status updates to "completed"

4. **Project Tracking**
Participants can check status anytime:
```clarity
;; Check job details
(contract-call? .freelance-escrow get-job-details u1)

;; Check specific milestone
(contract-call? .freelance-escrow get-milestone-details u1 u0)
```

## Security Features

1. **Fund Security**
- Client's funds are locked in the contract
- Release only happens upon milestone approval
- No direct withdrawal without completion

2. **Authorization Checks**
- Only the client can approve milestones
- Only the client can set milestone details
- System prevents unauthorized access

3. **State Management**
- Clear status tracking for jobs and milestones
- Prevents double-payments
- Maintains payment sequence integrity

## Benefits

1. **For Clients**
- Protected funds through escrow
- Milestone-based risk management
- Clear progress tracking
- No need for traditional escrow services

2. **For Freelancers**
- Guaranteed payment for completed work
- Clear milestone definitions
- Automated payments
- Reduced payment disputes

3. **For Platform**
- Automated fee collection
- Transparent transaction handling
- Reduced administrative overhead
- Scalable business model

## Error Handling
The contract handles common scenarios:
- ERR-NOT-AUTHORIZED (u1): Unauthorized access attempt
- ERR-INSUFFICIENT-FUNDS (u2): Insufficient balance for job creation
- ERR-INVALID-STATE (u3): Invalid job or milestone state

## Best Practices
1. Set realistic milestone deadlines
2. Keep milestone amounts proportional to work
3. Clearly define deliverables for each milestone
4. Regular progress checking using get-job-details
5. Prompt milestone approval upon satisfactory completion

This system provides a trustless, automated solution for freelance work management, ensuring fair and secure transactions for all parties involved.