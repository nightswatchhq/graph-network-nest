# RFC-0059 S0: checkpointed folds on the Network corpus (nightswatchhq/nuthatch#1439)

Run 2026-09-21 on the ThinkPad, against the sealed replay `nest-parity-20260920`: 10,285 segments
through block 507,179,123. **Verdict: continue.** The carry-and-window form reproduces the one-shot
views exactly, and it does so at a small fraction of their cost. Four findings amend RFC-0059, and one
part of S0 was not done. Both are listed below.

## What was tested

The saved-clock, epoch-schedule, epoch-bounds and pause chain: views `05`, `06`, `26` and `48`, and
the parts of `20`, `38` and `45` they read. It is projected to the ten values clients depend on:

- `currentEpoch`, `epochLength`, `lastRunEpoch`, `lastLengthUpdateEpoch`, `lastLengthUpdateBlock`;
- `epochCount`, `currentL1BlockNumber`, `isPaused`, `isPartialPaused`;
- a digest of every epoch's `startBlock` and `endBlock`.

`fold-step.sql` is the rewrite. It holds nine carries:

| Carry | What it holds |
|---|---|
| schedule | the last row |
| clock | the last L1 value, and whether any refresh has happened yet |
| epochs | latest observation per epoch |
| persisted | the latest persisted observation |
| latest observation | the latest observation |
| indexers | the set of known indexers |
| legacy allocations | the set of legacy allocation ids |
| pause | pause states |
| epoch run | the last epoch run |

Set-membership carries re-enter the nest's own views as events at block 0, so the original `EXISTS`
rules run unchanged.

## Harness, and its limits

Plain DuckDB **1.5.4** (the version nuthatch's `libduckdb-sys 1.10504.0` bundles), driven by bash and
jq. The layers:

- **Raw layer** (`gen-raw.sh`). Every table in `schema.json` is typed per `docs/reading-segments.md`,
  with only the catalogue segments that overlap the window unioned on by name.
- **Reference** (`run-ref.sh`). The nest's views, unchanged, over `(0, n]`.
- **Fold** (`step.sh`, `walk.sh`, `eval-at.sh`). One window at a time, with carries in and out as
  Parquet.

Limits:

- **`nuthatch_uint256` is a macro.** It is exact below 2^64 and refuses anything larger. The chain
  reads only `blockNum()`.
- **`nuthatch_abi_tuple` is approximated by a structural check.** Only `TRY(...) IS NOT NULL` in
  `38-registration` reads it, and the reference and the fold share it, so the differential is exact.
  The head comparison against the gateway matched regardless.
- **Sealed history only.** The hot tail is not exercised.
- **Measurements are of a cold DuckDB process per evaluation,** not of a resident runtime (see
  finding 3).

## The reference is right

- At block **123,615,752**, all nine values and **all 261 epoch bounds** equal the gateway reference
  the draft recorded (`validation/backfill-123m-reference.json`; `results/gw-123m-bounds.csv`).
- At head, **507,179,123**, all nine equal the live public endpoint (graph-node deployment
  `QmR8WQ…`), queried the same day.

## Results against #1439

| Criterion | Result |
|---|---|
| Fold equals one-shot views at ≥20 blocks, incl. ≥3 epoch boundaries and the Horizon transition | **Pass: 24 of 24.** See the block list below |
| Partition invariance, ≥3 random partitions | **Pass.** Regular (49 windows) and three random partitions (38, 42, 42) give all nine carries identical at 507,177,123. At the first refresh event after each of 37 random cuts, all 37 agree |
| Dropping a carry turns partition invariance red | **Fails as specified, passes as amended.** Finding 1 |
| Head evaluation ≤500 ms p99, ≤256 MiB | **The fold's own statements pass: 0.135 to 0.146 s. The cold process does not: 0.85 to 1.12 s, 252 to 313 MiB.** Finding 3 |
| No whole-history step over 512 MiB | **Fails at 10M-block windows (591 MiB), passes at 5M (417 and 359 MiB).** Finding 2 |
| Carry size per fold | Nine carries, eight of them tiny. Finding 4 |

The 24 differential blocks were:

- the draft's validated checkpoints: 42.46M, 43.44M, 84.36M, 123.6M;
- 150M, 200M, 250M, 350M and 500M;
- two arbitrary blocks, 271,828,182 and 314,159,265;
- epoch **792** at 300,388,509 and 300,388,510;
- the Horizon transition: PaymentsEscrow's start minus one (397,491,105), SubgraphService's start and
  the block before it (397,492,864 and 397,492,865), and 397,500,000;
- epoch **1224** at 450,497,132 and 450,497,133;
- the IssuanceAllocator start, 486,895,439;
- the CRLF outage block, 505,750,187;
- epoch **1387** at 506,793,273 and 506,793,274;
- head.

The cost gap grows with history (`results/diff-a*.log`):

| Block | One-shot views | Fold, from the nearest 10M checkpoint |
|---|---|---|
| 42,460,000 | 0.85 s, 71 MiB | 0.75 s, 112 MiB |
| 250,000,000 | 21.8 s, 9.1 GiB | 0.80 s, 148 MiB |
| 507,179,123 (head) | **63.2 s, 10.7 GiB** | **0.90 s, 282 MiB** |

At the extremes, fold evaluations ranged from 0.75 to 1.43 s and 84 to 446 MiB across the 24 blocks.
The whole genesis-to-head walk took **61.8 s over 49 steps**, about the cost of one one-shot evaluation
at head.

## Findings for RFC-0059

1. **End-state invariance cannot see a lost carry. Probe after the cut.** Two mutations of the
   carries, M1 (lose the carried L1 clock) and M2 (forget which epochs were seen), both left all nine
   carries at the end state identical to the correct run, over both partitions. The folds heal
   themselves: later events in a window overwrite an early mistake.

   Evaluating at the first refresh event after each of 37 random cuts, **M2 is visible at 26**, moving
   `currentL1BlockNumber` early. At 500,000,152 the reference and the correct fold both say
   25,869,204, and M2 says 25,869,229. **M1 is visible at 0 of 37.** Its carried value only repeats the
   previous observation's clock, so it cannot change a served field. That is evidence plus reasoning,
   not proof.

   RFC-0059 §8 should require probe-point invariance, and treat a mutation that survives it as a
   finding to explain.
2. **Windows must be bounded by event volume, not block span.** The densest 10M-block window,
   (200M, 210M], peaked at 591 MiB. Split at 205M, it peaked at 417 and 359 MiB, with identical carries.
   Random windows of 84M and 118M blocks reached 1.6 GiB.
3. **Measure S1 in process.** Of a head evaluation's 0.85 to 1.12 s, **0.64 to 0.69 s and 273 to 280 MiB
   is the cost of an empty window**: a cold DuckDB parsing about 150 view definitions. The fold's own 36
   statements take 0.14 s. A resident runtime pays the fixed part once, but that is a claim until S1
   measures it inside the process.
4. **One carry dominates storage.** The legacy-allocation set is **591,071 ids and 23.9 MB of
   Parquet**; the other eight carries total under 40 KB. It exists only to filter
   `HorizonRewardsAssigned` against legacy allocations. Keeping every checkpoint would cost hundreds of
   GB, which is the reason RFC-0059's retention policy exists. Narrowing this carry (only legacy
   allocations that could still receive rewards) or storing sets as deltas would remove most of it.

## Not done

- **The recursive delegation ledger (`41-delegation`)**, which #1439 asked for, is not covered. It
  calls `nuthatch_mul_div` (exact 512-bit multiply and divide). Plain DuckDB cannot reproduce that
  faithfully, since `BIGNUM` multiplication coerces to floating point. It needs a harness on
  nuthatch's own connection, with `analytics_scalars::register`. DuckDB's recursive performance inside
  a window therefore remains unmeasured.
- **The hot tail** (redb) was not part of the corpus. Windows here are sealed-only.

## An incident worth keeping

Two concurrent DuckDB processes started in the same directory share the default spill location,
`.tmp/duckdb_temp_storage_DEFAULT-*.tmp`. Three reference runs that overlapped one another either
segfaulted or read garbage: an INT64 overflow between two nonsense values, and a "missing" call row
the fold had just read. After giving each process its own `temp_directory`, all three matched. Any
nuthatch path that opens more than one DuckDB with the default temp directory in one working directory
is exposed to the same thing.

## Reproduce

On a host with the corpus, run the commands in this order:

```sh
./walk.sh ckpt-a $(seq 50000000 10000000 500000000) 506179123 507079123 507177123
./diff-at.sh ckpt-a 507179123
./probe-invariance.sh walk-b.cuts ckpt-b ckpt-a ckpt-m2b fold-step-m2.sql
```

`NEST` names the corpus directory. The DuckDB CLI goes in `bin/`.
