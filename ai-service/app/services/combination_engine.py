import random
import numpy as np
from typing import List, Dict, Tuple, Set

class LTFreeEngine:
    """
    Porte de la lógica LTFree (C#) a Python, integrada con el sistema de puntuación Luxora.
    """
    
    RANGE = 40
    LOTO_SIZE = 6
    
    # Reglas Estrictas LTFree (Hard Filters)
    SUM_MIN = 100
    SUM_MAX = 170
    POSITION_RANGES = [
        (1, 20), (6, 26), (11, 31), (17, 37), (18, 38), (22, 40)
    ]
    PAIR_SUM_RULES = [
        (0, 1, 3, 36),   # Pos 1+2
        (2, 3, 13, 68),  # Pos 3+4
        (4, 5, 40, 78)   # Pos 5+6
    ]

    @staticmethod
    def is_valid(numbers: List[int]) -> bool:
        """Verifica si la combinación cumple con TODAS las reglas de LTFree."""
        if len(numbers) != 6: return False
        sorted_nums = sorted(numbers)
        
        # 1. Sin duplicados y en rango 1-40
        if len(set(sorted_nums)) != 6: return False
        if sorted_nums[0] < 1 or sorted_nums[-1] > 40: return False
        
        # 2. Paridad: 3 Pares / 3 Impares (Luxora improvement)
        evens = [n for n in sorted_nums if n % 2 == 0]
        if len(evens) != 3: return False
        
        # 3. Suma Total (100-170)
        total_sum = sum(sorted_nums)
        if total_sum < LTFreeEngine.SUM_MIN or total_sum > LTFreeEngine.SUM_MAX: return False
        
        # 4. Sin 3 consecutivos
        for i in range(len(sorted_nums) - 2):
            if sorted_nums[i] + 1 == sorted_nums[i+1] and sorted_nums[i+1] + 1 == sorted_nums[i+2]:
                return False
                
        # 5. Rangos por Posición
        for i, (low, high) in enumerate(LTFreeEngine.POSITION_RANGES):
            if sorted_nums[i] < low or sorted_nums[i] > high: return False
            
        # 6. Sumas de Pares (Pos 1+2, etc)
        for i, j, low, high in LTFreeEngine.PAIR_SUM_RULES:
            s = sorted_nums[i] + sorted_nums[j]
            if s < low or s > high: return False
            
        # 7. Regla de Decenios (Máximo 3 por bloque)
        deciles = [0, 0, 0]
        for n in sorted_nums:
            if n <= 20: deciles[0] += 1
            elif n <= 26: deciles[1] += 1
            else: deciles[2] += 1
        if any(d > 3 for d in deciles): return False
        
        # 8. Simetría: suma 3 primeros < suma 3 últimos
        if sum(sorted_nums[:3]) >= sum(sorted_nums[3:]): return False
        
        return True

    @staticmethod
    def calculate_score(numbers: List[int], stats: Dict) -> float:
        """
        Calcula el score de Luxora (Multi-criterio).
        stats contiene: mean_freq, std_dev_freq, number_profiles (z-score, cycle_boost)
        """
        sorted_nums = sorted(numbers)
        profiles = stats.get('profiles', {})
        
        # Frecuencia (Z-Score)
        z_scores = [profiles.get(n, {}).get('z_score', 0) for n in sorted_nums]
        freq_score = np.mean(z_scores) if z_scores else 0
        
        # Dispersión
        disp_score = np.std(sorted_nums) / 40
        
        # Cycle Boost (Vencidos)
        cycle_boosts = [profiles.get(n, {}).get('cycle_boost', 0) for n in sorted_nums]
        cycle_score = np.sum(cycle_boosts)
        
        # Score Final Ponderado
        score = (freq_score * 0.4) + (disp_score * 0.3) + (cycle_score * 0.3)
        return float(score)

    @staticmethod
    def generate_batch(stats: Dict, amount: int = 1000) -> List[Dict]:
        """Genera un lote de combinaciones válidas con sus puntuaciones."""
        results = []
        attempts = 0
        max_attempts = amount * 100
        
        # Pool de números basado en pesos (si está disponible)
        profiles = stats.get('profiles', {})
        all_nums = list(range(1, 41))
        weights = [profiles.get(n, {}).get('weight', 1.0) for n in all_nums]
        
        while len(results) < amount and attempts < max_attempts:
            attempts += 1
            # Selección balanceada: 3 pares, 3 impares
            pares = [n for n in all_nums if n % 2 == 0]
            p_weights = [profiles.get(n, {}).get('weight', 1.0) for n in pares]
            impares = [n for n in all_nums if n % 2 != 0]
            i_weights = [profiles.get(n, {}).get('weight', 1.0) for n in impares]
            
            try:
                sel_p = random.choices(pares, weights=p_weights, k=3)
                sel_i = random.choices(impares, weights=i_weights, k=3)
                combo = list(set(sel_p + sel_i))
                
                if len(combo) == 6 and LTFreeEngine.is_valid(combo):
                    score = LTFreeEngine.calculate_score(combo, stats)
                    results.append({
                        "numbers": sorted(combo),
                        "score": score
                    })
            except:
                continue
                
        # Ordenar por probabilidad (score)
        results.sort(key=lambda x: x['score'], reverse=True)
        return results
