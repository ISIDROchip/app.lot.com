from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from app.routers import dreams, engine

app = FastAPI(title="Smart Lottery AI Service", version="1.0.0")

app.include_router(dreams.router, prefix="/dreams", tags=["Dreams"])
app.include_router(engine.router, prefix="/engine", tags=["Engine"])

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(status_code=500, content={"detail": f"Error interno del servidor: {str(exc)}"})

@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
