# Diccionario de Datos — Sistema Luxora (Smart Lottery App)

Este documento describe la estructura y el propósito de las tablas principales en la base de datos PostgreSQL del sistema Luxora.

## 1. Núcleo de la Aplicación

### `users`
Almacena la información de todos los usuarios, administradores y super-administradores.
*   `id`: Identificador único (UUID).
*   `full_name`: Nombre completo del usuario.
*   `email`: Correo electrónico (único, usado para login).
*   `is_active`: Estado de la cuenta (activar/desactivar).
*   `is_admin`: Flag para administradores.
*   `is_super_admin`: Flag para acceso total al sistema y motor.
*   `max_pulls`: Límite máximo de "Pull-10" permitidos (por defecto 15).

### `lotteries`
Catálogo de las diferentes loterías soportadas por el sistema (ej. Loto Más, Loto Pool).
*   `id`: Identificador único (UUID).
*   `name`: Nombre de la lotería.
*   `config`: Parámetros técnicos (rango de números, cantidad de bolas).

### `historical_results`
**Aquí llega la data del Scraper.** Contiene el historial real de sorteos pasados.
*   `id`: Identificador único.
*   `draw_date`: Fecha en la que se realizó el sorteo.
*   `numbers`: Arreglo de números ganadores (ej. `{1, 5, 12, 23, 30, 38}`).
*   `lottery_id`: Relación con la tabla de loterías.

---

## 2. Motor Estadístico y Pool (Híbrido Luxora + LTFree)

### `lot_pool_combinations`
**El corazón del sistema.** Contiene millones de combinaciones pre-generadas y puntuadas por el motor.
*   `numbers`: La combinación (siempre guardada en orden ascendente para evitar duplicados).
*   `score`: La probabilidad/calidad calculada por el motor (Z-score + Ciclos + Rangos).
*   `is_delivered`: Flag que indica si esta jugada ya fue entregada a un usuario.
*   `delivered_to`: ID del usuario que recibió esta jugada (garantiza unicidad).

### `lot_number_frequency`
Frecuencia histórica de aparición de cada número.
*   `number`: El número (1-40).
*   `frequency`: Cuántas veces ha salido en total.
*   `last_seen`: Fecha de su última aparición.

### `lot_number_cycles`
Mide los "ciclos de ausencia".
*   `draws_since_last`: Cuántos sorteos han pasado desde la última vez que salió este número.
*   `avg_cycle`: El promedio histórico de cada cuánto tiempo suele salir.

### `lot_pair_frequency`
Analiza la afinidad entre números.
*   `number_a` / `number_b`: Pareja de números.
*   `frequency`: Cuántas veces han salido juntos en el mismo sorteo.

### `lot_position_frequency`
Analiza la tendencia por posición (ej. el número 1 suele salir más en la posición 1).
*   `position`: Posición del 1 al 6.
*   `number`: El número que apareció.
*   `frequency`: Cantidad de ocurrencias.

---

## 3. Transacciones y Gobernanza

### `commitment_contracts`
Almacena los contratos digitales firmados por los usuarios para aceptar los términos de la comunidad.
*   `user_id`: Quién firma.
*   `signature_data`: Firma digital o trazo.
*   `photo_data`: Foto capturada durante la firma (para auditoría).
*   `ip_address` / `location`: Datos de geolocalización de la firma.

### `plays`
Registro de cada jugada entregada o realizada.
*   `user_id`: Dueño de la jugada.
*   `numbers`: Los números jugados.
*   `source`: Origen de la jugada (`pull_10`, `engine`, `manual`).
*   `matched_count`: Cantidad de aciertos logrados (se actualiza tras el sorteo).

### `lot_engine_config`
Configuración dinámica de los pesos del motor.
*   `weight_frequency`: Importancia dada a los números que más salen.
*   `cycle_boost_factor`: Importancia dada a los números que tienen mucho tiempo sin salir.
