"""
Glue ETL Job: bronze-to-silver-etl-bdclp
-----------------------------------------
Reads employees table from Bronze S3 layer (Glue Data Catalog: bronze_db.employees),
applies schema transformation, and writes clean Parquet to Silver S3 layer.
Job Bookmarks enabled — only new incremental files are processed on each run.

Pipeline:  S3 Bronze → Glue ETL → S3 Silver
Region:    eu-north-1
Account:   430006376054
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# ── READ FROM BRONZE (Glue Data Catalog) ──────────────────────────
datasource = glueContext.create_dynamic_frame.from_catalog(
    database="bronze_db",
    table_name="employees",
    transformation_ctx="datasource"
)

# ── TRANSFORM — Apply Schema ───────────────────────────────────────
# Keeps: id (int), name (string), department (string), salary (decimal), hire_date (date)
transformed = ApplyMapping.apply(
    frame=datasource,
    mappings=[
        ("id",         "int",     "id",         "int"),
        ("name",       "string",  "name",       "string"),
        ("department", "string",  "department", "string"),
        ("salary",     "decimal", "salary",     "decimal"),
        ("hire_date",  "date",    "hire_date",  "date"),
    ],
    transformation_ctx="transformed"
)

# ── WRITE TO SILVER (S3 Parquet + Snappy) ─────────────────────────
glueContext.write_dynamic_frame.from_options(
    frame=transformed,
    connection_type="s3",
    connection_options={
        "path": "s3://my-pipeline-silver-bdclp/transformed/employees/",
        "partitionKeys": []
    },
    format="parquet",
    format_options={"compression": "snappy"},
    transformation_ctx="silver_output"
)

job.commit()
