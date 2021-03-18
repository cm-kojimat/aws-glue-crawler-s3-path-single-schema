# AWS Glue Crawler で `S3 パスごとに単一のスキーマを作成する` の挙動を確認する

- crawler_a ... S3 パスごとに単一のスキーマを作成する: True
- crawler_b ... S3 パスごとに単一のスキーマを作成する: False

## 準備

```bash
terraform apply -auto-approve
terraform output -raw init_sh | bash
```

## 結果

```
$ terraform output --raw init_sh | bash
+ set -Eeuo pipefail
+ aws s3 sync db s3://crawler-data-source-m11lqs5r/db1
+ aws s3 sync db s3://crawler-data-source-m11lqs5r/db2
+ aws glue start-crawler --name crawler_a_m11lqs5r
+ aws glue start-crawler --name crawler_b_m11lqs5r
+ sleep 1m
+ aws glue get-tables --database-name catalog_a_m11lqs5r --query 'TableList[].Name'
[
    "db1"
]
+ aws glue get-tables --database-name catalog_b_m11lqs5r --query 'TableList[].Name'
[
    "ab1_json",
    "ab2_json",
    "ab2_json_3766893a6cef2f3607f9123389ac6556",
    "ab3_json"
]

```
