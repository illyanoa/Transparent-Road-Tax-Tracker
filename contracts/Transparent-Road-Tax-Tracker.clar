(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-project-not-found (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-voting-period-ended (err u105))
(define-constant err-not-authorized (err u106))

(define-data-var total-pool-balance uint u0)
(define-data-var next-project-id uint u1)
(define-data-var tax-rate uint u100)

(define-map taxpayers principal uint)
(define-map projects uint {
  name: (string-ascii 64),
  description: (string-ascii 256),
  requested-amount: uint,
  allocated-amount: uint,
  recipient: principal,
  votes: uint,
  voters: (list 50 principal),
  created-at: uint,
  status: (string-ascii 20)
})

(define-map project-votes {project-id: uint, voter: principal} bool)
(define-map community-representatives principal bool)
(define-map allocation-history uint {
  project-id: uint,
  amount: uint,
  allocated-by: principal,
  timestamp: uint
})

(define-data-var next-allocation-id uint u1)

(define-public (pay-road-tax (amount uint))
  (let ((current-balance (default-to u0 (map-get? taxpayers tx-sender))))
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-pool-balance (+ (var-get total-pool-balance) amount))
    (map-set taxpayers tx-sender (+ current-balance amount))
    (ok amount)
  )
)

(define-public (propose-project (name (string-ascii 64)) (description (string-ascii 256)) (requested-amount uint))
  (let ((project-id (var-get next-project-id)))
    (asserts! (> requested-amount u0) err-invalid-amount)
    (asserts! (> (len name) u0) err-invalid-amount)
    (map-set projects project-id {
      name: name,
      description: description,
      requested-amount: requested-amount,
      allocated-amount: u0,
      recipient: tx-sender,
      votes: u0,
      voters: (list),
      created-at: stacks-block-height,
      status: "proposed"
    })
    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

(define-public (vote-for-project (project-id uint))
  (let ((project (unwrap! (map-get? projects project-id) err-project-not-found))
        (has-voted (is-some (map-get? project-votes {project-id: project-id, voter: tx-sender})))
        (taxpayer-balance (default-to u0 (map-get? taxpayers tx-sender))))
    (asserts! (> taxpayer-balance u0) err-not-authorized)
    (asserts! (not has-voted) err-already-voted)
    (asserts! (is-eq (get status project) "proposed") err-voting-period-ended)
    
    (map-set project-votes {project-id: project-id, voter: tx-sender} true)
    (map-set projects project-id (merge project {
      votes: (+ (get votes project) u1),
      voters: (unwrap-panic (as-max-len? (append (get voters project) tx-sender) u50))
    }))
    (ok true)
  )
)

(define-public (allocate-funds (project-id uint) (amount uint))
  (let ((project (unwrap! (map-get? projects project-id) err-project-not-found))
        (current-pool (var-get total-pool-balance))
        (allocation-id (var-get next-allocation-id)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount current-pool) err-insufficient-funds)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (is-eq (get status project) "proposed") err-project-not-found)
    
    (try! (as-contract (stx-transfer? amount tx-sender (get recipient project))))
    (var-set total-pool-balance (- current-pool amount))
    
    (map-set projects project-id (merge project {
      allocated-amount: (+ (get allocated-amount project) amount),
      status: "funded"
    }))
    
    (map-set allocation-history allocation-id {
      project-id: project-id,
      amount: amount,
      allocated-by: tx-sender,
      timestamp: stacks-block-height
    })
    
    (var-set next-allocation-id (+ allocation-id u1))
    (ok allocation-id)
  )
)

(define-public (add-community-representative (representative principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set community-representatives representative true)
    (ok true)
  )
)

(define-public (remove-community-representative (representative principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-delete community-representatives representative)
    (ok true)
  )
)

(define-public (update-tax-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-rate u0) err-invalid-amount)
    (var-set tax-rate new-rate)
    (ok new-rate)
  )
)

(define-public (emergency-withdrawal (amount uint))
  (let ((current-pool (var-get total-pool-balance)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount current-pool) err-insufficient-funds)
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (var-set total-pool-balance (- current-pool amount))
    (ok amount)
  )
)

(define-read-only (get-pool-balance)
  (var-get total-pool-balance)
)

(define-read-only (get-taxpayer-contribution (taxpayer principal))
  (default-to u0 (map-get? taxpayers taxpayer))
)

(define-read-only (get-project (project-id uint))
  (map-get? projects project-id)
)

(define-read-only (get-project-votes (project-id uint))
  (match (map-get? projects project-id)
    project (some (get votes project))
    none
  )
)

(define-read-only (has-voted (project-id uint) (voter principal))
  (is-some (map-get? project-votes {project-id: project-id, voter: voter}))
)

(define-read-only (get-allocation-history (allocation-id uint))
  (map-get? allocation-history allocation-id)
)

(define-read-only (is-community-representative (address principal))
  (default-to false (map-get? community-representatives address))
)

(define-read-only (get-tax-rate)
  (var-get tax-rate)
)

(define-read-only (get-contract-info)
  {
    total-pool: (var-get total-pool-balance),
    next-project-id: (var-get next-project-id),
    tax-rate: (var-get tax-rate),
    owner: contract-owner,
    current-block: stacks-block-height
  }
)

(define-read-only (calculate-tax (usage-miles uint))
  (* usage-miles (var-get tax-rate))
)

(define-read-only (get-total-allocated)
  (fold + (map get-project-allocated (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)) u0)
)

(define-read-only (get-recent-projects)
  (let ((current-id (var-get next-project-id)))
    (if (> current-id u10)
      (map get-project (list (- current-id u9) (- current-id u8) (- current-id u7) 
                            (- current-id u6) (- current-id u5) (- current-id u4)
                            (- current-id u3) (- current-id u2) (- current-id u1) current-id))
      (map get-project (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))
    )
  )
)

(define-private (get-project-allocated (project-id uint))
  (match (get-project project-id)
    project (get allocated-amount project)
    u0
  )
)
