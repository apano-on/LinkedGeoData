#/bin/bash

echo "lgd-osm-sync environment:"
env | grep -i "osm\|db\|post"


# Check the database whether the data was loaded
statusKey="lgd-osm-sync:status"


psql "$DB_URL" -c "CREATE TABLE IF NOT EXISTS \"status\"(\"k\" text PRIMARY KEY NOT NULL, \"v\" text);"
#psql "$DB_URL" -c "DELETE FROM \"status\" WHERE \"k\" = '$statusKey';"

statusVal=`psql "$DB_URL" -tc "SELECT \"v\" FROM \"status\" WHERE "k"='$statusKey'"`

echo "Retrieved status value from $DB_URL for key [$statusKey] is '$statusVal'"

mkdir -p sync

# If the status is empty, then load the data
if [ -z "$statusVal" ]; then
  #PBF_DATA=http://downloads.linkedgeodata.org/debugging/monaco-170618.osm.pbf
  rm -f data.osm.pbf
  curl -L "$OSM_DATA_BASE_URL" --create-dirs -o data.osm.pbf

  timestamp=`osmconvert --out-timestamp "data.osm.pbf"`
  curl "https://osm.mazdermind.de/replicate-sequences/?$timestamp" > sync/state.txt


# TODO Fix lgd-createdb to include port
#  lgd-createdb -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -U "$DB_USER" -W "$DB_PASS" -f "data.osm.bpf" 
  lgd-createdb -h "$DB_HOST" -d "$DB_NAME" -U "$DB_USER" -W "$DB_PASS" -f "data.osm.pbf"

  psql "$DB_URL" -c "INSERT INTO \"status\"(\"k\", \"v\") VALUES('$statusKey', 'loaded')"
fi

# NOTE lgd-run-sync uses ./sync/configuration.txt by default

cat configuration.txt.dist | envsubst > sync/configuration.txt

# The sync script picks up the environment variables
/usr/share/linkedgeodata/lgd-run-sync.sh

