# postgres-s3-backup

PostgreSQL のデータベースを `pg_dump` でバックアップし、S3 (または S3 互換ストレージ) にアップロードする Docker イメージです。

## Docker イメージ

```
ghcr.io/windyakin/postgres-s3-backup:latest
```

`linux/amd64` と `linux/arm64` に対応しています。

## 使い方

```bash
docker run --rm \
  -e POSTGRES_HOST=db.example.com \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  -e S3_BUCKET=my-backup-bucket \
  ghcr.io/windyakin/postgres-s3-backup:latest
```

### 複数データベースのバックアップ

`POSTGRES_DB` にカンマ区切りで複数のデータベースを指定できます。指定した順に逐次バックアップされます。

```bash
-e POSTGRES_DB=db1,db2,db3
```

### Dry-run

`--dry-run` を指定すると、ダンプは実行されますが S3 へのアップロードはスキップされます。

```bash
docker run --rm \
  -e POSTGRES_HOST=db.example.com \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  -e S3_BUCKET=my-backup-bucket \
  ghcr.io/windyakin/postgres-s3-backup:latest --dry-run
```

## 環境変数

| 変数 | 必須 | デフォルト | 説明 |
|------|------|-----------|------|
| `POSTGRES_HOST` | Yes | - | PostgreSQL ホスト |
| `POSTGRES_PORT` | No | `5432` | PostgreSQL ポート |
| `POSTGRES_USER` | Yes | - | PostgreSQL ユーザー |
| `POSTGRES_PASSWORD` | Yes | - | PostgreSQL パスワード |
| `POSTGRES_DB` | Yes | - | バックアップ対象のデータベース名 (カンマ区切りで複数指定可) |
| `S3_BUCKET` | Yes | - | アップロード先の S3 バケット名 |
| `S3_PREFIX` | No | `backup` | S3 オブジェクトキーのプレフィックス |
| `AWS_ENDPOINT_URL` | No | - | S3 互換 API のエンドポイント URL (MinIO, Cloudflare R2 など) |
| `AWS_ACCESS_KEY_ID` | No | - | AWS アクセスキー (IAM ロール使用時は不要) |
| `AWS_SECRET_ACCESS_KEY` | No | - | AWS シークレットキー (IAM ロール使用時は不要) |
| `AWS_DEFAULT_REGION` | No | - | AWS リージョン |
| `PROCESS_PRIORITY` | No | `19` | `nice` の優先度 (0-19, 大きいほど低優先) |
| `IONICE_CLASS` | No | `3` | `ionice` のクラス (3=idle) |

## S3 上のファイル構成

```
s3://{S3_BUCKET}/{S3_PREFIX}/{POSTGRES_DB}_{YYYYMMDD_HHMMSS}.sql.gz
```

## Kubernetes CronJob での使用例

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
