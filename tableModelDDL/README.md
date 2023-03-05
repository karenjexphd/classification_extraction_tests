Scripts required to create database tables to represent the table object model
and to allow storage and processing of the ground truth and extracted tables for each method

Run the setup_table_model.sh script to run each of the sql scripts in turn.

Note, there is a 00_cleanup.sql script that is NOT run by default as this drops the associated database, schema and user before creating the objects.

In order to start from scratch, uncomment the line containing this script before running setup_table_model.sh
