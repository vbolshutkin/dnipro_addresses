#!/usr/bin/bash

#setup

sudo apt-get install postgis osm2pgsql
sudo -u postgres psql -w -c "ALTER USER postgres WITH PASSWORD 'postgres'";
PGPASSWORD="postgres" psql -h localhost -U postgres -f init.sql

# install manually with a patch until https://github.com/Keyang/node-csvtojson/pull/177 is merged
# npm install csvtojson

# setup osmosis

wget -N http://bretth.dev.openstreetmap.org/osmosis-build/osmosis-latest.tgz
mkdir osmosis
mv osmosis-latest.tgz osmosis
cd osmosis
tar xvfz osmosis-latest.tgz
rm osmosis-latest.tgz
chmod a+x bin/osmosis
cd ..

#download and prepare input

wget http://rename.dp.ua/rename.json -N
node extract_rename_csv.js

wget https://s3.amazonaws.com/data.openaddresses.io/runs/195517/ua/12/city_of_dnipropetrovsk.zip -N
unzip -o city_of_dnipropetrovsk.zip -d openaddr
cp openaddr/ua/12/city_of_dnipropetrovsk.csv openaddr.csv

# mapzen metro extract (Dnipro nabe)
wget -N https://s3.amazonaws.com/mapzen.odes/ex_TYmP6kTFD2Lw5ucUHJYXUyZCKcT4S.osm.pbf

# import data to PGSQL
# password is applied implicitely
export PGPASSWORD="postgres"

osm2pgsql -l -H localhost  -U postgres --database dnipro_addresses ex_TYmP6kTFD2Lw5ucUHJYXUyZCKcT4S.osm.pbf
 
psql -h localhost -U postgres -d dnipro_addresses -f osmosis/script/pgsnapshot_schema_0.6.sql
osmosis/bin/osmosis --read-pbf ex_TYmP6kTFD2Lw5ucUHJYXUyZCKcT4S.osm.pbf  --write-pgsql host="localhost" database="dnipro_addresses" user="postgres" password="${PGPASSWORD}"


export PWD=`pwd`



psql -h localhost -U postgres -d dnipro_addresses -c "\copy rename from '${PWD}/rename.csv' delimiter ',' CSV HEADER;"
psql -h localhost -U postgres -d dnipro_addresses -c "\copy openaddr from '${PWD}/openaddr.csv' delimiter ',' CSV HEADER;"

psql -h localhost -U postgres -d dnipro_addresses -f main.sql


#экспорт СSV

psql -h localhost -U postgres -d dnipro_addresses -c "\copy openaddr_updated to '${PWD}/openaddr_upd.csv' DELIMITER ',' CSV HEADER;"
psql -h localhost -U postgres -d dnipro_addresses -c "\copy streets_final to '${PWD}/streets_final.csv' DELIMITER ',' CSV HEADER;"

# convert to final JSON

node convert.js
