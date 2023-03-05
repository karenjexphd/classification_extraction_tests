alias psql_phd_pg="psql postgres://postgres@p.qnplnpl3nbabto2zddq2phjlwi.db.postgresbridge.com:5432/postgres"
alias psql_phd_tm="psql postgres://postgres@p.qnplnpl3nbabto2zddq2phjlwi.db.postgresbridge.com:5432/table_model"

script_dir=/home/karen/workspaces/classification_extraction_tests/tableModelDDL

# The following line is commented out by default. 
# If you want to remove the entire table_model database, schema and user before re-creating, please uncomment it.

# psql_phd_pg -f $script_dir/00_cleanup.sql

psql_phd_pg -f $script_dir/01_create_user.sql

psql_phd_tm -f $script_dir/02_create_tables.sql
psql_phd_tm -f $script_dir/03_create_contstraints.sql


