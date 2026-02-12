#!/bin/bash
set -euo pipefail

: "${POSTGRES_HOST:?POSTGRES_HOST is required}"
: "${POSTGRES_PORT:=5432}"
: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${S3_BUCKET:?S3_BUCKET is required}"
: "${S3_PREFIX:=backup}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
DUMP_FILE="/tmp/${POSTGRES_DB}_${TIMESTAMP}.sql.gz"

export PGPASSWORD="${POSTGRES_PASSWORD}"

echo "Starting backup of database '${POSTGRES_DB}' from ${POSTGRES_HOST}:${POSTGRES_PORT}..."

pg_dump \
  -h "${POSTGRES_HOST}" \
  -p "${POSTGRES_PORT}" \
  -U "${POSTGRES_USER}" \
  -d "${POSTGRES_DB}" \
  --no-password \
  | gzip > "${DUMP_FILE}"

echo "Dump completed: ${DUMP_FILE} ($(du -h "${DUMP_FILE}" | cut -f1))"

S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/${POSTGRES_DB}_${TIMESTAMP}.sql.gz"

echo "Uploading to ${S3_PATH}..."

aws s3 cp "${DUMP_FILE}" "${S3_PATH}"

echo "Upload completed."

rm -f "${DUMP_FILE}"

echo "Backup finished successfully."
