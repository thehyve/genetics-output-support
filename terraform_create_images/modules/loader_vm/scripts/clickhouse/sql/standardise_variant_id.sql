-- Tables to update
-- 1. chrom, pos, ref, alt
-- manhattan
ALTER TABLE manhattan
ADD COLUMN IF NOT EXISTS variant_id String DEFAULT concat(
        cast(chrom as String),
        '_',
        cast(pos as String),
        '_',
        ref,
        '_',
        alt
    );
-- l2g_by_gsl
ALTER TABLE l2g_by_gsl
ADD COLUMN IF NOT EXISTS variant_id String DEFAULT concat(
        cast(chrom as String),
        '_',
        cast(pos as String),
        '_',
        ref,
        '_',
        alt
    );
-- l2g_by_slg
ALTER TABLE l2g_by_slg
ADD COLUMN IF NOT EXISTS variant_id String DEFAULT concat(
        cast(chrom as String),
        '_',
        cast(pos as String),
        '_',
        ref,
        '_',
        alt
    );
-- v2d_sa_molecular_trait
ALTER TABLE v2d_sa_molecular_trait
ADD COLUMN IF NOT EXISTS variant_id String DEFAULT concat(
        cast(chrom as String),
        '_',
        cast(pos as String),
        '_',
        ref,
        '_',
        alt
    );
-- v2d_sa_gwas
ALTER TABLE v2d_sa_gwas
ADD COLUMN IF NOT EXISTS variant_id String DEFAULT concat(
        cast(chrom as String),
        '_',
        cast(pos as String),
        '_',
        ref,
        '_',
        alt
    );
-- 2. lead / tag
-- d2v2g_scored
ALTER TABLE d2v2g_scored
ADD COLUMN IF NOT EXISTS lead_variant_id String DEFAULT concat(
        cast(lead_chrom as String),
        '_',
        cast(lead_pos as String),
        '_',
        lead_ref,
        '_',
        lead_alt
    );
ALTER TABLE d2v2g_scored
ADD COLUMN IF NOT EXISTS tag_variant_id String DEFAULT concat(
        cast(tag_chrom as String),
        '_',
        cast(tag_pos as String),
        '_',
        tag_ref,
        '_',
        tag_alt
    );
-- v2d_by_chrpos 
ALTER TABLE v2d_by_chrpos
ADD COLUMN IF NOT EXISTS lead_variant_id String DEFAULT concat(
        cast(lead_chrom as String),
        '_',
        cast(lead_pos as String),
        '_',
        lead_ref,
        '_',
        lead_alt
    );
ALTER TABLE v2d_by_chrpos
ADD COLUMN IF NOT EXISTS tag_variant_id String DEFAULT concat(
        cast(tag_chrom as String),
        '_',
        cast(tag_pos as String),
        '_',
        tag_ref,
        '_',
        tag_alt
    );
-- v2d_by_stchr
ALTER TABLE v2d_by_stchr
ADD COLUMN IF NOT EXISTS lead_variant_id String DEFAULT concat(
        cast(lead_chrom as String),
        '_',
        cast(lead_pos as String),
        '_',
        lead_ref,
        '_',
        lead_alt
    );
ALTER TABLE v2d_by_stchr
ADD COLUMN IF NOT EXISTS tag_variant_id String DEFAULT concat(
        cast(tag_chrom as String),
        '_',
        cast(tag_pos as String),
        '_',
        tag_ref,
        '_',
        tag_alt
    );
-- v2d_credset 
ALTER TABLE v2d_credset
ADD COLUMN IF NOT EXISTS lead_variant_id String DEFAULT concat(
        cast(lead_chrom as String),
        '_',
        cast(lead_pos as String),
        '_',
        lead_ref,
        '_',
        lead_alt
    );
ALTER TABLE v2d_credset
ADD COLUMN IF NOT EXISTS tag_variant_id String DEFAULT concat(
        cast(tag_chrom as String),
        '_',
        cast(tag_pos as String),
        '_',
        tag_ref,
        '_',
        tag_alt
    );
-- 3. Left / Right
-- v2d_coloc
ALTER TABLE v2d_coloc
ADD COLUMN IF NOT EXISTS left_variant_id String DEFAULT concat(
        cast(left_chrom as String),
        '_',
        cast(left_pos as String),
        '_',
        left_ref,
        '_',
        left_alt
    );
ALTER TABLE v2d_coloc
ADD COLUMN IF NOT EXISTS right_variant_id String DEFAULT concat(
        cast(right_chrom as String),
        '_',
        cast(right_pos as String),
        '_',
        right_ref,
        '_',
        right_alt
    );
-- studies_overlap
ALTER TABLE studies_overlap
ADD COLUMN IF NOT EXISTS A_variant_id String DEFAULT concat(
        cast(A_chrom as String),
        '_',
        cast(A_pos as String),
        '_',
        A_ref,
        '_',
        A_alt
    );
ALTER TABLE studies_overlap
ADD COLUMN IF NOT EXISTS B_variant_id String DEFAULT concat(
        cast(B_chrom as String),
        '_',
        cast(B_pos as String),
        '_',
        B_ref,
        '_',
        B_alt
    );