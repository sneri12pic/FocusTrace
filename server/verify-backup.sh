#!/bin/sh
# Restore into a new disposable database; never overwrite the running database.
set -eu
cd "$(dirname "$0")"
archive=$(find backups -maxdepth 1 -name 'focustrace-*.dump' -type f | sort | tail -n 1)
test -n "$archive"
database="focustrace_restore_check_$(date -u +%Y%m%d%H%M%S)_$$"
docker compose exec -T postgres createdb -U focustrace_admin -O focustrace_app "$database"
trap 'docker compose exec -T postgres dropdb -U focustrace_admin "$database"' EXIT HUP INT TERM
docker compose exec -T postgres pg_restore -U focustrace_admin --role=focustrace_app \
    --no-owner --exit-on-error -d "$database" < "$archive"
migrations=$(docker compose exec -T postgres psql -U focustrace_app -d "$database" -tAc \
    'SELECT count(*) FROM flyway_schema_history WHERE success')
test "$migrations" = 4
docker compose exec -T postgres psql -U focustrace_app -d "$database" -tAc \
    'SELECT count(*) AS restored_usage_days FROM usage_days'
printf 'PASS: backup restored into a disposable database; all four migrations present\n'
