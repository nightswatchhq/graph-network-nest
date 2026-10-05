-- The genesis checkpoint: every carry, empty, with the types each step writes.
COPY (SELECT NULL::BIGINT AS seq, NULL::UBIGINT AS block_number, NULL::UBIGINT AS log_index,
             NULL::BIGINT AS epoch, NULL::BIGINT AS length, NULL::BIGINT AS start_block WHERE false)
    TO '__OUT__/c_sched.parquet' (FORMAT parquet);
COPY (SELECT NULL::BIGINT AS last_l1, false AS any_v4) TO '__OUT__/c_clock.parquet' (FORMAT parquet);
COPY (SELECT NULL::BIGINT AS epoch, NULL::UBIGINT AS block_number, NULL::UBIGINT AS log_index,
             NULL::BIGINT AS start_block, NULL::BIGINT AS length WHERE false)
    TO '__OUT__/c_epochs.parquet' (FORMAT parquet);
COPY (SELECT NULL::UBIGINT AS block_number, NULL::UBIGINT AS log_index, NULL::BIGINT AS l1_block WHERE false)
    TO '__OUT__/c_persisted.parquet' (FORMAT parquet);
COPY (SELECT NULL::UBIGINT AS block_number, NULL::UBIGINT AS log_index, NULL::BIGINT AS epoch WHERE false)
    TO '__OUT__/c_latest_obs.parquet' (FORMAT parquet);
COPY (SELECT NULL::VARCHAR AS indexer WHERE false) TO '__OUT__/c_indexers.parquet' (FORMAT parquet);
COPY (SELECT NULL::VARCHAR AS id WHERE false) TO '__OUT__/c_legacy_allocs.parquet' (FORMAT parquet);
COPY (SELECT NULL::VARCHAR AS kind, NULL::UBIGINT AS block_number, NULL::UBIGINT AS log_index,
             NULL::BOOLEAN AS value WHERE false)
    TO '__OUT__/c_pause.parquet' (FORMAT parquet);
COPY (SELECT NULL::UBIGINT AS block_number, NULL::UBIGINT AS log_index, NULL::VARCHAR AS epoch WHERE false)
    TO '__OUT__/c_last_run.parquet' (FORMAT parquet);
