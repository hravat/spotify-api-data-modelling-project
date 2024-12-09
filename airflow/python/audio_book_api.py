import datetime
from spotipy import Spotify
from spotipy.oauth2 import SpotifyClientCredentials
import json
import pandas as pd 
import spotipy 
import time
from pydantic import BaseModel, Field ,TypeAdapter
from typing import List, Optional, Dict
import os 
from sqlalchemy import create_engine
from utils import spotify_authenticate,df_to_spotify_api_stg

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

def spotify_push_api_to_db():

    sp=spotify_authenticate()
    print('#### AUTHENTICATION SET UP  SUCCESSFUL ###')

    ### REQUEST RESPONSE TO GET AUDIO BOOKS ####
    #markets=['US','CA','AU','NZ']
    years= [x for x in range(2002,2024)]
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
        
        ##Reset necessary vaiables
        offset=0 
        all_audiobooks=list()











