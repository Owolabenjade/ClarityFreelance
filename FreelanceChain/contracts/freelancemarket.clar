;; FreelanceChain: A Decentralized Freelance Marketplace Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-FUNDS (err u2))
(define-constant ERR-INVALID-STATE (err u3))
(define-constant ERR-DEADLINE-PASSED (err u4))
(define-constant ERR-INVALID-RATING (err u5))
(define-constant ERR-INVALID-JOB-ID (err u6))
(define-constant ERR-INVALID-PARAMS (err u7))
(define-constant ERR-INVALID-STRING-LENGTH (err u8))
(define-constant MIN-REASON-LENGTH u10)
(define-constant MIN-EVIDENCE-LENGTH u20)
(define-constant DISPUTE-RESOLUTION-PERIOD u1440) ;; Blocks (approximately 10 days)
(define-constant RATING-DECIMALS u100)

;; Data Variables
(define-data-var platform-fee uint u5) ;; 5% platform fee
(define-data-var arbitrator principal contract-owner)

;; Data Maps
(define-map jobs
    { job-id: uint }
    {
        client: principal,
        freelancer: principal,
        amount: uint,
        status: (string-ascii 20),
        milestone-count: uint,
        current-milestone: uint,
        creation-time: uint,
        last-updated: uint,
        dispute-status: (string-ascii 20),
        dispute-initiator: (optional principal),
        client-rating: (optional uint),
        freelancer-rating: (optional uint)
    }
)

(define-map milestones
    { job-id: uint, milestone-id: uint }
    {
        amount: uint,
        status: (string-ascii 20),
        deadline: uint,
        deliverables: (string-ascii 256),
        submission-time: (optional uint),
        review-time: (optional uint)
    }
)

(define-map user-stats
    { user: principal }
    {
        total-jobs: uint,
        completed-jobs: uint,
        total-rating: uint,
        rating-count: uint,
        disputes-initiated: uint,
        disputes-lost: uint
    }
)

(define-map disputes
    { job-id: uint }
    {
        reason: (string-ascii 256),
        evidence: (string-ascii 512),
        resolution-deadline: uint,
        proposed-resolution: (optional (string-ascii 256)),
        client-response: (optional (string-ascii 256)),
        freelancer-response: (optional (string-ascii 256))
    }
)

;; Validation Functions
(define-private (is-valid-milestone-id (job-id uint) (milestone-id uint))
    (let 
        ((job-data (unwrap! (map-get? jobs { job-id: job-id }) false)))
        (and 
            (>= milestone-id u0)
            (< milestone-id (get milestone-count job-data))
            (is-none (map-get? milestones { job-id: job-id, milestone-id: milestone-id }))
        )
    )
)

(define-private (validate-milestone-creation 
    (validated-job-id uint) 
    (validated-milestone-id uint)
    (validated-amount uint)
    (validated-deadline uint)
)
    (begin
        (asserts! (is-valid-milestone-id validated-job-id validated-milestone-id) ERR-INVALID-PARAMS)
        (asserts! (> validated-amount u0) ERR-INVALID-PARAMS)
        (asserts! (< validated-amount u1000000000000) ERR-INVALID-PARAMS)  ;; Max amount check
        (asserts! (> validated-deadline block-height) ERR-INVALID-PARAMS)
        (ok true)
    )
)

(define-private (is-valid-job-id (job-id uint))
    (and 
        (> job-id u0)
        (< job-id u1000000)
        (is-none (map-get? jobs { job-id: job-id }))
    )
)

(define-private (is-valid-milestone-count (count uint))
    (and 
        (> count u0)
        (<= count u20)  ;; Maximum 20 milestones per job
    )
)

(define-private (is-valid-amount (amount uint))
    (and 
        (> amount u0)
        (<= amount u1000000000000)  ;; Set a reasonable maximum amount
    )
)

(define-private (is-valid-milestone-status (status (string-ascii 20)))
    (or 
        (is-eq status "pending")
        (is-eq status "submitted")
        (is-eq status "approved")
        (is-eq status "rejected")
    )
)

;; Enhanced String Validation Functions
(define-private (validate-string-input-256 (input (string-ascii 256)) (min-length uint))
    (begin
        (asserts! (and 
            (>= (len input) min-length)
            (<= (len input) u256)
            (is-valid-ascii-256 input)
        ) ERR-INVALID-STRING-LENGTH)
        (ok true)
    )
)

(define-private (validate-string-input-512 (input (string-ascii 512)) (min-length uint))
    (begin
        (asserts! (and 
            (>= (len input) min-length)
            (<= (len input) u512)
            (is-valid-ascii-512 input)
        ) ERR-INVALID-STRING-LENGTH)
        (ok true)
    )
)

;; ASCII Validation Functions
(define-private (is-valid-ascii-256 (input (string-ascii 256)))
    true
)

(define-private (is-valid-ascii-512 (input (string-ascii 512)))
    true
)

;; String Sanitization Functions
(define-private (sanitize-and-validate-string-256 (input (string-ascii 256)) (min-length uint))
    (begin
        (asserts! (and 
            (>= (len input) min-length)
            (<= (len input) u256)
        ) ERR-INVALID-STRING-LENGTH)
        (ok input)
    )
)

(define-private (sanitize-and-validate-string-512 (input (string-ascii 512)) (min-length uint))
    (begin
        (asserts! (and 
            (>= (len input) min-length)
            (<= (len input) u512)
        ) ERR-INVALID-STRING-LENGTH)
        (ok input)
    )
)

;; Enhanced Job and Dispute Validation
(define-private (validate-job-id (job-id uint))
    (begin
        (asserts! (and 
            (> job-id u0)
            (< job-id u1000000)
        ) ERR-INVALID-JOB-ID)
        (ok job-id)
    )
)

(define-private (validate-dispute-input 
    (validated-job-id uint)
    (validated-reason (string-ascii 256))
    (validated-evidence (string-ascii 512))
)
    (begin
        (try! (validate-job-id validated-job-id))
        (try! (sanitize-and-validate-string-256 validated-reason MIN-REASON-LENGTH))
        (try! (sanitize-and-validate-string-512 validated-evidence MIN-EVIDENCE-LENGTH))
        (ok true)
    )
)

;; Private Helper Functions
(define-private (update-user-stats (user principal) (completed bool) (rating (optional uint)) (dispute-lost bool))
    (let
        (
            (current-stats (default-to
                {
                    total-jobs: u0,
                    completed-jobs: u0,
                    total-rating: u0,
                    rating-count: u0,
                    disputes-initiated: u0,
                    disputes-lost: u0
                }
                (map-get? user-stats { user: user })
            ))
        )
        (map-set user-stats
            { user: user }
            {
                total-jobs: (+ (get total-jobs current-stats) u1),
                completed-jobs: (if completed
                    (+ (get completed-jobs current-stats) u1)
                    (get completed-jobs current-stats)),
                total-rating: (match rating
                    rating-value (+ (get total-rating current-stats) rating-value)
                    (get total-rating current-stats)
                ),
                rating-count: (match rating
                    rating-value (+ (get rating-count current-stats) u1)
                    (get rating-count current-stats)
                ),
                disputes-initiated: (get disputes-initiated current-stats),
                disputes-lost: (if dispute-lost
                    (+ (get disputes-lost current-stats) u1)
                    (get disputes-lost current-stats))
            }
        )
        true
    )
)

;; Public Functions
(define-public (create-job (job-id uint) (freelancer principal) (milestone-count uint) (total-amount uint))
    (let
        (
            (fee (/ (* total-amount (var-get platform-fee)) u100))
            (current-block-height block-height)
            (validated-job-id (try! (validate-job-id job-id)))
        )
        ;; Input validation
        (asserts! (is-valid-job-id validated-job-id) ERR-INVALID-JOB-ID)
        (asserts! (not (is-eq freelancer tx-sender)) ERR-INVALID-PARAMS)
        (asserts! (is-valid-milestone-count milestone-count) ERR-INVALID-PARAMS)
        (asserts! (is-valid-amount total-amount) ERR-INSUFFICIENT-FUNDS)
        (asserts! (>= (stx-get-balance tx-sender) (+ total-amount fee)) ERR-INSUFFICIENT-FUNDS)
        
        ;; Process job creation
        (try! (stx-transfer? (+ total-amount fee) tx-sender (as-contract tx-sender)))
        
        ;; Create job record
        (map-set jobs
            { job-id: validated-job-id }
            {
                client: tx-sender,
                freelancer: freelancer,
                amount: total-amount,
                status: "active",
                milestone-count: milestone-count,
                current-milestone: u0,
                creation-time: current-block-height,
                last-updated: current-block-height,
                dispute-status: "none",
                dispute-initiator: none,
                client-rating: none,
                freelancer-rating: none
            }
        )
        
        ;; Update user stats
        (and 
            (update-user-stats tx-sender false none false)
            (update-user-stats freelancer false none false)
        )
        
        (ok true)
    )
)

(define-public (initiate-dispute (job-id uint) (reason (string-ascii 256)) (evidence (string-ascii 512)))
    (let
        (
            (validated-job-id (try! (validate-job-id job-id)))
            (validated-reason (try! (sanitize-and-validate-string-256 reason MIN-REASON-LENGTH)))
            (validated-evidence (try! (sanitize-and-validate-string-512 evidence MIN-EVIDENCE-LENGTH)))
            (job (unwrap! (map-get? jobs { job-id: validated-job-id }) ERR-INVALID-STATE))
        )
        ;; Comprehensive validation
        (try! (validate-dispute-input validated-job-id validated-reason validated-evidence))
        
        ;; Authorization check
        (asserts! (or
            (is-eq tx-sender (get client job))
            (is-eq tx-sender (get freelancer job))
        ) ERR-NOT-AUTHORIZED)
        
        ;; Create dispute with validated data
        (map-set disputes
            { job-id: validated-job-id }
            {
                reason: validated-reason,
                evidence: validated-evidence,
                resolution-deadline: (+ block-height DISPUTE-RESOLUTION-PERIOD),
                proposed-resolution: none,
                client-response: none,
                freelancer-response: none
            }
        )
        
        ;; Update job status
        (map-set jobs
            { job-id: validated-job-id }
            (merge job {
                dispute-status: "active",
                dispute-initiator: (some tx-sender)
            })
        )
        
        (ok true)
    )
)

(define-public (create-milestone (job-id uint) (milestone-id uint) (amount uint) (deadline uint))
    (let
        (
            (validated-job-id (try! (validate-job-id job-id)))
            (validated-milestone-id milestone-id)
            (validated-amount amount)
            (validated-deadline deadline)
            (job (unwrap! (map-get? jobs { job-id: validated-job-id }) ERR-INVALID-STATE))
        )
        ;; Input validation
        (try! (validate-milestone-creation validated-job-id validated-milestone-id validated-amount validated-deadline))
        
        ;; Authorization check
        (asserts! (is-eq tx-sender (get client job)) ERR-NOT-AUTHORIZED)
        
        ;; Create milestone
        (map-set milestones
            { job-id: validated-job-id, milestone-id: validated-milestone-id }
            {
                amount: validated-amount,
                status: "pending",
                deadline: validated-deadline,
                deliverables: "",
                submission-time: none,
                review-time: none
            }
        )
        
        (ok true)
    )
)

(define-public (submit-milestone (job-id uint) (milestone-id uint) (deliverables (string-ascii 256)))
    (let
        (
            (validated-job-id (try! (validate-job-id job-id)))
            (validated-deliverables (try! (sanitize-and-validate-string-256 deliverables u1)))
            (job (unwrap! (map-get? jobs { job-id: validated-job-id }) ERR-INVALID-STATE))
            (milestone (unwrap! (map-get? milestones { job-id: validated-job-id, milestone-id: milestone-id }) ERR-INVALID-STATE))
        )
        ;; State validation
        (asserts! (< milestone-id (get milestone-count job)) ERR-INVALID-PARAMS)
        (asserts! (is-eq (get status milestone) "pending") ERR-INVALID-STATE)
        (asserts! (<= block-height (get deadline milestone)) ERR-DEADLINE-PASSED)
        
        ;; Authorization check
        (asserts! (is-eq tx-sender (get freelancer job)) ERR-NOT-AUTHORIZED)
        
        ;; Update milestone
        (map-set milestones
            { job-id: validated-job-id, milestone-id: milestone-id }
            (merge milestone {
                status: "submitted",
                deliverables: validated-deliverables,
                submission-time: (some block-height)
            })
        )
        
        (ok true)
    )
)

;; Dispute Resolution
(define-public (resolve-dispute (job-id uint) (resolution (string-ascii 256)) (refund-percentage uint))
    (let
        (
            (validated-job-id (try! (validate-job-id job-id)))
            (validated-resolution (try! (sanitize-and-validate-string-256 resolution u1)))
            (job (unwrap! (map-get? jobs { job-id: validated-job-id }) ERR-INVALID-STATE))
            (dispute (unwrap! (map-get? disputes { job-id: validated-job-id }) ERR-INVALID-STATE))
        )
        ;; Validation
        (asserts! (<= refund-percentage u100) ERR-INVALID-PARAMS)
        
        ;; Authorization check
        (asserts! (is-eq tx-sender (var-get arbitrator)) ERR-NOT-AUTHORIZED)
        
        ;; State validation
        (asserts! (is-eq (get dispute-status job) "active") ERR-INVALID-STATE)
        (asserts! (<= block-height (get resolution-deadline dispute)) ERR-DEADLINE-PASSED)
        
        ;; Process refund
        (if (> refund-percentage u0)
            (let
                (
                    (refund-amount (/ (* (get amount job) refund-percentage) u100))
                )
                (try! (as-contract (stx-transfer? refund-amount tx-sender (get client job))))
                (try! (as-contract (stx-transfer? (- (get amount job) refund-amount) tx-sender (get freelancer job))))
            )
            (try! (as-contract (stx-transfer? (get amount job) tx-sender (get freelancer job))))
        )
        
        ;; Update job status with validated data
        (map-set jobs
            { job-id: validated-job-id }
            (merge job {
                dispute-status: "resolved",
                status: "completed"
            })
        )
        
        ;; Update dispute with resolution
        (map-set disputes
            { job-id: validated-job-id }
            (merge dispute {
                proposed-resolution: (some validated-resolution)
            })
        )
        
        (ok true)
    )
)

;; Administrative Functions
(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-fee u20) ERR-INVALID-PARAMS)  ;; Max 20% fee
        (var-set platform-fee new-fee)
        (ok true)
    )
)

(define-public (set-arbitrator (new-arbitrator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) ERR-NOT-AUTHORIZED)
        (asserts! (not (is-eq new-arbitrator contract-owner)) ERR-INVALID-PARAMS)
        (var-set arbitrator new-arbitrator)
        (ok true)
    )
)

;; Read-Only Functions
(define-read-only (get-job-details (job-id uint))
    (let 
        ((validated-job-id (try! (validate-job-id job-id))))
        (ok (unwrap! (map-get? jobs { job-id: validated-job-id }) ERR-INVALID-JOB-ID))
    )
)

(define-read-only (get-milestone-details (job-id uint) (milestone-id uint))
    (let 
        ((validated-job-id (try! (validate-job-id job-id))))
        (ok (unwrap! (map-get? milestones { job-id: validated-job-id, milestone-id: milestone-id }) ERR-INVALID-STATE))
    )
)

(define-read-only (get-user-stats (user principal))
    (ok (default-to
        {
            total-jobs: u0,
            completed-jobs: u0,
            total-rating: u0,
            rating-count: u0,
            disputes-initiated: u0,
            disputes-lost: u0
        }
        (map-get? user-stats { user: user })
    ))
)

(define-read-only (get-dispute-details (job-id uint))
    (let 
        ((validated-job-id (try! (validate-job-id job-id))))
        (ok (unwrap! (map-get? disputes { job-id: validated-job-id }) ERR-INVALID-STATE))
    )
)

(define-read-only (get-platform-fee)
    (ok (var-get platform-fee))
)

(define-read-only (get-arbitrator)
    (ok (var-get arbitrator))
)

(define-read-only (is-job-completed (job-id uint))
    (let 
        ((validated-job-id (try! (validate-job-id job-id)))
         (job-data (default-to 
            { status: "" }
            (map-get? jobs { job-id: validated-job-id }))))
        (ok (is-eq (get status job-data) "completed"))
    )
)