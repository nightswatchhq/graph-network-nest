-- controller_state's two pause flags, latest per kind.
SELECT kind, block_number, log_index, value FROM (
    SELECT 'pause' AS kind, block_number, log_index, CAST("isPaused" AS BOOLEAN) AS value FROM controller__pause_changed
    UNION ALL
    SELECT 'partial', block_number, log_index, CAST("isPaused" AS BOOLEAN) FROM controller__partial_pause_changed
) QUALIFY row_number() OVER (PARTITION BY kind ORDER BY block_number DESC, log_index DESC) = 1
