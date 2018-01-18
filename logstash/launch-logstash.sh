#!/bin/bash
set -eu

LS_JAVA_OPTS="-XX:+PreserveFramePointer" /usr/share/logstash/bin/logstash -f logstash.conf --path.settings /etc/logstash/ --pipeline.workers 4 --pipeline.batch.size 4500
