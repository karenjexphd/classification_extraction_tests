import sys 
import psycopg2

# Goals: 
#   Compare each ground truth table with the associated TabbyXL output table

# 1. Create connection to table_model database with search_path set to table_model
#    (Need to parameterise this)

tm_conn = psycopg2.connect(
    host="p.qnplnpl3nbabto2zddq2phjlwi.db.postgresbridge.com",
    database="table_model",
    user="postgres")

cur = tm_conn.cursor()
cur.execute('SET SEARCH_PATH=table_model')

# select information from tables_to_compare view

select_stmt="SELECT * FROM tables_to_compare"
cur.execute(select_stmt)

tables_to_compare=cur.fetchall()

print(tables_to_compare)

cur.close()
