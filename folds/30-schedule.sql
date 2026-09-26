-- The last epoch_schedule row.
WITH RECURSIVE
w_len AS (
SELECT block_number, log_index, epoch, length, l1_block,
       (SELECT coalesce(max(seq), 0) FROM schedule__carry)
         + row_number() OVER (ORDER BY block_number, log_index) AS seq
FROM epoch_length_event
), w_sched(seq, block_number, log_index, epoch, length, start_block) AS (
    SELECT * FROM (
        SELECT seq, block_number, log_index, epoch, length, start_block FROM schedule__carry
        UNION ALL
        SELECT seq, block_number, log_index, epoch, length, l1_block FROM w_len WHERE seq = 1
    )
    UNION ALL
    SELECT e.seq, e.block_number, e.log_index, e.epoch, e.length,
           s.start_block + ((e.l1_block - s.start_block) // s.length) * s.length
    FROM w_sched s JOIN w_len e ON e.seq = s.seq + 1
)
SELECT seq, block_number, log_index, epoch, length, start_block FROM w_sched
ORDER BY seq DESC LIMIT 1
