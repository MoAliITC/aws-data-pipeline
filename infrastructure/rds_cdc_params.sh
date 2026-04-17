#!/bin/bash
# ================================================================
# RDS CDC Parameter Group Setup
# Enables MySQL binary logging for real-time CDC via DMS
# Region: eu-north-1
# ================================================================

REGION="eu-north-1"
PARAM_GROUP="mysql-cdc-params-bdclp"
RDS_INSTANCE="lab-mysql-bdclp"

# ── 1. Create custom parameter group ─────────────────────────────
aws rds create-db-parameter-group \
  --db-parameter-group-name $PARAM_GROUP \
  --db-parameter-group-family mysql8.0 \
  --description "CDC parameters for DMS binary log replication" \
  --region $REGION

# ── 2. Set CDC parameters ─────────────────────────────────────────
# binlog_format=ROW       — row-level change capture (required by DMS)
# binlog_checksum=NONE    — DMS cannot read checksummed binary logs
# binlog_row_image=Full   — capture complete before/after row state
aws rds modify-db-cluster-parameter-group \
  --db-cluster-parameter-group-name $PARAM_GROUP \
  --parameters \
    "ParameterName=binlog_format,ParameterValue=ROW,ApplyMethod=pending-reboot" \
    "ParameterName=binlog_checksum,ParameterValue=NONE,ApplyMethod=pending-reboot" \
    "ParameterName=binlog_row_image,ParameterValue=Full,ApplyMethod=pending-reboot" \
  --region $REGION

# ── 3. Apply to RDS instance ──────────────────────────────────────
aws rds modify-db-instance \
  --db-instance-identifier $RDS_INSTANCE \
  --db-parameter-group-name $PARAM_GROUP \
  --apply-immediately \
  --region $REGION

# ── 4. Reboot to activate ─────────────────────────────────────────
aws rds reboot-db-instance \
  --db-instance-identifier $RDS_INSTANCE \
  --region $REGION

echo "Parameter group $PARAM_GROUP applied to $RDS_INSTANCE"
echo "Waiting for reboot to complete..."
aws rds wait db-instance-available \
  --db-instance-identifier $RDS_INSTANCE \
  --region $REGION
echo "RDS reboot complete. CDC binary logging is now active."
