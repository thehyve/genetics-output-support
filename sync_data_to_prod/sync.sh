#!/bin/bash

ssh noah-login-05 "sudo -u otftpuser mkdir /nfs/ftp/private/otftpuser/upload/genetics/${RELEASE_ID_PROD}".01"; sudo -u otftpuser chmod 775 /nfs/ftp/private/otftpuser/upload/genetics/${RELEASE_ID_PROD}".01""
ssh noah-login-05 "tmux new-session -d -s gencopytoftp"
ssh noah-login-05 "tmux send-keys 'umask 002; cd /nfs/ftp/private/otftpuser/upload/genetics/${RELEASE_ID_PROD}".01"; CLOUDSDK_PYTHON=/nfs/production/opentargets/anaconda3/bin/python /nfs/production/opentargets/google-cloud-sdk/bin/gsutil rsync -r gs://${GS_SYNC_FROM}/ . '  C-m"
ssh noah-login-05 "tmux send-keys 'sudo -u otftpuser umask 002; sudo -u otftpuser mkdir /nfs/ftp/pub/databases/opentargets/genetics/${RELEASE_ID_PROD}".01"; '  C-m"
ssh noah-login-05 "tmux send-keys 'sudo -u otftpuser umask 002; sudo -u otftpuser rsync -rv /nfs/ftp/private/otftpuser/upload/genetics/${RELEASE_ID_PROD}".01"/* /nfs/ftp/pub/databases/opentargets/genetics/${RELEASE_ID_PROD}".01"'  C-m"
ssh noah-login-05 "tmux send-keys 'sudo -u otftpuser chmod -R 755 /nfs/ftp/pub/databases/opentargets/genetics/${RELEASE_ID_PROD}".01"'  C-m"
ssh noah-login-05 "tmux send-keys 'cd /ebi/ftp/pub/databases/opentargets/genetics'  C-m"
ssh noah-login-05 "tmux send-keys 'sudo -u otftpuser umask 002; sudo -u otftpuser ln -nsf ${RELEASE_ID_PROD}".01" latest'  C-m"
ssh noah-login-05 "tmux send-keys 'echo "done"'  C-m"
#do not kill the session here!
#ssh noah-login-05 "tmux kill-session -t gencopytoftp"
