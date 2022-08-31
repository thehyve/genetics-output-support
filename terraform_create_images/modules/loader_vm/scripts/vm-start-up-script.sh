#!/bin/bash
# Startup script for Elastic Search VM Instance

echo "---> [LAUNCH] GOS support VM"

echo "---> Printing environment variables:"

echo "PROJECT_ID: ${PROJECT_ID}"
echo "GS: ${GS_ETL_DATASET}"
echo "CH_DISK: ${CH_DISK}"
echo "CH_VERSION: ${CH_VERSION}"
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

# === DISKS
es_mount="/mnt/disks/es"
ch_mount="/mnt/disks/ch"

# === Docker
docker_es=elasticsearch
docker_ch=clickhouse

echo "---> Installing dependencies for GOS VM"

apt update &&
  apt -y install wget python3-pip ca-certificates curl gnupg lsb-release

echo "---> Installing Python dependencies"
pip3 install elasticsearch-loader

echo "---> Installing Docker"
mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

apt update
apt -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "---> Preparing CH Disk"
# based on the device-name used in infrastructure definition it should be
# /dev/disk/by-id/google-ch-disk
# format disk
sudo mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0,discard \
  /dev/disk/by-id/google-$CH_DISK
# create mount and add disk
sudo mkdir -p $ch_mount
sudo mount -o discard,defaults /dev/disk/by-id/google-${CH_DISK} $ch_mount
# Change permission so anyone can write
sudo chmod a+w $ch_mount

echo "---> Preparing ES Disk"
sudo mkfs.ext4 -F -E lazy_itable_init=0,lazy_journal_init=0,discard \
  /dev/disk/by-id/google-${ES_DISK}
sudo mkdir -p $es_mount
sudo mount -o discard,defaults /dev/disk/by-id/google-${ES_DISK} $es_mount
sudo chmod a+w $es_mount

echo "---> Downloading loading scripts"
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
  v2d_coloc_log.sql
  v2d_coloc.sql
  v2d_credset_log.sql
  v2d_credset.sql
  v2d_log.sql
  v2d.sql
  v2d_sa_gwas_log.sql
  v2d_sa_gwas_log.sql
  v2d_sa_molecular_trait_log.sql
  v2d_sa_molecular_trait.sql
  v2g_scored_log.sql
  v2g_scored.sql
  v2g_structure.sql
  variants_log.sql
  variants.sql
)

content=https://raw.githubusercontent.com/opentargets/genetics-output-support/${DEP_BRANCH}/terraform_create_images/modules/${MODULE}/scripts/clickhouse/sql

for scrpt in $${sql_scripts[@]}; do
  wget $content/$scrpt
done

es_indexes=(
  index_settings_genes.json
  index_settings_studies.json
  index_settings_variants.json
)
content=https://raw.githubusercontent.com/opentargets/genetics-output-support/${DEP_BRANCH}/terraform_create_images/modules/${MODULE}/scripts/elasticseach

for scrpt in $${sql_scripts[@]}; do
  wget $content/$scrpt
done

wget https://raw.githubusercontent.com/opentargets/genetics-output-support/${DEP_BRANCH}/terraform_create_images/modules/${MODULE}/scripts/create_and_load_everything_from_scratch.sh

chmod +x create_and_load_everything_from_scratch.sh

# start Clickhouse
# https://hub.docker.com/r/clickhouse/clickhouse-server/
echo "---> Starting Clickhouse Docker image"
docker run -d \
  -p 8123:8123 \
  -p 9000:9000 \
  --name clickhouse \
  --mount type=bind,source="$CH_DISK"/var/lib/clickhouse,target=/var/lib/clickhouse \
  --ulimit nofile=262144:262144 \
  clickhouse/clickhouse-server:${CH_VERSION}

# start Elasticsearch
echo "---> Staring Elasticsearch Docker image"
#configure elasticseach
#  cluster.name            must be unique on network for udp broadcast
#  network.host            allow connections on any network device, not just localhost
#  bootstrap.memory_lock   disable swap
#  xpack.security.enabled  turn off xpack extras
#  search.max_open_scroll_context
#                          increase nuber of scrolls possible at once
#  discovery.type          turn off clustering
#  thread_pool.write.queue_size
#    size of the queue for bulk indexing tasks
#      needed for high submissions from pipeline
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
  --mount type=bind,source=${ES_DISK}/elasticsearch,target=/usr/share/elasticsearch/data \
  -v /var/elasticsearch/log:/var/log/elasticsearch \
  docker.elastic.co/elasticsearch/elasticsearch-oss:${ES_VERSION}

echo "---> Starting data loading"
time create_and_load_everything_from_scratch.sh $GS_ETL_DATASET >$CH_DISK"/genetics_loading_log.txt"

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
gcloud compute disks snapshot es_disk ch_disk --snapshot-names es-1,ch-1
# copy disks to correct zones

# shutdown machine
