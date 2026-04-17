#!/bin/bash
# ================================================================
# IAM Setup — dms-s3-target-role-bdclp
# Single reusable role for: DMS, Glue, Lambda, CodeBuild, CodePipeline
# Region: eu-north-1  |  Account: 430006376054
#
# NOTE: This account has hit the 1000 RolesPerAccount limit.
#       All services reuse this single role.
# ================================================================

ROLE_NAME="dms-s3-target-role-bdclp"
ACCOUNT_ID="430006376054"
REGION="eu-north-1"

# ── 1. Create Role with multi-service trust policy ───────────────
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": [
            "dms.amazonaws.com",
            "dms.eu-north-1.amazonaws.com",
            "lambda.amazonaws.com",
            "glue.amazonaws.com",
            "codebuild.amazonaws.com",
            "codepipeline.amazonaws.com"
          ]
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }' \
  --region $REGION

# ── 2. Attach managed policies ───────────────────────────────────
aws iam attach-role-policy --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-role-policy --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole

aws iam attach-role-policy --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess

aws iam attach-role-policy --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess

aws iam attach-role-policy --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AWSCodeCommitFullAccess

aws iam attach-role-policy --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

# ── 3. Inline policies ───────────────────────────────────────────

# Allow explicit CloudWatch Logs actions (managed policy may have conditions)
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name AllowCloudWatchLogs \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }]
  }'

# Allow CodeBuild to pass the Glue role (required for update-job)
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name AllowPassGlueRole \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Action\": \"iam:PassRole\",
      \"Resource\": \"arn:aws:iam::${ACCOUNT_ID}:role/glue-crawler-role-bdclp\"
    }]
  }"

echo "IAM role $ROLE_NAME created and configured."
