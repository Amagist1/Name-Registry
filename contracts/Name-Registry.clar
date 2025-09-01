(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NAME_TAKEN (err u101))
(define-constant ERR_NAME_NOT_FOUND (err u102))
(define-constant ERR_INVALID_NAME (err u103))
(define-constant ERR_ALREADY_REGISTERED (err u104))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u105))


(define-constant ERR_NAME_EXPIRED (err u106))
(define-constant ERR_PARENT_NOT_FOUND (err u107))
(define-constant ERR_SUBDOMAIN_NOT_FOUND (err u108))
(define-constant ERR_INVALID_SUBDOMAIN (err u109))
(define-constant ERR_NO_REDIRECT_SET (err u110))
(define-constant ERR_INVALID_REDIRECT_TYPE (err u111))

(define-data-var registration-fee uint u1000000)
(define-data-var renewal-fee uint u500000)
(define-data-var registration-period uint u52560)
(define-data-var total-registrations uint u0)


(define-map name-to-address { name: (string-ascii 50) } { owner: principal, registered-at: uint, expires-at: uint })
(define-map address-to-name { owner: principal } { name: (string-ascii 50) })
(define-map name-metadata { name: (string-ascii 50) } { description: (string-ascii 200), website: (string-ascii 100) })
(define-map name-redirects { name: (string-ascii 50) } { redirect-type: (string-ascii 20), target: (string-ascii 200) })

(define-public (register-name (name (string-ascii 50)))
  (let (
    (name-length (len name))
    (existing-name (map-get? name-to-address { name: name }))
    (existing-address (map-get? address-to-name { owner: tx-sender }))
    (current-height stacks-block-height)
    (expiry-height (+ current-height (var-get registration-period)))
  )
    (asserts! (> name-length u0) ERR_INVALID_NAME)
    (asserts! (<= name-length u50) ERR_INVALID_NAME)
    (asserts! (is-name-available-or-expired name) ERR_NAME_TAKEN)
    (asserts! (is-none existing-address) ERR_ALREADY_REGISTERED)
    
    (try! (stx-transfer? (var-get registration-fee) tx-sender CONTRACT_OWNER))
    
    (if (is-some existing-name)
      (let ((old-owner (get owner (unwrap-panic existing-name))))
        (map-delete address-to-name { owner: old-owner }))
      true)
    
    (map-set name-to-address 
      { name: name } 
      { owner: tx-sender, registered-at: current-height, expires-at: expiry-height })
    (map-set address-to-name 
      { owner: tx-sender } 
      { name: name })
    
    (var-set total-registrations (+ (var-get total-registrations) u1))
    (ok name)
  )
)

(define-public (renew-name (name (string-ascii 50)))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
    (current-expiry (get expires-at name-info))
    (new-expiry (+ current-expiry (var-get registration-period)))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    
    (try! (stx-transfer? (var-get renewal-fee) tx-sender CONTRACT_OWNER))
    
    (map-set name-to-address 
      { name: name } 
      { owner: current-owner, 
        registered-at: (get registered-at name-info), 
        expires-at: new-expiry })
    
    (ok new-expiry)
  )
)

(define-public (set-renewal-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set renewal-fee new-fee)
    (ok true)
  )
)

(define-public (set-registration-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set registration-period new-period)
    (ok true)
  )
)

(define-public (transfer-name (name (string-ascii 50)) (new-owner principal))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
    (expiry-height (get expires-at name-info))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    (asserts! (> expiry-height stacks-block-height) ERR_NAME_EXPIRED)
    (asserts! (is-none (map-get? address-to-name { owner: new-owner })) ERR_ALREADY_REGISTERED)
    
    (map-delete address-to-name { owner: current-owner })
    (map-set name-to-address 
      { name: name } 
      { owner: new-owner, 
        registered-at: (get registered-at name-info),
        expires-at: expiry-height })
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
    (expiry-height (get expires-at name-info))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    (asserts! (> expiry-height stacks-block-height) ERR_NAME_EXPIRED)
    
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
    (map-delete name-redirects { name: name })
    
    (var-set total-registrations (- (var-get total-registrations) u1))
    (ok true)
  )
)

(define-read-only (get-name-owner (name (string-ascii 50)))
  (match (map-get? name-to-address { name: name })
    name-info 
      (if (> (get expires-at name-info) stacks-block-height)
        (ok (get owner name-info))
        ERR_NAME_EXPIRED)
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

(define-read-only (get-renewal-fee)
  (ok (var-get renewal-fee))
)

(define-read-only (get-registration-period)
  (ok (var-get registration-period))
)

(define-read-only (get-total-registrations)
  (ok (var-get total-registrations))
)

(define-read-only (is-name-available (name (string-ascii 50)))
  (is-none (map-get? name-to-address { name: name }))
)

(define-read-only (is-name-expired (name (string-ascii 50)))
  (match (map-get? name-to-address { name: name })
    name-info (<= (get expires-at name-info) stacks-block-height)
    false
  )
)

(define-read-only (is-name-available-or-expired (name (string-ascii 50)))
  (match (map-get? name-to-address { name: name })
    name-info (<= (get expires-at name-info) stacks-block-height)
    true
  )
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

(define-public (set-redirect (name (string-ascii 50)) (redirect-type (string-ascii 20)) (target (string-ascii 200)))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
    (expiry-height (get expires-at name-info))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    (asserts! (> expiry-height stacks-block-height) ERR_NAME_EXPIRED)
    (asserts! (or (is-eq redirect-type "url") (is-eq redirect-type "stacks") (is-eq redirect-type "bitcoin")) ERR_INVALID_REDIRECT_TYPE)
    (asserts! (> (len target) u0) ERR_INVALID_REDIRECT_TYPE)
    
    (map-set name-redirects 
      { name: name } 
      { redirect-type: redirect-type, target: target })
    
    (ok true)
  )
)

(define-public (remove-redirect (name (string-ascii 50)))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
    (expiry-height (get expires-at name-info))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    (asserts! (> expiry-height stacks-block-height) ERR_NAME_EXPIRED)
    (asserts! (is-some (map-get? name-redirects { name: name })) ERR_NO_REDIRECT_SET)
    
    (map-delete name-redirects { name: name })
    (ok true)
  )
)

(define-read-only (resolve-name (name (string-ascii 50)))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (expiry-height (get expires-at name-info))
  )
    (asserts! (> expiry-height stacks-block-height) ERR_NAME_EXPIRED)
    (match (map-get? name-redirects { name: name })
      redirect-info (ok redirect-info)
      ERR_NO_REDIRECT_SET
    )
  )
)

(define-read-only (get-redirect (name (string-ascii 50)))
  (match (map-get? name-redirects { name: name })
    redirect-info (ok redirect-info)
    ERR_NO_REDIRECT_SET
  )
)

(define-read-only (has-redirect (name (string-ascii 50)))
  (is-some (map-get? name-redirects { name: name }))
)
