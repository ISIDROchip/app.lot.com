from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Optional
from app.services.combination_engine import LTFreeEngine

router = APIRouter()

class GenerationRequest(BaseModel):
    amount: int = 1000
    stats: Dict

class CombinationResponse(BaseModel):
    numbers: List[int]
    score: float

@router.post("/generate-batch", response_model=List[CombinationResponse])
async def generate_batch(request: GenerationRequest):
    """
    Endpoint para generar un lote masivo de combinaciones optimizadas.
    """
    try:
        results = LTFreeEngine.generate_batch(request.stats, request.amount)
        return results
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
