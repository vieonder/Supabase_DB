-- ##########################################################
-- 028_summary_tables.sql
-- Müsaitlik ve Doluluk İçin Özet Tablolar
-- ##########################################################

-- ======================================
-- Günlük Müsaitlik Özeti (Kategori Bazlı)
-- ======================================
CREATE TABLE public.daily_availability_summary (
    id BIGSERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    room_category_id UUID NOT NULL REFERENCES public.hotels_room_categories(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_rooms_in_category INT NOT NULL, -- O kategorideki toplam oda sayısı (referans için)
    physical_rooms_out_of_order INT NOT NULL DEFAULT 0, -- Bakım, arıza vb. nedeniyle fiziksel olarak kapalı
    manual_override_block INT NOT NULL DEFAULT 0, -- price_availability_rules ile manuel kapatılan
    available_room_count INT NOT NULL CHECK (available_room_count >= 0), -- Satılabilir oda sayısı (total - out_of_order - manual_block - occupied)
    occupied_count INT NOT NULL DEFAULT 0, -- O gün dolu olan oda sayısı (rezervasyonlardan gelen)
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, hotel_id, room_category_id, date)
);

-- İndeksler
CREATE INDEX idx_daily_availability_summary_cat_date ON public.daily_availability_summary(room_category_id, date);
CREATE INDEX idx_daily_availability_summary_hotel_date ON public.daily_availability_summary(hotel_id, date);

-- updated_at trigger'ı
CREATE TRIGGER trg_daily_availability_summary_updated_at
BEFORE UPDATE ON public.daily_availability_summary
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ======================================
-- Günlük Doluluk Özeti (Otel Bazlı)
-- ======================================
CREATE TABLE public.daily_occupancy_summary (
    id BIGSERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    total_physical_rooms INT NOT NULL, -- Oteldeki toplam fiziksel oda sayısı
    total_sellable_rooms INT NOT NULL, -- Satılabilir oda sayısı (total_physical - out_of_order)
    occupied_rooms INT NOT NULL DEFAULT 0, -- Dolu oda sayısı
    occupancy_rate NUMERIC(5, 2) GENERATED ALWAYS AS ( -- Otomatik hesaplanan sütun
        CASE
            WHEN total_sellable_rooms > 0 THEN ROUND((occupied_rooms::numeric * 100) / total_sellable_rooms, 2)
            ELSE 0
        END
    ) STORED,
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, hotel_id, date)
);

-- İndeksler
CREATE INDEX idx_daily_occupancy_summary_hotel_date ON public.daily_occupancy_summary(hotel_id, date);

-- updated_at trigger'ı
CREATE TRIGGER trg_daily_occupancy_summary_updated_at
BEFORE UPDATE ON public.daily_occupancy_summary
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
