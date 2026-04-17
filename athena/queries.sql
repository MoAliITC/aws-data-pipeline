-- ================================================================
-- Athena Queries — silver_db.employees
-- Database: silver_db  |  Table: employees
-- Results bucket: s3://my-pipeline-scripts-bdclp/athena-results/
-- Region: eu-north-1
-- ================================================================

-- 1. View all employees
SELECT * FROM silver_db.employees
ORDER BY id;

-- 2. Average salary by department
SELECT
    department,
    COUNT(*)        AS headcount,
    AVG(salary)     AS avg_salary,
    MIN(salary)     AS min_salary,
    MAX(salary)     AS max_salary
FROM silver_db.employees
GROUP BY department
ORDER BY avg_salary DESC;

-- 3. Top 3 highest earners
SELECT id, name, department, salary
FROM silver_db.employees
ORDER BY salary DESC
LIMIT 3;

-- 4. Employees with salary above department average (window function)
SELECT
    name,
    department,
    salary,
    ROUND(AVG(salary) OVER (PARTITION BY department), 2) AS dept_avg_salary
FROM silver_db.employees
ORDER BY department, salary DESC;

-- 5. Salary banding with min/max context per row (window function)
SELECT
    name,
    department,
    salary,
    MIN(salary) OVER () AS company_min_salary,
    MAX(salary) OVER () AS company_max_salary,
    ROUND(salary * 100.0 / MAX(salary) OVER (), 1) AS pct_of_max
FROM silver_db.employees
ORDER BY salary DESC;

-- 6. Employees hired by year
SELECT
    YEAR(hire_date)  AS hire_year,
    COUNT(*)         AS employees_hired
FROM silver_db.employees
GROUP BY YEAR(hire_date)
ORDER BY hire_year;

-- 7. Department headcount and salary share
SELECT
    department,
    COUNT(*)                             AS headcount,
    SUM(salary)                          AS total_salary,
    ROUND(SUM(salary) * 100.0 /
          SUM(SUM(salary)) OVER (), 2)   AS salary_pct
FROM silver_db.employees
GROUP BY department
ORDER BY total_salary DESC;
