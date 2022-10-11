#!/bin/bash

pre_data_release="gs://${GS_SYNC_FROM}/"
echo $pre_data_release

echo "=== Start copying..."
cmd=`gsutil -m rsync -r $pre_data_release gs://open-targets-genetics-releases/${RELEASE_ID_PROD}/`
echo "=== Copying done."
