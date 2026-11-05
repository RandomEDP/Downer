#!/usr/bin/env bash
# Migrations must be named NNNN_description.sql, numbered 0001, 0002, ... with no gaps or duplicates.
set -euo pipefail
cd "$(dirname "$0")/../supabase/migrations"
expected=1
status=0
for f in $(ls *.sql | sort); do
  if [[ ! "$f" =~ ^([0-9]{4})_[a-z0-9_]+\.sql$ ]]; then
    echo "Bad migration name: $f (want NNNN_snake_case.sql)"; status=1; continue
  fi
  n=$((10#${BASH_REMATCH[1]}))
  if [[ $n -ne $expected ]]; then
    printf 'Expected %04d, found %s\n' "$expected" "$f"; status=1
  fi
  expected=$((n + 1))
done
[[ $status -eq 0 ]] && printf 'Migrations OK, next number is %04d\n' "$expected"
exit $status
