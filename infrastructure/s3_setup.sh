#!/bin/bash
# ================================================================
# S3 Bucket Setup — 3 storage layers
# Region: eu-north-1  |  Account: 430006376054
# ================================================================

REGION="eu-north-1"
ACCOUNT_ID="430006376054"

# ── Bronze — Raw DMS output ───────────────────────────────────────
aws s3api create-bucket \
  --bucket my-pipeline-bronze-bdclp \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

aws s3api put-bucket-versioning \
  --bucket my-pipeline-bronze-bdclp \
  --versioning-configuration Status=Enabled

# ── Silver — Transformed Parquet ─────────────────────────────────
aws s3api create-bucket \
  --bucket my-pipeline-silver-bdclp \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

aws s3api put-bucket-versioning \
  --bucket my-pipeline-silver-bdclp \
  --versioning-configuration Status=Enabled

# ── Scripts — Glue scripts, Athena results, QuickSight files ─────
aws s3api create-bucket \
  --bucket my-pipeline-scripts-bdclp \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

# Create standard folder structure
aws s3api put-object --bucket my-pipeline-scripts-bdclp --key glue-scripts/
aws s3api put-object --bucket my-pipeline-scripts-bdclp --key athena-results/
aws s3api put-object --bucket my-pipeline-scripts-bdclp --key quicksight/

# ── Bucket policy for CodePipeline access ────────────────────────
aws s3api put-bucket-policy \
  --bucket my-pipeline-scripts-bdclp \
  --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Principal\": {\"AWS\": \"arn:aws:iam::${ACCOUNT_ID}:role/dms-s3-target-role-bdclp\"},
        \"Action\": [\"s3:GetObject\",\"s3:PutObject\",\"s3:ListBucket\",\"s3:GetBucketAcl\",\"s3:GetBucketLocation\"],
        \"Resource\": [
          \"arn:aws:s3:::my-pipeline-scripts-bdclp\",
          \"arn:aws:s3:::my-pipeline-scripts-bdclp/*\"
        ]
      }
    ]
  }"

echo "All S3 buckets created."
