#Copyright (c) 2015-2016, EMC Corporation
#
#Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.



#!/bin/bash

__setup_database() {
  if [ -z "${DB_HOST}" ]; then

    DB_HOST="localhost"

    #Grant rights
    usermod -G wheel postgres

    if [ -z "${DB_USER}" ]; then
       DB_USER="metalnx"
    fi

    if [ -z "${DB_NAME}" ]; then
       DB_NAME="metalnx"
    fi

    PG_CONFDIR="/var/lib/pgsql/data"

    echo "Setting up local database..."

    if [ -z "${DB_PASS}" ]; then
      echo ""
      echo "WARNING: "
      echo "No password specified for \"${DB_USER}\". Generating one"
      echo ""
      DB_PASS=$(pwgen -c -n -1 12)
      echo "Password for \"${DB_USER}\" created as: \"${DB_PASS}\""
    fi

    echo "Creating user \"${DB_USER}\"..."
    echo "CREATE ROLE ${DB_USER} with CREATEROLE login superuser PASSWORD '${DB_PASS}';" |
      sudo -u postgres -H postgres --single \
       -c config_file=${PG_CONFDIR}/postgresql.conf -D ${PG_CONFDIR}
  
    if [ -n "${DB_NAME}" ]; then
      echo "Creating database \"${DB_NAME}\"..."
      echo "CREATE DATABASE ${DB_NAME};" | \
        sudo -u postgres -H postgres --single \
         -c config_file=${PG_CONFDIR}/postgresql.conf -D ${PG_CONFDIR}
    fi

    if [ -n "${DB_USER}" ]; then
      echo "Granting access to database \"${DB_NAME}\" for user \"${DB_USER}\"..."
      echo "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} to ${DB_USER};" |
        sudo -u postgres -H postgres --single \
        -c config_file=${PG_CONFDIR}/postgresql.conf -D ${PG_CONFDIR}
    fi

    echo "Database $DB_NAME is available !"

  else
    # Postgres is not on this machine, so wait for the database to become available...
    # Check postgres at startup
    until PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER $DB_NAME -c "\d" 1> /dev/null 2> /dev/null;
    do
      >&2 echo "Postgres is unavailable - sleeping"
      sleep 1
    done

    echo "Database $DB_NAME is available at host: $DB_HOST !"
  fi

  env_file=/usr/share/tomcat/webapps/emc-metalnx-web/WEB-INF/classes/database.properties

  sed -ir "s|db.url=.*$|db.url=jdbc:postgresql://$DB_HOST:$DB_PORT/$DB_NAME|" $env_file
  sed -ir "s|db.username=.*$|db.username=$DB_USER|" $env_file
  sed -ir "s|db.password=.*$|db.password=$DB_PASS|" $env_file

  cat $env_file
}

__setup_irods() {
  env_file=/usr/share/tomcat/webapps/emc-metalnx-web/WEB-INF/classes/irods.environment.properties

  sed -ir "s|irods.host=.*$|irods.host=$IRODS_HOST|" $env_file
  sed -ir "s|irods.port=.*$|irods.port=$IRODS_PORT|" $env_file
  sed -ir "s|irods.zoneName=.*$|irods.zoneName=$IRODS_ZONE|" $env_file
  sed -ir "s|irods.auth.scheme.*$|irods.auth.scheme=$IRODS_AUTH|" $env_file
  sed -ir "s|jobs.irods.username=.*$|jobs.irods.username=$IRODS_USER|" $env_file
  sed -ir "s|jobs.irods.password=.*$|jobs.irods.password=$IRODS_PASS|" $env_file
  sed -ir "s|jobs.irods.auth.scheme=.*$|jobs.irods.auth.scheme=$IRODS_AUTH|" $env_file

#cat >> $env_file <<EOF
# sets jargon ssl negotiation policy for the client. Leaving to DONT_CARE defers to the server, and is recommended
# NO_NEGOTIATION, CS_NEG_REFUSE, CS_NEG_REQUIRE, CS_NEG_DONT_CARE
#ssl.negotiation.policy=CS_NEG_REQUIRE
#EOF

  cat $env_file
}

__run_supervisor() {
  supervisord -n
}

keytool -import -alias irodscertificate -keystore /etc/ssl/irodskeystore -storepass changeit -noprompt -file /etc/ssl/irods.crt
#keytool -import -trustcacerts -keystore /etc/pki/java/cacerts -storepass changeit -noprompt -alias irodscertificate -file /etc/ssl/irods.crt
keytool -import -trustcacerts -keystore /etc/ssl/certs/java/cacerts -storepass changeit -noprompt -alias irodscertificate -file /etc/ssl/irods.crt

# Call all functions
__setup_database
__setup_irods
__run_supervisor
