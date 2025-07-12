-- Fonksiyon: Belirli bir otel ve tarih aralığı için müsait oda kategorilerini ve toplam fiyatlarını getirir.
CREATE OR REPLACE FUNCTION public.get_availability_and_price(
    p_hotel_id UUID,
    p_check_in_date DATE,
    p_check_out_date DATE
    -- p_adults INT DEFAULT 1, -- Gelecekte kişi sayısına göre filtreleme eklenebilir
    -- p_children INT DEFAULT 0
)
RETURNS TABLE (
    room_category_id UUID,
    category_name TEXT,
    category_description TEXT,
    max_occupancy INT,
    total_price NUMERIC,
    currency_code TEXT
)
LANGUAGE plpgsql
STABLE -- Veriyi değiştirmez, sadece okur
SECURITY INVOKER -- RLS politikalarının uygulanması için çağıranın yetkileriyle çalışır
AS $$
DECLARE
    v_num_nights INT;
    v_hotel_currency TEXT;
BEGIN
    -- Gece sayısını hesapla
    v_num_nights := p_check_out_date - p_check_in_date;

    -- Otelin para birimini al
    SELECT currency_code INTO v_hotel_currency FROM public.hotels WHERE id = p_hotel_id;

    -- Ana sorgu
    RETURN QUERY
    WITH DateSeries AS (
        -- Tarih aralığındaki her günü üret
        SELECT generate_series(p_check_in_date, p_check_out_date - INTERVAL '1 day', '1 day'::interval)::date AS stay_date
    ),
    AvailableCategories AS (
        -- Belirtilen tarih aralığındaki *her gün* müsait olan kategorileri bul
        SELECT das.room_category_id
        FROM public.daily_availability_summary das
        JOIN DateSeries ds ON das.date = ds.stay_date
        WHERE das.hotel_id = p_hotel_id
          AND das.available_room_count > 0 -- Müsait oda olmalı
          AND das.stop_sell IS DISTINCT FROM TRUE -- Stop sell olmamalı
        GROUP BY das.room_category_id
        HAVING COUNT(das.date) = v_num_nights -- Aralıktaki tüm günler için müsait olmalı
    ),
    CategoryPricing AS (
        -- Müsait kategorilerin her biri için tarih aralığındaki toplam fiyatı hesapla
        SELECT
            pdr.room_category_id,
            SUM(COALESCE(pdr.rate_amount, cat.default_base_price, 0)) AS calculated_total_price -- Fiyat yoksa kategori varsayılanını kullan
        FROM public.price_daily_rates pdr
        JOIN DateSeries ds ON pdr.date = ds.stay_date
        JOIN public.hotels_room_categories cat ON pdr.room_category_id = cat.id -- Varsayılan fiyat için join
        WHERE pdr.hotel_id = p_hotel_id
          AND pdr.room_category_id IN (SELECT room_category_id FROM AvailableCategories)
          AND pdr.rate_plan_id IS NULL -- MVP: Sadece varsayılan (base) fiyat planını dikkate al
        GROUP BY pdr.room_category_id
    )
    -- Sonuçları birleştir ve kategori bilgilerini ekle
    SELECT
        ac.room_category_id,
        cat.name AS category_name,
        cat.description AS category_description,
        cat.max_occupancy,
        cp.calculated_total_price AS total_price,
        v_hotel_currency AS currency_code
    FROM AvailableCategories ac
    JOIN public.hotels_room_categories cat ON ac.room_category_id = cat.id
    JOIN CategoryPricing cp ON ac.room_category_id = cp.room_category_id
    WHERE cat.is_active = true -- Sadece aktif kategorileri göster
    ORDER BY cat.sort_order, cp.calculated_total_price; -- Önce sıralama sonra fiyata göre sırala

END;
$$;
