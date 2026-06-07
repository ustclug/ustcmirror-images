#!/bin/bash

cat << EOF > /etc/bandersnatch.conf
[mirror]
directory = $TO
master = $PYPI_MASTER
timeout = $BANDERSNATCH_TIMEOUT
workers = $BANDERSNATCH_WORKERS
hash-index = false
stop-on-error = $BANDERSNATCH_STOP_ON_ERROR
delete-packages = true
EOF
