;; FrameHive Contract
;; Handles photo sharing, critiques, and collaboration

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))

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

;; Data variables
(define-data-var photo-count uint u0)
(define-data-var comment-count uint u0)
(define-data-var collab-count uint u0)

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