# postgres-s3-backup

**[English](#english)** | **[日本語](#日本語)**

---

## English

A Docker image that backs up PostgreSQL databases using `pg_dump` and uploads them to S3 (or S3-compatible storage).

### Docker Image

```
ghcr.io/windyakin/postgres-s3-backup:latest
```

Supports `linux/amd64` and `linux/arm64`.

### Usage

```bash
docker run --rm \
  -e POSTGRES_HOST=db.example.com \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  -e S3_BUCKET=my-backup-bucket \
  ghcr.io/windyakin/postgres-s3-backup:latest
```

#### Backing Up Multiple Databases

You can specify multiple databases in `POSTGRES_DB` separated by commas. They will be backed up sequentially in the specified order.

```bash
-e POSTGRES_DB=db1,db2,db3
```

#### Dry-run

With `--dry-run`, the dump will be executed but the upload to S3 will be skipped.

```bash
docker run --rm \
  -e POSTGRES_HOST=db.example.com \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  -e S3_BUCKET=my-backup-bucket \
  ghcr.io/windyakin/postgres-s3-backup:latest --dry-run
```

### Restore

#### List Backups

```bash
docker run --rm \
  -e POSTGRES_HOST=db.example.com \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  -e S3_BUCKET=my-backup-bucket \
  --entrypoint restore.sh \
  ghcr.io/windyakin/postgres-s3-backup:latest --list
```

#### Restore from Latest Backup

```bash
docker run --rm \
  -e POSTGRES_HOST=db.example.com \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  -e S3_BUCKET=my-backup-bucket \
  --entrypoint restore.sh \
  ghcr.io/windyakin/postgres-s3-backup:latest --latest
```

#### Restore from a Specific Backup File

```bash
docker run --rm \
  -e POSTGRES_HOST=db.example.com \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  -e S3_BUCKET=my-backup-bucket \
  --entrypoint restore.sh \
  ghcr.io/windyakin/postgres-s3-backup:latest mydb_20250101_030000.sql.gz
```

#### Dry-run (Restore)

With `--dry-run`, the download from S3 will be executed but the restore to the database will be skipped.

```bash
docker run --rm \
  -e POSTGRES_HOST=db.example.com \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  -e S3_BUCKET=my-backup-bucket \
  --entrypoint restore.sh \
  ghcr.io/windyakin/postgres-s3-backup:latest --latest --dry-run
```

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `POSTGRES_HOST` | Yes | - | PostgreSQL host |
| `POSTGRES_PORT` | No | `5432` | PostgreSQL port |
| `POSTGRES_USER` | Yes | - | PostgreSQL user |
| `POSTGRES_PASSWORD` | Yes | - | PostgreSQL password |
| `POSTGRES_DB` | Yes | - | Database name(s) to back up (comma-separated for multiple) |
| `S3_BUCKET` | Yes | - | Destination S3 bucket name |
| `S3_PREFIX` | No | `backup` | Prefix for S3 object keys |
| `AWS_ENDPOINT_URL` | No | - | Endpoint URL for S3-compatible APIs (MinIO, Cloudflare R2, etc.) |
| `AWS_ACCESS_KEY_ID` | No | - | AWS access key (not required when using IAM roles) |
| `AWS_SECRET_ACCESS_KEY` | No | - | AWS secret key (not required when using IAM roles) |
| `AWS_DEFAULT_REGION` | No | - | AWS region |
| `PROCESS_PRIORITY` | No | `19` | `nice` priority (0-19, higher means lower priority) |
| `IONICE_CLASS` | No | `3` | `ionice` class (3=idle) |

### File Structure on S3

```
s3://{S3_BUCKET}/{S3_PREFIX}/{POSTGRES_DB}_{YYYYMMDD_HHMMSS}.sql.gz
```

### Kubernetes CronJob Example

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 3 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: backup
              image: ghcr.io/windyakin/postgres-s3-backup:latest
              env:
                - name: POSTGRES_HOST
                  value: postgres.default.svc.cluster.local
                - name: POSTGRES_USER
                  valueFrom:
                    secretKeyRef:
                      name: postgres-credentials
                      key: username
                - name: POSTGRES_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: postgres-credentials
                      key: password
                - name: POSTGRES_DB
                  value: "app_production,app_analytics"
                - name: S3_BUCKET
                  value: my-backup-bucket
          restartPolicy: OnFailure
```
