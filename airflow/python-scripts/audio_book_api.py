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

print('#############')

#spotify_client_id = os.getenv('SPOTIFY_CLIENT_ID')
#print(spotify_client_id)

# Set up authentication
CLIENT_ID =  os.getenv("SPOTIFY_CLIENT_ID") # Replace with your Spotify Client ID
CLIENT_SECRET = os.getenv("SPOTIFY_CLIENT_SECRET") 


client_credentials_manager = SpotifyClientCredentials(
    client_id=CLIENT_ID, client_secret=CLIENT_SECRET
)
sp = Spotify(client_credentials_manager=client_credentials_manager)

print('#### AUTHENTICATION SET UP  SUCCESSFUL ###')

### REQUEST RESPONSE TO GET AUDIO BOOKS ####
year = "2023"


offset = 0
all_audiobooks=list()
limit=50
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

# Now all_audiobooks contains all the audiobooks from the search
print(f"Total audiobooks fetched: {len(all_audiobooks)}")
print('#### REQUEST RESPONSE SUCCCESFUL ###')


## DEFINING CLASSES ###
class Author(BaseModel):
    name: str
    
class Copyrights(BaseModel):
    text: Optional[str] = None 
    type: Optional[str] = None 


class External_URL(BaseModel):
    spotify: str
    
class Images(BaseModel):
    url: Optional[str] = None 
    width: Optional[int] = None
    height: Optional[int] = None
    
class Narrators(BaseModel):
    name: Optional[str] = None     
    
    

class Audiobook(BaseModel):
    id: str
    description: Optional[str] = None
    explicit: Optional[bool] = None
    authors: List[Author]
    available_markets: Optional[List[str]] = None
    copyrights: Optional[List[Copyrights]]
    html_description: Optional[str] = None
    edition: Optional[str] = None
    external_urls: Optional[External_URL]
    href: Optional[str] = None
    images: List[Images]
    languages: Optional[List[str]] = None
    media_type: Optional[str] = None       
    name: Optional[str] = None
    narrators: Optional[List[Narrators]]
    publisher: Optional[str] = None
    type: Optional[str] = None
    uri: Optional[str] = None
    total_chapters: Optional[int] = None
    
class FlattenedAuthorResponse(BaseModel):
    id: str
    description: Optional[str] = None
    explicit: Optional[bool] = None
    author_name: str  # Flattened author name into a separate field  
    available_market: Optional[str] = None 
    copyright_text: Optional[str] = None
    copyright_type: Optional[str] = None
    html_description: Optional[str] = None
    edition: Optional[str] = None
    spotify_external_url: Optional[str] = None
    href: Optional[str] = None
    image_url: Optional[str] = None
    image_height: Optional[int] = None
    image_width: Optional[int] = None
    languages: Optional[str] = None
    media_type: Optional[str] = None
    book_name: Optional[str] = None
    narrator_name: Optional[str] = None
    publisher: Optional[str] = None
    book_type: Optional[str] = None
    book_uri: Optional[str] = None
    total_chapters: Optional[int] = None    
    
class AudiobooksResponse(BaseModel):
    audiobooks: List[Audiobook]
    
    def flatten(self) -> List[FlattenedAuthorResponse]:
        """Flatten the authors into separate rows."""
        flattened_data = []
        flattened_data = [
            FlattenedAuthorResponse(
                id=audiobook.id,
                author_name=author.name,
                available_market=market,
                copyright_text=copyright.text,
                copyright_type=copyright.type,
                description=audiobook.description,
                html_description=audiobook.html_description,
                explicit=audiobook.explicit,
                edition=audiobook.edition,
                spotify_external_url=external_url[1],
                href=audiobook.href,
                image_url=images.url,
                image_width=images.width,
                image_height=images.height,
                languages=languages,
                media_type=audiobook.media_type,
                book_name=audiobook.name,
                narrator_name=narrator_name.name,
                publisher=audiobook.publisher,
                book_type= audiobook.type,
                book_uri= audiobook.uri,
                total_chapters= audiobook.total_chapters
            )
        for audiobook in self.audiobooks
        for copyright in audiobook.copyrights
        for market in audiobook.available_markets
        for author in audiobook.authors
        for external_url in audiobook.external_urls
        for images in audiobook.images
        for languages in audiobook.languages
        for narrator_name in audiobook.narrators
        ]
        return flattened_data 
    
print('### CLASSES DEFINED SUCCESFULLY #####')


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
username = 'postgres'
password = 'postgres'
host = 'postgres_db'  # Use '127.0.0.1' or the hostname of the database
port = 5432
database = 'postgres'


# Create a connection string
engine = create_engine(f'postgresql+psycopg2://{username}:{password}@{host}:{port}/{database}')

# Push the DataFrame to PostgreSQL
table_name = 'spotify_audiobooks'  # Replace with your desired table name
try:
    df.to_sql(table_name, 
              engine, 
              if_exists='replace', 
              index=False,
              schema='spotify_api_stg')
    print(f"DataFrame successfully written to table '{table_name}'.")
except Exception as e:
    print(f"Error occurred: {e}")

print('#### PUSHED TO DATABASE #####')











