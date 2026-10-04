#!/bin/sh
# Separate schema owner from PostgreSQL's bootstrap administrator.
set -eu
psql -v ON_ERROR_STOP=1 -U focustrace_admin -d focustrace \
    -v app_password="$FOCUSTRACE_DB_PASSWORD" <<'SQL'
CREATE ROLE focustrace_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD :'app_password';
ALTER DATABASE focustrace OWNER TO focustrace_app;
SQL
