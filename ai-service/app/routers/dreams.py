from fastapi import APIRouter, Header, HTTPException
from app.config import API_KEY
from app.models.schemas import DreamRequest, DreamResponse
from app.services.dream_analyzer import analyze

router = APIRouter()


@router.post("/interpret", response_model=DreamResponse)
async def interpret_dream(
    request: DreamRequest,
    x_api_key: str = Header(..., alias="X-API-Key"),
) -> DreamResponse:
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="API Key inválida")
    return analyze(request.text)
