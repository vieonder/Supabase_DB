-- ##########################################################
-- 030_alter_price_daily_rates.sql
-- price_daily_rates tablosuna hesaplanmış temel fiyat sütunu ekler
-- ##########################################################

ALTER TABLE public.price_daily_rates
ADD COLUMN calculated_base_price NUMERIC(10, 2) NULL;

COMMENT ON COLUMN public.price_daily_rates.price IS 'Personel tarafından manuel olarak girilen veya grid üzerinden ayarlanan günlük fiyat. NULL olabilir.';
COMMENT ON COLUMN public.price_daily_rates.calculated_base_price IS 'Sistem tarafından stabil kurallara göre hesaplanan öneri temel fiyatı. NULL olabilir.';
