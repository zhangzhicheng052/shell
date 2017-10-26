#!/bin/bash
mkdir /data &> /dev/null
\cp /etc/*.conf /data
tar czvf /tmp/$(date +%F_%T).tar.gz /data
