import sys
import os 
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'python-scripts')))

from airflow.decorators import task, dag
from datetime import datetime
from audio_book_api import spotify_push_api_to_db


@dag(
    dag_id="spotify_api_dag",
    start_date=datetime.today(),
    schedule_interval=None,
    catchup=False,
)
def spotify_api_dag():
    @task.python
    def push_data_to_db():
        # Call the function from audio_book_api.py that pushes data to the database
        spotify_push_api_to_db()

    # Define the sequence of tasks in the DAG
    spotify_api_task =push_data_to_db()
    spotify_api_task
    
# Instantiate the DAG
spotify_api_dag()