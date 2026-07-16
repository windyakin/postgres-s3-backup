#!/bin/bash
set -euo pipefail

: "${PROCESS_PRIORITY:=19}"
: "${IONICE_CLASS:=3}"
: "${POSTGRES_HOST:?POSTGRES_HOST is required}"
: "${POSTGRES_PORT:=5432}"
: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${S3_BUCKET:?S3_BUCKET is required}"
: "${S3_PREFIX:=backup}"
DRY_RUN=false
for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=true ;;
  esac
done

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

export PGPASSWORD="${POSTGRES_PASSWORD}"

AWS_OPTS=()
if [[ -n "${AWS_ENDPOINT_URL:-}" ]]; then
  AWS_OPTS+=(--endpoint-url "${AWS_ENDPOINT_URL}")
fi

IFS=',' read -ra DATABASES <<< "${POSTGRES_DB}"

for DATABASE in "${DATABASES[@]}"; do
  DATABASE="$(echo "${DATABASE}" | xargs)"
  [[ -z "${DATABASE}" ]] && continue

  DUMP_FILE="/tmp/${DATABASE}_${TIMESTAMP}.sql.gz"

  echo "Starting backup of database '${DATABASE}' from ${POSTGRES_HOST}:${POSTGRES_PORT}..."

  nice -n "${PROCESS_PRIORITY}" \
  ionice -c "${IONICE_CLASS}" \
  pg_dump \
    -h "${POSTGRES_HOST}" \
    -p "${POSTGRES_PORT}" \
    -U "${POSTGRES_USER}" \
    -d "${DATABASE}" \
    --no-password \
    | gzip > "${DUMP_FILE}"

  echo "Dump completed: ${DUMP_FILE} ($(du -h "${DUMP_FILE}" | cut -f1))"

  S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/${DATABASE}_${TIMESTAMP}.sql.gz"

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[dry-run] Would upload to ${S3_PATH}"
    echo "[dry-run] Skipping upload and removing dump file."
    rm -f "${DUMP_FILE}"
    continue
  fi

  echo "Uploading to ${S3_PATH}..."

  aws s3 cp "${AWS_OPTS[@]}" "${DUMP_FILE}" "${S3_PATH}"

  echo "Upload completed."

  rm -f "${DUMP_FILE}"
done

echo "Backup finished successfully."
