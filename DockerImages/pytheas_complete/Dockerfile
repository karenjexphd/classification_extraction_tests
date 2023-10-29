# syntax=docker/dockerfile:1
FROM karenjexphd/table_extraction_tests:docker-pytheas-base
WORKDIR /app
COPY pytheas_apply_to_file.py pytheas_apply_to_file.py 
COPY pytheas_evaluate_tables.sh pytheas_evaluate_tables.sh
COPY pytheas_evaluate.py pytheas_evaluate.py
COPY pytheas_extract_tables.py pytheas_extract_tables.py
COPY pytheas_extract_tables.sh pytheas_extract_tables.sh
COPY pytheas_compare.py pytheas_compare.py
WORKDIR /app