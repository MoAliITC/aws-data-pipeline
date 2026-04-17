"""
Lambda Function: schema-validator-bdclp
----------------------------------------
Validates the Silver layer schema against the expected column structure
by querying the Glue Data Catalog. Called as an S3 event trigger — fires
every time DMS writes a new CDC Parquet file to S3 Bronze, then triggers
the Glue ETL job for incremental processing.

Trigger:   S3 Event — my-pipeline-bronze-bdclp (prefix: raw/labdb/, suffix: .parquet)
Runtime:   Python 3.12
Region:    eu-north-1
IAM Role:  dms-s3-target-role-bdclp

Behaviour:
  - Skips files not under labdb/ prefix
  - Validates silver_db.employees schema matches EXPECTED
  - On schema PASSED: triggers bronze-to-silver-etl-bdclp Glue job
  - On schema FAILED: returns 400 with detailed error list
"""

import boto3
import json

glue = boto3.client('glue', region_name='eu-north-1')

# ── CONFIG ────────────────────────────────────────────────────────
DATABASE   = 'silver_db'
TABLE      = 'employees'
GLUE_JOB   = 'bronze-to-silver-etl-bdclp'

EXPECTED = {
    'id':         'int',
    'name':       'string',
    'department': 'string',
    'salary':     'decimal',
    'hire_date':  'date'
}

# ── HANDLER ───────────────────────────────────────────────────────
def lambda_handler(event, context):
    # Parse S3 event
    bucket = event['Records'][0]['s3']['bucket']['name']
    key    = event['Records'][0]['s3']['object']['key']

    print(f"Triggered by: s3://{bucket}/{key}")

    # Only process labdb CDC files
    if 'labdb' not in key:
        print("Skipping — not a labdb file")
        return {'statusCode': 200, 'body': 'Skipped'}

    # ── SCHEMA VALIDATION ─────────────────────────────────────────
    try:
        response = glue.get_table(DatabaseName=DATABASE, Name=TABLE)
        columns  = response['Table']['StorageDescriptor']['Columns']
        actual   = {col['Name']: col['Type'] for col in columns}
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'status': 'ERROR', 'message': str(e)})}

    errors = []

    if len(actual) != len(EXPECTED):
        errors.append(f"Column count mismatch: expected {len(EXPECTED)}, got {len(actual)}")

    for col_name, expected_type in EXPECTED.items():
        if col_name not in actual:
            errors.append(f"Missing column: {col_name}")
        elif expected_type not in actual[col_name]:
            errors.append(f"Type mismatch on '{col_name}': expected '{expected_type}', got '{actual[col_name]}'")

    if errors:
        print(f"Schema FAILED: {errors}")
        return {
            'statusCode': 400,
            'body': json.dumps({'status': 'FAILED', 'errors': errors})
        }

    # ── TRIGGER GLUE ETL ──────────────────────────────────────────
    print("Schema PASSED — triggering Glue ETL job")
    run = glue.start_job_run(
        JobName=GLUE_JOB,
        Arguments={'--job-bookmark-option': 'job-bookmark-enable'}
    )

    return {
        'statusCode': 200,
        'body': json.dumps({
            'status':   'PASSED',
            'columns':  actual,
            'JobRunId': run['JobRunId']
        })
    }
