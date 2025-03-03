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
(define-constant err-invalid-input (err u106))
(define-constant gallery-creation-cost u100)
(define-constant min-curator-reputation u50)
(define-constant rate-limit-blocks u144) ;; 24 hours in blocks
(define-constant max-batch-size u10)
(define-constant ipfs-hash-prefix "Qm")

;; Contract status
(define-data-var contract-paused bool false)

;; Enhanced statistics tracking
(define-map gallery-stats
    { gallery-id: uint }
    {
        total-ratings: uint,
        rating-sum: uint,
        view-count: uint,
        last-updated: uint
    }
)

;; Rate limiting with dynamic cooldown
(define-map rating-timestamps
    { user: principal, gallery-id: uint }
    { 
        last-rated: uint,
        rating-count: uint
    }
)

;; Input validation
(define-private (is-valid-ipfs-hash (hash (string-ascii 64)))
    (match (string-slice? hash 0 2)
        success (is-eq success ipfs-hash-prefix)
        false
    )
)

;; Enhanced event emission with categories
(define-private (emit-event (event-type (string-ascii 20)) (category (string-ascii 20)) (data (string-ascii 256)))
    (let
        ((event-id (var-get last-event-id))
         (new-id (+ event-id u1)))
        (map-set events
            { event-id: event-id }
            {
                event-type: event-type,
                category: category,
                user: tx-sender,
                data: data,
                timestamp: block-height
            }
        )
        (var-set last-event-id new-id)
        (ok event-id)
    )
)

;; Enhanced photo upload with validation
(define-public (upload-photo (title (string-ascii 100)) (description (string-ascii 500)) (ipfs-hash (string-ascii 64)))
    (begin
        (asserts! (not (var-get contract-paused)) err-paused)
        (asserts! (is-valid-ipfs-hash ipfs-hash) err-invalid-input)
        
        (let ((photo-id (var-get photo-count)))
            (map-set photos
                { photo-id: photo-id }
                {
                    title: title,
                    description: description,
                    ipfs-hash: ipfs-hash,
                    owner: tx-sender,
                    created-at: block-height
                }
            )
            (var-set photo-count (+ photo-id u1))
            (emit-event "PHOTO_UPLOAD" "content" (concat (uint-to-ascii photo-id) "-uploaded"))
            (ok photo-id)
        )
    )
)

;; Enhanced gallery rating with statistics
(define-public (rate-gallery (gallery-id uint) (rating uint))
    (let 
        ((last-rating (default-to { last-rated: u0, rating-count: u0 }
            (map-get? rating-timestamps { user: tx-sender, gallery-id: gallery-id })))
         (stats (default-to { total-ratings: u0, rating-sum: u0, view-count: u0, last-updated: u0 }
            (map-get? gallery-stats { gallery-id: gallery-id }))))
        
        (asserts! (not (var-get contract-paused)) err-paused)
        (asserts! (>= (- block-height (get last-rated last-rating)) rate-limit-blocks) err-rate-limit)
        (asserts! (<= rating u5) err-invalid-gallery)
        
        (map-set rating-timestamps
            { user: tx-sender, gallery-id: gallery-id }
            { 
                last-rated: block-height,
                rating-count: (+ (get rating-count last-rating) u1)
            }
        )
        
        (map-set gallery-stats
            { gallery-id: gallery-id }
            {
                total-ratings: (+ (get total-ratings stats) u1),
                rating-sum: (+ (get rating-sum stats) rating),
                view-count: (get view-count stats),
                last-updated: block-height
            }
        )
        
        (let ((gallery (unwrap! (map-get? galleries { gallery-id: gallery-id }) err-not-found)))
            (map-set galleries
                { gallery-id: gallery-id }
                (merge gallery { 
                    rating: (/ (get rating-sum stats) (get total-ratings stats))
                })
            )
            (award-curator-points (get curator gallery) rating)
            (emit-event "GALLERY_RATED" "interaction" (concat (uint-to-ascii gallery-id) "-rated"))
            (ok true)
        )
    )
)

;; [Previous functions remain unchanged]
