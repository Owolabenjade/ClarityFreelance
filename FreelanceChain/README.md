# FreelanceChain: Decentralized Freelance Marketplace
FreelanceChain aims to create a decentralized, trustless environment where freelance transactions can be conducted without intermediaries. The platform enforces contract terms and handles payments, disputes, and reviews on-chain, allowing for efficient and secure freelance project management.

### Key Roles:
- **Client**: The user who posts a job and manages the project's milestones.
- **Freelancer**: The user who completes the job and submits deliverables for review.
- **Arbitrator**: The individual or entity assigned to resolve disputes between clients and freelancers.

## Features
- **Job and Milestone Management**: Allows the creation of jobs with multiple milestones, each associated with payment and deadlines.
- **Escrow System**: Funds are securely held until milestone completion or job resolution.
- **Dispute Resolution**: Includes functionality for dispute initiation, management, and arbitration.
- **User Ratings**: Clients and freelancers can rate each other post-project to encourage quality service.
- **Platform Fees**: Supports platform sustainability with configurable platform fees.

## How It Works
1. **Job Creation**: Clients initiate jobs with an assigned freelancer, specifying the total amount and milestones. An escrow system holds the funds until completion.
2. **Milestone Submission**: Freelancers submit deliverables for each milestone, which clients review and approve or reject.
3. **Dispute Resolution**: If disputes arise, clients or freelancers can initiate a dispute, which the arbitrator reviews.
4. **Finalization**: Upon successful completion of all milestones, funds are released to the freelancer, and both parties can rate each other.

## Practical Use Case
### Scenario
*Alice is a startup founder* who needs a website designed. She decides to use FreelanceChain to hire a designer, *Bob*, through a decentralized platform.

#### Step-by-Step Workflow
1. **Alice Creates a Job**: Alice posts a job on FreelanceChain with an initial payment of 1,000 STX and sets three milestones for the project (e.g., wireframes, initial design, final delivery). Each milestone has a set deadline and amount.
   
2. **Funds Escrowed**: The total funds (including a 5% platform fee) are transferred to FreelanceChain’s escrow, where they’re held until the milestones are completed.

3. **Bob Accepts the Job**: Bob reviews the job details and accepts the terms. He begins working on the first milestone, wireframes.

4. **Milestone Submission and Review**:
   - **Milestone 1**: Bob completes the wireframe and submits it through the contract. Alice reviews and approves it, releasing the first payment.
   - **Milestone 2**: Bob works on the initial design and submits it. Alice requests a few revisions, which Bob provides before Alice approves it.
   
5. **Dispute (Optional)**: If a milestone was contested, Alice or Bob could initiate a dispute. For instance, if Alice was dissatisfied with the quality of work, she could open a dispute. The arbitrator then reviews both sides and decides on fund allocation.

6. **Final Milestone and Rating**: Once Bob completes the final design and Alice approves it, the funds are released to Bob. Both Alice and Bob rate each other, contributing to their respective reputation scores on the platform.

By using FreelanceChain, Alice and Bob benefit from a secure, trustless environment without relying on a centralized freelance platform.

## Getting Started

### Prerequisites
- A Clarity development environment.
- Familiarity with Clarity smart contract language.
- STX tokens for testing and transactions.

### Setup
1. **Clone the repository**:
    ```bash
    git clone https://github.com/username/FreelanceChain
    cd FreelanceChain
    ```
2. **Install dependencies** (if applicable):
    ```bash
    npm install
    ```
3. **Deploy the contract**:
   Use Clarinet or any other Stacks development tool to deploy the contract.

### Running Tests
Run the test suite with Clarinet:
```bash
clarinet test
```
The tests cover various scenarios, including job creation, milestone management, dispute resolution, and rating.

## Functions
Below are some key functions within FreelanceChain.

### Public Functions
1. **create-job**:
   - Description: Creates a job with specified milestones.
   - Parameters: `job-id`, `freelancer`, `milestone-count`, `total-amount`.
   
2. **create-milestone**:
   - Description: Creates a milestone within a job.
   - Parameters: `job-id`, `milestone-id`, `amount`, `deadline`.
   
3. **submit-milestone**:
   - Description: Submits deliverables for a milestone.
   - Parameters: `job-id`, `milestone-id`, `deliverables`.

4. **initiate-dispute**:
   - Description: Starts a dispute if there is an issue with the job or milestone.
   - Parameters: `job-id`, `reason`, `evidence`.
   
5. **resolve-dispute**:
   - Description: Resolves an active dispute.
   - Parameters: `job-id`, `resolution`, `refund-percentage`.

6. **set-platform-fee**:
   - Description: Sets the platform fee for job transactions.
   - Parameters: `new-fee`.

### Read-Only Functions
1. **get-job-details**:
   - Returns details of a specific job.

2. **get-milestone-details**:
   - Returns milestone-specific information within a job.

3. **get-user-stats**:
   - Provides statistics for a user, including total jobs and rating count.

4. **get-dispute-details**:
   - Returns details of a dispute for a specified job.

## Testing
This contract includes validation and tests to handle key workflows:
- **Job and Milestone Creation**: Ensures jobs and milestones are accurately created.
- **Dispute Management**: Tests dispute initiation, response, and resolution.
- **Rating and Platform Fee Validation**: Validates user ratings and fee calculations.
- **Edge Cases**: Covers cases like deadline expiry, insufficient funds, and invalid inputs.

To run tests:
```bash
clarinet test
```