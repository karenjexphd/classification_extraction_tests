# need to parameterise this:
psql_phd_pg="psql postgres://postgres@p.qnplnpl3nbabto2zddq2phjlwi.db.postgresbridge.com:5432/postgres"

# need to parameterise this:
script_dir=/home/karen/workspaces/classification_extraction_tests/tableModelDDL

$psql_phd_pg -f $script_dir/00_drop_schema.sql

