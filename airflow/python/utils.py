from spotipy import Spotify
from spotipy.oauth2 import SpotifyClientCredentials
import os
from sqlalchemy import create_engine

def spotify_authenticate():
    
    
    print('######### INSIDE UTILS SPOTIFY_AUTHENTICATE #######')
    CLIENT_ID =  os.getenv("SPOTIFY_CLIENT_ID") # Replace with your Spotify Client ID
    CLIENT_SECRET = os.getenv("SPOTIFY_CLIENT_SECRET") 


    client_credentials_manager = SpotifyClientCredentials(
        client_id=CLIENT_ID, client_secret=CLIENT_SECRET
    )
    sp = Spotify(client_credentials_manager=client_credentials_manager)    
    
    return sp
    
def df_to_spotify_api_stg(df,table_name):
    
    print('######### INSIDE UTILS PUSH TO STG API #######')
    
    username = os.getenv("SPOTIFY_DB_USER")
    password = os.getenv("SPOTIFY_DB_PASSWORD")
    print(f'########## SPOTIFY FB USER NAME {username} #######################')
    print(f'########## SPOTIFY FB USER PASSWORD {password} #######################')


    host = 'postgres_db'  # Use '127.0.0.1' or the hostname of the database
    port = 5432
    database = 'postgres'


    # Create a connection string
    engine = create_engine(f'postgresql+psycopg2://{username}:{password}@{host}:{port}/{database}')

    # Push the DataFrame to PostgreSQL
    #table_name = 'raw_spotify_audiobooks_api_stg'  # Replace with your desired table name
    
    try:
        df.to_sql(table_name, 
                  engine, 
                  if_exists='append', 
                  index=False,
                  schema='spotify_api_stg')
        print(f"DataFrame successfully written to table '{table_name}'.")
    except Exception as e:
        print(f"Error occurred: {e}")

    print('#### PUSHED TO DATABASE #####')

    
    