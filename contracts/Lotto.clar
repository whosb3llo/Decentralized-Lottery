;; title: Lotto
;; version: 1.0.0
;; summary: Decentralized lottery with transparent on-chain ticket sales and drawing
;; description: A fully decentralized lottery system where users can buy tickets, and winners are drawn using block hash randomness

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_LOTTERY_NOT_ACTIVE (err u102))
(define-constant ERR_LOTTERY_ALREADY_ACTIVE (err u103))
(define-constant ERR_INSUFFICIENT_TICKETS (err u104))
(define-constant ERR_ALREADY_DRAWN (err u105))
(define-constant ERR_NOT_WINNER (err u106))
(define-constant ERR_ALREADY_CLAIMED (err u107))
(define-constant ERR_INVALID_TICKET (err u108))
(define-constant ERR_INVALID_REFERRER (err u109))
(define-constant ERR_SELF_REFERRAL (err u110))
(define-constant ERR_ALREADY_REFERRED (err u111))

(define-constant TICKET_PRICE u1000000)
(define-constant MIN_TICKETS_TO_DRAW u10)
(define-constant WINNER_PERCENTAGE u80)
(define-constant OWNER_FEE_PERCENTAGE u5)
(define-constant REFERRAL_BONUS_PERCENTAGE u10)
(define-constant MIN_REFERRAL_REWARD u50000)

(define-data-var lottery-id uint u0)
(define-data-var is-lottery-active bool false)
(define-data-var current-prize-pool uint u0)
(define-data-var ticket-counter uint u0)
(define-data-var draw-block-height uint u0)
(define-data-var winning-number uint u0)
(define-data-var total-tickets-sold uint u0)
(define-data-var total-referral-rewards uint u0)

(define-map lottery-tickets 
    {lottery-id: uint, ticket-number: uint} 
    {owner: principal, block-height: uint})

(define-map user-tickets 
    {lottery-id: uint, user: principal} 
    {ticket-count: uint, tickets: (list 20 uint)})

(define-map lottery-winners 
    {lottery-id: uint} 
    {winner: principal, prize-amount: uint, claimed: bool})

(define-map lottery-stats 
    {lottery-id: uint} 
    {total-tickets: uint, prize-pool: uint, winning-number: uint, draw-block: uint})

(define-map user-referrals 
    {user: principal} 
    {referrer: principal, total-referred: uint, lifetime-rewards: uint})

(define-map referral-rewards 
    {referrer: principal} 
    {total-referrals: uint, unclaimed-rewards: uint, lifetime-earnings: uint})

(define-private (get-random-number (target-block uint) (max-value uint))
    (let ((block-hash (unwrap! (get-stacks-block-info? id-header-hash target-block) u0)))
        (mod (+ target-block (len block-hash)) max-value)))

(define-private (calculate-winner-prize (total-pool uint))
    (/ (* total-pool WINNER_PERCENTAGE) u100))

(define-private (calculate-owner-fee (total-pool uint))
    (/ (* total-pool OWNER_FEE_PERCENTAGE) u100))

(define-private (calculate-referral-reward (ticket-price uint))
    (/ (* ticket-price REFERRAL_BONUS_PERCENTAGE) u100))

(define-private (process-referral-reward (buyer principal) (referrer principal) (reward uint))
    (let ((current-rewards (default-to {total-referrals: u0, unclaimed-rewards: u0, lifetime-earnings: u0}
                                     (map-get? referral-rewards {referrer: referrer}))))
        (map-set referral-rewards 
            {referrer: referrer}
            {total-referrals: (+ (get total-referrals current-rewards) u1),
             unclaimed-rewards: (+ (get unclaimed-rewards current-rewards) reward),
             lifetime-earnings: (+ (get lifetime-earnings current-rewards) reward)})
        (var-set total-referral-rewards (+ (var-get total-referral-rewards) reward))
        true))

(define-private (add-ticket-to-user (lotto-id uint) (user principal) (ticket-number uint))
    (let ((current-data (default-to {ticket-count: u0, tickets: (list)} 
                                  (map-get? user-tickets {lottery-id: lotto-id, user: user}))))
        (let ((new-count (+ (get ticket-count current-data) u1))
              (current-tickets (get tickets current-data)))
            (if (< (len current-tickets) u20)
                (map-set user-tickets 
                    {lottery-id: lotto-id, user: user}
                    {ticket-count: new-count, 
                     tickets: (unwrap! (as-max-len? (append current-tickets ticket-number) u20) false)})
                false))))

(define-public (start-lottery)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (not (var-get is-lottery-active)) ERR_LOTTERY_ALREADY_ACTIVE)
        (var-set lottery-id (+ (var-get lottery-id) u1))
        (var-set is-lottery-active true)
        (var-set current-prize-pool u0)
        (var-set ticket-counter u0)
        (var-set draw-block-height u0)
        (var-set winning-number u0)
        (var-set total-tickets-sold u0)
        (var-set total-referral-rewards u0)
        (ok (var-get lottery-id))))

(define-public (buy-ticket)
    (let ((current-lottery-id (var-get lottery-id))
          (current-ticket-number (+ (var-get ticket-counter) u1))
          (referral-data (map-get? user-referrals {user: tx-sender})))
        (begin
            (asserts! (var-get is-lottery-active) ERR_LOTTERY_NOT_ACTIVE)
            (try! (stx-transfer? TICKET_PRICE tx-sender (as-contract tx-sender)))
            (var-set ticket-counter current-ticket-number)
            (var-set current-prize-pool (+ (var-get current-prize-pool) TICKET_PRICE))
            (var-set total-tickets-sold (+ (var-get total-tickets-sold) u1))
            (match referral-data
                referrer-info (let ((referral-reward (calculate-referral-reward TICKET_PRICE)))
                                (process-referral-reward tx-sender (get referrer referrer-info) referral-reward))
                true)
            (map-set lottery-tickets 
                {lottery-id: current-lottery-id, ticket-number: current-ticket-number}
                {owner: tx-sender, block-height: stacks-block-height})
            (add-ticket-to-user current-lottery-id tx-sender current-ticket-number)
            (ok current-ticket-number))))

(define-public (buy-multiple-tickets (quantity uint))
    (begin
        (asserts! (var-get is-lottery-active) ERR_LOTTERY_NOT_ACTIVE)
        (asserts! (and (> quantity u0) (<= quantity u10)) ERR_INVALID_AMOUNT)
        (if (is-eq quantity u1)
            (buy-ticket)
            (if (is-eq quantity u2)
                (begin (try! (buy-ticket)) (buy-ticket))
                (if (is-eq quantity u3)
                    (begin (try! (buy-ticket)) (try! (buy-ticket)) (buy-ticket))
                    (if (is-eq quantity u4)
                        (begin (try! (buy-ticket)) (try! (buy-ticket)) (try! (buy-ticket)) (buy-ticket))
                        (if (is-eq quantity u5)
                            (begin (try! (buy-ticket)) (try! (buy-ticket)) (try! (buy-ticket)) (try! (buy-ticket)) (buy-ticket))
                            (buy-ticket))))))))

(define-public (draw-winner)
    (let ((current-lottery-id (var-get lottery-id))
          (total-tickets (var-get ticket-counter))
          (current-block stacks-block-height))
        (begin
            (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
            (asserts! (var-get is-lottery-active) ERR_LOTTERY_NOT_ACTIVE)
            (asserts! (>= total-tickets MIN_TICKETS_TO_DRAW) ERR_INSUFFICIENT_TICKETS)
            (asserts! (is-eq (var-get draw-block-height) u0) ERR_ALREADY_DRAWN)
            (let ((random-ticket-number (+ (get-random-number (- current-block u1) total-tickets) u1)))
                (var-set winning-number random-ticket-number)
                (var-set draw-block-height current-block)
                (let ((winner-data (unwrap! (map-get? lottery-tickets 
                                                    {lottery-id: current-lottery-id, 
                                                     ticket-number: random-ticket-number}) 
                                          ERR_INVALID_TICKET)))
                    (let ((winner-address (get owner winner-data))
                          (total-pool (var-get current-prize-pool))
                          (winner-prize (calculate-winner-prize total-pool))
                          (owner-fee (calculate-owner-fee total-pool)))
                        (map-set lottery-winners 
                            {lottery-id: current-lottery-id}
                            {winner: winner-address, prize-amount: winner-prize, claimed: false})
                        (map-set lottery-stats
                            {lottery-id: current-lottery-id}
                            {total-tickets: total-tickets, 
                             prize-pool: total-pool,
                             winning-number: random-ticket-number,
                             draw-block: current-block})
                        (var-set is-lottery-active false)
                        (try! (as-contract (stx-transfer? owner-fee tx-sender CONTRACT_OWNER)))
                        (ok {winner: winner-address, 
                             winning-ticket: random-ticket-number, 
                             prize: winner-prize})))))))

(define-public (claim-prize)
    (let ((current-lottery-id (var-get lottery-id)))
        (match (map-get? lottery-winners {lottery-id: current-lottery-id})
            winner-data (begin
                           (asserts! (is-eq tx-sender (get winner winner-data)) ERR_NOT_WINNER)
                           (asserts! (not (get claimed winner-data)) ERR_ALREADY_CLAIMED)
                           (map-set lottery-winners 
                               {lottery-id: current-lottery-id}
                               (merge winner-data {claimed: true}))
                           (as-contract (stx-transfer? (get prize-amount winner-data) 
                                                     tx-sender 
                                                     (get winner winner-data))))
            ERR_NOT_WINNER)))

(define-public (emergency-stop)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set is-lottery-active false)
        (ok true)))

(define-public (refund-tickets)
    (let ((current-lottery-id (var-get lottery-id))
          (user-data (map-get? user-tickets {lottery-id: current-lottery-id, user: tx-sender})))
        (match user-data
            tickets-data (let ((ticket-count (get ticket-count tickets-data))
                             (refund-amount (* ticket-count TICKET_PRICE)))
                           (begin
                               (asserts! (not (var-get is-lottery-active)) ERR_LOTTERY_ALREADY_ACTIVE)
                               (asserts! (is-eq (var-get draw-block-height) u0) ERR_ALREADY_DRAWN)
                               (map-delete user-tickets {lottery-id: current-lottery-id, user: tx-sender})
                               (var-set current-prize-pool (- (var-get current-prize-pool) refund-amount))
                               (var-set total-tickets-sold (- (var-get total-tickets-sold) ticket-count))
                               (as-contract (stx-transfer? refund-amount tx-sender tx-sender))))
            ERR_INVALID_TICKET)))

(define-public (set-referrer (referrer principal))
    (begin
        (asserts! (not (is-eq tx-sender referrer)) ERR_SELF_REFERRAL)
        (asserts! (is-none (map-get? user-referrals {user: tx-sender})) ERR_ALREADY_REFERRED)
        (map-set user-referrals 
            {user: tx-sender}
            {referrer: referrer, total-referred: u0, lifetime-rewards: u0})
        (ok referrer)))

(define-public (claim-referral-rewards)
    (let ((rewards-data (map-get? referral-rewards {referrer: tx-sender})))
        (match rewards-data
            reward-info (let ((unclaimed (get unclaimed-rewards reward-info)))
                          (begin
                              (asserts! (>= unclaimed MIN_REFERRAL_REWARD) ERR_INVALID_AMOUNT)
                              (map-set referral-rewards 
                                  {referrer: tx-sender}
                                  (merge reward-info {unclaimed-rewards: u0}))
                              (var-set total-referral-rewards (- (var-get total-referral-rewards) unclaimed))
                              (as-contract (stx-transfer? unclaimed tx-sender tx-sender))))
            ERR_INVALID_REFERRER)))

(define-read-only (get-lottery-info)
    {lottery-id: (var-get lottery-id),
     is-active: (var-get is-lottery-active),
     prize-pool: (var-get current-prize-pool),
     total-tickets: (var-get ticket-counter),
     ticket-price: TICKET_PRICE,
     min-tickets-to-draw: MIN_TICKETS_TO_DRAW,
     winner-percentage: WINNER_PERCENTAGE})

(define-read-only (get-user-tickets (user principal) (lotto-id uint))
    (map-get? user-tickets {lottery-id: lotto-id, user: user}))

(define-read-only (get-ticket-owner (lotto-id uint) (ticket-number uint))
    (map-get? lottery-tickets {lottery-id: lotto-id, ticket-number: ticket-number}))

(define-read-only (get-current-winner)
    (let ((current-lottery-id (var-get lottery-id)))
        (map-get? lottery-winners {lottery-id: current-lottery-id})))

(define-read-only (get-lottery-history (lotto-id uint))
    (map-get? lottery-stats {lottery-id: lotto-id}))

(define-read-only (get-winning-details)
    {lottery-id: (var-get lottery-id),
     winning-number: (var-get winning-number),
     draw-block: (var-get draw-block-height),
     total-tickets-sold: (var-get total-tickets-sold)})

(define-read-only (can-draw)
    (and (var-get is-lottery-active)
         (>= (var-get ticket-counter) MIN_TICKETS_TO_DRAW)
         (is-eq (var-get draw-block-height) u0)))

(define-read-only (get-contract-balance)
    (stx-get-balance (as-contract tx-sender)))

(define-read-only (calculate-potential-winnings)
    (if (var-get is-lottery-active)
        (some (calculate-winner-prize (var-get current-prize-pool)))
        none))

(define-read-only (get-odds)
    (if (var-get is-lottery-active)
        (some (var-get ticket-counter))
        none))

(define-read-only (is-ticket-winner (lotto-id uint) (ticket-number uint))
    (match (map-get? lottery-stats {lottery-id: lotto-id})
        stats (is-eq ticket-number (get winning-number stats))
        false))

(define-read-only (get-user-winning-status (user principal) (lotto-id uint))
    (match (map-get? lottery-winners {lottery-id: lotto-id})
        winner-data (is-eq user (get winner winner-data))
        false))

(define-read-only (get-referral-info (referrer principal))
    (map-get? referral-rewards {referrer: referrer}))

(define-read-only (get-user-referrer (user principal))
    (map-get? user-referrals {user: user}))

(define-read-only (get-referral-stats)
    {total-referral-pool: (var-get total-referral-rewards),
     referral-bonus-percentage: REFERRAL_BONUS_PERCENTAGE,
     minimum-claim-amount: MIN_REFERRAL_REWARD})

(define-read-only (calculate-referral-earnings (ticket-purchases uint))
    (/ (* ticket-purchases TICKET_PRICE REFERRAL_BONUS_PERCENTAGE) u100))

(define-read-only (has-referrer (user principal))
    (is-some (map-get? user-referrals {user: user})))
