import os 
import sys
# Get the current directory
current_dir = os.path.dirname(__file__)

# Move up one level (parent directory)
parent_dir = os.path.abspath(os.path.join(current_dir, '..'))
pyspark_dir = parent_dir+'/pyspark-scripts'

sys.path.insert(0,pyspark_dir)
sys.path.insert(0,'/home/airflow/.local/lib/python3.12/site-packages/')
sys.path.insert(0,'/opt/airflow/lib/python3.12/site-packages/')


import pickle
import datetime
from spotipy import Spotify
from spotipy.oauth2 import SpotifyClientCredentials
import json
import pandas as pd 
import spotipy 
import time
from pydantic import BaseModel, Field ,TypeAdapter
from typing import List, Optional, Dict
from sqlalchemy import create_engine
from utils import spotify_authenticate,df_to_spotify_api_stg
from audio_book_flatten import flatten_audiobook
from pyspark.sql import SparkSession
from pyspark.sql.functions import udf
from pyspark.sql.types import StringType
from pyspark.sql import Row
from pyspark.sql.types import StructType, StructField, StringType , BinaryType

from audiobook_models import (
    Author,
    Copyrights,
    External_URL,
    Images,
    Narrators,
    Audiobook,
    FlattenedAuthorResponse,
    AudiobooksResponse
)

spark = SparkSession.builder.master("spark://spark-master:7077")\
        .appName("flatten_audiobook").getOrCreate()


spark.sparkContext.addPyFile("audiobook_models.py")
spark.sparkContext.addPyFile(pyspark_dir+"/audio_book_flatten.py")

flatten_udf = udf(flatten_audiobook, BinaryType())



def spotify_push_api_to_db():

    sp=spotify_authenticate()
    print('#### AUTHENTICATION SET UP  SUCCESSFUL ###')

    ### REQUEST RESPONSE TO GET AUDIO BOOKS ####
    #markets=['US','CA','AU','NZ']
    years= [x for x in range(2023,2024)]
    offset = 0
    all_audiobooks=list()
    limit=50
    
    for year in years:
        while offset < 1000:
            search_response = sp.search(
                q=f'year:{year}',
                type='audiobook',
                limit=limit,
                offset=offset
            )

            # Get the audiobooks from the search response
            audiobooks = search_response.get('audiobooks', {}).get('items', [])

            if not audiobooks:
                # If no more audiobooks are found, stop the loop
                break
            
            # Append the audiobooks to the list
            all_audiobooks.extend(audiobooks)
            
            # Increment the offset for the next request
            offset += limit

            # Sleep to prevent rate-limiting issues (if necessary)
            time.sleep(1)
        
           
        print(f"Number of audibooks in year {year} :- {len(all_audiobooks)}")
        

    
        #### DATA VALICATION AND CONVERSION TO DATAFRAME#####
        audiobook_list_adapter = TypeAdapter(List[Audiobook])
        validated_audiobook = audiobook_list_adapter.validate_python(all_audiobooks)
        df_audiobooks_dense = pd.DataFrame([audiobook.model_dump() for audiobook in validated_audiobook])

        response = AudiobooksResponse(audiobooks=validated_audiobook)
        flattened_data = response.flatten()
        df = pd.DataFrame([audiobook.model_dump() for audiobook in flattened_data])
        print(f'Length of flattened dataframe :- {len(df)}')
        print('Column names')
        print(df.dtypes)
        print('#### Data Succesfully Flattened ###########')

        #### Push to Postgres 
        #
        ## PostgreSQL connection details

        table_name = 'raw_spotify_audiobooks_api_stg' 
        df_to_spotify_api_stg(df,table_name)
        
        ### Adding Pyspark
        print('#### STARTING PYSPARK #####')
        pickled_audiobooks = [pickle.dumps(audiobook) for audiobook in validated_audiobook]
        print('### AUDIO BOOKS SUCCESFULLY PICKLED ####')
        
        unpickled_audiobooks = [pickle.loads(audiobook) for audiobook in pickled_audiobooks]
        #print(unpickled_audiobooks[0])
        print('### AUDIO BOOKS SUCCESFULLY UNPICKLED ####')
        
        
        
        rdd_pickled = spark.sparkContext.parallelize(pickled_audiobooks)
        print(f"Number of rows in RDD: {rdd_pickled.count()}")
        print('### RDD SUCCESFULLY CREATED ####')
        
        #schema = StructType([StructField("audiobook_pickle", BinaryType(), True)])
        rows = rdd_pickled.map(lambda x: Row(serialized_object=x))
        df_pickled = spark.createDataFrame(rows)
        print(f"Number of rows in df_pickled: {df_pickled.count()}")
        print('### DF SUCCESFULLY CREATED ####')

        df_flattened = df_pickled.withColumn("flattened_data", flatten_udf(df_pickled["serialized_object"]))
        df_flattened.collect()
        df_final_flattened=df_flattened.drop("serialized_object")
        print(f'NUmber of rows in flattened data :- {df_final_flattened.count()}')
        #df_final_flattened.limit(10).coalesce(1).write.csv('output_file_small.csv', header=True)
        print('### DF FLATTENED SUCCESFULLY CREATED ####') 
        
        print('#### INSPECTING THE DATAFRAME ############')
        pickled_rows = df_final_flattened.select("flattened_data").take(2)
        pickled_row = pickled_rows[1]
        pickled_data = pickled_row["flattened_data"]
        unpickled_data=pickle.loads(pickled_data)
        print(type(unpickled_data))
        print(unpickled_data)
        #pandas_df = pickle.loads(pickled_data)
        #print(pandas_df.head())
        
        ##Reset necessary vaiables
        offset=0 
        all_audiobooks=list()




spotify_push_api_to_db()

