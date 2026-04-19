from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from app.routers import dreams

app = FastAPI(title="Smart Lottery AI Service", version="1.0.0")
app.include_router(dreams.router)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(status_code=500, content={"detail": "Error interno del servidor"})


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
