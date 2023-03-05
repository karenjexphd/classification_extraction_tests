\c postgres
CREATE DATABASE table_model;
CREATE USER table_model;

\c table_model
CREATE SCHEMA table_model;
GRANT CREATE ON DATABASE table_model TO table_model;
GRANT CREATE ON SCHEMA table_model TO table_model;

