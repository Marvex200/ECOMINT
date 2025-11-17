;; -----------------------------------------------------------------------------
;; EcoTrack.clar
;; Smart Waste Management Token System (EcoTrack)
;; - Users register and submit waste reports (weight in kg + description)
;; - Approved verifiers confirm submissions and mint ECO tokens as rewards
;; - Admin manages verifiers and contract parameters
;; -----------------------------------------------------------------------------

;; Error codes (return as `err <uint>`)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-NOT-REGISTERED (err u102))
(define-constant ERR-NOT-VERIFIER (err u103))
(define-constant ERR-SUBMISSION-NOT-FOUND (err u104))
(define-constant ERR-BAD-STATUS (err u105))
(define-constant ERR-ZERO-REWARD (err u106))

;; ------------------------------
;; Token declaration
;; ------------------------------
;; Define a fungible token ECO with an initial supply (adjust as desired)
(define-fungible-token eco-token u1000000)

;; ------------------------------
;; Admin / state vars
;; ------------------------------
;; The deployer becomes initial admin
(define-data-var admin principal tx-sender)

;; Submission id counter
(define-data-var submission-counter uint u0)

;; Users map: user principal -> { points: uint }
(define-map users { user: principal } { points: uint })

;; Verifiers map: verifier principal -> { active: bool }
(define-map verifiers { account: principal } { active: bool })

;; Submissions map:
;; key: { id: uint }
;; value: {
;;   submitter: principal,
;;   description: (string-ascii 128),
;;   weight_kg: uint,
;;   status: (string-ascii 10), ;; "PENDING" | "VERIFIED" | "REJECTED"
;;   verifier: (optional principal),
;;   timestamp: uint
;; }
(define-map submissions
  { id: uint }
  {
    submitter: principal,
    description: (string-ascii 128),
    weight_kg: uint,
    status: (string-ascii 10),
    verifier: (optional principal),
    timestamp: uint
  })

;; ------------------------------
;; UTIL / INTERNAL HELPERS
;; ------------------------------
(define-read-only (is-admin (p principal))
  (ok (is-eq p (var-get admin))))

(define-read-only (is-active-verifier (p principal))
  (match (map-get? verifiers { account: p })
    some-v (ok (get active some-v))
    (ok false)
  ))

;; ------------------------------
;; PUBLIC: Admin functions
;; ----------------------------

;; Change admin (only current admin)
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (let ((old (var-get admin)))
      (var-set admin new-admin)
      (print {event: "admin-changed", old-admin: old, new-admin: new-admin})
      (ok new-admin)
    )
  ))

;; Add a verifier (only admin)
(define-public (add-verifier (account principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (map-set verifiers { account: account } { active: true })
    (print {event: "verifier-added", account: account})
    (ok account)
  ))

;; Remove a verifier (only admin)
(define-public (remove-verifier (account principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (map-set verifiers { account: account } { active: false })
    (print {event: "verifier-removed", account: account})
    (ok account)
  ))

;; ------------------------------
;; PUBLIC: User registration & submission
;; ----------------------------

;; Register the caller as a user (once)
(define-public (register-user)
  (match (map-get? users { user: tx-sender })
    some-u ERR-ALREADY-REGISTERED
    (begin
      (map-set users { user: tx-sender } { points: u0 })
      (ok "registered")
    )
  )
)

;; Submit a waste report
;; description: short ascii description of waste/action (e.g., "Plastic drop-off")
;; weight-kg: uint weight in kilograms (non-zero recommended)
(define-public (submit-waste (description (string-ascii 128)) (weight-kg uint))
  (match (map-get? users { user: tx-sender })
    some-u
    (let ((new-id (+ (var-get submission-counter) u1)))
      (begin
        (map-set submissions { id: new-id }
          {
            submitter: tx-sender,
            description: description,
            weight_kg: weight-kg,
            status: "PENDING",
            verifier: none,
            timestamp: stacks-block-height
          })
        (var-set submission-counter new-id)
        (print {event: "submission-created", id: new-id, submitter: tx-sender, weight: weight-kg, timestamp: stacks-block-height})
        (ok new-id)
      )
    )
    ERR-NOT-REGISTERED
  )
)

;; ------------------------------
;; PUBLIC: Verification & Rewarding (verifier-only)
;; ----------------------------

;; Verify or reject a submission.
;; approved: bool - true => verified (mint reward), false => rejected
;; reward-per-kg: uint - number of ECO tokens per kg to issue
;; Fixed parenthesis matching and nested let/if structure
(define-public (verify-submission (submission-id uint) (approved bool) (reward-per-kg uint))
  (let
    (
      (verifier-data (unwrap! (map-get? verifiers { account: tx-sender }) ERR-NOT-VERIFIER))
    )
    ;; ensure caller is an active verifier
    (asserts! (get active verifier-data) ERR-NOT-VERIFIER)
    
    ;; fetch submission
    (match (map-get? submissions { id: submission-id })
      some-sub
      (let
        (
          (current-status (get status some-sub))
          (submitter (get submitter some-sub))
          (weight (get weight_kg some-sub))
        )
        ;; ensure submission still pending
        (asserts! (is-eq current-status "PENDING") ERR-BAD-STATUS)
        
        (if approved
          ;; APPROVE branch
          (let
            (
              (reward-amount (* reward-per-kg weight))
            )
            (begin
              (asserts! (> reward-amount u0) ERR-ZERO-REWARD)
              ;; update submission map to VERIFIED
              (map-set submissions { id: submission-id }
                {
                  submitter: submitter,
                  description: (get description some-sub),
                  weight_kg: weight,
                  status: "VERIFIED",
                  verifier: (some tx-sender),
                  timestamp: (get timestamp some-sub)
                })
              ;; update user points (accumulate weight as points)
              (let (
                      (user-entry (unwrap! (map-get? users { user: submitter }) ERR-NOT-REGISTERED))
                      (old-points (get points user-entry))
                   )
                (map-set users { user: submitter } { points: (+ old-points weight) })
              )
              ;; mint ECO tokens to submitter
              (try! (ft-mint? eco-token reward-amount submitter))
              (print {event: "submission-verified", id: submission-id, verifier: tx-sender, reward: reward-amount, timestamp: stacks-block-height})
              (ok reward-amount)
            )
          )
          ;; REJECT branch
          (begin
            (map-set submissions { id: submission-id }
              {
                submitter: submitter,
                description: (get description some-sub),
                weight_kg: weight,
                status: "REJECTED",
                verifier: (some tx-sender),
                timestamp: (get timestamp some-sub)
              })
            (print {event: "submission-rejected", id: submission-id, verifier: tx-sender, timestamp: stacks-block-height})
            (ok u0)
          )
        )
      )
      ERR-SUBMISSION-NOT-FOUND
    )
  ))

;; ------------------------------
;; PUBLIC: Utility / Read-only views
;; ----------------------------

;; Get submission by id
(define-read-only (get-submission (submission-id uint))
  (map-get? submissions { id: submission-id }))

;; Get submission count
(define-read-only (get-submission-count)
  (ok (var-get submission-counter)))

;; Check if an account is an active verifier
(define-read-only (check-verifier (account principal))
  (match (map-get? verifiers { account: account })
    some-v (ok (get active some-v))
    (ok false)
  ))

;; Get user points
(define-read-only (get-user-points (account principal))
  (match (map-get? users { user: account })
    some-u (ok (get points some-u))
    ERR-NOT-REGISTERED
  )
)

(define-read-only (get-eco-balance (account principal))
  (ok (ft-get-balance eco-token account))
)
