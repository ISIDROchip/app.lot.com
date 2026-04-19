import os
import sys
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("API_KEY", "")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
PORT = int(os.getenv("PORT", "8000"))

if not API_KEY:
    print("ERROR: Variable de entorno API_KEY es requerida", file=sys.stderr)
    sys.exit(1)

if not OPENAI_API_KEY:
    print("WARNING: Variable de entorno OPENAI_API_KEY no detectada. Usando modo simulación.", file=sys.stderr)
