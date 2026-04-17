-- ================================================================
-- Redshift Setup — Data Warehouse
-- Cluster:  my-datawarehouse-bdclp  (dc2.large)
-- Database: dev
-- Region:   eu-north-1
-- IAM Role: arn:aws:iam::430006376054:role/dms-s3-target-role-bdclp
-- ================================================================

-- 1. Create employees table
CREATE TABLE IF NOT EXISTS public.employees (
    id         INTEGER,
    name       VARCHAR(255),
    department VARCHAR(255),
    salary     DECIMAL(10,2),
    hire_date  DATE
);

-- 2. Load data from S3 Silver (Parquet)
--    Run this after Glue ETL has written to Silver layer
COPY public.employees
FROM 's3://my-pipeline-silver-bdclp/transformed/employees/'
IAM_ROLE 'arn:aws:iam::430006376054:role/dms-s3-target-role-bdclp'
FORMAT AS PARQUET;

-- 3. Verify load
SELECT COUNT(*) AS total_rows FROM public.employees;
SELECT * FROM public.employees ORDER BY id;

-- 4. Analytical queries
SELECT department, COUNT(*) AS headcount, AVG(salary) AS avg_salary
FROM public.employees
GROUP BY department
ORDER BY avg_salary DESC;

-- 5. Truncate and reload (for full refresh)
TRUNCATE TABLE public.employees;

COPY public.employees
FROM 's3://my-pipeline-silver-bdclp/transformed/employees/'
IAM_ROLE 'arn:aws:iam::430006376054:role/dms-s3-target-role-bdclp'
FORMAT AS PARQUET;
