# AWS End-to-End Data Pipeline

**Region:** eu-north-1

## Architecture

```
MySQL RDS  →  AWS DMS (CDC)  →  S3 Bronze  →  Lambda  →  Glue ETL  →  S3 Silver
                                                                          ↓
                                                          Athena   Redshift   QuickSight
                                                                    ↑
                                                          CodePipeline CI/CD (auto-deploy)
```

## Pipeline Stages

| # | Step | Service | Resource |
|---|------|---------|----------|
| 1 | S3 Storage Layers | Amazon S3 | my-pipeline-bronze/silver/scripts-bdclp |
| 2 | IAM Role | AWS IAM | dms-s3-target-role-bdclp |
| 3 | DMS Replication Instance | AWS DMS | my-replication-instance-bdclp |
| 4 | DMS Endpoints | AWS DMS | mysql-source-bdclp, s3-target-bronze-bdclp |
| 5 | Network Fix | VPC / SG / NACL | sg-09110bf03c6b09146 |
| 6 | Binary Logging (CDC) | Amazon RDS | mysql-cdc-params-bdclp |
| 7 | Migration Task | AWS DMS | db-to-s3-task-bdclp (Full Load + CDC) |
| 8 | S3 Bronze Verified | Amazon S3 | raw/labdb/employees/ — 10 records |
| 9 | Bronze Crawler | AWS Glue | bronze-crawler-bdclp → bronze_db.employees |
| 10 | Glue ETL Job | AWS Glue ETL | bronze-to-silver-etl-bdclp |
| 11 | Silver Crawler | AWS Glue | silver-crawler-bdclp → silver_db.employees |
| 12 | Athena Queries | Amazon Athena | silver_db.employees |
| 13 | Redshift Load | Amazon Redshift | my-datawarehouse-bdclp — COPY from S3 |
| 14 | QuickSight Dashboard | Amazon QuickSight | Employee Analytics BDCLP |
| 15 | Lambda Schema Validator | AWS Lambda | schema-validator-bdclp |
| 16 | CDC Automation | S3 Trigger + Lambda + Glue | Real-time end-to-end |
| 17 | CI/CD Pipeline | CodePipeline + CodeBuild | data-pipeline-cicd-bdclp |

## Repository Structure

```
data-pipeline-bdclp/
├── buildspec.yml                     # CodeBuild build specification
├── glue_etl/
│   └── bronze_to_silver.py           # Glue ETL: Bronze → Silver transformation
├── lambda/
│   └── schema_validator.py           # Lambda: Schema validation + CDC trigger
├── athena/
│   └── queries.sql                   # Athena analytical queries
├── redshift/
│   └── setup.sql                     # Redshift table creation + COPY command
├── quicksight/
│   └── employees_manifest.json       # QuickSight S3 manifest file
├── infrastructure/
│   ├── iam_setup.sh                  # IAM role + policies creation
│   ├── s3_setup.sh                   # S3 buckets creation
│   ├── dms_setup.sh                  # DMS instance, endpoints, task
│   ├── network_fix.sh                # VPC Security Group + NACL fixes
│   ├── rds_cdc_params.sh             # RDS binary logging parameter group
│   ├── glue_setup.sh                 # Glue crawlers + ETL job
│   ├── lambda_setup.sh               # Lambda deploy + S3 trigger
│   └── cicd_setup.sh                 # CodePipeline + CodeBuild setup
└── README.md
```

## Real-Time CDC Flow

Every MySQL change automatically propagates to Silver in real-time:

1. `INSERT/UPDATE/DELETE` on MySQL RDS
2. DMS reads binary log → writes new Parquet to **S3 Bronze** (`raw/labdb/`)
3. **S3 Event** fires Lambda (`schema-validator-bdclp`)
4. Lambda validates schema against Glue Data Catalog
5. Lambda triggers **Glue ETL** job with Job Bookmark enabled
6. Glue processes only new incremental records → writes to **S3 Silver**

## CI/CD Flow

Every code push auto-deploys to production:

1. Developer pushes to **CodeCommit** (`data-pipeline-bdclp`, `main` branch)
2. **CodePipeline** Source stage detects change
3. **CodeBuild** runs `buildspec.yml`:
   - Copies `glue_etl/bronze_to_silver.py` → S3 scripts bucket
   - Calls `aws glue update-job` → live Glue job points to new script
4. Deployment complete — no manual steps

## Key Resources

| Resource | Value |
|----------|-------|
| Bronze S3 | `s3://my-pipeline-bronze-bdclp/raw/labdb/employees/` |
| Silver S3 | `s3://my-pipeline-silver-bdclp/transformed/employees/` |
| Glue Catalog | `bronze_db.employees`, `silver_db.employees` |
| Redshift | `my-datawarehouse-bdclp` → `dev.public.employees` |
| Lambda | `schema-validator-bdclp` |
| Pipeline | `data-pipeline-cicd-bdclp` |
| IAM Role | `arn:aws:iam::430006376054:role/dms-s3-target-role-bdclp` |
