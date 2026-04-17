#!/bin/bash
# ================================================================
# DMS Setup — Replication instance, endpoints, migration task
# Type: Full Load + CDC (real-time binary log streaming)
# Region: eu-north-1  |  Account: 430006376054
# ================================================================

REGION="eu-north-1"
ROLE_ARN="arn:aws:iam::430006376054:role/dms-s3-target-role-bdclp"
BRONZE_BUCKET="my-pipeline-bronze-bdclp"
RDS_HOST="lab-mysql-bdclp.cc0jwdrrs7ro.eu-north-1.rds.amazonaws.com"

# ── 1. Subnet Group ───────────────────────────────────────────────
aws dms create-replication-subnet-group \
  --replication-subnet-group-identifier dms-subnet-group-bdclp \
  --replication-subnet-group-description "DMS subnet group" \
  --subnet-ids subnet-0352858b2852cf871 subnet-0352858b2852cf872 \
  --region $REGION

# ── 2. Replication Instance ───────────────────────────────────────
aws dms create-replication-instance \
  --replication-instance-identifier my-replication-instance-bdclp \
  --replication-instance-class dms.t3.medium \
  --allocated-storage 20 \
  --vpc-security-group-ids sg-09110bf03c6b09146 \
  --replication-subnet-group-identifier dms-subnet-group-bdclp \
  --publicly-accessible \
  --region $REGION

# Wait for available
aws dms wait replication-instance-available \
  --filters Name=replication-instance-id,Values=my-replication-instance-bdclp \
  --region $REGION

# ── 3. Source Endpoint (MySQL RDS) ────────────────────────────────
aws dms create-endpoint \
  --endpoint-identifier mysql-source-bdclp \
  --endpoint-type source \
  --engine-name mysql \
  --username admin \
  --password "YOUR_RDS_PASSWORD" \
  --server-name $RDS_HOST \
  --port 3306 \
  --database-name labdb \
  --region $REGION

# ── 4. Target Endpoint (S3 Bronze) ────────────────────────────────
aws dms create-endpoint \
  --endpoint-identifier s3-target-bronze-bdclp \
  --endpoint-type target \
  --engine-name s3 \
  --s3-settings "{
    \"ServiceAccessRoleArn\": \"${ROLE_ARN}\",
    \"BucketName\": \"${BRONZE_BUCKET}\",
    \"BucketFolder\": \"raw\",
    \"DataFormat\": \"parquet\",
    \"CompressionType\": \"NONE\",
    \"IncludeOpForFullLoad\": false
  }" \
  --region $REGION

# ── 5. Migration Task (Full Load + CDC) ───────────────────────────
# Get replication instance ARN first
RI_ARN=$(aws dms describe-replication-instances \
  --filters Name=replication-instance-id,Values=my-replication-instance-bdclp \
  --query "ReplicationInstances[0].ReplicationInstanceArn" \
  --output text --region $REGION)

SOURCE_ARN=$(aws dms describe-endpoints \
  --filters Name=endpoint-id,Values=mysql-source-bdclp \
  --query "Endpoints[0].EndpointArn" --output text --region $REGION)

TARGET_ARN=$(aws dms describe-endpoints \
  --filters Name=endpoint-id,Values=s3-target-bronze-bdclp \
  --query "Endpoints[0].EndpointArn" --output text --region $REGION)

aws dms create-replication-task \
  --replication-task-identifier db-to-s3-task-bdclp \
  --source-endpoint-arn $SOURCE_ARN \
  --target-endpoint-arn $TARGET_ARN \
  --replication-instance-arn $RI_ARN \
  --migration-type full-load-and-cdc \
  --table-mappings '{
    "rules": [{
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "include-all",
      "object-locator": {"schema-name": "%", "table-name": "%"},
      "rule-action": "include"
    }]
  }' \
  --region $REGION

echo "DMS setup complete. Start task manually from console or run:"
echo "aws dms start-replication-task --replication-task-arn <ARN> --start-replication-task-type start-replication --region $REGION"
