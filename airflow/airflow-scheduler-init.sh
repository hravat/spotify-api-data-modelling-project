### THIS FILE IS NO LONGER IN USE AS ALL DEPENCNCIES ARE IN DOCKER FILE
### THEY ARE ADDED BY THE COMMAND docker-compose -f docker-compose.yml build 

#!/bin/bash

# Load environment variables from .env file if it exists
if [[ -f ".env" ]]; then
    export $(cat .env | xargs)
fi

# Get UID and GID from environment
USER_ID=${AIRFLOW_UID:-1000}
GROUP_ID=${AIRFLOW_GID:-0}

# Check if UID exists in /etc/passwd
#if ! getent passwd $USER_ID > /dev/null 2>&1; then
    # Add a new entry to /etc/passwd
echo "airflow:x:$USER_ID:$GROUP_ID:Airflow User:/home/airflow:/bin/bash" >> /etc/passwd
#fi


# Print the UID to verify it's loaded correctly
echo "Using AIRFLOW_UID in AIRFLOW WEBSERVER: ${AIRFLOW_UID}"


# Print the UID to verify it's loaded correctly
echo "Using SPOTIFY_CLIENT_ID in AIRFLOW WEBSERVER: ${SPOTIFY_CLIENT_ID}"

# Print the UID to verify it's loaded correctly
echo "Using SPOTIFY_CLIENT_SECRET in AIRFLOW WEBSERVER: ${SPOTIFY_CLIENT_SECRET}"

echo "Installing required Python libraries..."
#pip install 
#pip install spotipy 
#pip install pydantic 
#pip install pandas 
#pip install sqlalchemy 
#pip install psycopg2-binary 
#pip install apache-airflow apache-airflow-providers-apache-spark 
#pip install apache-airflow
#pip install pyspark

chmod +x /home/airflow/.local/lib/python3.12/site-packages/pyspark/bin/spark-submit
chmod +x /home/airflow/.local/lib/python3.12/site-packages/bin/spark-submit
chmod +x /home/airflow/tmp/pyspark/bin/spark-submit

# Start the Airflow webserver
echo "Starting Airflow scheduler..."
exec airflow scheduler