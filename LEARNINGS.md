# Network Subgraph facade learnings

Status: **IN PROGRESS - paused on 2026-09-21.** This is an evidence record, not a claim of a
drop-in replacement.

## What worked

- The Arbitrum One Network contract inventory, ABI decoding, hash-pinned calls and event folds
  replayed from full history to chain head on the ThinkPad.
- The native writer remained fresh at the point it was stopped: the last check reported a
  three-second head age and nine blocks of distance from the observed head.
- Captured allocation, protocol, epoch, deployment, escrow, signer and redemption fixtures pass
  against the Nuthatch GraphQL handler at their recorded blocks. The fixture corpus contains the
  fixed client documents used by indexer-agent, indexer-service-rs and the TAP monitor.
- GraphQL scalar encoding, lowercase identifiers, pagination, `_meta`, and block-pinned archive
  reads have focused coverage. `arg_max` is not part of this work: the incremental entity engine still
  refuses it (`src/entities.rs`, `every_ineligible_construct_is_refused`), and no view here uses it.

## What did not meet the production bar

The full replay created 10,285 immutable Parquet segments. A pinned `graphNetwork` query over that
corpus initially hit the ordinary 1,024 descriptor limit. Raising the reader to 65,536 descriptors
removed that failure, but the same query then exceeded DuckDB's 512 MiB public-query budget.

Reader batching and disabling insertion-order retention did not make it suitable for serving. The
query still exceeded 512 MiB, taking 36.1 seconds in the final bounded-reader measurement. Raising
the public timeout or memory limit would make the endpoint less safe without meeting indexer-agent
freshness expectations, so it was deliberately not used as a cutover workaround.

## Required before resuming

1. Maintain current protocol, allocation, deployment and escrow state incrementally from events.
2. Seed those relations once from sealed history and prove reorg retraction.
3. Route only unpinned GraphQL reads to maintained state. `block:` reads must retain archive
   semantics and must never receive a current-state answer.
4. Run every captured client document against both the native facade and a pinned gateway reference,
   comparing scalar strings, IDs, nullability and `_meta`.
5. Prove current-head latency, memory, rate-limit behaviour and freshness before changing Caddy's
   upstream from the gateway route.

## Draft validation limitation

The current `nuthatch check --dir .` view validator runs dependent statements in this directory as
independent units. It therefore reports unresolved intermediate views such as `controller_state`,
`protocol_parameter_event` and `allocation_lifecycle`. The live query path loads each SQL file in
order and the recorded fixture tests exercise that path, but the standalone checker result is not
clean. Treat this as an open Nuthatch validator issue, not as a successful draft validation.

## Operational state on pause

- `network-facade-backfill.service` on the ThinkPad has been stopped cleanly.
- The private parity reader has been stopped.
- The public HTTPS route remains live and gateway-backed. It is not affected by stopping native
  ingestion.
- No RPC key, gateway credential, budget ledger, hot store or historical segment data belongs in
  this repository.
