-- ##########################################################
-- 017_functions_and_triggers.sql
-- Veritabanı Fonksiyonları ve Trigger'lar
-- ##########################################################

-- ======================================
-- Genel Yardımcı Fonksiyonlar
-- ======================================

-- `updated_at` sütununu otomatik güncelleyen fonksiyon
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$$ language 'plpgsql';

-- Yeni kullanıcı oluşturulduğunda public.user_profiles tablosuna kayıt ekleyen fonksiyon
-- (Supabase Auth hook'u tarafından tetiklenir)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (user_id, first_name, last_name)
  VALUES (
    NEW.id,
    -- Eğer raw_user_meta_data'dan gelen isim NULL ise 'Misafir' kullan
    COALESCE(NEW.raw_user_meta_data ->> 'first_name', 'Misafir'),
    -- Eğer raw_user_meta_data'dan gelen soyisim NULL ise 'Kullanıcı' kullan
    COALESCE(NEW.raw_user_meta_data ->> 'last_name', 'Kullanıcı')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Not: SECURITY DEFINER kullanımı ve `raw_user_meta_data` içeriği dikkatle yönetilmelidir.

-- Booking referansı oluşturma fonksiyonu (örnek)
-- CREATE OR REPLACE FUNCTION public.generate_booking_reference(length INT DEFAULT 8)
-- RETURNS TEXT AS $$
-- DECLARE
--   chars TEXT[] := '{A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,0,1,2,3,4,5,6,7,8,9}';
--   result TEXT := '';
--   i INT;
-- BEGIN
--   FOR i IN 1..length LOOP
--     result := result || chars[1+floor(random()*(array_length(chars, 1)-1))];
--   END LOOP;
--   RETURN result;
-- END;
-- $$ LANGUAGE plpgsql VOLATILE;


-- ======================================
-- RLS Yardımcı Fonksiyonları
-- ======================================
-- Geçerli kullanıcının tenant ID'sini JWT'den alır
CREATE OR REPLACE FUNCTION public.get_tenant_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY INVOKER -- Use SECURITY INVOKER for RLS helper functions accessing JWT
AS $$
  SELECT nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'tenant_id', '')::uuid;
$$;

-- Geçerli kullanıcının ID'sini (auth.users.id) JWT'den alır
CREATE OR REPLACE FUNCTION public.get_user_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  SELECT nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid;
$$;

-- YENİ: Kullanıcının super_admin olup olmadığını kontrol eder (raw_app_meta_data üzerinden)
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER -- raw_app_meta_data'ya erişim için SECURITY DEFINER gerekli
SET search_path = public -- Güvenlik için schema belirtmek önemlidir
AS $$
  -- auth.uid() o anki oturumun kullanıcı ID'sini güvenli bir şekilde verir
  SELECT COALESCE((SELECT raw_app_meta_data ->> 'is_super_admin' FROM auth.users WHERE id = auth.uid()), 'false')::boolean;
$$;

-- Geçerli kullanıcının geçerli tenant'taki rolünü alır (tenant_members tablosundan)
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  SELECT role
  FROM public.tenant_members
  WHERE user_id = public.get_user_id()
    AND tenant_id = public.get_tenant_id()
  LIMIT 1; -- Tek bir rol varsayılıyor
$$;

-- Geçerli kullanıcının geçerli tenant'ta erişebileceği otel ID'lerini alır (tenant_members tablosundan)
CREATE OR REPLACE FUNCTION public.get_user_hotel_ids()
RETURNS UUID[]
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  SELECT hotel_ids
  FROM public.tenant_members
  WHERE user_id = public.get_user_id()
    AND tenant_id = public.get_tenant_id()
  LIMIT 1;
$$;

-- GÜNCELLENMİŞ: Kullanıcının (tenant) admin rolüne sahip olup olmadığını kontrol eder
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  -- Super admin aynı zamanda tenant admini yetkilerine sahip olmalı
  SELECT public.is_super_admin() OR (public.get_user_role() = 'admin');
$$;

-- GÜNCELLENMİŞ: Kullanıcının belirli bir otele erişimi olup olmadığını kontrol eder
CREATE OR REPLACE FUNCTION public.has_hotel_access(hotel_id_to_check UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  -- Superadmins have access to all hotels.
  -- Tenant Admins have access to all hotels within their tenant.
  -- Non-admin members have access ONLY if hotel_id_to_check is explicitly in their assigned list (or the list is NULL, meaning all).
  SELECT
    public.is_super_admin() OR -- Super admin her şeye erişir
    (
      -- Tenant bağlamında olmalı (get_tenant_id() NULL değilse)
      -- Bu fonksiyon tenant dışı bağlamda çağrılırsa (örn. super admin tarafından) tenant kontrolü atlanmalı
      -- Ancak RLS politikaları genelde tenant bağlamında çalışır, bu yüzden get_tenant_id() genellikle NULL olmaz.
      -- Şimdilik tenant kontrolünü RLS politikasına bırakalım, burada eklemeyelim.
      (
        -- get_user_role() tenant bazlı olduğu için is_admin() de tenant bazlıdır.
        -- Super admin kontrolü yukarıda yapıldığı için buradaki is_admin() sadece tenant adminini kontrol eder.
        (SELECT public.get_user_role() = 'admin') OR -- Tenant admini tüm otellere erişir
        (
          public.get_user_hotel_ids() IS NULL OR -- hotel_ids NULL ise tüm otellere erişim
          hotel_id_to_check = ANY(COALESCE(public.get_user_hotel_ids(), '{}'::UUID[])) -- Belirli otel listede varsa
        )
      )
    );
$$;

-- Giriş yapmış kullanıcının geçerli tenant'taki misafir ID'sini alır
-- Eğer kullanıcı bu tenant'ta bir misafirle eşleşmiyorsa NULL döner.
CREATE OR REPLACE FUNCTION public.get_current_guest_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  SELECT g.id
  FROM public.guests g
  JOIN public.user_profiles up ON g.user_profile_id = up.user_id
  WHERE g.tenant_id = public.get_tenant_id() -- Geçerli tenant kontrolü
    AND up.user_id = public.get_user_id()   -- Geçerli kullanıcı kontrolü
  LIMIT 1;
$$;

-- ======================================
-- Rezervasyon İşlemleri
-- ======================================

-- Rezervasyon durumu değiştiğinde oda durumunu güncelle
CREATE OR REPLACE FUNCTION public.handle_reservation_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Eski durum 'confirmed' ise ve yeni durum farklıysa odayı serbest bırak
    IF (OLD.status = 'confirmed' AND NEW.status != 'confirmed') THEN
        UPDATE public.hotels_rooms
        SET status = 'available'
        WHERE id IN (
            SELECT room_id 
            FROM public.res_reservation_rooms 
            WHERE reservation_id = NEW.id
        );
    -- Yeni durum 'confirmed' ise odayı rezerve et
    ELSIF (NEW.status = 'confirmed') THEN
        UPDATE public.hotels_rooms
        SET status = 'reserved'
        WHERE id IN (
            SELECT room_id 
            FROM public.res_reservation_rooms 
            WHERE reservation_id = NEW.id
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fiyat hesaplama fonksiyonu (Dinamik Fiyatlandırma Entegreli)
CREATE OR REPLACE FUNCTION public.calculate_room_price(
    p_room_category_id UUID,
    p_check_in_date DATE,
    p_check_out_date DATE,
    p_hotel_id UUID, -- Dinamik strateji için gerekli
    p_rate_plan_id UUID DEFAULT NULL,
    p_adults INT DEFAULT 1,
    p_children INT DEFAULT 0,
    p_booking_date DATE DEFAULT CURRENT_DATE -- Rezervasyonun yapıldığı tarih (lead time için)
)
RETURNS DECIMAL AS $$
DECLARE
    v_total_price DECIMAL := 0;
    v_current_date DATE;
    v_base_price DECIMAL;
    v_daily_price DECIMAL;
    v_rate_modifier DECIMAL := 1.0;
    v_strategy_id UUID;
    v_adjustment DECIMAL := 0;
    v_lead_time INT;
    v_day_of_week INT;
    -- v_occupancy_rate DECIMAL; -- İhtiyaç duyulursa hesaplanacak
    v_event_adjustment DECIMAL := 0;
    v_manual_rate DECIMAL;
BEGIN
    -- Temel fiyatı al
    SELECT base_price INTO v_base_price
    FROM public.hotels_room_categories
    WHERE id = p_room_category_id;

    -- Rate plan modifier'ı al (varsa)
    IF p_rate_plan_id IS NOT NULL THEN
        SELECT COALESCE(base_rate_modifier, 1.0) INTO v_rate_modifier
        FROM public.res_rate_plans
        WHERE id = p_rate_plan_id AND is_active = true;
    END IF;

    -- Her gün için fiyat hesapla
    v_current_date := p_check_in_date;
    WHILE v_current_date < p_check_out_date LOOP
        v_daily_price := v_base_price; -- Günlük fiyatı temel fiyattan başlat
        v_adjustment := 0; -- Günlük ayarlamayı sıfırla
        v_event_adjustment := 0;

        -- 1. Geçerli Dinamik Stratejiyi Bul
        SELECT id INTO v_strategy_id
        FROM public.dynamic_pricing_strategies s
        WHERE s.hotel_id = p_hotel_id
          AND s.is_active = true
          AND (s.room_category_id IS NULL OR s.room_category_id = p_room_category_id)
          AND (s.start_date IS NULL OR v_current_date >= s.start_date)
          AND (s.end_date IS NULL OR v_current_date <= s.end_date)
        ORDER BY s.room_category_id NULLS LAST, s.start_date DESC NULLS LAST -- En spesifik olanı seç
        LIMIT 1;

        -- 2. Strateji Varsa Kuralları Uygula
        IF v_strategy_id IS NOT NULL THEN
            v_lead_time := v_current_date - p_booking_date;
            v_day_of_week := EXTRACT(ISODOW FROM v_current_date); -- 1 (Pazartesi) - 7 (Pazar)

            -- Gerekirse doluluk oranı hesaplanır (bu örnekte basit tutuldu)
            -- SELECT calculate_occupancy_rate(p_hotel_id, v_current_date) INTO v_occupancy_rate;

            -- Eşleşen Kurallara Göre Ayarlama Hesapla
            SELECT COALESCE(SUM(r.adjustment_value), 0)
            INTO v_adjustment
            FROM public.dynamic_pricing_rules r
            JOIN public.dynamic_pricing_factors f ON r.factor_id = f.id
            WHERE r.strategy_id = v_strategy_id
              AND r.is_active = true
              AND (
                  -- Faktör kontrolleri
                  (f.factor_type = 'lead_time' AND v_lead_time >= f.min_value AND v_lead_time <= f.max_value)
                  OR (f.factor_type = 'day_of_week' AND v_day_of_week = f.numeric_value)
                  -- OR (f.factor_type = 'occupancy' AND v_occupancy_rate >= f.min_value AND v_occupancy_rate <= f.max_value)
                  OR (f.factor_type = 'length_of_stay' AND (p_check_out_date - p_check_in_date) >= f.min_value AND (p_check_out_date - p_check_in_date) <= f.max_value)
              );
              -- NOT: Şimdilik sadece adjustment_value toplandı, adjustment_type (percentage/fixed) dikkate alınmadı.
              -- Daha karmaşık implementasyon yüzdelik ve sabit ayarlamaları doğru şekilde uygular.
        END IF;

        -- 3. Özel Etkinlik Kontrolü
        SELECT COALESCE(SUM(e.price_adjustment), 0)
        INTO v_event_adjustment
        FROM public.dynamic_pricing_events e
        WHERE e.hotel_id = p_hotel_id
          AND e.is_active = true
          AND v_current_date BETWEEN e.start_date AND e.end_date;

        -- 4. Dinamik Ayarlamaları Uygula
        -- Önce etkinlik ayarlaması, sonra kural ayarlaması (öncelik sırası belirlenebilir)
        v_daily_price := v_daily_price + v_event_adjustment + v_adjustment;

        -- 5. Manuel Fiyat Kontrolü (price_daily_rates)
        SELECT rate_amount INTO v_manual_rate
        FROM public.price_daily_rates dr
        WHERE dr.hotel_id = p_hotel_id
          AND dr.room_category_id = p_room_category_id
          AND dr.date = v_current_date
          AND (dr.rate_plan_id IS NULL OR dr.rate_plan_id = p_rate_plan_id)
        ORDER BY dr.rate_plan_id NULLS LAST -- Spesifik plan öncelikli
        LIMIT 1;

        IF v_manual_rate IS NOT NULL THEN
            v_daily_price := v_manual_rate; -- Manuel fiyat dinamik fiyatı ezer
        END IF;

        -- 6. Fiyat Planı Çarpanını Uygula
        v_daily_price := v_daily_price * v_rate_modifier;

        -- Negatif fiyat olmamasını sağla
        IF v_daily_price < 0 THEN
           v_daily_price := 0;
        END IF;

        -- Günlük fiyatı toplama ekle
        v_total_price := v_total_price + v_daily_price;

        v_current_date := v_current_date + 1;
    END LOOP;

    RETURN v_total_price;
END;
$$ LANGUAGE plpgsql STABLE SECURITY INVOKER; -- Fiyat herkese açık olacağı için INVOKER

-- Split-stay rezervasyon validasyonu
CREATE OR REPLACE FUNCTION public.validate_split_stay_reservation(
    -- p_reservation_id UUID -- Parametre kaldırıldı
)
RETURNS TRIGGER AS $$ -- RETURNS TRIGGER olarak değiştirildi, çünkü NEW kullanacak
DECLARE
    v_is_valid BOOLEAN := true;
    v_prev_segment RECORD;
    v_curr_segment RECORD;
BEGIN
    -- Split-stay segmentlerini sıralı şekilde al
    FOR v_curr_segment IN (
        SELECT 
            s.check_in_date,
            s.check_out_date,
            s.hotel_id,
            h.name as hotel_name
        FROM public.split_stay_segments s
        JOIN public.hotels h ON h.id = s.hotel_id
        WHERE s.reservation_id = NEW.reservation_id -- NEW.reservation_id kullanıldı
        ORDER BY s.check_in_date
    ) LOOP
        -- İlk segment değilse, önceki segment ile karşılaştır
        IF v_prev_segment IS NOT NULL THEN
            -- Tarih kontrolü
            IF v_curr_segment.check_in_date != v_prev_segment.check_out_date THEN
                RAISE EXCEPTION 'Geçersiz split-stay: % oteli check-out ve % oteli check-in tarihleri uyuşmuyor',
                    v_prev_segment.hotel_name, v_curr_segment.hotel_name;
                -- v_is_valid := false; -- İşlemi durdurmak için exception yeterli
                RETURN NULL; -- Veya uygun bir hata yönetimi
            END IF;
        END IF;
        
        v_prev_segment := v_curr_segment;
    END LOOP;

    RETURN NEW; -- Trigger fonksiyonları genellikle NEW veya OLD döndürür
END;
$$ LANGUAGE plpgsql STABLE; -- STABLE kalabilir

-- ======================================
-- Misafir İşlemleri
-- ======================================

-- Misafir birleştirme fonksiyonu
CREATE OR REPLACE FUNCTION public.merge_guest_records(
    p_primary_guest_id UUID,
    p_secondary_guest_id UUID
)
RETURNS VOID AS $$
BEGIN
    -- Güvenlik kontrolü
    IF NOT (SELECT public.has_hotel_access(
        (SELECT hotel_id FROM public.guests WHERE id = p_primary_guest_id LIMIT 1)
    )) THEN
        RAISE EXCEPTION 'Bu işlem için yetkiniz yok';
    END IF;

    -- Rezervasyonları güncelle
    UPDATE public.res_reservations
    SET guest_id = p_primary_guest_id
    WHERE guest_id = p_secondary_guest_id;

    -- Tercihleri birleştir
    INSERT INTO public.guest_preferences (
        tenant_id, guest_id, preference_type, preference_value, preference_notes
    )
    SELECT 
        tenant_id, p_primary_guest_id, preference_type, preference_value, preference_notes
    FROM public.guest_preferences
    WHERE guest_id = p_secondary_guest_id
    ON CONFLICT (guest_id, preference_type) DO NOTHING;

    -- İletişim geçmişini güncelle
    UPDATE public.guest_communications
    SET guest_id = p_primary_guest_id
    WHERE guest_id = p_secondary_guest_id;

    -- Notları güncelle
    UPDATE public.guest_notes
    SET guest_id = p_primary_guest_id
    WHERE guest_id = p_secondary_guest_id;

    -- İkincil kaydı sil
    DELETE FROM public.guests WHERE id = p_secondary_guest_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Misafir tercihleri güncelleme
CREATE OR REPLACE FUNCTION public.update_guest_preferences(
    p_guest_id UUID,
    p_preferences JSONB
)
RETURNS VOID AS $$
DECLARE
    v_key TEXT;
    v_value TEXT;
BEGIN
    -- Her bir tercih için
    FOR v_key, v_value IN SELECT key, value FROM jsonb_each_text(p_preferences)
    LOOP
        -- Tercihi güncelle veya ekle
        INSERT INTO public.guest_preferences (
            tenant_id,
            guest_id,
            preference_type,
            preference_value
        )
        VALUES (
            (SELECT tenant_id FROM public.guests WHERE id = p_guest_id),
            p_guest_id,
            v_key, -- Değişken kullanıldı
            v_value -- Değişken kullanıldı
        )
        ON CONFLICT (guest_id, preference_type) 
        DO UPDATE SET 
            preference_value = EXCLUDED.preference_value,
            updated_at = now();
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ======================================
-- Yeni Tetikleyiciler
-- ======================================

-- Rezervasyon durumu değişikliği tetikleyicisi
DROP TRIGGER IF EXISTS handle_reservation_status_change ON public.res_reservations;
CREATE TRIGGER handle_reservation_status_change
    AFTER UPDATE OF status ON public.res_reservations
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.handle_reservation_status_change();

-- Split-stay validasyon tetikleyicisi
DROP TRIGGER IF EXISTS validate_split_stay ON public.split_stay_segments;
CREATE TRIGGER validate_split_stay
    AFTER INSERT OR UPDATE ON public.split_stay_segments
    FOR EACH ROW
    EXECUTE PROCEDURE public.validate_split_stay_reservation();

-- ======================================
-- Trigger Tanımları
-- ======================================

-- handle_new_user trigger'ı (Supabase Auth hook'u)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Not: updated_at tetikleyicileri ilgili tabloların oluşturulduğu
-- migrasyon dosyalarında tanımlanmıştır. Bu dosyada tekrar tanımlanmaz.
