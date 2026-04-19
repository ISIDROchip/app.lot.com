Scraper de Loto Más - Leidsa
https://loteriasdominicanas.com/leidsa/loto-mas

Extrae resultados desde el 01-01-2021 hasta hoy.
El sorteo se realiza los miércoles y sábados.

INSTALACIÓN:
    pip install playwright beautifulsoup4
    playwright install chromium

USO:
    python scraper_loto_mas.py

SALIDA:
    loto_mas_resultados.csv
"""

import csv
import time
import re
from datetime import date, timedelta
from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup

# ─── Configuración ────────────────────────────────────────────────────────────
START_DATE    = date(2021, 1, 1)
END_DATE      = date.today()
BASE_URL      = "https://loteriasdominicanas.com/leidsa/loto-mas?date={}"
OUTPUT_FILE   = "loto_mas_resultados.csv"
DELAY_SECONDS = 2        # Espera entre peticiones (ser respetuoso con el servidor)
PAGE_TIMEOUT  = 30_000   # 30 segundos por página


# ─── Helpers ──────────────────────────────────────────────────────────────────

def get_sorteo_dates(start: date, end: date) -> list[date]:
    """Retorna solo los miércoles (weekday=2) y sábados (weekday=5) en el rango."""
    dates = []
    current = start
    while current <= end:
        if current.weekday() in (2, 5):   # miércoles=2, sábado=5
            dates.append(current)
        current += timedelta(days=1)
    return dates


def parse_results(html: str, target_date: date) -> list[dict]:
    """
    Parsea el HTML renderizado y extrae los sorteos visibles.
    Retorna una lista de dicts con los datos del sorteo.
    """
    soup = BeautifulSoup(html, "html.parser")
    results = []

    # El sitio muestra bloques de resultados en divs/sections con fecha y números
    # Buscamos todos los bloques que contengan números del sorteo
    # Estructura observada: fecha "DD-MM", luego 6 números + bono Más + bono Super

    # Buscar todos los elementos que contengan la fecha del sorteo objetivo
    date_str_ddmm = target_date.strftime("%d-%m")   # ej. "05-01"
    date_str_full = target_date.strftime("%d-%m-%Y") # ej. "05-01-2021"

    # Extraer todos los bloques de resultado
    # Estrategia 1: buscar por texto de fecha
    all_text = soup.get_text(separator="\n")
    lines = [l.strip() for l in all_text.split("\n") if l.strip()]

    # Encontrar índices donde aparece nuestra fecha objetivo
    target_indices = []
    for i, line in enumerate(lines):
        if date_str_ddmm in line or date_str_full in line:
            target_indices.append(i)

    for idx in target_indices:
        # Recolectar los números que siguen a la fecha (tipicamente 6 principales + 2 bonos)
        window = lines[idx : idx + 20]
        numbers = []
        for token in window:
            # Tokens que son solo 1-2 dígitos son números del sorteo
            if re.match(r"^\d{1,2}$", token):
                numbers.append(token.zfill(2))
            if len(numbers) >= 8:
                break

        if len(numbers) >= 6:
            row = {
                "fecha":      target_date.isoformat(),
                "dia_semana": target_date.strftime("%A"),
                "n1": numbers[0],
                "n2": numbers[1],
                "n3": numbers[2],
                "n4": numbers[3],
                "n5": numbers[4],
                "n6": numbers[5],
                "bono_mas":        numbers[6] if len(numbers) > 6 else "",
                "bono_super_mas":  numbers[7] if len(numbers) > 7 else "",
            }
            results.append(row)
            break  # Solo necesitamos el primer match de esa fecha

    return results


def scrape_page(page, url: str, target_date: date) -> list[dict]:
    """Navega a la URL y extrae los resultados."""
    try:
        page.goto(url, wait_until="networkidle", timeout=PAGE_TIMEOUT)
        time.sleep(1.5)  # Espera extra para JS
        html = page.content()
        return parse_results(html, target_date)
    except Exception as e:
        print(f"  [ERROR] {url} → {e}")
        return []


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    sorteo_dates = get_sorteo_dates(START_DATE, END_DATE)
    total = len(sorteo_dates)
    print(f"Fechas a scrapear: {total} sorteos ({START_DATE} → {END_DATE})")

    all_rows = []
    fieldnames = ["fecha", "dia_semana", "n1", "n2", "n3", "n4", "n5", "n6",
                  "bono_mas", "bono_super_mas"]

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            )
        )
        page = context.new_page()

        for i, sorteo_date in enumerate(sorteo_dates, 1):
            date_param = sorteo_date.strftime("%d-%m-%Y")
            url = BASE_URL.format(date_param)
            print(f"[{i:>4}/{total}] {sorteo_date.isoformat()} → {url}")

            rows = scrape_page(page, url, sorteo_date)

            if rows:
                all_rows.extend(rows)
                print(f"         ✓ Sorteo: {' | '.join(r['n1']+'-'+r['n2']+'-'+r['n3']+'-'+r['n4']+'-'+r['n5']+'-'+r['n6'] for r in rows)}")
            else:
                # El sorteo puede no haberse realizado (feriado, etc.)
                print(f"         ⚠  Sin datos para esta fecha")

            # Guardar progreso incremental cada 20 sorteos
            if i % 20 == 0:
                _save_csv(all_rows, fieldnames, OUTPUT_FILE)
                print(f"  → Progreso guardado ({len(all_rows)} registros)")

            time.sleep(DELAY_SECONDS)

        browser.close()

    # Guardado final
    _save_csv(all_rows, fieldnames, OUTPUT_FILE)
    print(f"\n✅ Completado: {len(all_rows)} sorteos guardados en '{OUTPUT_FILE}'")


def _save_csv(rows: list[dict], fieldnames: list[str], path: str):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
    🔹 ¿Qué hace en general?
Va al sitio:
👉 loteriasdominicanas.com/leidsa/loto-mas
Recorre todas las fechas desde 01-01-2021 hasta hoy.
Filtra solo:
miércoles
sábados
(días en que se juega Loto Más)
Para cada fecha:
Abre la página con esa fecha
Extrae los números del sorteo:
6 números principales
Bono Más
Bono Super Más
Guarda todo en:
👉 loto_mas_resultados.csv
🔹 Cómo lo hace internamente
1. Genera las fechas válidas
get_sorteo_dates()
Recorre día por día
Solo guarda miércoles (2) y sábados (5)
2. Abre la web (con JavaScript)

Usa:

playwright

Esto es clave porque:

La página carga datos dinámicos (JS)
No basta con requests normal
3. Extrae los datos
parse_results()
Convierte el HTML en texto con BeautifulSoup
Busca la fecha (ej: 05-01)
Luego toma los números que vienen después
Detecta números con regex:
^\d{1,2}$
4. Estructura los datos

Guarda algo así:

{
  "fecha": "2021-01-05",
  "dia_semana": "Tuesday",
  "n1": "01",
  "n2": "15",
  ...
  "bono_mas": "12",
  "bono_super_mas": "08"
}
5. Guarda en CSV

Cada 20 sorteos:

_save_csv()

Y al final guarda todo completo.

🔹 Cosas importantes (bien pensadas)
⏱ Espera entre requests (DELAY_SECONDS = 2) → no tumbar el servidor
🧠 Maneja errores (si una fecha no tiene datos)
💾 Guarda progreso parcial → no pierdes todo si falla
🤖 Usa navegador real (Playwright) → más confiable