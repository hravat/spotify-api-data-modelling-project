-- Create a database for Airflow
CREATE DATABASE airflow_db;

-- Create a user for Airflow
CREATE USER airflow_user WITH PASSWORD 'airflow_password';

-- Grant privileges on the database to the user
GRANT ALL PRIVILEGES ON DATABASE airflow_db TO airflow_user;

-- Optional: Create a schema in the database for Airflow
\c airflow_db
CREATE SCHEMA IF NOT EXISTS airflow AUTHORIZATION airflow_user;

-- Grant usage and privileges on the schema
GRANT ALL PRIVILEGES ON SCHEMA public TO airflow_user;
