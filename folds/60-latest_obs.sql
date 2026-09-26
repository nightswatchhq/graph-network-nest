-- The latest observation overall is the latest of each epoch's latest.
SELECT block_number, log_index, epoch FROM epochs
ORDER BY block_number DESC, log_index DESC LIMIT 1
