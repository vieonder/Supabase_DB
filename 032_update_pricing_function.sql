-- ##########################################################
-- 032_update_pricing_function.sql
-- Fiyat hesaplama fonksiyonunu yeni oda yapısına göre günceller
-- ##########################################################

BEGIN;

CREATE OR REPLACE FUNCTION public.calculate_room_price(
    p_room_category_id UUID,
    p_check_in_date DATE,
    p_check_out_date DATE,
    p_hotel_id UUID,
    p_rate_plan_id UUID DEFAULT NULL,
    p_adults INT DEFAULT 1,
    p_children INT DEFAULT 0,
    p_booking_date DATE DEFAULT CURRENT_DATE,
    p_room_id UUID DEFAULT NULL -- Oda bazlı override için eklendi
)
RETURNS DECIMAL AS $$
DECLARE
    v_total_price DECIMAL := 0;
    v_current_date DATE;
    v_base_price DECIMAL; -- O gün için geçerli temel fiyat
    v_daily_price DECIMAL; -- Ayarlamalar sonrası günlük fiyat
    v_rate_modifier DECIMAL := 1.0;
    v_strategy_id UUID;
    v_adjustment DECIMAL := 0;
    v_lead_time INT;
    v_day_of_week INT;
    v_event_adjustment DECIMAL := 0;
    v_manual_rate RECORD; -- price_daily_rates'ten gelen satır
    v_room_override_price DECIMAL; -- hotels_rooms.override_base_price
    v_category_default_price DECIMAL; -- hotels_room_categories.default_price
BEGIN
    -- Rate plan modifier'ı al (varsa)
    IF p_rate_plan_id IS NOT NULL THEN
        SELECT COALESCE(adjustment_value, 0), adjustment_type INTO v_rate_modifier -- TODO: Bu kısım RFC-001'e göre güncellenmeli (percentage/fixed)
        FROM public.res_rate_plans
        WHERE id = p_rate_plan_id AND is_active = true;
        -- Şimdilik basitçe modifier'ı 1.0 varsayalım, bu mantık daha sonra detaylandırılmalı.
        v_rate_modifier := 1.0;
    END IF;

    -- Oda bazlı override fiyatını al (varsa)
    IF p_room_id IS NOT NULL THEN
        SELECT override_base_price INTO v_room_override_price
        FROM public.hotels_rooms
        WHERE id = p_room_id;
    END IF;

    -- Kategori varsayılan fiyatını al
    SELECT default_price INTO v_category_default_price
    FROM public.hotels_room_categories
    WHERE id = p_room_category_id;

    -- Her gün için fiyat hesapla
    v_current_date := p_check_in_date;
    WHILE v_current_date < p_check_out_date LOOP
        v_base_price := NULL; -- Her gün için sıfırla
        v_adjustment := 0;
        v_event_adjustment := 0;

        -- 1. Temel Fiyatı Belirle (Öncelik Sırası: Oda Override -> Manuel Günlük -> Hesaplanan Günlük -> Kategori Varsayılan)
        -- a. Oda Override Fiyatı
        v_base_price := v_room_override_price; -- Eğer NULL değilse bu kullanılacak

        -- b. Manuel/Hesaplanan Günlük Fiyat (price_daily_rates)
        IF v_base_price IS NULL THEN
            SELECT price, calculated_base_price INTO v_manual_rate
            FROM public.price_daily_rates dr
            WHERE dr.hotel_id = p_hotel_id
              AND dr.room_category_id = p_room_category_id
              AND dr.date = v_current_date
              AND (dr.rate_plan_id IS NULL OR dr.rate_plan_id = p_rate_plan_id) -- Veya sadece base plan (NULL) kontrolü?
            ORDER BY dr.rate_plan_id NULLS LAST -- Spesifik plan öncelikli (eğer rate_plan_id NULL değilse)
            LIMIT 1;

            -- Önce manuel girilen fiyata bak, sonra hesaplanmışa
            v_base_price := COALESCE(v_manual_rate.price, v_manual_rate.calculated_base_price);
        END IF;

        -- c. Kategori Varsayılan Fiyatı
        IF v_base_price IS NULL THEN
            v_base_price := v_category_default_price;
        END IF;

        -- d. Hiçbir fiyat bulunamazsa (hata veya varsayılan 0)
        IF v_base_price IS NULL THEN
             -- RAISE WARNING 'No base price found for category % on date %', p_room_category_id, v_current_date;
             v_base_price := 0; -- Veya hata döndür
        END IF;

        -- Günlük fiyatı temel fiyattan başlat
        v_daily_price := v_base_price;

        -- 2. Geçerli Dinamik Stratejiyi Bul (Bu kısım aynı kalabilir)
        SELECT id INTO v_strategy_id
        FROM public.dynamic_pricing_strategies s
        WHERE s.hotel_id = p_hotel_id
          AND s.is_active = true
          AND (s.base_rate_plan_id IS NULL OR s.base_rate_plan_id = p_rate_plan_id) -- Stratejinin hangi plana uygulandığı kontrolü
          -- Stratejinin oda kategorisi hedeflemesi de eklenebilir
        ORDER BY s.priority DESC -- Öncelik sırası
        LIMIT 1;

        -- 3. Strateji Varsa Kuralları Uygula (Bu kısım aynı kalabilir, ancak v_daily_price'a uygulanır)
        IF v_strategy_id IS NOT NULL THEN
            v_lead_time := v_current_date - p_booking_date;
            v_day_of_week := EXTRACT(ISODOW FROM v_current_date);

            -- TODO: Doluluk oranı gibi faktörleri hesapla
            -- SELECT calculate_occupancy_rate(p_hotel_id, v_current_date) INTO v_occupancy_rate;

            -- Eşleşen Kurallara Göre Ayarlama Hesapla (Basitleştirilmiş - Sadece fixed_amount topluyor)
            SELECT COALESCE(SUM(CASE WHEN r.action_type = 'adjust_fixed' THEN r.action_value ELSE 0 END), 0)
            INTO v_adjustment
            FROM public.dynamic_pricing_rules r
            -- JOIN public.dynamic_pricing_factors f ON ... -- Faktör kontrolü eklenecek
            WHERE r.strategy_id = v_strategy_id
              AND r.is_active = true
              AND (r.start_date IS NULL OR v_current_date >= r.start_date)
              AND (r.end_date IS NULL OR v_current_date <= r.end_date)
              AND (r.days_of_week IS NULL OR v_day_of_week = ANY(r.days_of_week))
              AND (r.target_room_categories IS NULL OR p_room_category_id = ANY(r.target_room_categories))
              AND (r.target_rate_plans IS NULL OR p_rate_plan_id = ANY(r.target_rate_plans));
              -- TODO: Yüzdesel ayarlama ve set_price/close_rate mantığı eklenmeli
        END IF;

        -- 4. Özel Etkinlik Kontrolü (Bu kısım aynı kalabilir)
        SELECT COALESCE(SUM(e.expected_impact::numeric), 0) -- expected_impact'ı sayısal bir değere dönüştürdüğümüzü varsayalım
        INTO v_event_adjustment
        FROM public.dynamic_pricing_events e
        WHERE e.hotel_id = p_hotel_id
          AND e.is_active = true
          AND v_current_date BETWEEN e.start_date AND e.end_date;

        -- 5. Dinamik Ayarlamaları Uygula
        v_daily_price := v_daily_price + v_event_adjustment + v_adjustment;

        -- 6. Fiyat Planı Ayarlamasını Uygula (RFC-001'e göre detaylandırılmalı)
        -- Şimdilik basitçe v_rate_modifier (1.0) ile çarpıyoruz
        v_daily_price := v_daily_price * v_rate_modifier;

        -- Negatif fiyat olmamasını sağla
        IF v_daily_price < 0 THEN
           v_daily_price := 0;
        END IF;

        -- Günlük fiyatı toplama ekle
        v_total_price := v_total_price + v_daily_price;

        v_current_date := v_current_date + INTERVAL '1 day';
    END LOOP;

    RETURN v_total_price;
END;
$$ LANGUAGE plpgsql STABLE SECURITY INVOKER;

COMMIT;
