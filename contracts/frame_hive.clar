;; FrameHive Contract
;; Handles photo sharing, critiques, collaboration and gallery curation

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-gallery (err u103))
(define-constant gallery-creation-cost u100)
(define-constant min-curator-reputation u50)

;; Data structures
(define-map photos 
    { photo-id: uint }
    {
        owner: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        ipfs-hash: (string-ascii 64),
        created-at: uint,
        reputation-points: uint
    }
)

(define-map comments
    { comment-id: uint }
    {
        photo-id: uint,
        author: principal,
        content: (string-ascii 500),
        created-at: uint
    }
)

(define-map user-reputation
    { user: principal }
    { score: uint }
)

(define-map collaborations
    { collab-id: uint }
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        members: (list 10 principal),
        status: (string-ascii 20)
    }
)

(define-map galleries
    { gallery-id: uint }
    {
        curator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        photos: (list 50 uint),
        created-at: uint,
        views: uint,
        rating: uint
    }
)

(define-map gallery-votes
    { gallery-id: uint, voter: principal }
    { rating: uint }
)

;; Data variables
(define-data-var photo-count uint u0)
(define-data-var comment-count uint u0)
(define-data-var collab-count uint u0)
(define-data-var gallery-count uint u0)

;; Photo functions
(define-public (upload-photo (title (string-ascii 100)) (description (string-ascii 500)) (ipfs-hash (string-ascii 64)))
    (let
        ((photo-id (var-get photo-count))
         (new-count (+ photo-id u1)))
        (map-set photos
            { photo-id: photo-id }
            {
                owner: tx-sender,
                title: title,
                description: description,
                ipfs-hash: ipfs-hash,
                created-at: block-height,
                reputation-points: u0
            }
        )
        (var-set photo-count new-count)
        (ok photo-id)
    )
)

(define-public (add-comment (photo-id uint) (content (string-ascii 500)))
    (let
        ((comment-id (var-get comment-count))
         (new-count (+ comment-id u1)))
        (map-set comments
            { comment-id: comment-id }
            {
                photo-id: photo-id,
                author: tx-sender,
                content: content,
                created-at: block-height
            }
        )
        (var-set comment-count new-count)
        (ok comment-id)
    )
)

;; Gallery curation functions
(define-public (create-gallery (title (string-ascii 100)) (description (string-ascii 500)))
    (let
        ((curator-rep (get score (get-user-reputation tx-sender))))
        (asserts! (>= curator-rep min-curator-reputation) err-unauthorized)
        (let
            ((gallery-id (var-get gallery-count))
             (new-count (+ gallery-id u1)))
            (map-set galleries
                { gallery-id: gallery-id }
                {
                    curator: tx-sender,
                    title: title,
                    description: description,
                    photos: (list),
                    created-at: block-height,
                    views: u0,
                    rating: u0
                }
            )
            (var-set gallery-count new-count)
            (ok gallery-id)
        )
    )
)

(define-public (add-photo-to-gallery (gallery-id uint) (photo-id uint))
    (let ((gallery (unwrap! (map-get? galleries { gallery-id: gallery-id }) err-not-found)))
        (asserts! (is-eq tx-sender (get curator gallery)) err-unauthorized)
        (ok (map-set galleries
            { gallery-id: gallery-id }
            (merge gallery
                { photos: (unwrap! (as-max-len? (append (get photos gallery) photo-id) u50) err-invalid-gallery) }
            )
        ))
    )
)

(define-public (rate-gallery (gallery-id uint) (rating uint))
    (begin
        (asserts! (<= rating u5) err-invalid-gallery)
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
            (ok true)
        )
    )
)

(define-private (award-curator-points (curator principal) (rating uint))
    (let ((points (* rating u10)))
        (award-points curator points)
    )
)

;; Reputation functions
(define-public (award-points (user principal) (points uint))
    (let
        ((current-score (default-to { score: u0 } (map-get? user-reputation { user: user }))))
        (map-set user-reputation
            { user: user }
            { score: (+ (get score current-score) points) }
        )
        (ok true)
    )
)

;; Collaboration functions
(define-public (create-collaboration (title (string-ascii 100)) (description (string-ascii 500)))
    (let
        ((collab-id (var-get collab-count))
         (new-count (+ collab-id u1)))
        (map-set collaborations
            { collab-id: collab-id }
            {
                creator: tx-sender,
                title: title,
                description: description,
                members: (list tx-sender),
                status: "active"
            }
        )
        (var-set collab-count new-count)
        (ok collab-id)
    )
)

;; Read functions
(define-read-only (get-photo (photo-id uint))
    (map-get? photos { photo-id: photo-id })
)

(define-read-only (get-user-reputation (user principal))
    (default-to { score: u0 } (map-get? user-reputation { user: user }))
)

(define-read-only (get-collaboration (collab-id uint))
    (map-get? collaborations { collab-id: collab-id })
)

(define-read-only (get-gallery (gallery-id uint))
    (map-get? galleries { gallery-id: gallery-id })
)

(define-read-only (get-gallery-rating (gallery-id uint) (voter principal))
    (map-get? gallery-votes { gallery-id: gallery-id, voter: voter })
)
