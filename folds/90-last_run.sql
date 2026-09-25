-- The last EpochRun.
SELECT block_number, log_index, epoch FROM (
    SELECT block_number, log_index, epoch FROM last_run__carry
    UNION ALL SELECT block_number, log_index, epoch FROM epoch_manager__epoch_run
) ORDER BY block_number DESC, log_index DESC LIMIT 1
