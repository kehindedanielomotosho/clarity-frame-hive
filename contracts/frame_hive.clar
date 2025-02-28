;; FrameHive Contract
;; Handles photo sharing, critiques, collaboration and gallery curation

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-gallery (err u103))
(define-constant err-rate-limit (err u104))
(define-constant err-paused (err u105))
(define-constant gallery-creation-cost u100)
(define-constant min-curator-reputation u50)
(define-constant rate-limit-blocks u144) ;; 24 hours in blocks

;; Contract status
(define-data-var contract-paused bool false)

;; Rate limiting
(define-map rating-timestamps
    { user: principal, gallery-id: uint }
    { last-rated: uint }
)

;; Events
(define-data-var last-event-id uint u0)
(define-map events 
    { event-id: uint }
    {
        event-type: (string-ascii 20),
        user: principal,
        data: (string-ascii 256)
    }
)

;; [Previous data structures remain unchanged]

;; Admin functions
(define-public (pause-contract)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused true)
        (ok true)
    )
)

(define-public (unpause-contract)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused false)
        (ok true)
    )
)

;; Event emission
(define-private (emit-event (event-type (string-ascii 20)) (data (string-ascii 256)))
    (let
        ((event-id (var-get last-event-id))
         (new-id (+ event-id u1)))
        (map-set events
            { event-id: event-id }
            {
                event-type: event-type,
                user: tx-sender,
                data: data
            }
        )
        (var-set last-event-id new-id)
        (ok event-id)
    )
)

;; Enhanced photo functions
(define-public (transfer-photo-ownership (photo-id uint) (new-owner principal))
    (let ((photo (unwrap! (map-get? photos { photo-id: photo-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get owner photo)) err-unauthorized)
        (map-set photos
            { photo-id: photo-id }
            (merge photo { owner: new-owner })
        )
        (emit-event "PHOTO_TRANSFER" (concat (uint-to-ascii photo-id) "-transferred"))
        (ok true)
    )
)

(define-public (batch-upload-photos (photo-data (list 10 {
    title: (string-ascii 100),
    description: (string-ascii 500),
    ipfs-hash: (string-ascii 64)
})))
    (fold upload-photo-from-batch photo-data (ok (list)))
)

(define-private (upload-photo-from-batch 
    (data {
        title: (string-ascii 100),
        description: (string-ascii 500),
        ipfs-hash: (string-ascii 64)
    }) 
    (previous-result (response (list uint) uint)))
    (match previous-result
        success (let ((photo-id (var-get photo-count)))
            (upload-photo (get title data) (get description data) (get ipfs-hash data))
            (ok (append success photo-id)))
        error (err error))
)

;; Enhanced gallery rating
(define-public (rate-gallery (gallery-id uint) (rating uint))
    (let ((last-rating (default-to { last-rated: u0 }
            (map-get? rating-timestamps { user: tx-sender, gallery-id: gallery-id }))))
        (asserts! (not (var-get contract-paused)) err-paused)
        (asserts! (>= (- block-height (get last-rated last-rating)) rate-limit-blocks) err-rate-limit)
        (asserts! (<= rating u5) err-invalid-gallery)
        
        (map-set rating-timestamps
            { user: tx-sender, gallery-id: gallery-id }
            { last-rated: block-height }
        )
        
        (map-set gallery-votes
            { gallery-id: gallery-id, voter: tx-sender }
            { rating: rating }
        )
        
        (let ((gallery (unwrap! (map-get? galleries { gallery-id: gallery-id }) err-not-found)))
            (map-set galleries
                { gallery-id: gallery-id }
                (merge gallery { rating: (/ (+ (get rating gallery) rating) u2) })
            )
            (award-curator-points (get curator gallery) rating)
            (emit-event "GALLERY_RATED" (concat (uint-to-ascii gallery-id) "-rated"))
            (ok true)
        )
    )
)

;; [Previous functions remain unchanged]
