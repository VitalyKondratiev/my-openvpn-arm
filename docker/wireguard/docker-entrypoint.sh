#!/bin/sh

[ -f /usr/local/share/.rules ] && iptables-restore -n < /usr/local/share/.rules

exec "$@"
