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
(define-constant ERR_IN_GRACE_PERIOD (err u112))
(define-constant ERR_GRACE_PERIOD_EXPIRED (err u113))
(define-constant ERR_HISTORY_NOT_FOUND (err u114))
(define-constant ERR_LEASE_NOT_FOUND (err u115))
(define-constant ERR_LEASE_EXPIRED (err u116))
(define-constant ERR_ALREADY_LEASED (err u117))
(define-constant ERR_NOT_LESSEE (err u118))

(define-constant ERR_RECORD_NOT_FOUND (err u119))
(define-constant ERR_INVALID_RECORD_KEY (err u120))
(define-constant ERR_INVALID_RECORD_VALUE (err u121))

(define-data-var registration-fee uint u1000000)
(define-data-var renewal-fee uint u500000)
(define-data-var registration-period uint u52560)
(define-data-var grace-period uint u2160)
(define-data-var total-registrations uint u0)


(define-map name-to-address { name: (string-ascii 50) } { owner: principal, registered-at: uint, expires-at: uint })
(define-map address-to-name { owner: principal } { name: (string-ascii 50) })
(define-map name-metadata { name: (string-ascii 50) } { description: (string-ascii 200), website: (string-ascii 100) })
(define-map name-redirects { name: (string-ascii 50) } { redirect-type: (string-ascii 20), target: (string-ascii 200) })
(define-map name-history-count { name: (string-ascii 50) } { count: uint })
(define-map name-history { name: (string-ascii 50), index: uint } { event-type: (string-ascii 20), from-owner: (optional principal), to-owner: principal, block-height: uint })
(define-map name-leases { name: (string-ascii 50) } { lessee: principal, lease-end: uint, lease-price: uint, leased-at: uint })

(define-map name-records { name: (string-ascii 50), key: (string-ascii 40) } { value: (string-ascii 200) })

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
    (unwrap-panic (record-name-event name "registration" none tx-sender))
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
    
    (unwrap-panic (record-name-event name "transfer" (some current-owner) new-owner))
    (ok true)
  )
)

(define-public (update-metadata (name (string-ascii 50)) (description (string-ascii 200)) (website (string-ascii 100)))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
    (expiry-height (get expires-at name-info))
  )
    (asserts! (or (is-eq tx-sender current-owner) (is-active-lessee tx-sender name)) ERR_UNAUTHORIZED)
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
    (map-delete name-history-count { name: name })
    (map-delete name-leases { name: name })
    
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
    name-info (let ((grace-end (+ (get expires-at name-info) (var-get grace-period))))
                (<= grace-end stacks-block-height))
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
    (asserts! (or (is-eq tx-sender current-owner) (is-active-lessee tx-sender name)) ERR_UNAUTHORIZED)
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

(define-public (recover-from-grace-period (name (string-ascii 50)))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
    (expiry-height (get expires-at name-info))
    (grace-end (+ expiry-height (var-get grace-period)))
    (current-height stacks-block-height)
    (new-expiry (+ current-height (var-get registration-period)))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    (asserts! (<= expiry-height current-height) ERR_NAME_EXPIRED)
    (asserts! (> grace-end current-height) ERR_GRACE_PERIOD_EXPIRED)
    
    (try! (stx-transfer? (var-get renewal-fee) tx-sender CONTRACT_OWNER))
    
    (map-set name-to-address 
      { name: name } 
      { owner: current-owner, 
        registered-at: (get registered-at name-info), 
        expires-at: new-expiry })
    
    (unwrap-panic (record-name-event name "recovery" none current-owner))
    (ok new-expiry)
  )
)

(define-public (set-grace-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set grace-period new-period)
    (ok true)
  )
)

(define-read-only (is-in-grace-period (name (string-ascii 50)))
  (match (map-get? name-to-address { name: name })
    name-info (let ((expiry (get expires-at name-info))
                    (grace-end (+ expiry (var-get grace-period))))
                (and (<= expiry stacks-block-height) 
                     (> grace-end stacks-block-height)))
    false
  )
)

(define-read-only (get-grace-period-end (name (string-ascii 50)))
  (match (map-get? name-to-address { name: name })
    name-info (ok (+ (get expires-at name-info) (var-get grace-period)))
    ERR_NAME_NOT_FOUND
  )
)

(define-read-only (get-grace-period)
  (ok (var-get grace-period))
)

(define-private (record-name-event (name (string-ascii 50)) (event-type (string-ascii 20)) (from-owner (optional principal)) (to-owner principal))
  (let (
    (current-count (default-to u0 (get count (map-get? name-history-count { name: name }))))
    (new-count (+ current-count u1))
  )
    (map-set name-history-count 
      { name: name } 
      { count: new-count })
    
    (map-set name-history 
      { name: name, index: new-count } 
      { event-type: event-type, from-owner: from-owner, to-owner: to-owner, block-height: stacks-block-height })
    
    (ok new-count)
  )
)

(define-read-only (get-name-history-count (name (string-ascii 50)))
  (ok (default-to u0 (get count (map-get? name-history-count { name: name }))))
)

(define-read-only (get-name-history-event (name (string-ascii 50)) (index uint))
  (match (map-get? name-history { name: name, index: index })
    history-event (ok history-event)
    ERR_HISTORY_NOT_FOUND
  )
)

(define-read-only (get-name-recent-events (name (string-ascii 50)) (limit uint))
  (let (
    (total-count (default-to u0 (get count (map-get? name-history-count { name: name }))))
    (start-index (if (> total-count limit) (- total-count (- limit u1)) u1))
  )
    (if (is-eq total-count u0)
      (ok none)
      (ok (some { start-index: start-index, total-count: total-count }))
    )
  )
)

(define-read-only (get-name-first-registration (name (string-ascii 50)))
  (get-name-history-event name u1)
)

(define-read-only (get-name-latest-event (name (string-ascii 50)))
  (let (
    (total-count (default-to u0 (get count (map-get? name-history-count { name: name }))))
  )
    (if (is-eq total-count u0)
      ERR_HISTORY_NOT_FOUND
      (get-name-history-event name total-count)
    )
  )
)

(define-private (is-active-lessee (user principal) (name (string-ascii 50)))
  (match (map-get? name-leases { name: name })
    lease-info (and (is-eq user (get lessee lease-info)) 
                    (> (get lease-end lease-info) stacks-block-height))
    false
  )
)

(define-public (lease-name (name (string-ascii 50)) (lessee principal) (duration uint) (price uint))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
    (expiry-height (get expires-at name-info))
    (lease-end (+ stacks-block-height duration))
    (existing-lease (map-get? name-leases { name: name }))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    (asserts! (> expiry-height stacks-block-height) ERR_NAME_EXPIRED)
    (asserts! (< lease-end expiry-height) ERR_NAME_EXPIRED)
    (asserts! (> price u0) ERR_INSUFFICIENT_PAYMENT)
    (asserts! (> duration u0) ERR_INVALID_NAME)
    (asserts! (match existing-lease 
                lease-data (<= (get lease-end lease-data) stacks-block-height)
                true) ERR_ALREADY_LEASED)
    
    (try! (stx-transfer? price lessee current-owner))
    
    (map-set name-leases 
      { name: name } 
      { lessee: lessee, lease-end: lease-end, lease-price: price, leased-at: stacks-block-height })
    
    (unwrap-panic (record-name-event name "lease" none lessee))
    (ok lease-end)
  )
)

(define-public (terminate-lease (name (string-ascii 50)))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
    (lease-info (unwrap! (map-get? name-leases { name: name }) ERR_LEASE_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    
    (map-delete name-leases { name: name })
    (ok true)
  )
)

(define-public (extend-lease (name (string-ascii 50)) (additional-duration uint) (additional-price uint))
  (let (
    (lease-info (unwrap! (map-get? name-leases { name: name }) ERR_LEASE_NOT_FOUND))
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
    (current-lessee (get lessee lease-info))
    (current-lease-end (get lease-end lease-info))
    (new-lease-end (+ current-lease-end additional-duration))
    (expiry-height (get expires-at name-info))
  )
    (asserts! (is-eq tx-sender current-lessee) ERR_NOT_LESSEE)
    (asserts! (> current-lease-end stacks-block-height) ERR_LEASE_EXPIRED)
    (asserts! (< new-lease-end expiry-height) ERR_NAME_EXPIRED)
    (asserts! (> additional-price u0) ERR_INSUFFICIENT_PAYMENT)
    
    (try! (stx-transfer? additional-price tx-sender current-owner))
    
    (map-set name-leases 
      { name: name } 
      { lessee: current-lessee, 
        lease-end: new-lease-end, 
        lease-price: (+ (get lease-price lease-info) additional-price),
        leased-at: (get leased-at lease-info) })
    
    (ok new-lease-end)
  )
)

(define-read-only (get-lease-info (name (string-ascii 50)))
  (match (map-get? name-leases { name: name })
    lease-info (ok lease-info)
    ERR_LEASE_NOT_FOUND
  )
)

(define-read-only (is-name-leased (name (string-ascii 50)))
  (match (map-get? name-leases { name: name })
    lease-info (> (get lease-end lease-info) stacks-block-height)
    false
  )
)

(define-read-only (get-lessee (name (string-ascii 50)))
  (match (map-get? name-leases { name: name })
    lease-info (if (> (get lease-end lease-info) stacks-block-height)
                  (ok (get lessee lease-info))
                  ERR_LEASE_EXPIRED)
    ERR_LEASE_NOT_FOUND
  )
)

(define-public (set-record (name (string-ascii 50)) (key (string-ascii 40)) (value (string-ascii 200)))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
    (expiry-height (get expires-at name-info))
    (key-length (len key))
    (value-length (len value))
  )
    (asserts! (or (is-eq tx-sender current-owner) (is-active-lessee tx-sender name)) ERR_UNAUTHORIZED)
    (asserts! (> expiry-height stacks-block-height) ERR_NAME_EXPIRED)
    (asserts! (> key-length u0) ERR_INVALID_RECORD_KEY)
    (asserts! (> value-length u0) ERR_INVALID_RECORD_VALUE)
    (map-set name-records { name: name, key: key } { value: value })
    (ok true)
  )
)

(define-public (remove-record (name (string-ascii 50)) (key (string-ascii 40)))
  (let (
    (name-info (unwrap! (map-get? name-to-address { name: name }) ERR_NAME_NOT_FOUND))
    (current-owner (get owner name-info))
    (expiry-height (get expires-at name-info))
    (existing (map-get? name-records { name: name, key: key }))
  )
    (asserts! (is-eq tx-sender current-owner) ERR_UNAUTHORIZED)
    (asserts! (> expiry-height stacks-block-height) ERR_NAME_EXPIRED)
    (asserts! (is-some existing) ERR_RECORD_NOT_FOUND)
    (map-delete name-records { name: name, key: key })
    (ok true)
  )
)

(define-read-only (get-record (name (string-ascii 50)) (key (string-ascii 40)))
  (match (map-get? name-records { name: name, key: key })
    record-info (ok (get value record-info))
    ERR_RECORD_NOT_FOUND
  )
)

(define-read-only (has-record (name (string-ascii 50)) (key (string-ascii 40)))
  (is-some (map-get? name-records { name: name, key: key }))
)
