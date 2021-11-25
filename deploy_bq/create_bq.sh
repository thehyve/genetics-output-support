#!/bin/bash

version_tag=${RELEASE_ID}
project_id=${PROJECT_ID}
path_prefix="gs://${GS_SYNC_FROM}/outputs"
this_path=`pwd`

if [ ${project_id} == "open-targets-genetics" ]; then
    echo "Production - no suffix - allAuthenticatedUsers ON"
    suffix=""
else
    echo "Dev - suffix dev - allAuthenticatedUsers OFF"
    suffix="_dev"
fi

bq --project_id=${project_id} --location='eu' rm -f -r genetics${suffix}
bq --project_id=${project_id} --location='eu' mk genetics${suffix}

echo ${version_tag} > genetics_sync_v.csv
bq --project_id=${project_id} --location='eu' mk genetics${suffix}.ot_release
bq --project_id=${project_id} --dataset_id=genetics${suffix} --location='eu' load genetics${suffix}.ot_release genetics_sync_v.csv release:string

bq --project_id=${project_id} mk -t --location=EU --description "Variant index" genetics${suffix}.variants
bq --project_id=${project_id} mk -t --location=EU --description "Study index" genetics${suffix}.studies
bq --project_id=${project_id} mk -t --location=EU --description "Study Overlap index" genetics${suffix}.studies_overlap
bq --project_id=${project_id} mk -t --location=EU --description "Gene index" genetics${suffix}.genes
bq --project_id=${project_id} mk -t --location=EU --description "Locus to gene index" genetics${suffix}.locus2gene
bq --project_id=${project_id} mk -t --location=EU --description "Variant to gene index" genetics${suffix}.variant_gene
bq --project_id=${project_id} mk -t --location=EU --description "Variant to study-trait index" genetics${suffix}.variant_disease
bq --project_id=${project_id} mk -t --location=EU --description "Gene to variant to study-trait index" genetics${suffix}.disease_variant_gene
bq --project_id=${project_id} mk -t --location=EU --description "Summary stats GWAS pval 0.05 cut-off" genetics${suffix}.sa_gwas
bq --project_id=${project_id} mk -t --location=EU --description "Summary stats Molecular Trait pval 0.05 cut-off" genetics${suffix}.sa_molecular_trait
bq --project_id=${project_id} mk -t --location=EU --description "Variant to study-trait index colocalisation analysis" genetics${suffix}.variant_disease_coloc
bq --project_id=${project_id} mk -t --location=EU --description "Variant to study-trait index credible set" genetics${suffix}.variant_disease_credset

# load data into tables
echo "inserting variant"
bq --project_id=${project_id} load --source_format=PARQUET \
  genetics${suffix}.variants \
  ${path_prefix}/variant-index/part-\*

echo "inserting locus2gene"
bq --project_id=${project_id} load --source_format=PARQUET \
  genetics${suffix}.locus2gene \
  ${path_prefix}/l2g/part-\*

echo "inserting genes"
bq --project_id=${project_id} load --source_format=NEWLINE_DELIMITED_JSON \
  --schema=${this_path}/deploy_bq/schema/bq.genes.schema.json \
  genetics${suffix}.genes \
  ${path_prefix}/lut/genes-index/part-\*

echo "inserting studies"
bq --project_id=${project_id} load --source_format=NEWLINE_DELIMITED_JSON \
  --schema=${this_path}/deploy_bq/schema/bq.studies.schema.json \
  genetics${suffix}.studies \
  ${path_prefix}/lut/study-index/part-\*

echo "inserting overlap"
bq --project_id=${project_id} load --source_format=NEWLINE_DELIMITED_JSON \
  --schema=${this_path}/deploy_bq/schema/bq.studies_overlap.schema.json \
  genetics${suffix}.studies_overlap \
  ${path_prefix}/lut/overlap-index/part-\*

echo "inserting variant-gene"
bq --project_id=${project_id} load --source_format=NEWLINE_DELIMITED_JSON \
  --schema=${this_path}/deploy_bq/schema/bq.v2g.schema.json \
  genetics${suffix}.variant_gene \
  ${path_prefix}/v2g/part-\*

echo "inserting variant-disease"
bq --project_id=${project_id} load --source_format=NEWLINE_DELIMITED_JSON \
  --schema=${this_path}/deploy_bq/schema/bq.v2d.schema.json \
  genetics${suffix}.variant_disease \
  ${path_prefix}/v2d/part-\*

echo "inserting disease-variant"
bq --project_id=${project_id} load --source_format=NEWLINE_DELIMITED_JSON \
  --schema=${this_path}/deploy_bq/schema/bq.d2v2g.schema.json \
  genetics${suffix}.disease_variant_gene \
  ${path_prefix}/d2v2g/part-\*

echo "inserting gwas"
bq --project_id=${project_id} load --source_format=PARQUET \
  genetics${suffix}.sa_gwas \
  ${path_prefix}/sa/gwas/210917/part-\*

echo "inserting molecular_trait"
bq --project_id=${project_id} load --source_format=PARQUET \
  genetics${suffix}.sa_molecular_trait \
  ${path_prefix}/sa/molecular_trait/210917/part-\*

echo "inserting v2d coloc"
bq --project_id=${project_id} load --source_format=NEWLINE_DELIMITED_JSON \
  --schema=${this_path}/deploy_bq/schema/bq.v2d_coloc.schema.json \
  genetics${suffix}.variant_disease_coloc \
  ${path_prefix}/v2d_coloc/part-\*

echo "inserting v2d-credset"
bq --project_id=${project_id} load --source_format=NEWLINE_DELIMITED_JSON \
  --schema=${this_path}/deploy_bq/schema/bq.v2d_credset.schema.json \
  genetics${suffix}.variant_disease_credset \
  ${path_prefix}/v2d_credset/part-\*

# Adding allUserAuth roles
if [ ${project_id} == "open-targets-genetics" ]; then
  bq show --format=prettyjson ${project_id}:genetics > genetcis_schema.json
  jq --argjson groupInfo '{"role":"roles/bigquery.metadataViewer", "specialGroup": "allAuthenticatedUsers"}' '.access += [$groupInfo]' genetics_schema.json > genetics_meta.json
  jq --argjson groupInfo '{"role":"READER", "specialGroup": "allAuthenticatedUsers"}' '.access += [$groupInfo]' genetics_meta.json > genetics_new_schema.json

  bq update --source genetics_new_schema.json ${project_id}:genetics

  rm genetics_sync_v.csv
  rm genetics_schema.json
  rm genetics_meta.json
  rm genetics_new_schema.json
else
    echo "The dataset must not be visible: allAuthenticatedUsers OFF"
fi

# Debug: view the new roles for the BiqQuery dataset
#bq show --format=prettyjson ${project_id}:genetics_${underscore_version_tag}
