# Steps to install local postgres database
# NOTE: want to change this to a containerised Postgres instance that can easily be distributed with the code

# as karen user:

# Install Postgres 15

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get -y install postgresql-15

# Connect as postgres user to perform database setup

sudo su - postgres

# Edit postgresql.conf and pg_hba.conf to allow external connections

sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/15/main/postgresql.conf

cat <<EOF >> /etc/postgresql/15/main/pg_hba.conf

# Allow anyone to connect from anywhere!
host    all             all             all                     scram-sha-256
EOF

# Give the postgres user a password
psql -c "alter user postgres with password 'pwd1'"

# Create the table_model role
psql -c "create database table_model"
psql -c "create role table_model"

exit

# Add postgres user's password to karen's .pgpass file 

echo "127.0.0.1:5432:*:postgres:pwd1" >> ~/.pgpass

# Can now connect to postgres user/database using  psql postgres -h 127.0.0.1 -U postgres

# Setup the table_model schema

psql table_model -h 127.0.0.1 -U postgres -f tableModelDDL/01_create_schema.sql
psql table_model -h 127.0.0.1 -U postgres -f tableModelDDL/02_create_tables.sql
psql table_model -h 127.0.0.1 -U postgres -f tableModelDDL/03_create_constraints.sql
psql table_model -h 127.0.0.1 -U postgres -f tableModelDDL/04_create_views.sql
psql table_model -h 127.0.0.1 -U postgres -f tableModelDDL/05_create_temp_tables.sql
psql table_model -h 127.0.0.1 -U postgres -f tableModelDDL/06_create_procedures.sql
