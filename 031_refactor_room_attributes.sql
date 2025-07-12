-- ##########################################################
-- 031_refactor_room_attributes.sql
-- Oda özelliklerini kategori yerine oda tablosuna taşır,
-- olanaklar için bağlantı tablosu ekler.
-- ##########################################################

BEGIN; -- İşlemleri tek bir transaction içinde yap

-- 1. hotels_room_categories tablosunu güncelle
ALTER TABLE public.hotels_room_categories
    -- max_occupancy sütununu yeniden adlandır ve nullable yap
    RENAME COLUMN max_occupancy TO default_max_occupancy;

ALTER TABLE public.hotels_room_categories
    ALTER COLUMN default_max_occupancy DROP NOT NULL,
    -- Diğer sütunları nullable yap (varsayılan olarak kalmaları için)
    ALTER COLUMN default_price DROP NOT NULL, -- Zaten nullable olabilir, yine de belirtelim
    ALTER COLUMN size_sqm DROP NOT NULL, -- Zaten nullable olabilir
    ALTER COLUMN bed_type DROP NOT NULL, -- Zaten nullable olabilir
    ALTER COLUMN view_type DROP NOT NULL; -- Zaten nullable olabilir

COMMENT ON COLUMN public.hotels_room_categories.default_max_occupancy IS 'Kategorinin varsayılan maksimum kişi kapasitesi (oda bazında geçersiz kılınabilir).';
COMMENT ON COLUMN public.hotels_room_categories.default_price IS 'Kategorinin varsayılan temel fiyatı (oda bazında veya price_daily_rates ile geçersiz kılınabilir).';
COMMENT ON COLUMN public.hotels_room_categories.size_sqm IS 'Kategorinin varsayılan metrekaresi (oda bazında geçersiz kılınabilir).';
COMMENT ON COLUMN public.hotels_room_categories.bed_type IS 'Kategorinin varsayılan yatak tipi (oda bazında geçersiz kılınabilir).';
COMMENT ON COLUMN public.hotels_room_categories.view_type IS 'Kategorinin varsayılan manzarası (oda bazında geçersiz kılınabilir).';

-- 2. hotels_rooms tablosuna yeni sütunları ekle
ALTER TABLE public.hotels_rooms
    ADD COLUMN max_occupancy INTEGER NULL, -- Başlangıçta NULL olabilir, sonra doldurulacak veya NOT NULL yapılacak
    ADD COLUMN size_sqm NUMERIC(6, 2) NULL,
    ADD COLUMN bed_type TEXT NULL,
    ADD COLUMN view_type TEXT NULL,
    ADD COLUMN override_base_price NUMERIC(10, 2) NULL,
    ADD COLUMN is_accessible BOOLEAN DEFAULT false,
    ADD COLUMN building_wing TEXT NULL,
    ADD COLUMN is_connecting BOOLEAN DEFAULT false,
    ADD COLUMN internal_notes TEXT NULL;

-- Yeni eklenen max_occupancy sütununa NOT NULL kısıtlaması eklemeden önce
-- mevcut odaların kategorilerinden varsayılan değeri alarak dolduralım (opsiyonel ama önerilir)
UPDATE public.hotels_rooms r
SET max_occupancy = COALESCE(r.max_occupancy, cat.default_max_occupancy, 1) -- Kategori veya 1 varsayılanı
FROM public.hotels_room_categories cat
WHERE r.category_id = cat.id AND r.max_occupancy IS NULL;

-- max_occupancy sütununu NOT NULL yap
ALTER TABLE public.hotels_rooms
    ALTER COLUMN max_occupancy SET NOT NULL;

COMMENT ON COLUMN public.hotels_rooms.max_occupancy IS 'Odanın gerçek maksimum kişi kapasitesi (ek yataklar dahil).';
COMMENT ON COLUMN public.hotels_rooms.size_sqm IS 'Odanın spesifik metrekaresi.';
COMMENT ON COLUMN public.hotels_rooms.bed_type IS 'Odanın spesifik yatak tipi (örn: "King + Sofa Bed").';
COMMENT ON COLUMN public.hotels_rooms.view_type IS 'Odanın spesifik manzarası.';
COMMENT ON COLUMN public.hotels_rooms.override_base_price IS 'Bu oda için kategori varsayılanından farklı bir temel fiyat uygulanacaksa.';
COMMENT ON COLUMN public.hotels_rooms.is_accessible IS 'Engelli erişimine uygun mu?';
COMMENT ON COLUMN public.hotels_rooms.building_wing IS 'Bulunduğu bina veya kanat.';
COMMENT ON COLUMN public.hotels_rooms.is_connecting IS 'Bağlantılı oda mı?';
COMMENT ON COLUMN public.hotels_rooms.internal_notes IS 'Sadece personel için özel notlar.';

-- 3. Oda-Olanak bağlantı tablosunu oluştur
CREATE TABLE public.hotels_room_amenities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.hotels_rooms(id) ON DELETE CASCADE,
    amenity_id UUID NOT NULL REFERENCES public.hotels_amenities(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (room_id, amenity_id) -- Bir odaya aynı olanak birden fazla eklenemez
);

-- İndeksler
CREATE INDEX idx_hotels_room_amenities_room ON public.hotels_room_amenities(room_id);
CREATE INDEX idx_hotels_room_amenities_amenity ON public.hotels_room_amenities(amenity_id);

-- Bu tablo için updated_at trigger'ı genellikle gereksizdir.

-- 4. Etkilenebilecek Fonksiyon/View/RLS güncellemeleri (Sonraki Adımlar)
-- TODO: calculate_room_price, get_availability_and_price, view_room_status_dashboard gibi fonksiyonları/view'ları kontrol et ve güncelle.
-- TODO: Yeni tablo ve değiştirilen sütunlar için RLS politikalarını gözden geçir/ekle.

COMMIT; -- Transaction'ı onayla
