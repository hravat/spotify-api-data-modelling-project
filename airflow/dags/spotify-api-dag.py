from airflow.decorators import task, dag
from datetime import datetime



@dag(
    dag_id="spotify_api_dag",
    start_date=datetime.today(),
    schedule_interval=None,
    catchup=False,
)
def spotify_api_dag():
    # Define the Bash task
    @task.bash
    def get_spotify_api():
        return """
        python /opt/airflow/python-scripts/audio_book_api.py
        """

    # Execute the task
    spotify_api_task = get_spotify_api()
    spotify_api_task
    
# Instantiate the DAG
spotify_api_dag()