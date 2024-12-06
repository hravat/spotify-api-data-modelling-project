import pandas as pd 
import time
import os 
from sqlalchemy import create_engine
from utils import spotify_authenticate,df_to_spotify_api_stg

def dim_market_stg_to_db():

    #### Push to Postgres 
    #
    ## PostgreSQL connection details
    script_dir = os.path.dirname(os.path.abspath(__file__))
    csv_path = os.path.join(script_dir, "../master-data/CountryCodes.csv")
    df = pd.read_csv(csv_path)
    table_name = 'DIM_MARKET_STG' 
    df_to_spotify_api_stg(df,table_name)









