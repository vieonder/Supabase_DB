-- Fonksiyon: Yeni bir rezervasyon oluşturur.
CREATE OR REPLACE FUNCTION public.create_reservation_rpc(
    p_hotel_id UUID,
    p_room_category_id UUID,
    p_check_in_date DATE,
    p_check_out_date DATE,
    p_adults INT,
    p_children INT,
    p_guest_data JSONB, -- { "first_name": "...", "last_name": "...", "email": "...", "phone": "..." }
    p_rate_plan_id UUID DEFAULT NULL, -- Opsiyonel
    p_total_price NUMERIC DEFAULT NULL -- Opsiyonel, frontend'den gelen veya hesaplanacak
)
RETURNS JSON -- Başarılı olursa rezervasyon detaylarını JSON olarak döndürür
LANGUAGE plpgsql
-- SECURITY DEFINER: Bu fonksiyonun, onu çağıran kullanıcının yetkilerinden bağımsız olarak,
-- fonksiyonu oluşturan kullanıcının (genellikle bir süper kullanıcı veya admin) yetkileriyle çalışmasını sağlar.
-- Bu, anonim kullanıcıların rezervasyon yapabilmesi ancak sadece kendi verilerini ekleyebilmesi için gereklidir.
-- Fonksiyon içinde tenant_id kontrolleri yapılmalıdır.
SECURITY DEFINER
-- search_path'i ayarlamak, fonksiyonun doğru şemadaki tablolara erişmesini sağlar.
SET search_path = public
AS $$
DECLARE
    v_tenant_id UUID;
    v_guest_id UUID;
    v_user_profile_id UUID;
    v_reservation_id UUID;
    v_booking_reference TEXT;
    v_room_id UUID; -- Atanacak oda ID'si (MVP'de basitçe ilk müsait oda)
    v_num_nights INT;
    v_calculated_price NUMERIC; -- Fiyatı burada tekrar hesaplayabiliriz (güvenlik için)
    v_status TEXT := 'confirmed'; -- MVP için varsayılan durum
BEGIN
    -- 1. Tenant ID'yi Otelden Al (Güvenlik ve İzolasyon)
    SELECT tenant_id INTO v_tenant_id FROM public.hotels WHERE id = p_hotel_id;
    IF v_tenant_id IS NULL THEN
        RAISE EXCEPTION 'Geçersiz Otel ID: %', p_hotel_id;
    END IF;

    -- 2. Misafir Kaydını Bul veya Oluştur
    SELECT id INTO v_guest_id
    FROM public.guests
    WHERE tenant_id = v_tenant_id AND email = p_guest_data ->> 'email'
    LIMIT 1;

    IF v_guest_id IS NULL THEN
        -- Opsiyonel: user_profiles ile eşleşme kontrolü (eğer misafirler kullanıcı olabilirse)
        SELECT user_id INTO v_user_profile_id FROM public.user_profiles WHERE email = p_guest_data ->> 'email' LIMIT 1;

        INSERT INTO public.guests (tenant_id, hotel_id, first_name, last_name, email, phone, user_profile_id)
        VALUES (
            v_tenant_id,
            p_hotel_id, -- Misafiri rezervasyon yapılan otele bağla
            p_guest_data ->> 'first_name',
            p_guest_data ->> 'last_name',
            p_guest_data ->> 'email',
            p_guest_data ->> 'phone',
            v_user_profile_id -- Varsa kullanıcı profili ID'si
        )
        RETURNING id INTO v_guest_id;
    ELSE
         -- Mevcut misafirin bilgilerini güncellemek isteyebiliriz (opsiyonel)
         UPDATE public.guests
         SET first_name = COALESCE(p_guest_data ->> 'first_name', first_name),
             last_name = COALESCE(p_guest_data ->> 'last_name', last_name),
             phone = COALESCE(p_guest_data ->> 'phone', phone)
         WHERE id = v_guest_id;
    END IF;

    -- 3. Müsaitlik ve Fiyat Kontrolü (Tekrar yapılmalı!)
    -- Güvenlik açısından, frontend'den gelen fiyata güvenmek yerine burada tekrar kontrol etmek önemlidir.
    -- Ayrıca, rezervasyon anında odanın hala müsait olup olmadığını kontrol etmeliyiz.
    -- Bu kontrol için `get_availability_and_price` veya benzer bir fonksiyon kullanılabilir.
    -- Eş zamanlılık sorunlarını önlemek için satır kilitleme (SELECT ... FOR UPDATE) gerekebilir.
    -- MVP için bu kontroller basitleştirilmiştir.
    v_num_nights := p_check_out_date - p_check_in_date;
    -- v_calculated_price := public.calculate_room_price(p_room_category_id, p_check_in_date, p_check_out_date, p_hotel_id, p_rate_plan_id, p_adults, p_children);
    -- IF p_total_price IS NOT NULL AND v_calculated_price != p_total_price THEN
    --     RAISE WARNING 'Frontend price (%) does not match calculated price (%)', p_total_price, v_calculated_price;
    --     -- Hata vermek yerine hesaplanan fiyatı kullanabiliriz: p_total_price := v_calculated_price;
    -- END IF;

    -- 4. Rezervasyon Kaydını Oluştur
    v_booking_reference := public.generate_booking_reference(); -- Bu fonksiyon 017'de olmalı

    INSERT INTO public.res_reservations (
        tenant_id, hotel_id, guest_id, booking_reference, check_in_date, check_out_date,
        num_adults, num_children, status, total_amount, currency_code, rate_plan_id, source
    )
    VALUES (
        v_tenant_id, p_hotel_id, v_guest_id, v_booking_reference, p_check_in_date, p_check_out_date,
        p_adults, p_children, v_status, COALESCE(p_total_price, 0), -- Fiyatı al veya 0 yap
        (SELECT currency_code FROM public.hotels WHERE id = p_hotel_id), -- Otel para birimi
        p_rate_plan_id, 'Website' -- Kaynak belirt
    )
    RETURNING id INTO v_reservation_id;

    -- 5. Rezervasyon Odasını Ata (MVP: Basitçe ilk müsait odayı bul - Gerçekte daha karmaşık olmalı)
    -- Eş zamanlılık sorunları için SELECT FOR UPDATE kullanılmalı!
    SELECT r.id INTO v_room_id
    FROM public.hotels_rooms r
    LEFT JOIN public.res_reservation_rooms rr ON r.id = rr.room_id
    LEFT JOIN public.res_reservations res ON rr.reservation_id = res.id
        AND res.status IN ('confirmed', 'checked_in') -- Çakışan rezervasyonlar
        AND (
            (res.check_in_date < p_check_out_date) AND (res.check_out_date > p_check_in_date)
        )
    WHERE r.hotel_id = p_hotel_id
      AND r.room_category_id = p_room_category_id
      AND r.is_active = true
      AND r.status = 'available' -- Veya müsaitlik durumunu kontrol eden başka bir mantık
      AND res.id IS NULL -- Başka çakışan rezervasyon yoksa
    LIMIT 1
    FOR UPDATE OF r SKIP LOCKED; -- Satırı kilitle, kilitliyse atla

    IF v_room_id IS NULL THEN
        -- Müsait oda bulunamadı, rezervasyonu iptal et veya beklemeye al?
        -- Şimdilik hata verelim.
        RAISE EXCEPTION 'Seçilen tarihler için % kategorisinde müsait oda bulunamadı.', p_room_category_id;
        -- Alternatif: DELETE FROM public.res_reservations WHERE id = v_reservation_id; RETURN NULL;
    END IF;

    -- Rezervasyon odası kaydını ekle
    INSERT INTO public.res_reservation_rooms (tenant_id, reservation_id, room_id, room_category_id)
    VALUES (v_tenant_id, v_reservation_id, v_room_id, p_room_category_id);

    -- Opsiyonel: Odanın durumunu 'reserved' olarak güncelle (trigger ile de yapılabilir)
    -- UPDATE public.hotels_rooms SET status = 'reserved' WHERE id = v_room_id;

    -- 6. Özet Tabloları Güncelle (Edge Function'ı çağırarak veya doğrudan)
    -- Bu fonksiyon içinden doğrudan çağırmak yerine, veritabanı trigger'ı veya
    -- ayrı bir işlemle Edge Function'ı tetiklemek daha iyi olabilir.
    -- PERFORM public.update_availability_for_range(v_tenant_id, p_hotel_id, p_check_in_date, p_check_out_date);

    -- 7. Başarılı yanıtı döndür
    RETURN json_build_object(
        'reservation_id', v_reservation_id,
        'booking_reference', v_booking_reference,
        'status', v_status
    );

EXCEPTION
    WHEN others THEN
        -- Hata durumunda loglama ve genel bir hata mesajı döndürme
        RAISE WARNING 'Rezervasyon oluşturma hatası: %', SQLERRM;
        RETURN json_build_object('error', 'Rezervasyon oluşturulurken bir sunucu hatası oluştu.');

END;
$$;
