#!/bin/sh
# Day 58: runs once, the first time the postgres container starts with an empty data volume
# (the official image executes every script in /docker-entrypoint-initdb.d).
# Applies the same scripts as setup.ps1, in the same order: schema -> tables -> functions -> indexes -> seed.
set -eu

for folder in schema tables functions indexes seed; do
  # sorted by full path, exactly like setup.ps1 (generated/ sorts after the numbered files)
  find "/learndb/$folder" -name '*.sql' | LC_ALL=C sort | while read -r file; do
    echo "  [$folder] $(basename "$file")"
    psql -v ON_ERROR_STOP=1 -q --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$file"
  done
done

echo "LearnInsuranceDB is ready."
