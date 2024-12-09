from pydantic import BaseModel, Field ,TypeAdapter
from typing import List, Optional, Dict

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
    author_name: str  # DIM_PERSON_NAME   
    available_market: Optional[str] = None 
    copyright_text: Optional[str] = None # DIM_COPYRIGHT
    copyright_type: Optional[str] = None # DIM_COPYRIGHT
    html_description: Optional[str] = None
    edition: Optional[str] = None
    spotify_external_url: Optional[str] = None
    href: Optional[str] = None
    image_url: Optional[str] = None   #DIM_IMAGE
    image_height: Optional[int] = None #DIM_IMAGE
    image_width: Optional[int] = None #DIM_IMAGE
    languages: Optional[str] = None #DIM_LANGUAGE
    media_type: Optional[str] = None 
    book_name: Optional[str] = None 
    narrator_name: Optional[str] = None # DIM_PERSON_NAME
    publisher: Optional[str] = None # DIM_PUBLISHER
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
