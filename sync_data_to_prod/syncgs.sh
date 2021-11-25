#!/bin/bash

pre_data_release="gs://${GS_SYNC_FROM}/"

echo "=== Start copying..."
cmd=`gsutil -m cp -r $pre_data_release gs://open-targets-genetics-releases /${RELEASE_ID_PROD}".02"/`
echo "=== Copying done."