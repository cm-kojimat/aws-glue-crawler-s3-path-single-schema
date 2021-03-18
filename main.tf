provider "random" {}
provider "aws" {}

resource "random_string" "uniqid" {
  length  = 8
  special = false
  lower   = true
  upper   = false
}

resource "aws_s3_bucket" "bucket" {
  bucket = replace("crawler_data_source_${random_string.uniqid.result}", "_", "-")
}

resource "aws_glue_catalog_database" "database_a" {
  name = "catalog_a_${random_string.uniqid.result}"
}

resource "aws_glue_catalog_database" "database_b" {
  name = "catalog_b_${random_string.uniqid.result}"
}

resource "aws_glue_crawler" "crawler_a" {
  name          = "crawler_a_${random_string.uniqid.result}"
  database_name = aws_glue_catalog_database.database_a.name

  role = aws_iam_role.role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.bucket.bucket}/db1"
  }

  configuration = jsonencode({
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
    Version = 1
  })
}

resource "aws_glue_crawler" "crawler_b" {
  name          = "crawler_b_${random_string.uniqid.result}"
  database_name = aws_glue_catalog_database.database_b.name

  role = aws_iam_role.role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.bucket.bucket}/db2"
  }
}

resource "aws_iam_role" "role" {
  name               = "role_${random_string.uniqid.result}"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "inline_policy" {
  policy = data.aws_iam_policy_document.inline_policy.json
}

data "aws_iam_policy_document" "inline_policy" {
  statement {
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy_attachment" "inline_policy_attachment" {
  name       = "attachment_${random_string.uniqid.result}"
  roles      = [aws_iam_role.role.name]
  policy_arn = aws_iam_policy.inline_policy.arn
}

output "init_sh" {
  value = <<EOF
  #!/usr/bin/env bash
  set -x
  set -Eeuo pipefail

  aws s3 sync db s3://${aws_s3_bucket.bucket.bucket}/db1
  aws s3 sync db s3://${aws_s3_bucket.bucket.bucket}/db2

  aws glue start-crawler --name ${aws_glue_crawler.crawler_a.name}
  aws glue start-crawler --name ${aws_glue_crawler.crawler_b.name}

  sleep 1m

  aws glue get-tables --database-name ${aws_glue_catalog_database.database_a.name} --query "TableList[].Name"
  aws glue get-tables --database-name ${aws_glue_catalog_database.database_b.name} --query "TableList[].Name"
  EOF
}
