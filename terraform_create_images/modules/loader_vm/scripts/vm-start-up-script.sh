#!/bin/bash
# Startup script for Elastic Search VM Instance
set -x

echo "---> [LAUNCH] GOS support VM"

echo "---> Printing environment variables:"

echo "PROJECT_ID: ${PROJECT_ID}"
echo "GS: ${GS_ETL_DATASET}"
echo "CH_DEVICE: ${CH_DEVICE}"
echo "CH_DISK: ${CH_DISK}"
echo "CH_VERSION: ${CH_VERSION}"
echo "ES_DEVICE: ${ES_DEVICE}"
echo "ES_DISK: ${ES_DISK}"
echo "ES_VERSION: ${ES_VERSION}"

echo "---> Calculating RAM allocations"
# take second column of second line for ram installed
RAM=$(free -g | awk 'FNR == 2 {print $2}')
ES_RAM_DENOMINATOR=6
CH_RAM_DENOMINATOR=2
ES_RAM=$(expr $RAM / $ES_RAM_DENOMINATOR)
CH_RAM=$(expr $RAM / $CH_RAM_DENOMINATOR)
echo "Total RAM available: $RAM"
echo "ES RAM allocation (1/"$ES_RAM_DENOMINATOR"th): $ES_RAM"
echo "CH RAM allocation (1/"$CH_RAM_DENOMINATOR"th): $CH_RAM"

# === Locations
es_mount="/mnt/disks/es"
ch_mount="/mnt/disks/ch"
ch_serv="$ch_mount/var/lib/clickhouse"
es_data="$es_mount/elasticsearch"
scripts=/tmp/scripts
mkdir -p $scripts

# === Docker
docker_es=elasticsearch
docker_ch=clickhouse

echo "---> Installing dependencies for GOS VM"

apt-get update &&
  apt-get -y install wget python3-pip ca-certificates curl gnupg lsb-release

echo "---> Installing Python dependencies"
pip3 install elasticsearch-loader

echo "---> Installing Docker"
mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "---> Installing clickhouse-client"
apt-get install -y apt-transport-https ca-certificates dirmngr
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 8919F6BD2B48D754

echo "deb https://packages.clickhouse.com/deb stable main" | sudo tee \
  /etc/apt/sources.list.d/clickhouse.list
apt-get update

apt-get install -y clickhouse-client

echo "---> Preparing CH Disk"
# based on the device-name used in infrastructure definition it should be
# /dev/disk/by-id/google-ch-disk
# format disk
sudo mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0,discard \
  /dev/disk/by-id/google-${CH_DEVICE}
# create mount and add disk
sudo mkdir -p $ch_mount
sudo mount -o discard,defaults /dev/disk/by-id/google-${CH_DEVICE} $ch_mount
# Change permission so anyone can write
sudo chmod a+w $ch_mount
mkdir -p $ch_serv

echo "---> Preparing ES Disk"
sudo mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0,discard \
  /dev/disk/by-id/google-${ES_DEVICE}
sudo mkdir -p $es_mount
sudo mount -o discard,defaults /dev/disk/by-id/google-${ES_DEVICE} $es_mount
sudo chmod a+w $es_mount
mkdir -p $es_data

echo "---> Downloading loading scripts"
content=https://raw.githubusercontent.com/opentargets/genetics-output-support/${DEP_BRANCH}/terraform_create_images/modules/${MODULE}/scripts

sql_scripts=(
  d2v2g_scored_log.sql
  d2v2g_scored.sql
  genes.sql
  l2g_log.sql
  l2g.sql
  manhattan_log.sql
  manhattan.sql
  studies_log.sql
  studies.sql
  studies_overlap.sql
  studies_overlap_log.sql
  v2d_coloc_log.sql
  v2d_coloc.sql
  v2d_credset_log.sql
  v2d_credset.sql
  v2d_log.sql
  v2d.sql
  v2d_sa_gwas_log.sql
  v2d_sa_gwas.sql
  v2d_sa_molecular_trait_log.sql
  v2d_sa_molecular_trait.sql
  v2g_scored_log.sql
  v2g_scored.sql
  v2g_structure.sql
  variants_log.sql
  variants.sql
)

for scrpt in $${sql_scripts[@]}; do
  wget -P $scripts $content/clickhouse/sql/$scrpt
done

es_indexes=(
  index_settings_genes.json
  index_settings_studies.json
  index_settings_variants.json
)

for scrpt in $${es_indexes[@]}; do
  wget -P $scripts $content/elasticsearch/$scrpt
done

helper_scripts=(
  create_and_load_everything_from_scratch.sh
)

for scrpt in $${helper_scripts[@]}; do
  wget -P $scripts $content/$scrpt
  chmod +x $scripts/$scrpt
done

# start Clickhouse
# https://hub.docker.com/r/clickhouse/clickhouse-server/
echo "---> Starting Clickhouse Docker image"
docker run -d \
  -p 8123:8123 \
  -p 9000:9000 \
  --name clickhouse \
  --mount type=bind,source=$ch_serv,target=/var/lib/clickhouse \
  --ulimit nofile=262144:262144 \
  clickhouse/clickhouse-server:${CH_VERSION}

# start Elasticsearch
echo "---> Staring Elasticsearch Docker image"
docker run -d --restart always \
  --name elasticsearch \
  -p 9200:9200 \
  -p 9300:9300 \
  -e discovery.type=single-node \
  -e bootstrap.memory_lock=true \
  -e repositories.url.allowed_urls='https://storage.googleapis.com/*' \
  -e thread_pool.write.queue_size=1000 \
  -e cluster.name=$(hostname) \
  -e network.host=0.0.0.0 \
  -e search.max_open_scroll_context=5000 \
  -e ES_JAVA_OPTS="-Xms$${ES_RAM}g -Xmx$${ES_RAM}g" \
  --mount type=bind,source=$es_data,target=/usr/share/elasticsearch/data \
  -v /var/elasticsearch/log:/var/log/elasticsearch \
  docker.elastic.co/elasticsearch/elasticsearch-oss:${ES_VERSION}

echo "---> Starting data loading"
time bash .$scripts/create_and_load_everything_from_scratch.sh ${GS_ETL_DATASET}

echo "---> Data loading complete"

# stop Clickhouse and elastic search
echo "---> Stopping docker containers"
docker stop $docker_ch
docker stop $docker_es

# detach disks
echo "---> Detaching disks"
umount $es_mount
umount $ch_mount

# create disk snapshots
# https://cloud.google.com/sdk/gcloud/reference/compute/disks/snapshot
gcloud compute disks snapshot ${ES_DISK} ${CH_DISK} --snapshot-names snap-${ES_DISK},snap-${CH_DISK} --zone ${GC_ZONE}

# copy disks to correct zones

# shutdown machine
