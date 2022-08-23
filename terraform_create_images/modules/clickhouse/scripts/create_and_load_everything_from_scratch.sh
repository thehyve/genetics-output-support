#!/bin/bash

# CURRENTLY, IN ORDER TO BUILD SOME TABLES WE NEED A HIGHMEM MACHINE

export CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-localhost}"
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [ $# -ne 1 ]; then
  echo "Recreates ot database and loads data."
  echo "Example: $0 gs://genetics-portal-output/190504"
  exit 1
fi
base_path="${1}"
cpu_count=$(nproc --all)
echo "${cpu_count} CPUs available for parallelisation."

load_foreach_parquet() {
  # you need two parameters, the path_prefix to make the wildcard and
  # the table_name name to load into
  local path_prefix=$1
  local table_name=$2
  echo loading $path_prefix glob files into this table $table_name
  local q="clickhouse-client -h ${CLICKHOUSE_HOST} --query=\"insert into ${table_name} format Parquet\" "

  # Set max-procs to 0 to allow xargs to max out allowed process count.
  gsutil ls "${path_prefix}"/*.parquet |
    xargs --max-procs=$cpu_count -t -I % \
      bash -c "gsutil cat % | ${q}"
  echo "done loading $path_prefix glob files into this table $table_name"
}

## Database setup
echo "Initialising database..."
clickhouse-client -h "${CLICKHOUSE_HOST}" --query="drop database if exists ot;"

intermediateTables=(
  studies
  studies_overlap
  variants
  v2d
  v2g_scored
  d2v2g_scored
  v2d_coloc
  v2d_credset
  v2d_sa_gwas
  v2d_sa_molecular_trait
  l2g
  manhattan
)
## Create intermediary tables
for t in "${intermediateTables[@]}"; do
  echo "Creating intermediary table: ${t}_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/${t}_log.sql"
done

## Load data
{
  load_foreach_parquet "${base_path}/lut/study-index" "ot.studies_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/studies.sql"
} &
{
  load_foreach_parquet "${base_path}/lut/overlap-index" "ot.studies_overlap_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/studies_overlap.sql"
} &
{
  load_foreach_parquet "${base_path}/lut/variant-index" "ot.variants_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/variants.sql"
} &
{
  load_foreach_parquet "${base_path}/d2v2g_scored" "ot.d2v2g_scored_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/d2v2g_scored.sql"
} &
{
  load_foreach_parquet "${base_path}/v2d" "ot.v2d_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/v2d.sql"
} &
{
  load_foreach_parquet "${base_path}/v2g_scored" "ot.v2g_scored_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/v2g_scored.sql"
  echo "Create v2g structure"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/v2g_structure.sql"
} &
{
  load_foreach_parquet "${base_path}/v2d_coloc" "ot.v2d_coloc_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/v2d_coloc.sql"
} &
{
  load_foreach_parquet "${base_path}/v2d_credset" "ot.v2d_credset_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/v2d_credset.sql"
} &
{
  load_foreach_parquet "${base_path}/sa/gwas" "ot.v2d_sa_gwas_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/v2d_sa_gwas.sql"
} &
{
  load_foreach_parquet "${base_path}/sa/molecular_trait" "ot.v2d_sa_molecular_trait_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/v2d_sa_molecular_trait.sql"
} &
{
  load_foreach_parquet "${base_path}/l2g" "ot.l2g_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/l2g.sql"
} &
{
  load_foreach_parquet "${base_path}/manhattan" "ot.manhattan_log"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/manhattan.sql"
} &
{
  echo "Load gene index"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n <"${SCRIPT_DIR}/genes.sql"
  load_foreach_parquet "${base_path}/lut/genes-index" "ot.genes"
} &
wait

## Drop intermediate tables
for t in "${intermediateTables[@]}"; do
  table="${t}_log"
  echo "Deleting intermediate table: ${table}"
  clickhouse-client -h "${CLICKHOUSE_HOST}" -m -n -q " drop table ot.${table}"
done
