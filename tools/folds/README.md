# Folds for this nest

`folds/` at the repo root is generated. Edit `gen-folds.sh`, not the files it writes, then
regenerate:

```sh
tools/folds/gen-folds.sh .
```

The rest is the RFC-0059 differential harness (nuthatch#1439, #1479, #1503). It runs on Linux only:
`measure.sh` reads `/proc`.

| Script | What it does |
|---|---|
| `run-compare.sh <nest> <tag>` | Projections at every spike block against `ref/`, then every carry against the spike's checkpoints, into `results-<tag>/`. About 25 minutes. |
| `probe.sh <nest> <tag>` | RFC-0059 §8's probe points: the first refresh after every interior checkpoint. |
| `project.sh`, `carries.sh` | One block of the above. |
| `measure.sh`, `rss-series.sh` | Wall time and peak RSS of a command. |

The head gate is `nuthatch fold bench --dir <nest> --iters 200`.

`spike/` is the S0 spike that produced the references: hand-written carry-and-window SQL over the
raw layer, its scripts and logs, and the one-shot epoch bounds in `spike/out/`.

## What is not in git

The corpora and checkpoints are several gigabytes and live on the ThinkPad.

| Variable | Default | What |
|---|---|---|
| `NUTHATCH` | `~/nuthatch-folds/target/release/nuthatch` | A nuthatch build with `--features folds` (3.11.0 measured #1503) |
| `SPIKE_CKPT` | `~/spike-0059/ckpt-a` | The spike's checkpoints, one directory per block |
| `SOURCE_NEST` | `~/.local/state/network-facade/nest-parity-20260920` | The raw nest the spike reads (`probe.sh`, `spike/`) |
| `DUCKDB` | `spike/bin/duckdb` | DuckDB v1.5.4 (08e34c447b); `spike/` always uses `spike/bin/duckdb`, so link it there |
| `RESULTS` | `results-<tag>` | Output directory |

The nest passed to `run-compare.sh` is a copy of this one with sealed segments and checkpoints, such
as `~/fold-port/nest-d` on the ThinkPad.
