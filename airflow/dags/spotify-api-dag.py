import sys
import os 

current_dir = os.path.dirname(__file__)

# Move up one level (parent directory)
parent_dir = os.path.abspath(os.path.join(current_dir, '..'))
pyspark_dir = parent_dir+'/pyspark-scripts'


# Move up one level (parent directory)
python_dir = os.path.abspath(os.path.join(current_dir, '..'))
python_dir = parent_dir+'/python-scripts'

sys.path.insert(0,pyspark_dir)
sys.path.insert(0,python_dir)
sys.path.insert(0,'/home/airflow/.local/lib/python3.12/site-packages/')
sys.path.insert(0,'/opt/airflow/lib/python3.12/site-packages/')


from airflow.decorators import task, dag
from datetime import datetime
from audio_book_api import spotify_push_api_to_db
from audio_book_api_pyspark import spotify_push_api_to_db_pyspark
from dim_market_stg import dim_market_stg_to_db
from airflow.models import Connection
from airflow import settings
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.providers.docker.operators.docker import DockerOperator
from airflow.utils.trigger_rule import TriggerRule
from airflow.operators.dummy import DummyOperator
from airflow.exceptions import AirflowSkipException


spotify_api_prod = Connection(
        conn_id='spotify_api_prod',
        conn_type='postgres',
        host='postgres_db',  # Replace with your PostgreSQL host
        schema='postgres',  # Replace with your schema
        login= os.getenv('SPOTIFY_DB_USER'),  # Replace with your username
        password=os.getenv('SPOTIFY_DB_PASSWORD'),  # Replace with your password
        port=5432  # Default Postgres port, adjust if necessary
    )


spark_docker = Connection(
        conn_id="spark_docker",  # Ensure this matches the conn_id in your DAG
        conn_type="spark",       # Specify the connection type as "spark"
        host="spark://spark-master",  # Your Spark master URL
        ##extra='{"spark.executor.memory": "2g", "spark.executor.cores": "4"}',
        port='7077' # Optional: extra configuration if needed
    )

session = settings.Session()

if not session.query(Connection).filter_by(conn_id='spotify_api_prod').first():
    session.add(spotify_api_prod)
    session.commit()
    
if not session.query(Connection).filter_by(conn_id='spark_docker').first():
    session.add(spark_docker)
    session.commit()    

@dag(
    dag_id="spotify_api_dag",
    start_date=datetime.today(),
    schedule_interval=None,
    catchup=False,
    template_searchpath="/opt/airflow/",
)
def spotify_api_dag():
    
    
    
    @task
    def skip_task(condition: bool):
        if not condition:
            raise AirflowSkipException("Condition not met, skipping this task.")
        print("Task executed because condition is True")

    
    @task.python
    def push_audiobook_flat_api_stg():
        # Call the function from audio_book_api.py 
        # that pushes data to the database
        spotify_push_api_to_db()
    
    @task.python
    def push_audiobook_flat_api_stg_pyspark():
        # Call the function from audio_book_api.py 
        # that pushes data to the database
        spotify_push_api_to_db_pyspark()

    @task.python
    def push_data_to_dim_market_stg():
        # Call the function from dim_market_stg_to_db
        # that pushes market data to the database
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
    
            
    test_spark_task = SparkSubmitOperator(
        task_id='test_spark_task',
        conn_id="spark_docker",  # Connection to your Spark cluster (ensure this is set up)
        application="/opt/airflow/pyspark-scripts/test-script.py",  # Path to the PySpark script
        name="TestSparkJob",
        conf={"spark.executor.memory": "1g", "spark.executor.cores": "1"},
        verbose=True,
        trigger_rule=TriggerRule.ALL_SUCCESS  
    )
    
    # Define tasks
    spotify_api_task = push_audiobook_flat_api_stg()
    spotify_api_pyspark_task = push_audiobook_flat_api_stg_pyspark()
    dim_market_stg_task = push_data_to_dim_market_stg()
    skip_task=skip_task(False)
    
    
    # Execute tasks in parallel
    dim_market_stg_task  >> dim_market_stg_to_prod_task 
    [spotify_api_pyspark_task, dim_market_stg_to_prod_task] >> fact_audio_book_task
    
    
    #Dummy Tasks for Testing
    skip_task >> [test_spark_task,spotify_api_task]
    
    
# Instantiate the DAG
spotify_api_dag()