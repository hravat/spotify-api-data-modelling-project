from pyspark.sql.functions import udf
from pyspark.sql.types import ArrayType, StructType, StructField, StringType, IntegerType

import os
import sys
import pickle
import pandas as pd

# Move up one level (parent directory)
current_dir = os.path.dirname(__file__)
parent_dir = os.path.abspath(os.path.join(current_dir, '..'))
python_dir = parent_dir+'/python-scripts'
sys.path.insert(0,python_dir)

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


# Flattening logic
def flatten_audiobook(audiobook_pickled):
    """Flatten the authors into separate rows."""
    print('### In Flattened audiobook####')
    audiobook=pickle.loads(audiobook_pickled)
    
    flattened_data = [
        {
            "id": audiobook.id,
            "author_name": author.name,
            "available_market": market,
            "copyright_text": copyright.text,
            "copyright_type": copyright.type,
            "description": audiobook.description,
            "html_description": audiobook.html_description,
            "explicit": audiobook.explicit,
            "edition": audiobook.edition,
            "spotify_external_url": external_url[1],
            "href": audiobook.href,
            "image_url": images.url,
            "image_width": images.width,
            "image_height": images.height,
            "languages": languages,
            "media_type": audiobook.media_type,
            "book_name": audiobook.name,
            "narrator_name": narrator_name.name,
            "publisher": audiobook.publisher,
            "book_type": audiobook.type,
            "book_uri": audiobook.uri,
            "total_chapters": audiobook.total_chapters
        }
        for copyright in audiobook.copyrights
        for market in audiobook.available_markets
        for author in audiobook.authors
        for external_url in audiobook.external_urls
        for images in audiobook.images
        for languages in audiobook.languages
        for narrator_name in audiobook.narrators
    ]
    
    df = pd.DataFrame(flattened_data)
    
    return pickle.dumps(df)



# Step 2: Define the schema of the flattened data
flattened_schema = ArrayType(
    StructType([
        StructField("id", IntegerType(), True),
        StructField("author_name", StringType(), True),
        StructField("available_market", StringType(), True),
        StructField("copyright_text", StringType(), True),
        StructField("copyright_type", StringType(), True),
        StructField("description", StringType(), True),
        StructField("html_description", StringType(), True),
        StructField("explicit", StringType(), True),
        StructField("edition", StringType(), True),
        StructField("spotify_external_url", StringType(), True),
        StructField("href", StringType(), True),
        StructField("image_url", StringType(), True),
        StructField("image_width", IntegerType(), True),
        StructField("image_height", IntegerType(), True),
        StructField("languages", StringType(), True),
        StructField("media_type", StringType(), True),
        StructField("book_name", StringType(), True),
        StructField("narrator_name", StringType(), True),
        StructField("publisher", StringType(), True),
        StructField("book_type", StringType(), True),
        StructField("book_uri", StringType(), True),
        StructField("total_chapters", IntegerType(), True),
    ])
)

