# Lifecycle Segmentation Logic

## Why Lifecycle Segmentation Is Used

Gaming analytics teams use lifecycle segmentation to turn raw activity into business actions. DAU and MAU show total activity, but they do not explain which player groups need attention. Segmentation helps answer:

- Who is new?
- Who is highly engaged?
- Who is slowing down?
- Who has already lapsed?
- Who recently came back?

This project uses `avatar_id` as the player proxy because the dataset does not contain account-level player IDs.

## Why Monthly Snapshots Are Used

The segmentation layer creates one snapshot per calendar month, using the last available activity date in that month. This avoids a single static final snapshot and makes it possible to track how segment sizes change over time.

Monthly snapshots support questions like:

- Is the lapsed segment growing?
- Are core engaged players declining?
- Is the at-risk group increasing before churn?

## Why Segments Are Mutually Exclusive

Each avatar receives only one segment per snapshot date. This makes reporting clean and prevents double-counting. For example, an avatar might be both guild active and highly engaged, but the priority logic assigns one final lifecycle segment.

## Segment Priority Order

Segments are assigned in this order:

1. Lapsed Players
2. Reactivated Players
3. New Explorers
4. At-Risk Players
5. Core Engaged
6. Fast Progressors
7. Social/Guild Engaged
8. Casual Returners
9. Low Activity / Other

Higher-priority segments are evaluated first.

## Exact Rule Definitions

### Lapsed Players

- **Rule:** `recency_days > 30`
- **Recommended action:** Win-back campaign / return incentive
- **Business meaning:** These avatars have not appeared recently and are likely outside the active base.

### Reactivated Players

- **Rule:** `reactivated_30d_flag = true`
- **Recommended action:** Reinforce return with limited-time progression or social event
- **Business meaning:** These avatars came back after a long break and may respond to return-focused offers.

### New Explorers

- **Rules:**
  - `days_since_first_seen <= 7`
  - `active_days_7 >= 1`
- **Recommended action:** Onboarding support / early-game guidance
- **Business meaning:** These avatars are early in the lifecycle and need smooth progression.

### At-Risk Players

- **Rules:**
  - `recency_days BETWEEN 8 AND 30`
  - `active_days_prev_30 >= 5`
  - and either:
    - `active_days_30 <= 2`
    - or `activity_drop_pct_30_vs_prev30 >= 0.5`
- **Recommended action:** Targeted reactivation challenge / personalized nudge
- **Business meaning:** These avatars were active before but show recent decline.

### Core Engaged

- **Rules:**
  - `active_days_30 >= 15`
  - or `observations_30 >= 75th percentile among active avatars in that snapshot`
- **Recommended action:** Advanced content / high-engagement event
- **Business meaning:** These avatars are the strongest engagement base.

### Fast Progressors

- **Rules:**
  - `fast_progressor_flag = true`
  - `active_days_30 >= 3`
- **Recommended action:** Recommend advanced zones / progression-focused event
- **Business meaning:** These avatars are moving quickly and may need progression-oriented content.

### Social/Guild Engaged

- **Rule:** `guild_engaged_flag = true`
- **Recommended action:** Guild-based event / group challenge
- **Business meaning:** These avatars show social participation signals.

### Casual Returners

- **Rules:**
  - `active_days_30 BETWEEN 2 AND 7`
  - `recency_days <= 30`
- **Recommended action:** Weekend challenge / lightweight recurring event
- **Business meaning:** These avatars are still reachable but not deeply engaged.

### Low Activity / Other

- **Rule:** All remaining avatars.
- **Recommended action:** General engagement monitoring
- **Business meaning:** This is the default group for avatars that do not meet stronger lifecycle patterns.

## Limitations

- `avatar_id` is a proxy, not a verified account-level player ID.
- The data does not include purchases, revenue, or CLV.
- Guild activity is based only on available guild fields.
- Segment labels are analytical categories, not confirmed player intent.
- Activity observations are not full session telemetry.

## How This Supports Business Decisions

The segmentation layer helps LiveOps and publishing teams:

- Prioritize win-back work for lapsed avatars.
- Protect highly engaged avatars with relevant content.
- Intervene before at-risk avatars lapse.
- Support new avatars with onboarding and early progression improvements.
- Monitor whether monthly player health is improving or weakening.
