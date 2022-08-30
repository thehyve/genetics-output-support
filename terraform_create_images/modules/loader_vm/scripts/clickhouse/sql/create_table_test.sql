CREATE TABLE IF NOT EXISTS ot.test_table (`variant_id` String) ENGINE = MergeTree
ORDER BY variant_id;
INSERT INTO ot.test_table
SELECT *, concat(
        cast(lead_chrom as String),
        '_',
        cast(lead_pos as String),
        '_',
        lead_ref,
        '_',
        lead_alt
    ) AS lead_variant_id
FROM ot.v2d_credset;