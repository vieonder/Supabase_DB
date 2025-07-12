-- ##########################################################
-- 015_analytics_and_reporting.sql
-- Analiz ve Raporlama için Özet Tablolar/Yapılar
-- Not: Karmaşık view'lar 018_views_and_materialized_views.sql'e taşınabilir.
-- ##########################################################

-- ======================================
-- Günlük Özetler (Daily Summaries)
-- ======================================

-- Günlük Doluluk ve Gelir Özeti (Otel Bazlı)
CREATE TABLE public.analytics_daily_hotel_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    summary_date DATE NOT NULL,
    total_rooms INTEGER,
    available_rooms INTEGER,
    occupied_rooms INTEGER,
    out_of_order_rooms INTEGER,
    occupancy_rate NUMERIC(5, 2), -- (occupied / available)
    total_arrivals INTEGER,
    total_departures INTEGER,
    total_room_revenue NUMERIC(14, 2),
    total_fb_revenue NUMERIC(14, 2),
    total_other_revenue NUMERIC(14, 2),
    total_revenue NUMERIC(14, 2),
    adr NUMERIC(10, 2), -- Average Daily Rate (total_room_revenue / occupied_rooms)
    revpar NUMERIC(10, 2), -- Revenue Per Available Room (total_room_revenue / available_rooms)
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(), -- Periyodik olarak güncellenecek
    UNIQUE (hotel_id, summary_date)
);

-- Günlük Oda Kategorisi Özeti
CREATE TABLE public.analytics_daily_room_category_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    room_category_id UUID NOT NULL REFERENCES public.hotels_room_categories(id) ON DELETE CASCADE,
    summary_date DATE NOT NULL,
    total_rooms_in_category INTEGER,
    available_rooms INTEGER,
    occupied_rooms INTEGER,
    occupancy_rate NUMERIC(5, 2),
    total_revenue NUMERIC(12, 2),
    adr NUMERIC(10, 2),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (room_category_id, summary_date)
);

-- Günlük Rezervasyon Kanalı Özeti
CREATE TABLE public.analytics_daily_channel_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    summary_date DATE NOT NULL,
    booking_channel TEXT NOT NULL,
    total_bookings INTEGER,
    total_room_nights INTEGER,
    total_revenue NUMERIC(14, 2),
    avg_lead_time_days NUMERIC(8, 2),
    cancellation_count INTEGER,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, summary_date, booking_channel)
);

-- ======================================
-- Misafir Analitikleri
-- ======================================

-- Misafir Segmentasyon Özeti
CREATE TABLE public.analytics_guest_segment_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    segment_id UUID REFERENCES public.personalization_segments(id) ON DELETE CASCADE,
    segment_name TEXT,
    guest_count INTEGER,
    total_stays INTEGER,
    total_nights INTEGER,
    total_spend NUMERIC(16, 2),
    avg_spend_per_stay NUMERIC(12, 2),
    last_calculated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, segment_id)
);

-- Misafir Yaşam Boyu Değeri (LTV) - Basit
CREATE TABLE public.analytics_guest_ltv (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    guest_id UUID UNIQUE NOT NULL REFERENCES public.guests(id) ON DELETE CASCADE,
    first_stay_date DATE,
    last_stay_date DATE,
    total_stays INTEGER,
    total_nights INTEGER,
    total_spend NUMERIC(16, 2),
    avg_spend_per_stay NUMERIC(12, 2),
    avg_nights_per_stay NUMERIC(6, 2),
    preferred_room_category_id UUID REFERENCES public.hotels_room_categories(id) ON DELETE SET NULL,
    last_calculated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- Web Analitikleri (Basit Özetler)
-- ======================================

-- Web Sitesi Trafik Özeti (Günlük)
CREATE TABLE public.analytics_website_traffic_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    summary_date DATE NOT NULL,
    total_sessions INTEGER,
    unique_visitors INTEGER,
    page_views INTEGER,
    avg_session_duration_seconds INTEGER,
    bounce_rate NUMERIC(5, 2),
    top_referrers JSONB, -- {"google.com": 100, "facebook.com": 50}
    top_pages JSONB, -- {"/booking": 500, "/rooms/suite": 200}
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, summary_date)
);

-- Rezervasyon Motoru Dönüşüm Hunisi (Funnel)
CREATE TABLE public.analytics_booking_funnel_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    summary_period TEXT NOT NULL, -- 'daily', 'weekly', 'monthly'
    period_start_date DATE NOT NULL,
    period_end_date DATE NOT NULL,
    step_search_initiated INTEGER, -- Arama başlatanlar
    step_results_viewed INTEGER, -- Sonuçları görenler
    step_room_details_viewed INTEGER, -- Oda detayını görenler
    step_checkout_started INTEGER, -- Ödeme adımına geçenler
    step_booking_completed INTEGER, -- Rezervasyonu tamamlayanlar
    overall_conversion_rate NUMERIC(5, 2), -- (completed / initiated)
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, period_start_date, summary_period)
);

-- ======================================
-- Raporlama için Basit View'lar (Örnekler)
-- Not: Bunlar 018'e taşınabilir.
-- ======================================

-- Aktif Rezervasyonlar View'ı
-- CREATE OR REPLACE VIEW public.view_active_reservations AS
-- SELECT r.*, g.full_name as guest_name, g.email as guest_email, h.name as hotel_name
-- FROM public.res_reservations r
-- JOIN public.hotels h ON r.hotel_id = h.id
-- LEFT JOIN public.guests g ON r.guest_id = g.id
-- WHERE r.status IN ('confirmed', 'checked_in');

-- Beklenen Varışlar View'ı
-- CREATE OR REPLACE VIEW public.view_expected_arrivals AS
-- SELECT r.id as reservation_id, r.booking_reference, r.check_in_date, r.number_of_adults, r.number_of_children,
--        g.full_name as guest_name, rr.room_category_id, rc.name as room_category_name, r.estimated_arrival_time
-- FROM public.res_reservations r
-- JOIN public.res_reservation_rooms rr ON r.id = rr.reservation_id
-- JOIN public.hotels_room_categories rc ON rr.room_category_id = rc.id
-- LEFT JOIN public.guests g ON r.guest_id = g.id
-- WHERE r.status = 'confirmed' AND r.check_in_date = CURRENT_DATE;

-- ======================================
-- TETİKLEYİCİLER (Özet Tabloların Güncellenmesi İçin)
-- Not: Bu tablolar genellikle periyodik olarak (örn: gece çalışan bir iş ile) veya trigger'lar ile güncellenir.
-- Trigger kullanımı performansı etkileyebilir, dikkatli olunmalıdır.
-- ======================================

CREATE TRIGGER trg_analytics_daily_hotel_summary_updated_at
BEFORE UPDATE ON public.analytics_daily_hotel_summary
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_analytics_daily_room_category_summary_updated_at
BEFORE UPDATE ON public.analytics_daily_room_category_summary
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_analytics_daily_channel_summary_updated_at
BEFORE UPDATE ON public.analytics_daily_channel_summary
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_analytics_guest_segment_summary_updated_at
BEFORE UPDATE ON public.analytics_guest_segment_summary
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_analytics_guest_ltv_updated_at
BEFORE UPDATE ON public.analytics_guest_ltv
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_analytics_website_traffic_summary_updated_at
BEFORE UPDATE ON public.analytics_website_traffic_summary
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_analytics_booking_funnel_summary_updated_at
BEFORE UPDATE ON public.analytics_booking_funnel_summary
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
