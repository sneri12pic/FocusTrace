#!/bin/sh
# Daily staging backup and proxy log rotation. Run from cron as the deployment user.
set -eu
cd "$(dirname "$0")"
umask 077
mkdir -p backups
exec 9>backups/.maintenance.lock
flock -n 9 || exit 0
stamp=$(date -u +%Y%m%dT%H%M%SZ)
temporary=$(mktemp backups/.dump.XXXXXX)
trap 'rm -f "$temporary"' EXIT HUP INT TERM
docker compose exec -T postgres pg_dump -U focustrace_app -d focustrace -Fc > "$temporary"
test -s "$temporary"
mv "$temporary" "backups/focustrace-$stamp.dump"
# Seven days of local backups; never use this as an off-host disaster recovery claim.
find backups -maxdepth 1 -name 'focustrace-*.dump' -type f -mtime +6 -delete
# nginx workers need to traverse the bind directory when reopening rotated logs.
# The outer deployment directory stays mode 700; files are not exposed to other users.
chmod 711 logs/proxy
for logfile in logs/proxy/access.log logs/proxy/error.log; do
    if test -f "$logfile"; then mv "$logfile" "$logfile.$stamp"; fi
done
docker compose exec -T proxy nginx -s reopen
find logs/proxy -maxdepth 1 -name '*.log.*' -type f -mtime +6 -delete
printf 'PASS: staging backup and proxy log rotation\n'
