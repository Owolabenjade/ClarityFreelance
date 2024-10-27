;; Freelance Escrow Smart Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1))
(define-constant ERR-INSUFFICIENT-FUNDS (err u2))
(define-constant ERR-INVALID-STATE (err u3))

;; Data Variables
(define-data-var platform-fee uint u5) ;; 5% platform fee

;; Data Maps
(define-map jobs
    { job-id: uint }
    {
        client: principal,
        freelancer: principal,
        amount: uint,
        status: (string-ascii 20),
        milestone-count: uint,
        current-milestone: uint
    }
)

(define-map milestones
    { job-id: uint, milestone-id: uint }
    {
        amount: uint,
        status: (string-ascii 20),
        deadline: uint
    }
)

;; Public Functions
(define-public (create-job (job-id uint) (freelancer principal) (milestone-count uint) (total-amount uint))
    (let
        (
            (fee (/ (* total-amount (var-get platform-fee)) u100))
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
                        current-milestone: u0
                    }
                )
                (ok true)
            )
            ERR-INSUFFICIENT-FUNDS
        )
    )
)

(define-public (set-milestone (job-id uint) (milestone-id uint) (amount uint) (deadline uint))
    (let
        (
            (job (unwrap! (map-get? jobs { job-id: job-id }) ERR-INVALID-STATE))
        )
        (if (and
                (is-eq tx-sender (get client job))
                (< milestone-id (get milestone-count job))
            )
            (begin
                (map-set milestones
                    { job-id: job-id, milestone-id: milestone-id }
                    {
                        amount: amount,
                        status: "pending",
                        deadline: deadline
                    }
                )
                (ok true)
            )
            ERR-NOT-AUTHORIZED
        )
    )
)

(define-public (complete-milestone (job-id uint) (milestone-id uint))
    (let
        (
            (job (unwrap! (map-get? jobs { job-id: job-id }) ERR-INVALID-STATE))
            (milestone (unwrap! (map-get? milestones { job-id: job-id, milestone-id: milestone-id }) ERR-INVALID-STATE))
        )
        (if (and
                (is-eq tx-sender (get client job))
                (is-eq (get status milestone) "pending")
            )
            (begin
                (try! (as-contract (stx-transfer? (get amount milestone) tx-sender (get freelancer job))))
                (map-set milestones
                    { job-id: job-id, milestone-id: milestone-id }
                    (merge milestone { status: "completed" })
                )
                (ok true)
            )
            ERR-NOT-AUTHORIZED
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