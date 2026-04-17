#!/bin/bash
# ================================================================
# Glue Setup — Crawlers + ETL Job
# Region: eu-north-1  |  Account: 430006376054
# ================================================================

REGION="eu-north-1"
ROLE_ARN="arn:aws:iam::430006376054:role/glue-crawler-role-bdclp"
SCRIPT_BUCKET="my-pipeline-scripts-bdclp"

# ── 1. Upload Glue ETL script to S3 ──────────────────────────────
aws s3 cp glue_etl/bronze_to_silver.py \
  s3://$SCRIPT_BUCKET/glue-scripts/bronze_to_silver.py \
  --region $REGION

# ── 2. Create Bronze Crawler ──────────────────────────────────────
aws glue create-crawler \
  --name bronze-crawler-bdclp \
  --role $ROLE_ARN \
  --database-name bronze_db \
  --targets '{"S3Targets": [{"Path": "s3://my-pipeline-bronze-bdclp/raw/labdb/"}]}' \
  --region $REGION

aws glue start-crawler --name bronze-crawler-bdclp --region $REGION
echo "Bronze crawler started. Waiting..."
aws glue get-crawler --name bronze-crawler-bdclp \
  --query "Crawler.State" --output text --region $REGION

# ── 3. Create Silver Crawler ──────────────────────────────────────
aws glue create-crawler \
  --name silver-crawler-bdclp \
  --role $ROLE_ARN \
  --database-name silver_db \
  --targets '{"S3Targets": [{"Path": "s3://my-pipeline-silver-bdclp/transformed/employees/"}]}' \
  --region $REGION

# ── 4. Create Glue ETL Job ────────────────────────────────────────
aws glue create-job \
  --name bronze-to-silver-etl-bdclp \
  --role $ROLE_ARN \
  --command "{
    \"Name\": \"glueetl\",
    \"ScriptLocation\": \"s3://${SCRIPT_BUCKET}/glue-scripts/bronze_to_silver.py\",
    \"PythonVersion\": \"3\"
  }" \
  --default-arguments '{
    "--job-bookmark-option": "job-bookmark-enable",
    "--enable-metrics": "",
    "--enable-continuous-cloudwatch-log": "true"
  }' \
  --glue-version "4.0" \
  --worker-type G.1X \
  --number-of-workers 2 \
  --region $REGION

echo "Glue crawlers and ETL job created."
echo "Run silver crawler after first ETL job completes:"
echo "aws glue start-crawler --name silver-crawler-bdclp --region $REGION"
