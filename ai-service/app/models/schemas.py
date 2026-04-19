from pydantic import BaseModel, Field
from typing import List


class DreamRequest(BaseModel):
    text: str = Field(..., min_length=10, max_length=2000)


class DreamResponse(BaseModel):
    numbers: List[int] = Field(..., min_length=3, max_length=6)
    keywords: List[str]
