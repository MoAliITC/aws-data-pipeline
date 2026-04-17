#!/bin/bash
# ================================================================
# Network Fix — VPC Security Group + NACL for DMS → RDS connectivity
# Fixes DMS error: Host is unreachable (DMS-00002) on port 3306
# Region: eu-north-1
# ================================================================

REGION="eu-north-1"
SG_ID="sg-09110bf03c6b09146"
NACL_ID="acl-02823ff24df71a214"

# ── Fix 1: Allow all outbound traffic on Security Group ───────────
# DMS replication instance needs outbound to reach RDS on port 3306
aws ec2 authorize-security-group-egress \
  --group-id $SG_ID \
  --protocol -1 \
  --cidr 0.0.0.0/0 \
  --region $REGION

echo "Security Group outbound rule added."

# ── Fix 2: Add NACL inbound rule for port 3306 ────────────────────
# Network ACL was blocking port 3306 traffic — rule 99 added
aws ec2 create-network-acl-entry \
  --network-acl-id $NACL_ID \
  --rule-number 99 \
  --protocol tcp \
  --rule-action allow \
  --ingress \
  --cidr-block 0.0.0.0/0 \
  --port-range From=3306,To=3306 \
  --region $REGION

echo "NACL rule 99 (port 3306 inbound) added."
echo "Both fixes applied. Re-test DMS endpoint connection."
