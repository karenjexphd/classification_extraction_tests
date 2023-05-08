# need to parameterise these:
psql_phd_pg="psql postgres://postgres@p.qnplnpl3nbabto2zddq2phjlwi.db.postgresbridge.com:5432/postgres"
psql_phd_tm="psql postgres://postgres@p.qnplnpl3nbabto2zddq2phjlwi.db.postgresbridge.com:5432/table_model"

# need to parameterise this:
script_dir=/home/karen/workspaces/classification_extraction_tests/tableModelDDL

$psql_phd_pg -f $script_dir/01_create_schema.sql

$psql_phd_tm -f $script_dir/02_create_tables.sql
$psql_phd_tm -f $script_dir/03_create_constraints.sql
$psql_phd_tm -f $script_dir/04_create_views.sql
$psql_phd_tm -f $script_dir/05_create_temp_tables.sql
$psql_phd_tm -f $script_dir/06_create_procedures.sql  

