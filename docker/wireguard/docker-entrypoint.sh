#!/bin/bash

[ -f /usr/local/share/.rules ] && iptables-restore < /usr/local/share/.rules

exec "$@"
