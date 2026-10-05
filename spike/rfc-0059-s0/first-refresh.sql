COPY (SELECT block_number FROM network_refresh_event ORDER BY block_number, log_index LIMIT 1) TO '/dev/stdout' (FORMAT csv, HEADER false);
