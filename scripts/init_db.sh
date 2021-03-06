#!/usr/bin/env bash
set -x
set -eo pipefail

# check if psql is installed if not throw error
if ! [ -x "$(command -v psql)" ]; then
    echo >&2 "Error: psql is not installed."
    exit 1
fi

# check if sqlx is installed, if not throw error
if ! [ -x "$(command -v sqlx)" ]; then
    echo >&2 "Error: sqlx is not installed"
    echo >&2 "Use:"
    echo >&2 "     cargo install --version=0.5.7 sqlx-cli --no-default-features --features postgres"
    echo >&2 "to install it"
fi


# set up environment variables for Postgres and our Docker container
DB_USER=${POSTGRES_USER:=postgres}

DB_PASSWORD="${POSTGRES_PASSWORD:=password}"

DB_NAME="${POSTGRES_DB:=newsletter}"

DB_PORT="${POSTGRES_PORT:=5432}"

if [[ -z "${SKIP_DOCKER}" ]]
then
    docker run \
        -e POSTGRES_USER=${DB_USER}         \
        -e POSTGRES_PASSWORD=${DB_PASSWORD} \
        -e POSTGRES_DB=${DB_NAME}           \
        -p "${DB_PORT}":5432                \
        -d postgres                         \
        postgres -N 1000
fi

# keep pinging postgres until it's ready to accept new commands
export PGPASSWORD="${DB_PASSWORD}"

>&2 echo "docker successfully started."

sleep 1
docker ps

until psql -h "localhost" -U "${DB_USER}" -p "${DB_PORT}" -d "postgres" -c '\q'; do
    >&2 echo "Postgres is still unavailable - Sleeping"
    sleep 1
done

>&2 echo "Postgres is up and running on port ${DB_PORT}!"

# Create the database using sqlx
export DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}
sqlx database create

sqlx migrate run
>&2 echo "Postgres has been migrated successfully"
