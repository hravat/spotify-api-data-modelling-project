#!/bin/bash

# Load environment variables from .env file if it exists
if [[ -f ".env" ]]; then
    export $(cat .env | xargs)
fi

# Print the UID to verify it's loaded correctly
echo "Using AIRFLOW_UID in AIRFLOW WEBSERVER: ${AIRFLOW_UID}"


# Print the UID to verify it's loaded correctly
echo "Using SPOTIFY_CLIENT_ID in AIRFLOW WEBSERVER: ${SPOTIFY_CLIENT_ID}"

# Print the UID to verify it's loaded correctly
echo "Using SPOTIFY_CLIENT_SECRET in AIRFLOW WEBSERVER: ${SPOTIFY_CLIENT_SECRET}"

echo "Installing required Python libraries..."
pip install spotipy pydantic pandas sqlalchemy psycopg2-binary

# Start the Airflow webserver
echo "Starting Airflow webserver..."
exec airflow webserver