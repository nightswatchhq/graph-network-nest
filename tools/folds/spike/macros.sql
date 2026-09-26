-- nuthatch_uint256 mirrors analytics_scalars.rs kind 1: exactly one 0x-prefixed 32-byte word,
-- returned as decimal text. Exact below 2^64, which covers EpochManager.blockNum(); a larger
-- word is refused loudly rather than truncated, because the real function would not truncate.
CREATE OR REPLACE MACRO nuthatch_uint256(w) AS CASE
    WHEN length(w) = 66 AND regexp_full_match(w, '0x0{48}[0-9a-fA-F]{16}')
        THEN CAST(CAST('0x' || right(w, 16) AS UBIGINT) AS VARCHAR)
    WHEN length(w) = 66 AND regexp_full_match(w, '0x[0-9a-fA-F]{64}')
        THEN error('spike macro: uint256 word at or above 2^64')
    ELSE error('expected one 32-byte ABI uint256 word') END;

-- APPROXIMATION. The real decoder is only ever read here as TRY(...) IS NOT NULL, in
-- 38-registration. This accepts a structurally plausible ABI payload (0x, whole words, at least
-- the three-word head) and rejects the rest. Both the reference and the folds use it, so the
-- fold-versus-reference differential is exact; a gateway comparison past Horizon is not, on this.
CREATE OR REPLACE MACRO nuthatch_abi_tuple(types, data) AS CASE
    WHEN data IS NOT NULL AND regexp_full_match(data, '0x([0-9a-fA-F]{64}){3,}') THEN data
    ELSE NULL END;

-- Bind-only stubs for views outside the clock chain. Non-volatile so TRY and folding accept
-- them; each returns a text sentinel built from its argument, so a numeric use of one at
-- runtime fails loudly instead of passing silently.
CREATE OR REPLACE MACRO nuthatch_mul_div(a, b, c) AS 'STUB_mul_div:' || a;
CREATE OR REPLACE MACRO nuthatch_cid_v0(a) AS 'STUB_cid_v0:' || a;
CREATE OR REPLACE MACRO nuthatch_base58_uint256(a) AS 'STUB_base58:' || a;
CREATE OR REPLACE MACRO nuthatch_uint256_word(a) AS 'STUB_word:' || a;
CREATE OR REPLACE MACRO nuthatch_keccak256(a) AS 'STUB_keccak:' || a;
