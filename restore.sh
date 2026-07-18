#!/bin/bash
set -euo pipefail

: "${POSTGRES_HOST:?POSTGRES_HOST is required}"
: "${POSTGRES_PORT:=5432}"
: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${S3_BUCKET:?S3_BUCKET is required}"
: "${S3_PREFIX:=backup}"

DRY_RUN=false
LIST_MODE=false
USE_LATEST=false
RESTORE_FILE=""

for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=true ;;
    --list) LIST_MODE=true ;;
    --latest) USE_LATEST=true ;;
    *) RESTORE_FILE="${arg}" ;;
  esac
done

export PGPASSWORD="${POSTGRES_PASSWORD}"

AWS_OPTS=()
if [[ -n "${AWS_ENDPOINT_URL:-}" ]]; then
  AWS_OPTS+=(--endpoint-url "${AWS_ENDPOINT_URL}")
fi

if [[ "${LIST_MODE}" == "true" ]]; then
  echo "Available backups in s3://${S3_BUCKET}/${S3_PREFIX}/:"
  aws s3 ls "${AWS_OPTS[@]}" "s3://${S3_BUCKET}/${S3_PREFIX}/" | grep '\.sql\.gz$' | sort
  exit 0
fi

if [[ "${USE_LATEST}" == "true" && -z "${RESTORE_FILE}" ]]; then
  echo "Finding latest backup for database '${POSTGRES_DB}'..."
  RESTORE_FILE="$(aws s3 ls "${AWS_OPTS[@]}" "s3://${S3_BUCKET}/${S3_PREFIX}/${POSTGRES_DB}_" \
    | grep '\.sql\.gz$' \
    | sort \
    | tail -n 1 \
    | awk '{print $NF}')"
  if [[ -z "${RESTORE_FILE}" ]]; then
    echo "Error: No backup found for database '${POSTGRES_DB}'." >&2
    exit 1
  fi
  echo "Latest backup: ${RESTORE_FILE}"
fi

if [[ -z "${RESTORE_FILE}" ]]; then
  echo "Error: Specify a backup file as an argument, or use --latest to restore the most recent backup." >&2
  echo "Use --list to see available backups." >&2
  exit 1
fi

S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/${RESTORE_FILE}"
DUMP_FILE="/tmp/${RESTORE_FILE}"

echo "Downloading ${S3_PATH}..."
aws s3 cp "${AWS_OPTS[@]}" "${S3_PATH}" "${DUMP_FILE}"
echo "Download completed: ${DUMP_FILE} ($(du -h "${DUMP_FILE}" | cut -f1))"

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "[dry-run] Would restore to database '${POSTGRES_DB}' on ${POSTGRES_HOST}:${POSTGRES_PORT}"
  echo "[dry-run] Skipping restore and removing dump file."
  rm -f "${DUMP_FILE}"
  exit 0
fi

echo "Restoring to database '${POSTGRES_DB}' on ${POSTGRES_HOST}:${POSTGRES_PORT}..."

gunzip -c "${DUMP_FILE}" | psql \
  -h "${POSTGRES_HOST}" \
  -p "${POSTGRES_PORT}" \
  -U "${POSTGRES_USER}" \
  -d "${POSTGRES_DB}" \
  --no-password

echo "Restore completed."

rm -f "${DUMP_FILE}"

echo "Restore finished successfully."
