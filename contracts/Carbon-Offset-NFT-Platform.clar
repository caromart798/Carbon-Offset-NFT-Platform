(define-non-fungible-token carbon-offset-nft uint)

(define-data-var last-token-id uint u0)
(define-data-var contract-owner principal tx-sender)
(define-data-var platform-fee uint u100)
(define-data-var total-offsets-created uint u0)
(define-data-var total-offsets-retired uint u0)

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

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-ALREADY-RETIRED (err u410))
(define-constant ERR-NOT-VERIFIED (err u403))
(define-constant ERR-INSUFFICIENT-CREDITS (err u411))

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
