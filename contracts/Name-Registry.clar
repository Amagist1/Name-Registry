(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NAME_TAKEN (err u101))
(define-constant ERR_NAME_NOT_FOUND (err u102))
(define-constant ERR_INVALID_NAME (err u103))
(define-constant ERR_ALREADY_REGISTERED (err u104))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u105))

(define-data-var registration-fee uint u1000000)
(define-data-var total-registrations uint u0)

(define-map name-to-address { name: (string-ascii 50) } { owner: principal, registered-at: uint })
(define-map address-to-name { owner: principal } { name: (string-ascii 50) })
(define-map name-metadata { name: (string-ascii 50) } { description: (string-ascii 200), website: (string-ascii 100) })

(define-public (register-name (name (string-ascii 50)))
  (let (
    (name-length (len name))
    (existing-name (map-get? name-to-address { name: name }))
    (existing-address (map-get? address-to-name { owner: tx-sender }))
  )
    (asserts! (> name-length u0) ERR_INVALID_NAME)
    (asserts! (<= name-length u50) ERR_INVALID_NAME)
    (asserts! (is-none existing-name) ERR_NAME_TAKEN)
    (asserts! (is-none existing-address) ERR_ALREADY_REGISTERED)
    
    (try! (stx-transfer? (var-get registration-fee) tx-sender CONTRACT_OWNER))
    
    (map-set name-to-address 
      { name: name } 
      { owner: tx-sender, registered-at: stacks-block-height })
    (map-set address-to-name 
      { owner: tx-sender } 
      { name: name })
    
    (var-set total-registrations (+ (var-get total-registrations) u1))
    (ok name)
  )
)

(define-public (transfer-name (name (string-ascii 50)) (new-owner principal))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? address-to-name { owner: new-owner })) ERR_ALREADY_REGISTERED)
    
    (map-delete address-to-name { owner: current-owner })
    (map-set name-to-address 
      { name: name } 
      { owner: new-owner, registered-at: (get registered-at name-info) })
    (map-set address-to-name 
      { owner: new-owner } 
      { name: name })
    
    (ok true)
  )
)

(define-public (update-metadata (name (string-ascii 50)) (description (string-ascii 200)) (website (string-ascii 100)))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    
    (map-set name-metadata 
      { name: name } 
      { description: description, website: website })
    
    (ok true)
  )
)

(define-public (set-registration-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set registration-fee new-fee)
    (ok true)
  )
)

(define-public (release-name (name (string-ascii 50)))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    
    (map-delete name-to-address { name: name })
    (map-delete address-to-name { owner: current-owner })
    (map-delete name-metadata { name: name })
    
    (var-set total-registrations (- (var-get total-registrations) u1))
    (ok true)
  )
)

(define-read-only (get-name-owner (name (string-ascii 50)))
  (match (map-get? name-to-address { name: name })
    name-info (ok (get owner name-info))
    ERR_NAME_NOT_FOUND
  )
)

(define-read-only (get-address-name (address principal))
  (match (map-get? address-to-name { owner: address })
    address-info (ok (get name address-info))
    ERR_NAME_NOT_FOUND
  )
)

(define-read-only (get-name-info (name (string-ascii 50)))
  (match (map-get? name-to-address { name: name })
    name-info (ok name-info)
    ERR_NAME_NOT_FOUND
  )
)

(define-read-only (get-name-metadata (name (string-ascii 50)))
  (match (map-get? name-metadata { name: name })
    metadata (ok metadata)
    ERR_NAME_NOT_FOUND
  )
)

(define-read-only (get-registration-fee)
  (ok (var-get registration-fee))
)

(define-read-only (get-total-registrations)
  (ok (var-get total-registrations))
)

(define-read-only (is-name-available (name (string-ascii 50)))
  (is-none (map-get? name-to-address { name: name }))
)

(define-read-only (get-contract-owner)
  (ok CONTRACT_OWNER)
)

(define-read-only (validate-name (name (string-ascii 50)))
  (let (
    (name-length (len name))
  )
    (and 
      (> name-length u0)
      (<= name-length u50)
    )
  )
)
