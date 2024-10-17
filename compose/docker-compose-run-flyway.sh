#!/usr/bin/env bash

export DATABASE_USER=$1
export DATABASE_PASSWORD=$2
export DATABASE_NAME=$3
export JDBC_URL=`echo "jdbc:postgresql://postgres:5432/$DATABASE_NAME?serverTimezone=UTC"`
export SCHEMA=public

until flyway -url=$JDBC_URL -schemas=$SCHEMA -user=$DATABASE_USER -password=$DATABASE_PASSWORD info > /dev/null
do
  echo "Waiting for MySQL …"
  sleep 3
done

echo "--------------------------------------------------------------------------"
echo "  SCHEMA: $DATABASE_NAME"
echo "--------------------------------------------------------------------------"

if find /flyway/sql -mindepth 1 -maxdepth 1 | read; then
  # dir not empty
  flyway -url=$JDBC_URL -schemas=$SCHEMA -user=$DATABASE_USER -password=$DATABASE_PASSWORD -driver=org.postgresql.Driver -table=flyway_schema_history -sqlMigrationPrefix=V -repeatableSqlMigrationPrefix=R -sqlMigrationSeparator=__ -sqlMigrationSuffixes=.sql -encoding=UTF-8 -validateOnMigrate=true -placeholderReplacement=true repair
  flyway -url=$JDBC_URL -schemas=$SCHEMA -user=$DATABASE_USER -password=$DATABASE_PASSWORD -driver=org.postgresql.Driver -table=flyway_schema_history -sqlMigrationPrefix=V -repeatableSqlMigrationPrefix=R -sqlMigrationSeparator=__ -sqlMigrationSuffixes=.sql -encoding=UTF-8 -validateOnMigrate=true -placeholderReplacement=true migrate
fi

flyway -url=$JDBC_URL -schemas=$SCHEMA -user=$DATABASE_USER -password=$DATABASE_PASSWORD -driver=org.postgresql.Driver -table=flyway_schema_history -sqlMigrationPrefix=V -repeatableSqlMigrationPrefix=R -sqlMigrationSeparator=__ -sqlMigrationSuffixes=.sql -encoding=UTF-8 -validateOnMigrate=true -placeholderReplacement=true info

