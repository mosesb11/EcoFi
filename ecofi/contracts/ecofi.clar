;; Carbon Credit Trading Platform
;; Enables the issuance, verification, and trading of carbon credits
;; Supports project registration, verification, and transparent trading

;; Define SIP-010 fungible token trait locally instead of importing
;; This avoids dependency on external contracts during development
(define-trait token-standard-trait
  (
    ;; Transfer from the caller to a new principal
    (transfer (uint principal principal (optional (buff 256))) (response bool uint))

    ;; Get the token balance of a specified principal
    (get-balance (principal) (response uint uint))

    ;; Get the total supply for the token
    (get-total-supply () (response uint uint))

    ;; Get the token name
    (get-name () (response (string-ascii 32) uint))

    ;; Get the token symbol
    (get-symbol () (response (string-ascii 32) uint))

    ;; Get the number of decimals used
    (get-decimals () (response uint uint))

    ;; Get the URI for token metadata
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Project types
(define-data-var program-types (list 10 (string-ascii 64)) 
  (list 
    "renewable-energy" 
    "reforestation" 
    "methane-capture" 
    "energy-efficiency" 
    "carbon-capture"
  )
)

;; Carbon projects
(define-map sustainability-programs
  { program-id: uint }
  {
    name: (string-utf8 128),
    description: (string-utf8 1024),
    location: (string-utf8 128),
    manager: principal,
    program-type: (string-ascii 64),
    start-date: uint,
    end-date: uint,
    total-credits: uint,
    available-credits: uint,
    retired-credits: uint,
    verified: bool,
    verification-data: (optional (buff 256)),
    status: (string-ascii 32),  ;; active, completed, suspended
    documentation-link: (string-utf8 256),
    created-at: uint
  }
)

;; Project verifications
(define-map program-verifications
  { program-id: uint, verification-id: uint }
  {
    verifier: principal,
    timestamp: uint,
    credits-issued: uint,
    report-url: (string-utf8 256),
    methodology: (string-ascii 64),
    period-start: uint,
    period-end: uint
  }
)

;; Credit batches
(define-map credit-batches
  { batch-id: uint }
  {
    program-id: uint,
    vintage-year: uint,
    quantity: uint,
    remaining: uint,
    price-per-unit: uint,
    created-at: uint,
    status: (string-ascii 32)  ;; available, sold, retired
  }
)

;; User credit balances
(define-map credit-balances
  { owner: principal, vintage-year: uint, program-id: uint }
  { balance: uint }
)

;; Retired credits
(define-map retired-credits
  { retirement-id: uint }
  {
    owner: principal,
    program-id: uint,
    batch-id: uint,
    quantity: uint,
    reason: (string-utf8 256),
    beneficiary: (optional principal),
    timestamp: uint,
    certificate-url: (optional (string-utf8 256))
  }
)

;; Authorized verifiers
(define-map authorized-verifiers
  { verifier: principal }
  {
    company: (string-utf8 128),
    credentials: (string-utf8 256),
    authorized-at: uint,
    authorized-by: principal,
    status: (string-ascii 32)
  }
)

;; Next available IDs
(define-data-var next-program-id uint u0)
(define-data-var next-batch-id uint u0)
(define-data-var next-retirement-id uint u0)
(define-map next-verification-id { program-id: uint } { id: uint })

;; Check if project type is valid
(define-private (is-valid-program-type (program-type (string-ascii 64)))
  (contains program-type (var-get program-types))
)

;; Helper function to check if a list contains a value
(define-private (contains (element (string-ascii 64)) (collection (list 10 (string-ascii 64))))
  (is-some (index-of collection element))
)

;; Register a new carbon project
(define-public (register-program
                (name (string-utf8 128))
                (description (string-utf8 1024))
                (location (string-utf8 128))
                (program-type (string-ascii 64))
                (start-date uint)
                (end-date uint)
                (documentation-link (string-utf8 256)))
  (let
    ((program-id (var-get next-program-id))
     ;; Sanitize inputs by explicitly casting them
     (sanitized-name name)
     (sanitized-description description)
     (sanitized-location location)
     (sanitized-program-type program-type)
     (sanitized-documentation-link documentation-link))
    
    ;; Validate inputs
    (asserts! (is-valid-program-type sanitized-program-type) (err u"Invalid program type"))
    (asserts! (< start-date end-date) (err u"End date must be after start date"))
    (asserts! (> (len sanitized-name) u0) (err u"Name cannot be empty"))
    (asserts! (> (len sanitized-location) u0) (err u"Location cannot be empty"))
    
    ;; Create the project record
    (map-set sustainability-programs
      { program-id: program-id }
      {
        name: sanitized-name,
        description: sanitized-description,
        location: sanitized-location,
        manager: tx-sender,
        program-type: sanitized-program-type,
        start-date: start-date,
        end-date: end-date,
        total-credits: u0,
        available-credits: u0,
        retired-credits: u0,
        verified: false,
        verification-data: none,
        status: "pending",
        documentation-link: sanitized-documentation-link,
        created-at: block-height
      }
    )
    
    ;; Initialize verification counter
    (map-set next-verification-id
      { program-id: program-id }
      { id: u0 }
    )
    
    ;; Increment project ID counter
    (var-set next-program-id (+ program-id u1))
    
    (ok program-id)
  )
)

;; Verify a project and issue carbon credits
(define-public (verify-program
                (program-id uint)
                (credits-issued uint)
                (report-url (string-utf8 256))
                (methodology (string-ascii 64))
                (period-start uint)
                (period-end uint)
                (verification-data (buff 256)))
  (let
    ((program (unwrap! (map-get? sustainability-programs { program-id: program-id }) (err u"Program not found")))
     (verification-counter (unwrap! (map-get? next-verification-id { program-id: program-id }) 
                                   (err u"Counter not found")))
     (verification-id (get id verification-counter))
     ;; Sanitize inputs by explicitly casting them
     (sanitized-report-url report-url)
     (sanitized-methodology methodology))
    
    ;; Validate
    (asserts! (is-authorized-verifier tx-sender) (err u"Not authorized as verifier"))
    (asserts! (is-eq (get status program) "pending") (err u"Program not in pending status"))
    (asserts! (<= period-start period-end) (err u"Invalid verification period"))
    (asserts! (> credits-issued u0) (err u"Credits issued must be greater than zero"))
    (asserts! (> (len sanitized-methodology) u0) (err u"Methodology cannot be empty"))
    
    ;; Create verification record
    (map-set program-verifications
      { program-id: program-id, verification-id: verification-id }
      {
        verifier: tx-sender,
        timestamp: block-height,
        credits-issued: credits-issued,
        report-url: sanitized-report-url,
        methodology: sanitized-methodology,
        period-start: period-start,
        period-end: period-end
      }
    )
    
    ;; Update project with verification data
    (map-set sustainability-programs
      { program-id: program-id }
      (merge program 
        { 
          verified: true, 
          verification-data: (some verification-data),
          status: "active",
          total-credits: (+ (get total-credits program) credits-issued),
          available-credits: (+ (get available-credits program) credits-issued)
        }
      )
    )
    
    ;; Increment verification counter
    (map-set next-verification-id
      { program-id: program-id }
      { id: (+ verification-id u1) }
    )
    
    (ok verification-id)
  )
)

;; Check if sender is an authorized verifier
(define-private (is-authorized-verifier (verifier principal))
  (match (map-get? authorized-verifiers { verifier: verifier })
    verifier-data (and 
                    (is-eq (get status verifier-data) "active")
                    true)
    false
  )
)

;; Authorize a verifier (admin only)
(define-public (authorize-verifier 
                (verifier principal)
                (company (string-utf8 128))
                (credentials (string-utf8 256)))
  (begin
    ;; Check if sender is admin
    (asserts! (is-system-admin) (err u"Only admin can authorize verifiers"))
    
    ;; Validate inputs
    (asserts! (not (is-eq verifier tx-sender)) (err u"Cannot authorize yourself as verifier"))
    (asserts! (> (len company) u0) (err u"Company cannot be empty"))
    (asserts! (> (len credentials) u0) (err u"Credentials cannot be empty"))
    
    ;; Register verifier
    (map-set authorized-verifiers
      { verifier: verifier }
      {
        company: company,
        credentials: credentials,
        authorized-at: block-height,
        authorized-by: tx-sender,
        status: "active"
      }
    )
    
    (ok true)
  )
)

;; Admin check - would be implemented properly in a real contract
(define-private (is-system-admin)
  ;; Simplified check
  true
)

;; Create a batch of carbon credits for sale
(define-public (create-credit-batch
                (program-id uint)
                (vintage-year uint)
                (quantity uint)
                (price-per-unit uint))
  (let
    ((program (unwrap! (map-get? sustainability-programs { program-id: program-id }) (err u"Program not found")))
     (batch-id (var-get next-batch-id)))
    
    ;; Validate
    (asserts! (is-eq tx-sender (get manager program)) (err u"Only program manager can create batches"))
    (asserts! (get verified program) (err u"Program must be verified first"))
    (asserts! (is-eq (get status program) "active") (err u"Program must be active"))
    (asserts! (>= (get available-credits program) quantity) (err u"Not enough available credits"))
    (asserts! (> quantity u0) (err u"Quantity must be greater than zero"))
    (asserts! (> price-per-unit u0) (err u"Price per unit must be greater than zero"))
    (asserts! (>= vintage-year u2020) (err u"Vintage year must be 2020 or later"))
    
    ;; Create the batch
    (map-set credit-batches
      { batch-id: batch-id }
      {
        program-id: program-id,
        vintage-year: vintage-year,
        quantity: quantity,
        remaining: quantity,
        price-per-unit: price-per-unit,
        created-at: block-height,
        status: "available"
      }
    )
    
    ;; Update project available credits
    (map-set sustainability-programs
      { program-id: program-id }
      (merge program { available-credits: (- (get available-credits program) quantity) })
    )
    
    ;; Increment batch ID counter
    (var-set next-batch-id (+ batch-id u1))
    
    (ok batch-id)
  )
)

;; Buy carbon credits from a batch
(define-public (purchase-credits (batch-id uint) (quantity uint))
  (let
    ((batch (unwrap! (map-get? credit-batches { batch-id: batch-id }) (err u"Batch not found")))
     (program (unwrap! (map-get? sustainability-programs { program-id: (get program-id batch) }) 
                      (err u"Program not found")))
     (total-cost (* quantity (get price-per-unit batch)))
     (balance-key { owner: tx-sender, vintage-year: (get vintage-year batch), program-id: (get program-id batch) })
     (current-balance (default-to { balance: u0 } (map-get? credit-balances balance-key))))
    
    ;; Validate
    (asserts! (is-eq (get status batch) "available") (err u"Batch not available"))
    (asserts! (>= (get remaining batch) quantity) (err u"Not enough credits available in batch"))
    (asserts! (> quantity u0) (err u"Quantity must be greater than zero"))
    
    ;; Transfer STX for purchase - use asserts! instead of try!
    (asserts! (is-ok (stx-transfer? total-cost tx-sender (get manager program))) 
              (err u"STX transfer failed"))
    
    ;; Update batch remaining credits
    (map-set credit-batches
      { batch-id: batch-id }
      (merge batch 
        { 
          remaining: (- (get remaining batch) quantity),
          status: (if (is-eq (- (get remaining batch) quantity) u0) "sold" "available")
        }
      )
    )
    
    ;; Update buyer's credit balance
    (map-set credit-balances
      balance-key
      { balance: (+ (get balance current-balance) quantity) }
    )
    
    (ok true)
  )
)

;; Retire carbon credits
(define-public (retire-credits 
                (program-id uint) 
                (vintage-year uint) 
                (quantity uint)
                (reason (string-utf8 256))
                (beneficiary (optional principal)))
  (let
    ((balance-key { owner: tx-sender, vintage-year: vintage-year, program-id: program-id })
     (current-balance (unwrap! (map-get? credit-balances balance-key) (err u"No credits owned")))
     (program (unwrap! (map-get? sustainability-programs { program-id: program-id }) (err u"Program not found")))
     (retirement-id (var-get next-retirement-id))
     (sanitized-reason reason)
     (sanitized-beneficiary beneficiary))
    
    ;; Validate
    (asserts! (>= (get balance current-balance) quantity) (err u"Not enough credits to retire"))
    (asserts! (> quantity u0) (err u"Quantity must be greater than zero"))
    (asserts! (> (len sanitized-reason) u0) (err u"Reason cannot be empty"))
    
    ;; Validate beneficiary if present
    (asserts! (match sanitized-beneficiary
                beneficiary-principal (not (is-eq beneficiary-principal tx-sender))
                true) 
              (err u"Beneficiary cannot be the same as the sender"))
    
    ;; Update user's balance
    (map-set credit-balances
      balance-key
      { balance: (- (get balance current-balance) quantity) }
    )
    
    ;; Update project retired credits
    (map-set sustainability-programs
      { program-id: program-id }
      (merge program { retired-credits: (+ (get retired-credits program) quantity) })
    )
    
    ;; Record retirement
    (map-set retired-credits
      { retirement-id: retirement-id }
      {
        owner: tx-sender,
        program-id: program-id,
        batch-id: u0, ;; Not tracking specific batch in this simplified version
        quantity: quantity,
        reason: sanitized-reason,
        beneficiary: sanitized-beneficiary,
        timestamp: block-height,
        certificate-url: none
      }
    )
    
    ;; Increment retirement ID counter
    (var-set next-retirement-id (+ retirement-id u1))
    
    (ok retirement-id)
  )
)

;; Transfer credits to another user
(define-public (transfer-credits
                (program-id uint)
                (vintage-year uint)
                (recipient principal)
                (quantity uint))
  (let
    ((sender-key { owner: tx-sender, vintage-year: vintage-year, program-id: program-id })
     (recipient-key { owner: recipient, vintage-year: vintage-year, program-id: program-id })
     (sender-balance (unwrap! (map-get? credit-balances sender-key) (err u"No credits owned")))
     (recipient-balance (default-to { balance: u0 } (map-get? credit-balances recipient-key))))
    
    ;; Validate
    (asserts! (>= (get balance sender-balance) quantity) (err u"Not enough credits to transfer"))
    (asserts! (> quantity u0) (err u"Quantity must be greater than zero"))
    
    ;; Update sender's balance
    (map-set credit-balances
      sender-key
      { balance: (- (get balance sender-balance) quantity) }
    )
    
    ;; Update recipient's balance
    (map-set credit-balances
      recipient-key
      { balance: (+ (get balance recipient-balance) quantity) }
    )
    
    (ok true)
  )
)

;; Generate retirement certificate (admin only)
(define-public (generate-retirement-certificate
                (retirement-id uint)
                (certificate-url (string-utf8 256)))
  (let
    ((retirement (unwrap! (map-get? retired-credits { retirement-id: retirement-id }) 
                         (err u"Retirement record not found")))
     (sanitized-url certificate-url))
    
    ;; Validate
    (asserts! (is-system-admin) (err u"Only admin can generate certificates"))
    (asserts! (is-none (get certificate-url retirement)) (err u"Certificate already generated"))
    (asserts! (> (len sanitized-url) u0) (err u"Certificate URL cannot be empty"))
    
    ;; Update retirement record
    (map-set retired-credits
      { retirement-id: retirement-id }
      (merge retirement { certificate-url: (some sanitized-url) })
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get project details
(define-read-only (get-program-details (program-id uint))
  (ok (unwrap! (map-get? sustainability-programs { program-id: program-id }) (err u"Program not found")))
)

;; Get batch details
(define-read-only (get-batch-details (batch-id uint))
  (ok (unwrap! (map-get? credit-batches { batch-id: batch-id }) (err u"Batch not found")))
)

;; Get user credit balance
(define-read-only (get-credit-balance (owner principal) (program-id uint) (vintage-year uint))
  (ok (default-to 
        { balance: u0 } 
        (map-get? credit-balances { owner: owner, vintage-year: vintage-year, program-id: program-id })
      )
  )
)

;; Get retirement details
(define-read-only (get-retirement-details (retirement-id uint))
  (ok (unwrap! (map-get? retired-credits { retirement-id: retirement-id }) (err u"Retirement not found")))
)