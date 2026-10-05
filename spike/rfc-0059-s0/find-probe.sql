-- First refresh observation after C that is an ordinary GRT transfer (not persisted by 48's
-- rule A), and the first Curation Signalled log after C, with their positions.
COPY (
  SELECT 'first_plain_transfer' AS what, block_number, log_index FROM graph_token__transfer
  WHERE "from" <> '0x0000000000000000000000000000000000000000' AND "to" <> '0x0000000000000000000000000000000000000000'
  ORDER BY block_number, log_index LIMIT 1
) TO '/dev/stdout' (FORMAT csv);
COPY (SELECT 'first_signalled' AS what, block_number, log_index FROM curation__signalled ORDER BY block_number, log_index LIMIT 1) TO '/dev/stdout' (FORMAT csv);
COPY (
  SELECT 'first_refresh_event' AS what, block_number, log_index FROM network_refresh_event ORDER BY block_number, log_index LIMIT 1
) TO '/dev/stdout' (FORMAT csv);
