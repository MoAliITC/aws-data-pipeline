#!/bin/bash
# ================================================================
# Lambda Setup — schema-validator-bdclp
# Deploys Lambda function + S3 event trigger for CDC automation
# Region: eu-north-1  |  Account: 430006376054
# ================================================================

REGION="eu-north-1"
ACCOUNT_ID="430006376054"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/dms-s3-target-role-bdclp"
FUNCTION_NAME="schema-validator-bdclp"
BRONZE_BUCKET="my-pipeline-bronze-bdclp"

# ── 1. Package Lambda code ────────────────────────────────────────
cd lambda
zip schema_validator.zip schema_validator.py
cd ..

# ── 2. Create Lambda function ─────────────────────────────────────
aws lambda create-function \
  --function-name $FUNCTION_NAME \
  --runtime python3.12 \
  --role $ROLE_ARN \
  --handler schema_validator.lambda_handler \
  --zip-file fileb://lambda/schema_validator.zip \
  --timeout 60 \
  --region $REGION

echo "Lambda function created."

# ── 3. Allow S3 to invoke Lambda ─────────────────────────────────
aws lambda add-permission \
  --function-name $FUNCTION_NAME \
  --statement-id AllowS3Invoke \
  --action lambda:InvokeFunction \
  --principal s3.amazonaws.com \
  --source-arn arn:aws:s3:::$BRONZE_BUCKET \
  --source-account $ACCOUNT_ID \
  --region $REGION

# ── 4. Get Lambda ARN ─────────────────────────────────────────────
LAMBDA_ARN=$(aws lambda get-function \
  --function-name $FUNCTION_NAME \
  --query "Configuration.FunctionArn" \
  --output text --region $REGION)

# ── 5. Configure S3 event trigger ────────────────────────────────
# Fires on every new .parquet file under raw/labdb/ prefix
aws s3api put-bucket-notification-configuration \
  --bucket $BRONZE_BUCKET \
  --notification-configuration "{
    \"LambdaFunctionConfigurations\": [
      {
        \"LambdaFunctionArn\": \"${LAMBDA_ARN}\",
        \"Events\": [\"s3:ObjectCreated:*\"],
        \"Filter\": {
          \"Key\": {
            \"FilterRules\": [
              {\"Name\": \"prefix\", \"Value\": \"raw/labdb/\"},
              {\"Name\": \"suffix\", \"Value\": \".parquet\"}
            ]
          }
        }
      }
    ]
  }" \
  --region $REGION

echo "S3 trigger configured. CDC automation is now active."
echo "Flow: MySQL change -> DMS -> S3 Bronze -> Lambda -> Glue ETL -> S3 Silver"
