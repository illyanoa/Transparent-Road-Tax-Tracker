(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-project-not-found (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-voting-period-ended (err u105))
(define-constant err-not-authorized (err u106))
(define-constant err-milestone-not-found (err u107))
(define-constant err-milestone-completed (err u108))
(define-constant err-invalid-rating (err u109))
(define-constant err-project-not-funded (err u110))
(define-constant err-invalid-milestone (err u111))
(define-constant err-already-verified (err u112))

(define-data-var total-pool-balance uint u0)
(define-data-var next-project-id uint u1)
(define-data-var tax-rate uint u100)
(define-data-var next-milestone-id uint u1)
(define-data-var total-completed-projects uint u0)

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

(define-map project-milestones uint {
  project-id: uint,
  title: (string-ascii 64),
  description: (string-ascii 256),
  target-completion: uint,
  completed: bool,
  completed-at: (optional uint),
  verification-count: uint
})

(define-map milestone-verifications {milestone-id: uint, verifier: principal} {
  verified: bool,
  verification-timestamp: uint,
  notes: (string-ascii 200)
})

(define-map project-impact-metrics uint {
  project-id: uint,
  road-condition-score: uint,
  usage-improvement: uint,
  safety-rating: uint,
  community-satisfaction: uint,
  measured-at: uint,
  verified: bool
})

(define-map project-performance-ratings uint {
  project-id: uint,
  overall-rating: uint,
  completion-timeliness: uint,
  budget-efficiency: uint,
  impact-effectiveness: uint,
  community-approval: uint,
  total-ratings: uint
})

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

(define-public (create-project-milestone (project-id uint) (title (string-ascii 64)) (description (string-ascii 256)) (target-completion uint))
  (let ((project (unwrap! (map-get? projects project-id) err-project-not-found))
        (milestone-id (var-get next-milestone-id)))
    (asserts! (is-eq tx-sender (get recipient project)) err-not-authorized)
    (asserts! (is-eq (get status project) "funded") err-project-not-funded)
    (asserts! (> target-completion stacks-block-height) err-invalid-milestone)
    
    (map-set project-milestones milestone-id {
      project-id: project-id,
      title: title,
      description: description,
      target-completion: target-completion,
      completed: false,
      completed-at: none,
      verification-count: u0
    })
    
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

(define-public (complete-milestone (milestone-id uint))
  (let ((milestone (unwrap! (map-get? project-milestones milestone-id) err-milestone-not-found))
        (project (unwrap! (map-get? projects (get project-id milestone)) err-project-not-found)))
    (asserts! (is-eq tx-sender (get recipient project)) err-not-authorized)
    (asserts! (not (get completed milestone)) err-milestone-completed)
    
    (map-set project-milestones milestone-id (merge milestone {
      completed: true,
      completed-at: (some stacks-block-height)
    }))
    
    (ok true)
  )
)

(define-public (verify-milestone-completion (milestone-id uint) (notes (string-ascii 200)))
  (let ((milestone (unwrap! (map-get? project-milestones milestone-id) err-milestone-not-found))
        (taxpayer-balance (default-to u0 (map-get? taxpayers tx-sender)))
        (verification-key {milestone-id: milestone-id, verifier: tx-sender})
        (existing-verification (map-get? milestone-verifications verification-key)))
    (asserts! (> taxpayer-balance u0) err-not-authorized)
    (asserts! (get completed milestone) err-milestone-not-found)
    (asserts! (is-none existing-verification) err-already-verified)
    
    (map-set milestone-verifications verification-key {
      verified: true,
      verification-timestamp: stacks-block-height,
      notes: notes
    })
    
    (map-set project-milestones milestone-id (merge milestone {
      verification-count: (+ (get verification-count milestone) u1)
    }))
    
    (ok true)
  )
)

(define-public (record-project-impact (project-id uint) (road-condition-score uint) (usage-improvement uint) (safety-rating uint) (community-satisfaction uint))
  (let ((project (unwrap! (map-get? projects project-id) err-project-not-found)))
    (asserts! (or (is-eq tx-sender contract-owner) (default-to false (map-get? community-representatives tx-sender))) err-not-authorized)
    (asserts! (is-eq (get status project) "funded") err-project-not-funded)
    (asserts! (and (<= road-condition-score u100) (<= usage-improvement u100) (<= safety-rating u100) (<= community-satisfaction u100)) err-invalid-rating)
    
    (map-set project-impact-metrics project-id {
      project-id: project-id,
      road-condition-score: road-condition-score,
      usage-improvement: usage-improvement,
      safety-rating: safety-rating,
      community-satisfaction: community-satisfaction,
      measured-at: stacks-block-height,
      verified: (default-to false (map-get? community-representatives tx-sender))
    })
    
    (ok true)
  )
)

(define-public (rate-project-performance (project-id uint) (overall-rating uint) (completion-timeliness uint) (budget-efficiency uint) (impact-effectiveness uint))
  (let ((project (unwrap! (map-get? projects project-id) err-project-not-found))
        (taxpayer-balance (default-to u0 (map-get? taxpayers tx-sender)))
        (current-rating (default-to {project-id: project-id, overall-rating: u0, completion-timeliness: u0, budget-efficiency: u0, impact-effectiveness: u0, community-approval: u0, total-ratings: u0} 
                          (map-get? project-performance-ratings project-id))))
    (asserts! (> taxpayer-balance u0) err-not-authorized)
    (asserts! (is-eq (get status project) "funded") err-project-not-funded)
    (asserts! (and (<= overall-rating u5) (<= completion-timeliness u5) (<= budget-efficiency u5) (<= impact-effectiveness u5)) err-invalid-rating)
    
    (let ((new-total-ratings (+ (get total-ratings current-rating) u1)))
      (map-set project-performance-ratings project-id {
        project-id: project-id,
        overall-rating: (/ (+ (* (get overall-rating current-rating) (get total-ratings current-rating)) overall-rating) new-total-ratings),
        completion-timeliness: (/ (+ (* (get completion-timeliness current-rating) (get total-ratings current-rating)) completion-timeliness) new-total-ratings),
        budget-efficiency: (/ (+ (* (get budget-efficiency current-rating) (get total-ratings current-rating)) budget-efficiency) new-total-ratings),
        impact-effectiveness: (/ (+ (* (get impact-effectiveness current-rating) (get total-ratings current-rating)) impact-effectiveness) new-total-ratings),
        community-approval: (get community-approval current-rating),
        total-ratings: new-total-ratings
      })
    )
    
    (ok true)
  )
)

(define-public (mark-project-completed (project-id uint))
  (let ((project (unwrap! (map-get? projects project-id) err-project-not-found)))
    (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender (get recipient project))) err-not-authorized)
    (asserts! (is-eq (get status project) "funded") err-project-not-funded)
    
    (map-set projects project-id (merge project {status: "completed"}))
    (var-set total-completed-projects (+ (var-get total-completed-projects) u1))
    
    (ok true)
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
    total-completed-projects: (var-get total-completed-projects),
    next-milestone-id: (var-get next-milestone-id),
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

(define-read-only (get-project-milestone (milestone-id uint))
  (map-get? project-milestones milestone-id)
)

(define-read-only (get-milestone-verification (milestone-id uint) (verifier principal))
  (map-get? milestone-verifications {milestone-id: milestone-id, verifier: verifier})
)

(define-read-only (get-project-impact-metrics (project-id uint))
  (map-get? project-impact-metrics project-id)
)

(define-read-only (get-project-performance-rating (project-id uint))
  (map-get? project-performance-ratings project-id)
)

(define-read-only (get-project-completion-status (project-id uint))
  (match (map-get? projects project-id)
    project {
      project-id: project-id,
      status: (get status project),
      completion-rate: (if (is-eq (get status project) "completed") u100 
                        (if (is-eq (get status project) "funded") u50 u0)),
      has-impact-data: (is-some (map-get? project-impact-metrics project-id)),
      has-performance-rating: (is-some (map-get? project-performance-ratings project-id))
    }
    {
      project-id: project-id,
      status: "not-found",
      completion-rate: u0,
      has-impact-data: false,
      has-performance-rating: false
    }
  )
)

(define-read-only (get-project-milestone-progress (project-id uint))
  (let ((project (map-get? projects project-id)))
    (match project
      project-data {
        project-exists: true,
        total-milestones: u0,
        completed-milestones: u0,
        completion-percentage: u0
      }
      {
        project-exists: false,
        total-milestones: u0,
        completed-milestones: u0,
        completion-percentage: u0
      }
    )
  )
)

(define-read-only (get-community-satisfaction-average)
  (let ((project1-metrics (map-get? project-impact-metrics u1))
        (project2-metrics (map-get? project-impact-metrics u2))
        (project3-metrics (map-get? project-impact-metrics u3)))
    (/ (+ 
        (match project1-metrics metrics1 (get community-satisfaction metrics1) u0)
        (match project2-metrics metrics2 (get community-satisfaction metrics2) u0)
        (match project3-metrics metrics3 (get community-satisfaction metrics3) u0)
       ) u3)
  )
)

(define-read-only (get-performance-analytics)
  {
    total-projects: (- (var-get next-project-id) u1),
    completed-projects: (var-get total-completed-projects),
    completion-rate: (if (> (var-get next-project-id) u1) 
                      (/ (* (var-get total-completed-projects) u100) (- (var-get next-project-id) u1))
                      u0),
    total-milestones: (- (var-get next-milestone-id) u1),
    average-community-satisfaction: (get-community-satisfaction-average)
  }
)
