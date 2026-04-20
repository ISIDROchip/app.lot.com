-- 008_historical_results_uniqueness.sql
-- Asegurar que no haya duplicados de sorteos por lotería y fecha.
-- Permite usar UPSERT (ON CONFLICT) en el scraper.

ALTER TABLE historical_results 
ADD CONSTRAINT unique_lottery_draw_date UNIQUE (lottery_id, draw_date);
