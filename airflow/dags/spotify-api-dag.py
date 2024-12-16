import sys
import os 
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'python-scripts')))
sys.path.insert(0,'/home/airflow/.local/lib/python3.12/site-packages/')



from airflow.decorators import task, dag
from datetime import datetime
from audio_book_api import spotify_push_api_to_db
from dim_market_stg import dim_market_stg_to_db
from airflow.models import Connection
from airflow import settings
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.providers.docker.operators.docker import DockerOperator

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
        extra='{"spark.executor.memory": "1g", "spark.executor.cores": "1"}',
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
    
    
    @task.python
    def push_audiobook_flat_api_stg():
        # Call the function from audio_book_api.py 
        # that pushes data to the database
        spotify_push_api_to_db()
    
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
    
    
#    @task.pyspark(conn_id="spark-docker")
#    def spark_task(spark: SparkSession, sc: SparkContext) -> pd.DataFrame:
#        df = spark.createDataFrame(
#        [
#            (1, "John Doe", 21),
#            (2, "Jane Doe", 22),
#            (3, "Joe Bloggs", 23),
#        ],
#        ["id", "name", "age"],
#        )
#        df.show()
        
        
    test_spark_task = SparkSubmitOperator(
        task_id='test_spark_task',
        conn_id="spark_docker",  # Connection to your Spark cluster (ensure this is set up)
        application="/opt/airflow/pyspark-scripts/test-script.py",  # Path to the PySpark script
        name="TestSparkJob",
        conf={"spark.executor.memory": "1g", "spark.executor.cores": "1"},
        verbose=True
    )
    
    # Define tasks
    spotify_api_task = push_audiobook_flat_api_stg()
    dim_market_stg_task = push_data_to_dim_market_stg()
    
    
    
    # Execute tasks in parallel
    spotify_api_task  # Runs in parallel
    #test_spark_task
    dim_market_stg_task  >> dim_market_stg_to_prod_task 
    [spotify_api_task, dim_market_stg_to_prod_task] >> fact_audio_book_task
   
    
# Instantiate the DAG
spotify_api_dag()