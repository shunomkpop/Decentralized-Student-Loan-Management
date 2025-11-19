;; title: LoanChain
;; version: 1.0.0
;; summary: Decentralized Student Loan Management System
;; description: A trustless system for managing and tracking student loans with immutable repayment records

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_LOAN_NOT_FOUND (err u404))
(define-constant ERR_INSUFFICIENT_FUNDS (err u400))
(define-constant ERR_LOAN_ALREADY_EXISTS (err u409))
(define-constant ERR_INVALID_AMOUNT (err u422))
(define-constant ERR_LOAN_NOT_ACTIVE (err u403))
(define-constant ERR_PAYMENT_TOO_LOW (err u402))
(define-constant ERR_LOAN_FULLY_PAID (err u410))
(define-constant ERR_REFINANCE_NOT_ELIGIBLE (err u411))
(define-constant ERR_REFINANCE_REQUEST_NOT_FOUND (err u412))
(define-constant ERR_REFINANCE_INVALID_TERMS (err u413))
(define-constant ERR_REFINANCE_NOT_PENDING (err u414))
(define-constant ERR_INSURANCE_NOT_SUBSCRIBED (err u421))
(define-constant ERR_INSURANCE_ALREADY_SUBSCRIBED (err u420))
(define-constant ERR_INSURANCE_POOL_INSUFFICIENT (err u425))
(define-constant ERR_INSURANCE_CLAIM_INVALID (err u426))
(define-constant REFINANCE_MIN_PAYMENT_PCT u70)
(define-constant REFINANCE_MIN_CREDIT_SCORE u650)
(define-constant REFINANCE_MAX_COUNT u3)
(define-constant REFINANCE_MIN_BLOCKS u34560)
(define-constant INSURANCE_PREMIUM_RATE u25)
(define-constant INSURANCE_POOL_MIN_CONTRIBUTION u100)
(define-constant INSURANCE_PREMIUM_CREDIT_SCORE u700)

;; Data Variables
(define-data-var loan-id-counter uint u0)
(define-data-var total-loans-issued uint u0)
(define-data-var total-amount-disbursed uint u0)
(define-data-var refinance-id-counter uint u0)
(define-data-var insurance-pool-balance uint u0)
(define-data-var total-insurance-claims-paid uint u0)
(define-data-var insurance-claim-id-counter uint u0)

;; Data Maps
(define-map loans 
    uint 
    {
        borrower: principal,
        lender: principal,
        principal-amount: uint,
        interest-rate: uint,
        term-months: uint,
        monthly-payment: uint,
        amount-paid: uint,
        created-at: uint,
        status: (string-ascii 20),
        last-payment: uint
    }
)

(define-map borrower-loans 
    principal 
    (list 50 uint)
)

(define-map lender-loans 
    principal 
    (list 100 uint)
)

(define-map payment-history 
    {loan-id: uint, payment-id: uint}
    {
        amount: uint,
        timestamp: uint,
        remaining-balance: uint
    }
)

(define-map loan-payment-counter uint uint)

(define-map user-profiles 
    principal 
    {
        total-borrowed: uint,
        total-lent: uint,
        credit-score: uint,
        verified: bool
    }
)

(define-map refinance-requests
    uint
    {
        original-loan-id: uint,
        borrower: principal,
        lender: principal,
        new-interest-rate: uint,
        new-term-months: uint,
        new-monthly-payment: uint,
        status: (string-ascii 20),
        requested-at: uint
    }
)

(define-map refinance-counter
    uint
    uint
)

(define-map insurance-subscriptions
    {loan-id: uint, lender: principal}
    {
        subscribed: bool,
        premium-paid: uint,
        timestamp: uint
    }
)

(define-map insurance-claims
    uint
    {
        loan-id: uint,
        claimant: principal,
        claim-amount: uint,
        status: (string-ascii 20),
        timestamp: uint
    }
)

(define-map pool-contributions
    principal
    uint
)

;; Private Functions
(define-private (calculate-insurance-premium (loan-amount uint) (credit-score uint))
    (let ((base (/ (* loan-amount INSURANCE_PREMIUM_RATE) u10000))
          (multiplier (if (>= credit-score INSURANCE_PREMIUM_CREDIT_SCORE) u90 u110)))
        (/ (* base multiplier) u100)
    )
)

(define-private (validate-insurance-eligibility (loan-id uint))
    (match (map-get? loans loan-id)
        loan (and (is-eq (get status loan) "active") (> (get principal-amount loan) u0))
        false
    )
)

(define-private (calculate-interest (principal uint) (rate uint) (months uint))
    (let ((monthly-rate (/ rate u1200)))
        (/ (* (* principal monthly-rate) (pow (+ u1 monthly-rate) months))
           (- (pow (+ u1 monthly-rate) months) u1)))
)

(define-private (get-outstanding-balance (loan-id uint))
    (match (map-get? loans loan-id)
        loan (- (get principal-amount loan) (get amount-paid loan))
        u0
    )
)

(define-private (update-user-stats (user principal) (amount uint) (is-borrower bool))
    (let ((profile (default-to {total-borrowed: u0, total-lent: u0, credit-score: u600, verified: false}
                               (map-get? user-profiles user))))
        (map-set user-profiles user
            (if is-borrower
                (merge profile {total-borrowed: (+ (get total-borrowed profile) amount)})
                (merge profile {total-lent: (+ (get total-lent profile) amount)})
            )
        )
    )
)

(define-private (add-payment-record (loan-id uint) (amount uint) (remaining uint))
    (let ((payment-count (default-to u0 (map-get? loan-payment-counter loan-id))))
        (map-set payment-history 
            {loan-id: loan-id, payment-id: (+ payment-count u1)}
            {amount: amount, timestamp: stacks-block-height, remaining-balance: remaining}
        )
        (map-set loan-payment-counter loan-id (+ payment-count u1))
    )
)

;; Read-Only Functions
(define-read-only (get-loan (loan-id uint))
    (map-get? loans loan-id)
)

(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles user)
)

(define-read-only (get-borrower-loans (borrower principal))
    (default-to (list) (map-get? borrower-loans borrower))
)

(define-read-only (get-lender-loans (lender principal))
    (default-to (list) (map-get? lender-loans lender))
)

(define-read-only (get-payment-history (loan-id uint) (payment-id uint))
    (map-get? payment-history {loan-id: loan-id, payment-id: payment-id})
)

(define-read-only (get-loan-stats)
    {
        total-loans: (var-get total-loans-issued),
        total-disbursed: (var-get total-amount-disbursed),
        current-loans: (var-get loan-id-counter)
    }
)

(define-read-only (calculate-monthly-payment (principal uint) (rate uint) (months uint))
    (calculate-interest principal rate months)
)

(define-read-only (get-loan-balance (loan-id uint))
    (get-outstanding-balance loan-id)
)

(define-read-only (is-loan-overdue (loan-id uint))
    (match (map-get? loans loan-id)
        loan (let ((months-passed (/ (- stacks-block-height (get created-at loan)) u4320))
                   (expected-paid (* months-passed (get monthly-payment loan))))
                (> expected-paid (get amount-paid loan)))
        false
    )
)

(define-read-only (get-payment-progress (loan-id uint))
    (match (map-get? loans loan-id)
        loan (if (> (get principal-amount loan) u0)
                 (/ (* (get amount-paid loan) u100) (get principal-amount loan))
                 u0)
        u0
    )
)

(define-read-only (is-eligible-for-refinance (loan-id uint))
    (match (map-get? loans loan-id)
        loan (let ((payment-progress (if (> (get principal-amount loan) u0)
                                         (/ (* (get amount-paid loan) u100) (get principal-amount loan))
                                         u0))
                   (months-passed (/ (- stacks-block-height (get created-at loan)) u4320))
                   (refinance-count (default-to u0 (map-get? refinance-counter loan-id)))
                   (user-profile (default-to {total-borrowed: u0, total-lent: u0, credit-score: u600, verified: false}
                                            (map-get? user-profiles (get borrower loan)))))
                (and
                    (is-eq (get status loan) "active")
                    (>= payment-progress REFINANCE_MIN_PAYMENT_PCT)
                    (>= (get credit-score user-profile) REFINANCE_MIN_CREDIT_SCORE)
                    (< refinance-count REFINANCE_MAX_COUNT)
                    (> months-passed (/ REFINANCE_MIN_BLOCKS u4320))
                ))
        false
    )
)

(define-read-only (get-refinance-request (refinance-id uint))
    (map-get? refinance-requests refinance-id)
)

(define-read-only (count-loan-refinances (loan-id uint))
    (default-to u0 (map-get? refinance-counter loan-id))
)

(define-read-only (get-insurance-pool-balance)
    (var-get insurance-pool-balance)
)

(define-read-only (get-insurance-status (loan-id uint))
    (match (map-get? loans loan-id)
        loan (default-to {subscribed: false, premium-paid: u0, timestamp: u0}
              (map-get? insurance-subscriptions {loan-id: loan-id, lender: (get lender loan)}))
        {subscribed: false, premium-paid: u0, timestamp: u0}
    )
)

(define-read-only (get-insurance-premium-quote (loan-id uint))
    (match (map-get? loans loan-id)
        loan (let ((profile (default-to {total-borrowed: u0, total-lent: u0, credit-score: u600, verified: false}
                                        (map-get? user-profiles (get borrower loan))))
                   (score (get credit-score profile)))
                (calculate-insurance-premium (get-outstanding-balance loan-id) score))
        u0
    )
)

(define-read-only (get-pool-utilization)
    {
        balance: (var-get insurance-pool-balance),
        claims-paid: (var-get total-insurance-claims-paid)
    }
)

;; Public Functions
(define-public (contribute-to-insurance-pool (amount uint))
    (begin
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (var-set insurance-pool-balance (+ (var-get insurance-pool-balance) amount))
        (let ((prev (default-to u0 (map-get? pool-contributions tx-sender))))
            (map-set pool-contributions tx-sender (+ prev amount))
        )
        (ok true)
    )
)

(define-public (subscribe-insurance (loan-id uint))
    (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get lender loan)) ERR_UNAUTHORIZED)
        (asserts! (validate-insurance-eligibility loan-id) ERR_INSURANCE_CLAIM_INVALID)
        (let ((profile (default-to {total-borrowed: u0, total-lent: u0, credit-score: u600, verified: false}
                                   (map-get? user-profiles (get borrower loan))))
              (existing (map-get? insurance-subscriptions {loan-id: loan-id, lender: tx-sender})))
            (asserts! (is-none existing) ERR_INSURANCE_ALREADY_SUBSCRIBED)
            (let ((premium (calculate-insurance-premium (get-outstanding-balance loan-id) (get credit-score profile)))
                  (contrib (default-to u0 (map-get? pool-contributions tx-sender))))
                (asserts! (>= contrib premium) ERR_INSURANCE_POOL_INSUFFICIENT)
                (map-set pool-contributions tx-sender (- contrib premium))
                (var-set insurance-pool-balance (+ (var-get insurance-pool-balance) premium))
                (map-set insurance-subscriptions {loan-id: loan-id, lender: tx-sender}
                    {subscribed: true, premium-paid: premium, timestamp: stacks-block-height}
                )
                (ok true)
            )
        )
    )
)

(define-public (claim-insurance (loan-id uint) (claim-amount uint))
    (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get lender loan)) ERR_UNAUTHORIZED)
        (asserts! (> claim-amount u0) ERR_INVALID_AMOUNT)
        (let ((sub (unwrap! (map-get? insurance-subscriptions {loan-id: loan-id, lender: tx-sender}) ERR_INSURANCE_NOT_SUBSCRIBED)))
            (asserts! (get subscribed sub) ERR_INSURANCE_NOT_SUBSCRIBED)
            (asserts! (is-loan-overdue loan-id) ERR_INSURANCE_CLAIM_INVALID)
            (let ((outstanding (get-outstanding-balance loan-id))
                  (pool (var-get insurance-pool-balance))
                  (cid (+ (var-get insurance-claim-id-counter) u1))
                  (payable (if (< claim-amount outstanding) claim-amount (if (< outstanding pool) outstanding pool))))
                (asserts! (> payable u0) ERR_INSURANCE_POOL_INSUFFICIENT)
                (var-set insurance-claim-id-counter cid)
                (var-set insurance-pool-balance (- pool payable))
                (var-set total-insurance-claims-paid (+ (var-get total-insurance-claims-paid) payable))
                (map-set insurance-claims cid {loan-id: loan-id, claimant: tx-sender, claim-amount: payable, status: "paid", timestamp: stacks-block-height})
                (ok {claim-id: cid, paid: payable})
            )
        )
    )
)

(define-public (withdraw-insurance-pool (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (>= (var-get insurance-pool-balance) amount) ERR_INSURANCE_POOL_INSUFFICIENT)
        (var-set insurance-pool-balance (- (var-get insurance-pool-balance) amount))
        (ok true)
    )
)

(define-public (create-loan-application 
    (lender principal)
    (principal-amount uint)
    (interest-rate uint)
    (term-months uint))
    (let ((loan-id (+ (var-get loan-id-counter) u1))
          (monthly-payment (calculate-interest principal-amount interest-rate term-months)))
        
        (asserts! (> principal-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (and (>= interest-rate u100) (<= interest-rate u3000)) ERR_INVALID_AMOUNT)
        (asserts! (and (>= term-months u1) (<= term-months u480)) ERR_INVALID_AMOUNT)
        
        (map-set loans loan-id {
            borrower: tx-sender,
            lender: lender,
            principal-amount: principal-amount,
            interest-rate: interest-rate,
            term-months: term-months,
            monthly-payment: monthly-payment,
            amount-paid: u0,
            created-at: stacks-block-height,
            status: "pending",
            last-payment: u0
        })
        
        (var-set loan-id-counter loan-id)
        (update-user-stats tx-sender principal-amount true)
        
        (ok loan-id)
    )
)

(define-public (approve-loan (loan-id uint))
    (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        
        (asserts! (is-eq tx-sender (get lender loan)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status loan) "pending") ERR_LOAN_NOT_ACTIVE)
        
        (map-set loans loan-id 
            (merge loan {status: "active"})
        )
        
        (let ((borrower-loan-list (default-to (list) (map-get? borrower-loans (get borrower loan))))
              (lender-loan-list (default-to (list) (map-get? lender-loans tx-sender))))
            
            (map-set borrower-loans (get borrower loan)
                (unwrap! (as-max-len? (append borrower-loan-list loan-id) u50) ERR_INVALID_AMOUNT))
            
            (map-set lender-loans tx-sender
                (unwrap! (as-max-len? (append lender-loan-list loan-id) u100) ERR_INVALID_AMOUNT))
        )
        
        (var-set total-loans-issued (+ (var-get total-loans-issued) u1))
        (var-set total-amount-disbursed (+ (var-get total-amount-disbursed) (get principal-amount loan)))
        (update-user-stats tx-sender (get principal-amount loan) false)
        
        (ok true)
    )
)

(define-public (reject-loan (loan-id uint))
    (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        
        (asserts! (is-eq tx-sender (get lender loan)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status loan) "pending") ERR_LOAN_NOT_ACTIVE)
        
        (map-set loans loan-id 
            (merge loan {status: "rejected"})
        )
        
        (ok true)
    )
)

(define-public (make-payment (loan-id uint) (amount uint))
    (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        
        (asserts! (is-eq tx-sender (get borrower loan)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status loan) "active") ERR_LOAN_NOT_ACTIVE)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        
        (let ((outstanding-balance (get-outstanding-balance loan-id))
              (new-amount-paid (+ (get amount-paid loan) amount))
              (new-status (if (>= new-amount-paid (get principal-amount loan)) "completed" "active")))
            
            (asserts! (> outstanding-balance u0) ERR_LOAN_FULLY_PAID)
            
            (let ((payment-amount (if (> amount outstanding-balance) outstanding-balance amount))
                  (final-amount-paid (+ (get amount-paid loan) payment-amount))
                  (remaining-balance (- (get principal-amount loan) final-amount-paid)))
                
                (map-set loans loan-id 
                    (merge loan {
                        amount-paid: final-amount-paid,
                        status: (if (is-eq remaining-balance u0) "completed" "active"),
                        last-payment: stacks-block-height
                    })
                )
                
                (add-payment-record loan-id payment-amount remaining-balance)
                
                (ok {
                    amount-paid: payment-amount,
                    remaining-balance: remaining-balance,
                    loan-status: (if (is-eq remaining-balance u0) "completed" "active")
                })
            )
        )
    )
)

(define-public (update-credit-score (user principal) (new-score uint))
    (let ((profile (default-to {total-borrowed: u0, total-lent: u0, credit-score: u600, verified: false}
                               (map-get? user-profiles user))))
        
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (and (>= new-score u300) (<= new-score u850)) ERR_INVALID_AMOUNT)
        
        (map-set user-profiles user
            (merge profile {credit-score: new-score})
        )
        
        (ok true)
    )
)

(define-public (verify-user (user principal))
    (let ((profile (default-to {total-borrowed: u0, total-lent: u0, credit-score: u600, verified: false}
                               (map-get? user-profiles user))))
        
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        
        (map-set user-profiles user
            (merge profile {verified: true})
        )
        
        (ok true)
    )
)

(define-public (calculate-loan-health (loan-id uint))
    (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        
        (let ((months-passed (/ (- stacks-block-height (get created-at loan)) u4320))
              (expected-paid (* months-passed (get monthly-payment loan)))
              (actual-paid (get amount-paid loan))
              (health-ratio (if (> expected-paid u0) (/ (* actual-paid u100) expected-paid) u100)))
            
            (ok {
                months-passed: months-passed,
                expected-paid: expected-paid,
                actual-paid: actual-paid,
                health-percentage: health-ratio,
                is-overdue: (< health-ratio u90)
            })
        )
    )
)

(define-public (emergency-pause-loan (loan-id uint))
    (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        
        (asserts! (or (is-eq tx-sender (get lender loan)) 
                     (is-eq tx-sender (get borrower loan))
                     (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
        
        (map-set loans loan-id 
            (merge loan {status: "paused"})
        )
        
        (ok true)
    )
)

(define-public (resume-loan (loan-id uint))
    (let ((loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND)))
        
        (asserts! (or (is-eq tx-sender (get lender loan)) 
                     (is-eq tx-sender CONTRACT_OWNER)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status loan) "paused") ERR_LOAN_NOT_ACTIVE)
        
        (map-set loans loan-id 
            (merge loan {status: "active"})
        )
        
        (ok true)
    )
)

(define-public (request-loan-refinance
    (original-loan-id uint)
    (new-interest-rate uint)
    (new-term-months uint))
    (let ((loan (unwrap! (map-get? loans original-loan-id) ERR_LOAN_NOT_FOUND))
          (refinance-id (+ (var-get refinance-id-counter) u1))
          (new-monthly-payment (calculate-interest (get-outstanding-balance original-loan-id) new-interest-rate new-term-months)))
        
        (asserts! (is-eq tx-sender (get borrower loan)) ERR_UNAUTHORIZED)
        (asserts! (is-eligible-for-refinance original-loan-id) ERR_REFINANCE_NOT_ELIGIBLE)
        (asserts! (and (>= new-interest-rate u100) (<= new-interest-rate u3000)) ERR_REFINANCE_INVALID_TERMS)
        (asserts! (and (>= new-term-months u1) (<= new-term-months u480)) ERR_REFINANCE_INVALID_TERMS)
        
        (map-set refinance-requests refinance-id {
            original-loan-id: original-loan-id,
            borrower: tx-sender,
            lender: (get lender loan),
            new-interest-rate: new-interest-rate,
            new-term-months: new-term-months,
            new-monthly-payment: new-monthly-payment,
            status: "pending",
            requested-at: stacks-block-height
        })
        
        (var-set refinance-id-counter refinance-id)
        (ok refinance-id)
    )
)

(define-public (approve-refinance (refinance-id uint))
    (let ((refinance-req (unwrap! (map-get? refinance-requests refinance-id) ERR_REFINANCE_REQUEST_NOT_FOUND))
          (original-loan (unwrap! (map-get? loans (get original-loan-id refinance-req)) ERR_LOAN_NOT_FOUND))
          (new-loan-id (+ (var-get loan-id-counter) u1))
          (outstanding-balance (get-outstanding-balance (get original-loan-id refinance-req))))
        
        (asserts! (is-eq tx-sender (get lender original-loan)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status refinance-req) "pending") ERR_REFINANCE_NOT_PENDING)
        
        (map-set refinance-requests refinance-id
            (merge refinance-req {status: "approved"})
        )
        
        (map-set loans (get original-loan-id refinance-req)
            (merge original-loan {status: "refinanced"})
        )
        
        (map-set loans new-loan-id {
            borrower: (get borrower refinance-req),
            lender: (get lender refinance-req),
            principal-amount: outstanding-balance,
            interest-rate: (get new-interest-rate refinance-req),
            term-months: (get new-term-months refinance-req),
            monthly-payment: (get new-monthly-payment refinance-req),
            amount-paid: u0,
            created-at: stacks-block-height,
            status: "active",
            last-payment: u0
        })
        
        (let ((borrower-loan-list (default-to (list) (map-get? borrower-loans (get borrower refinance-req))))
              (lender-loan-list (default-to (list) (map-get? lender-loans tx-sender)))
              (refinance-count (default-to u0 (map-get? refinance-counter (get original-loan-id refinance-req)))))
            
            (map-set borrower-loans (get borrower refinance-req)
                (unwrap! (as-max-len? (append borrower-loan-list new-loan-id) u50) ERR_INVALID_AMOUNT))
            
            (map-set lender-loans tx-sender
                (unwrap! (as-max-len? (append lender-loan-list new-loan-id) u100) ERR_INVALID_AMOUNT))
            
            (map-set refinance-counter (get original-loan-id refinance-req) (+ refinance-count u1))
        )
        
        (var-set loan-id-counter new-loan-id)
        (ok new-loan-id)
    )
)

(define-public (reject-refinance (refinance-id uint))
    (let ((refinance-req (unwrap! (map-get? refinance-requests refinance-id) ERR_REFINANCE_REQUEST_NOT_FOUND)))
        
        (asserts! (is-eq tx-sender (get lender refinance-req)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status refinance-req) "pending") ERR_REFINANCE_NOT_PENDING)
        
        (map-set refinance-requests refinance-id
            (merge refinance-req {status: "rejected"})
        )
        
        (ok true)
    )
)

(define-public (get-platform-metrics)
    (ok {
        total-loans: (var-get total-loans-issued),
        total-disbursed: (var-get total-amount-disbursed),
        active-loans: (var-get loan-id-counter),
        current-block: stacks-block-height
    })
)
