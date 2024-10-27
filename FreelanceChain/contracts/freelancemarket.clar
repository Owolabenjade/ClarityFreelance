;; Enhanced Freelance Escrow Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-FUNDS (err u2))
(define-constant ERR-INVALID-STATE (err u3))
(define-constant ERR-DEADLINE-PASSED (err u4))
(define-constant ERR-INVALID-RATING (err u5))
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

;; Private Functions
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
            (merge current-stats
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
                    disputes-lost: (if dispute-lost
                        (+ (get disputes-lost current-stats) u1)
                        (get disputes-lost current-stats))
                }
            )
        )
    )
)

;; Public Functions
(define-public (create-job (job-id uint) (freelancer principal) (milestone-count uint) (total-amount uint))
    (let
        (
            (fee (/ (* total-amount (var-get platform-fee)) u100))
            (current-block-height block-height)
        )
        (if (>= (stx-get-balance tx-sender) (+ total-amount fee))
            (begin
                (try! (stx-transfer? (+ total-amount fee) tx-sender (as-contract tx-sender)))
                (map-set jobs
                    { job-id: job-id }
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
                (update-user-stats tx-sender false none false)
                (update-user-stats freelancer false none false)
                (ok true)
            )
            ERR-INSUFFICIENT-FUNDS
        )
    )
)

(define-public (submit-milestone (job-id uint) (milestone-id uint) (deliverables (string-ascii 256)))
    (let
        (
            (job (unwrap! (map-get? jobs { job-id: job-id }) ERR-INVALID-STATE))
            (milestone (unwrap! (map-get? milestones { job-id: job-id, milestone-id: milestone-id }) ERR-INVALID-STATE))
        )
        (if (and
                (is-eq tx-sender (get freelancer job))
                (is-eq (get status milestone) "pending")
                (<= block-height (get deadline milestone))
            )
            (begin
                (map-set milestones
                    { job-id: job-id, milestone-id: milestone-id }
                    (merge milestone {
                        status: "submitted",
                        deliverables: deliverables,
                        submission-time: (some block-height)
                    })
                )
                (ok true)
            )
            ERR-NOT-AUTHORIZED
        )
    )
)

(define-public (initiate-dispute (job-id uint) (reason (string-ascii 256)) (evidence (string-ascii 512)))
    (let
        (
            (job (unwrap! (map-get? jobs { job-id: job-id }) ERR-INVALID-STATE))
        )
        (if (or
                (is-eq tx-sender (get client job))
                (is-eq tx-sender (get freelancer job))
            )
            (begin
                (map-set disputes
                    { job-id: job-id }
                    {
                        reason: reason,
                        evidence: evidence,
                        resolution-deadline: (+ block-height DISPUTE-RESOLUTION-PERIOD),
                        proposed-resolution: none,
                        client-response: none,
                        freelancer-response: none
                    }
                )
                (map-set jobs
                    { job-id: job-id }
                    (merge job {
                        dispute-status: "active",
                        dispute-initiator: (some tx-sender)
                    })
                )
                (ok true)
            )
            ERR-NOT-AUTHORIZED
        )
    )
)

(define-public (resolve-dispute (job-id uint) (resolution (string-ascii 256)) (refund-percentage uint))
    (let
        (
            (job (unwrap! (map-get? jobs { job-id: job-id }) ERR-INVALID-STATE))
            (dispute (unwrap! (map-get? disputes { job-id: job-id }) ERR-INVALID-STATE))
        )
        (if (and
                (is-eq tx-sender (var-get arbitrator))
                (is-eq (get dispute-status job) "active")
                (<= block-height (get resolution-deadline dispute))
            )
            (begin
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
                (map-set jobs
                    { job-id: job-id }
                    (merge job {
                        dispute-status: "resolved",
                        status: "completed"
                    })
                )
                (ok true)
            )
            ERR-NOT-AUTHORIZED
        )
    )
)

(define-public (rate-participant (job-id uint) (rating uint) (is-rating-client bool))
    (let
        (
            (job (unwrap! (map-get? jobs { job-id: job-id }) ERR-INVALID-STATE))
        )
        (if (and
                (or (is-eq tx-sender (get client job)) (is-eq tx-sender (get freelancer job)))
                (is-eq (get status job) "completed")
                (<= rating (* u5 RATING-DECIMALS))
            )
            (begin
                (map-set jobs
                    { job-id: job-id }
                    (merge job
                        (if is-rating-client
                            { client-rating: (some rating) }
                            { freelancer-rating: (some rating) }
                        )
                    )
                )
                (update-user-stats
                    (if is-rating-client (get client job) (get freelancer job))
                    true
                    (some rating)
                    false
                )
                (ok true)
            )
            ERR-INVALID-RATING
        )
    )
)

;; Read-only Functions
(define-read-only (get-job-details (job-id uint))
    (map-get? jobs { job-id: job-id })
)

(define-read-only (get-milestone-details (job-id uint) (milestone-id uint))
    (map-get? milestones { job-id: job-id, milestone-id: milestone-id })
)

(define-read-only (get-user-stats (user principal))
    (map-get? user-stats { user: user })
)

(define-read-only (get-dispute-details (job-id uint))
    (map-get? disputes { job-id: job-id })
)

(define-read-only (get-user-rating (user principal))
    (let
        (
            (stats (unwrap! (map-get? user-stats { user: user }) (ok u0)))
        )
        (if (> (get rating-count stats) u0)
            (ok (/ (get total-rating stats) (get rating-count stats)))
            (ok u0)
        )
    )
)