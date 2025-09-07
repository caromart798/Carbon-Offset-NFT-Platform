(define-non-fungible-token carbon-offset-nft uint)

(define-data-var last-token-id uint u0)
(define-data-var contract-owner principal tx-sender)
(define-data-var platform-fee uint u100)
(define-data-var total-offsets-created uint u0)
(define-data-var total-offsets-retired uint u0)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-ALREADY-RETIRED (err u410))
(define-constant ERR-NOT-VERIFIED (err u403))
(define-constant ERR-INSUFFICIENT-CREDITS (err u411))

(define-constant ERR-BUNDLE-NOT-FOUND (err u450))
(define-constant ERR-BUNDLE-INACTIVE (err u451))
(define-constant ERR-BUNDLE-LIMIT-EXCEEDED (err u452))
(define-constant ERR-BUNDLE-EMPTY (err u453))
(define-constant ERR-NOT-BUNDLE-OWNER (err u454))

(define-constant ERR-LEASE-NOT-FOUND (err u500))
(define-constant ERR-LEASE-EXPIRED (err u501))
(define-constant ERR-LEASE-ACTIVE (err u502))
(define-constant ERR-INVALID-DURATION (err u503))
(define-constant ERR-NOT-LESSEE (err u504))

(define-map offset-details uint {
    project-id: (string-ascii 50),
    carbon-amount: uint,
    verification-standard: (string-ascii 30),
    vintage-year: uint,
    project-type: (string-ascii 50),
    location: (string-ascii 50),
    price: uint,
    created-at: uint,
    retired: bool,
    retired-at: (optional uint),
    retired-by: (optional principal)
})

(define-map project-registry (string-ascii 50) {
    verifier: principal,
    total-credits: uint,
    available-credits: uint,
    verified: bool,
    created-at: uint
})

(define-map user-stats principal {
    total-purchased: uint,
    total-retired: uint,
    total-spent: uint
})

(define-map verifier-registry principal {
    name: (string-ascii 50),
    certified: bool,
    total-projects: uint
})


(define-read-only (get-last-token-id)
    (var-get last-token-id)
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? carbon-offset-nft token-id))
)

(define-read-only (get-offset-details (token-id uint))
    (map-get? offset-details token-id)
)

(define-read-only (get-project-info (project-id (string-ascii 50)))
    (map-get? project-registry project-id)
)

(define-read-only (get-user-stats (user principal))
    (default-to 
        {total-purchased: u0, total-retired: u0, total-spent: u0}
        (map-get? user-stats user)
    )
)

(define-read-only (get-verifier-info (verifier principal))
    (map-get? verifier-registry verifier)
)

(define-read-only (get-platform-stats)
    {
        total-offsets-created: (var-get total-offsets-created),
        total-offsets-retired: (var-get total-offsets-retired),
        platform-fee: (var-get platform-fee)
    }
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (nft-get-owner? carbon-offset-nft token-id)) ERR-NOT-FOUND)
        (nft-transfer? carbon-offset-nft token-id sender recipient)
    )
)

(define-public (register-verifier (verifier principal) (name (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? verifier-registry verifier)) ERR-ALREADY-EXISTS)
        (map-set verifier-registry verifier {
            name: name,
            certified: true,
            total-projects: u0
        })
        (ok true)
    )
)

(define-public (register-project 
    (project-id (string-ascii 50))
    (total-credits uint)
)
    (let (
        (verifier-info (unwrap! (map-get? verifier-registry tx-sender) ERR-NOT-AUTHORIZED))
    )
        (asserts! (get certified verifier-info) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? project-registry project-id)) ERR-ALREADY-EXISTS)
        (asserts! (> total-credits u0) ERR-INVALID-AMOUNT)
        
        (map-set project-registry project-id {
            verifier: tx-sender,
            total-credits: total-credits,
            available-credits: total-credits,
            verified: true,
            created-at: stacks-block-height
        })
        
        (map-set verifier-registry tx-sender 
            (merge verifier-info {total-projects: (+ (get total-projects verifier-info) u1)})
        )
        (ok true)
    )
)

(define-public (mint-offset-nft
    (recipient principal)
    (project-id (string-ascii 50))
    (carbon-amount uint)
    (verification-standard (string-ascii 30))
    (vintage-year uint)
    (project-type (string-ascii 50))
    (location (string-ascii 50))
    (price uint)
)
    (let (
        (token-id (+ (var-get last-token-id) u1))
        (project-info (unwrap! (map-get? project-registry project-id) ERR-NOT-FOUND))
    )
        (asserts! (get verified project-info) ERR-NOT-VERIFIED)
        (asserts! (>= (get available-credits project-info) carbon-amount) ERR-INSUFFICIENT-CREDITS)
        (asserts! (> carbon-amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> price u0) ERR-INVALID-AMOUNT)
        
        (try! (nft-mint? carbon-offset-nft token-id recipient))
        
        (map-set offset-details token-id {
            project-id: project-id,
            carbon-amount: carbon-amount,
            verification-standard: verification-standard,
            vintage-year: vintage-year,
            project-type: project-type,
            location: location,
            price: price,
            created-at: stacks-block-height,
            retired: false,
            retired-at: none,
            retired-by: none
        })
        
        (map-set project-registry project-id 
            (merge project-info {available-credits: (- (get available-credits project-info) carbon-amount)})
        )
        
        (var-set last-token-id token-id)
        (var-set total-offsets-created (+ (var-get total-offsets-created) u1))
        (ok token-id)
    )
)

(define-public (purchase-offset (token-id uint))
    (let (
        (offset-info (unwrap! (map-get? offset-details token-id) ERR-NOT-FOUND))
        (current-owner (unwrap! (nft-get-owner? carbon-offset-nft token-id) ERR-NOT-FOUND))
        (price (get price offset-info))
        (fee (/ (* price (var-get platform-fee)) u10000))
        (buyer-stats (get-user-stats tx-sender))
    )
        (asserts! (not (is-eq tx-sender current-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (not (get retired offset-info)) ERR-ALREADY-RETIRED)
        
        (try! (stx-transfer? (- price fee) tx-sender current-owner))
        (try! (stx-transfer? fee tx-sender (var-get contract-owner)))
        (try! (nft-transfer? carbon-offset-nft token-id current-owner tx-sender))
        
        (map-set user-stats tx-sender {
            total-purchased: (+ (get total-purchased buyer-stats) u1),
            total-retired: (get total-retired buyer-stats),
            total-spent: (+ (get total-spent buyer-stats) price)
        })
        
        (ok true)
    )
)

(define-public (retire-offset (token-id uint))
    (let (
        (offset-info (unwrap! (map-get? offset-details token-id) ERR-NOT-FOUND))
        (owner (unwrap! (nft-get-owner? carbon-offset-nft token-id) ERR-NOT-FOUND))
        (user-stats-data (get-user-stats tx-sender))
    )
        (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
        (asserts! (not (get retired offset-info)) ERR-ALREADY-RETIRED)
        
        (map-set offset-details token-id 
            (merge offset-info {
                retired: true,
                retired-at: (some stacks-block-height),
                retired-by: (some tx-sender)
            })
        )
        
        (map-set user-stats tx-sender {
            total-purchased: (get total-purchased user-stats-data),
            total-retired: (+ (get total-retired user-stats-data) u1),
            total-spent: (get total-spent user-stats-data)
        })
        
        (var-set total-offsets-retired (+ (var-get total-offsets-retired) u1))
        (ok true)
    )
)

(define-public (update-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-fee u1000) ERR-INVALID-AMOUNT)
        (var-set platform-fee new-fee)
        (ok true)
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-public (set-token-uri (token-id uint) (uri (optional (string-utf8 256))))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (ok true)
    )
)

(define-data-var last-bundle-id uint u0)

(define-map bundle-registry uint {
    creator: principal,
    name: (string-ascii 50),
    total-carbon-amount: uint,
    total-price: uint,
    token-ids: (list 20 uint),
    created-at: uint,
    active: bool
})

(define-map bundle-ownership uint principal)

(define-read-only (get-bundle-details (bundle-id uint))
    (map-get? bundle-registry bundle-id)
)

(define-read-only (get-bundle-owner (bundle-id uint))
    (map-get? bundle-ownership bundle-id)
)

(define-read-only (get-last-bundle-id)
    (var-get last-bundle-id)
)

(define-public (create-bundle 
    (name (string-ascii 50))
    (token-ids (list 20 uint))
)
    (let (
        (bundle-id (+ (var-get last-bundle-id) u1))
        (total-carbon (fold calculate-bundle-carbon token-ids u0))
        (total-price (fold calculate-bundle-price token-ids u0))
    )
        (asserts! (> (len token-ids) u0) ERR-BUNDLE-EMPTY)
        (asserts! (<= (len token-ids) u20) ERR-BUNDLE-LIMIT-EXCEEDED)
        (asserts! (check-token-ownership token-ids) ERR-NOT-AUTHORIZED)
        
        (map-set bundle-registry bundle-id {
            creator: tx-sender,
            name: name,
            total-carbon-amount: total-carbon,
            total-price: total-price,
            token-ids: token-ids,
            created-at: stacks-block-height,
            active: true
        })
        
        (map-set bundle-ownership bundle-id tx-sender)
        (var-set last-bundle-id bundle-id)
        (ok bundle-id)
    )
)

(define-public (purchase-bundle (bundle-id uint))
    (let (
        (bundle-info (unwrap! (map-get? bundle-registry bundle-id) ERR-BUNDLE-NOT-FOUND))
        (bundle-owner (unwrap! (map-get? bundle-ownership bundle-id) ERR-BUNDLE-NOT-FOUND))
        (total-price (get total-price bundle-info))
        (fee (/ (* total-price (var-get platform-fee)) u10000))
        (buyer-stats (get-user-stats tx-sender))
    )
        (asserts! (get active bundle-info) ERR-BUNDLE-INACTIVE)
        (asserts! (not (is-eq tx-sender bundle-owner)) ERR-NOT-AUTHORIZED)
    
        (try! (stx-transfer? (- total-price fee) tx-sender bundle-owner))
        (try! (stx-transfer? fee tx-sender (var-get contract-owner)))
        
        (try! (transfer-bundle-tokens (get token-ids bundle-info) bundle-owner tx-sender))
        
        (map-set bundle-ownership bundle-id tx-sender)
        (map-set user-stats tx-sender {
            total-purchased: (+ (get total-purchased buyer-stats) (len (get token-ids bundle-info))),
            total-retired: (get total-retired buyer-stats),
            total-spent: (+ (get total-spent buyer-stats) total-price)
        })
        
        (ok true)
    )
)

(define-public (retire-bundle (bundle-id uint))
    (let (
        (bundle-info (unwrap! (map-get? bundle-registry bundle-id) ERR-BUNDLE-NOT-FOUND))
        (bundle-owner (unwrap! (map-get? bundle-ownership bundle-id) ERR-BUNDLE-NOT-FOUND))
    )
        (asserts! (is-eq tx-sender bundle-owner) ERR-NOT-BUNDLE-OWNER)
        (asserts! (get active bundle-info) ERR-BUNDLE-INACTIVE)
        
        (try! (retire-bundle-tokens (get token-ids bundle-info)))
        
        (map-set bundle-registry bundle-id 
            (merge bundle-info {active: false})
        )
        
        (ok true)
    )
)

(define-private (calculate-bundle-carbon (token-id uint) (acc uint))
    (match (map-get? offset-details token-id)
        offset-info (+ acc (get carbon-amount offset-info))
        acc
    )
)

(define-private (calculate-bundle-price (token-id uint) (acc uint))
    (match (map-get? offset-details token-id)
        offset-info (+ acc (get price offset-info))
        acc
    )
)

(define-private (check-token-ownership (token-ids (list 20 uint)))
    (fold check-single-token-ownership token-ids true)
)

(define-private (check-single-token-ownership (token-id uint) (acc bool))
    (and acc (is-eq (some tx-sender) (nft-get-owner? carbon-offset-nft token-id)))
)

(define-private (transfer-bundle-tokens (token-ids (list 20 uint)) (from principal) (to principal))
    (let (
        (result (fold transfer-single-token token-ids {from: from, to: to, success: true}))
    )
        (if (get success result)
            (ok true)
            ERR-NOT-AUTHORIZED
        )
    )
)

(define-private (transfer-single-token (token-id uint) (transfer-data {from: principal, to: principal, success: bool}))
    (if (get success transfer-data)
        (match (nft-transfer? carbon-offset-nft token-id (get from transfer-data) (get to transfer-data))
            success transfer-data
            error (merge transfer-data {success: false})
        )
        transfer-data
    )
)

(define-private (retire-bundle-tokens (token-ids (list 20 uint)))
    (let (
        (result (fold retire-single-bundle-token token-ids true))
    )
        (if result
            (ok true)
            ERR-NOT-AUTHORIZED
        )
    )
)

(define-private (retire-single-bundle-token (token-id uint) (acc bool))
    (and acc (is-ok (retire-offset token-id)))
)

(define-data-var last-lease-id uint u0)

(define-map lease-registry uint {
    token-id: uint,
    lessor: principal,
    lessee: principal,
    start-block: uint,
    end-block: uint,
    lease-price: uint,
    active: bool,
    created-at: uint
})

(define-map active-leases uint uint)

(define-read-only (get-lease-details (lease-id uint))
    (map-get? lease-registry lease-id)
)

(define-read-only (get-token-lease (token-id uint))
    (map-get? active-leases token-id)
)

(define-read-only (is-token-leased (token-id uint))
    (match (map-get? active-leases token-id)
        lease-id (match (map-get? lease-registry lease-id)
            lease-info (and (get active lease-info) (>= (get end-block lease-info) stacks-block-height))
            false
        )
        false
    )
)

(define-public (create-lease (token-id uint) (duration uint) (lease-price uint))
    (let (
        (lease-id (+ (var-get last-lease-id) u1))
        (token-owner (unwrap! (nft-get-owner? carbon-offset-nft token-id) ERR-NOT-FOUND))
        (offset-info (unwrap! (map-get? offset-details token-id) ERR-NOT-FOUND))
        (end-block (+ stacks-block-height duration))
    )
        (asserts! (is-eq tx-sender token-owner) ERR-NOT-AUTHORIZED)
        (asserts! (not (get retired offset-info)) ERR-ALREADY-RETIRED)
        (asserts! (not (is-token-leased token-id)) ERR-LEASE-ACTIVE)
        (asserts! (> duration u0) ERR-INVALID-DURATION)
        (asserts! (> lease-price u0) ERR-INVALID-AMOUNT)
        
        (map-set lease-registry lease-id {
            token-id: token-id,
            lessor: tx-sender,
            lessee: tx-sender,
            start-block: stacks-block-height,
            end-block: end-block,
            lease-price: lease-price,
            active: false,
            created-at: stacks-block-height
        })
        
        (var-set last-lease-id lease-id)
        (ok lease-id)
    )
)

(define-public (accept-lease (lease-id uint))
    (let (
        (lease-info (unwrap! (map-get? lease-registry lease-id) ERR-LEASE-NOT-FOUND))
        (fee (/ (* (get lease-price lease-info) (var-get platform-fee)) u10000))
    )
        (asserts! (not (is-eq tx-sender (get lessor lease-info))) ERR-NOT-AUTHORIZED)
        (asserts! (not (get active lease-info)) ERR-LEASE-ACTIVE)
        (asserts! (>= (get end-block lease-info) stacks-block-height) ERR-LEASE-EXPIRED)
        
        (try! (stx-transfer? (- (get lease-price lease-info) fee) tx-sender (get lessor lease-info)))
        (try! (stx-transfer? fee tx-sender (var-get contract-owner)))
        
        (map-set lease-registry lease-id 
            (merge lease-info {lessee: tx-sender, active: true})
        )
        (map-set active-leases (get token-id lease-info) lease-id)
        (ok true)
    )
)

(define-map user-reputation principal {
    environmental-score: uint,
    activity-level: uint,
    total-impact: uint,
    reputation-tier: uint,
    last-updated: uint
})

(define-map verifier-reputation principal {
    reliability-score: uint,
    projects-verified: uint,
    community-rating: uint,
    verification-tier: uint,
    last-active: uint
})

(define-read-only (get-user-reputation (user principal))
    (default-to 
        {environmental-score: u0, activity-level: u0, total-impact: u0, reputation-tier: u0, last-updated: u0}
        (map-get? user-reputation user)
    )
)

(define-read-only (get-verifier-reputation (verifier principal))
    (default-to 
        {reliability-score: u0, projects-verified: u0, community-rating: u0, verification-tier: u0, last-active: u0}
        (map-get? verifier-reputation verifier)
    )
)

(define-read-only (calculate-reputation-discount (user principal))
    (let (
        (user-rep (get-user-reputation user))
        (tier (get reputation-tier user-rep))
    )
        (if (>= tier u4) u500
            (if (>= tier u3) u300
                (if (>= tier u2) u150
                    (if (>= tier u1) u50 u0)
                )
            )
        )
    )
)

(define-private (update-user-reputation (user principal) (carbon-amount uint) (action-type uint))
    (let (
        (current-rep (get-user-reputation user))
        (score-boost (if (is-eq action-type u1) (* carbon-amount u10) (* carbon-amount u20)))
        (new-score (+ (get environmental-score current-rep) score-boost))
        (new-activity (+ (get activity-level current-rep) u1))
        (new-impact (+ (get total-impact current-rep) carbon-amount))
        (new-tier (calculate-user-tier new-score new-activity))
    )
        (map-set user-reputation user {
            environmental-score: new-score,
            activity-level: new-activity,
            total-impact: new-impact,
            reputation-tier: new-tier,
            last-updated: stacks-block-height
        })
    )
)

(define-private (update-verifier-reputation (verifier principal))
    (let (
        (current-rep (get-verifier-reputation verifier))
        (new-projects (+ (get projects-verified current-rep) u1))
        (new-score (+ (get reliability-score current-rep) u100))
        (new-tier (calculate-verifier-tier new-score new-projects))
    )
        (map-set verifier-reputation verifier {
            reliability-score: new-score,
            projects-verified: new-projects,
            community-rating: (get community-rating current-rep),
            verification-tier: new-tier,
            last-active: stacks-block-height
        })
    )
)

(define-private (calculate-user-tier (score uint) (activity uint))
    (if (and (>= score u10000) (>= activity u50)) u4
        (if (and (>= score u5000) (>= activity u25)) u3
            (if (and (>= score u2000) (>= activity u10)) u2
                (if (and (>= score u500) (>= activity u3)) u1 u0)
            )
        )
    )
)

(define-private (calculate-verifier-tier (score uint) (projects uint))
    (if (and (>= score u5000) (>= projects u20)) u4
        (if (and (>= score u2500) (>= projects u10)) u3
            (if (and (>= score u1000) (>= projects u5)) u2
                (if (and (>= score u300) (>= projects u2)) u1 u0)
            )
        )
    )
)