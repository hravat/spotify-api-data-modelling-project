import sys
import os 
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'python-scripts')))


from airflow.decorators import task, dag
from datetime import datetime
from audio_book_api import spotify_push_api_to_db
from dim_market_stg import dim_market_stg_to_db
from airflow.models import Connection
from airflow import settings
from airflow.providers.postgres.operators.postgres import PostgresOperator







session = settings.Session()
if not session.query(Connection).filter_by(conn_id='spotify_api_prod').first():
    session.add(spotify_api_prod)
    session.commit()

@dag(
    dag_id="spotify_api_dag",
    start_date=datetime.today(),
    schedule_interval=None,
    catchup=False,
    template_searchpath="/opt/airflow/",
)
def spotify_api_dag():
    
    
    @task.python
    def push_audiobook_flat_api_stg():
        # Call the function from audio_book_api.py that pushes data to the database
        spotify_push_api_to_db()
    
    @task.python
    def push_data_to_dim_market_stg():
        # Call the function from audio_book_api.py that pushes data to the database
        dim_market_stg_to_db()
         
    dim_market_stg_to_prod_task=PostgresOperator(
            task_id='dim_market_stg_to_prod',
            postgres_conn_id='spotify_api_prod',  # Connection ID in Airflow
            sql='sql-scripts/DimMarket.sql',  # Path to the SQL file
        )
    
    fact_audio_book_task=PostgresOperator(
            task_id='fact_audio_book_task',
            postgres_conn_id='spotify_api_prod',  # Connection ID in Airflow
            sql='sql-scripts/FactAudioBook.sql',  # Path to the SQL file
        )
    
    # Define tasks
    spotify_api_task = push_audiobook_flat_api_stg()
    dim_market_stg_task = push_data_to_dim_market_stg()
  
    # Execute tasks in parallel
    spotify_api_task  # Runs in parallel
    dim_market_stg_task  >> dim_market_stg_to_prod_task 
    [spotify_api_task, dim_market_stg_to_prod_task] >> fact_audio_book_task
   
    
# Instantiate the DAG
spotify_api_dag()