import random
import json
from openai import OpenAI
from app.models.schemas import DreamResponse
from app.config import OPENAI_API_KEY

client = OpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None

KEYWORD_MAP: dict[str, list[int]] = {
    "agua":      [3, 7, 21],
    "fuego":     [1, 9, 18],
    "casa":      [4, 12, 25],
    "perro":     [5, 14, 28],
    "gato":      [6, 11, 22],
    "dinero":    [2, 8, 33],
    "muerte":    [13, 26, 36],
    "amor":      [7, 15, 29],
    "viaje":     [10, 19, 31],
    "mar":       [3, 16, 24],
    "cielo":     [9, 20, 35],
    "tierra":    [4, 17, 30],
    "sol":       [1, 11, 23],
    "luna":      [6, 18, 32],
    "arbol":     [5, 13, 27],
    "pajaro":    [8, 16, 34],
    "serpiente": [2, 10, 20],
    "escalera":  [7, 14, 28],
    "carro":     [3, 12, 25],
    "nino":      [4, 9, 19],
}

_ACCENT_MAP = str.maketrans("áéíóúüñÁÉÍÓÚÜÑ", "aeiouunAEIOUUN")

def _normalize(text: str) -> str:
    return text.translate(_ACCENT_MAP).lower()

def _local_analyze(text: str) -> DreamResponse:
    normalized = _normalize(text)
    found_keywords: list[str] = []
    numbers: set[int] = set()

    for keyword, nums in KEYWORD_MAP.items():
        if keyword in normalized:
            found_keywords.append(keyword)
            numbers.update(nums)

    all_numbers = list(range(1, 37))
    while len(numbers) < 3:
        numbers.add(random.choice(all_numbers))

    result = sorted(numbers)[:6]
    return DreamResponse(numbers=result, keywords=found_keywords)

def analyze(text: str) -> DreamResponse:
    if not client:
        return _local_analyze(text)

    try:
        prompt = f"""
        Interpreta el siguiente texto. Si parece ser la descripción de un sueño, identifica los temas principales y conviértelos en una lista de entre 3 y 6 números de lotería (del 1 al 36).
        Si el texto NO es un sueño o no tiene sentido, devuelve números aleatorios pero indica que no se detectó un sueño claro en las palabras clave.
        
        Responde ESTRICTAMENTE en formato JSON con esta estructura:
        {{
            "numbers": [número1, número2, ...],
            "keywords": ["tema1", "tema2", ...],
            "is_dream": true/false
        }}
        
        Texto a interpretar: "{text}"
        """

        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "Eres un experto en oniromancia y numerología para loterías. Solo respondes en JSON."},
                {"role": "user", "content": prompt}
            ],
            response_format={ "type": "json_object" }
        )

        data = json.loads(response.choices[0].message.content)
        
        # Validate numbers are within range [1, 36]
        valid_numbers = [max(1, min(36, n)) for n in data.get("numbers", [])]
        if not valid_numbers:
             return _local_analyze(text)
             
        return DreamResponse(
            numbers=sorted(list(set(valid_numbers)))[:6],
            keywords=data.get("keywords", [])
        )
    except Exception as e:
        print(f"Error calling OpenAI: {e}")
        return _local_analyze(text)
