-- ##########################################################
-- 018_views_and_materialized_views.sql
-- Veri Erişimini Kolaylaştıran View'lar ve Materyalize View'lar
-- ##########################################################

-- ======================================
-- Basit View'lar (Örnekler)
-- ======================================

-- Aktif Rezervasyonlar View'ı
CREATE OR REPLACE VIEW public.view_active_reservations AS
SELECT
    -- Sütunlar r.* yerine açıkça listelendi
    r.id,
    r.tenant_id,
    r.hotel_id,
    r.guest_id,
    r.booking_reference,
    r.check_in_date,
    r.check_out_date,
    r.status,
    r.total_amount,
    (r.total_amount - r.paid_amount) as balance_due,
    r.paid_amount,
    r.adults,
    r.children,
    r.rate_plan_id,
    r.guest_notes,
    r.special_requests,
    r.estimated_arrival_time,
    r.created_at,
    r.updated_at,
    -- Diğer tablolardan sütunlar
    g.full_name as guest_name,
    g.email as guest_email,
    h.name as hotel_name,
    (SELECT string_agg(rc.name, ', ')
     FROM public.res_reservation_rooms rrr
     JOIN public.hotels_room_categories rc ON rrr.room_category_id = rc.id
     WHERE rrr.reservation_id = r.id) as room_categories
FROM public.res_reservations r
JOIN public.hotels h ON r.hotel_id = h.id
LEFT JOIN public.guests g ON r.guest_id = g.id
WHERE r.tenant_id = public.get_tenant_id() -- RLS için tenant kontrolü
  AND r.status IN ('confirmed', 'checked_in');

-- Beklenen Varışlar View'ı (Bugün)
CREATE OR REPLACE VIEW public.view_expected_arrivals_today AS
SELECT r.id as reservation_id,
       r.booking_reference,
       r.check_in_date,
       r.adults,
       r.children,
       g.full_name as guest_name,
       g.phone as guest_phone,
       rr.id as reservation_room_id,
       rc.name as room_category_name,
       assigned_room.room_number as assigned_room_number,
       r.estimated_arrival_time,
       r.guest_notes as reservation_notes,
       r.special_requests
FROM public.res_reservations r
JOIN public.res_reservation_rooms rr ON r.id = rr.reservation_id AND rr.check_in_date = r.check_in_date -- Sadece ilk segmenti al (split stay için)
JOIN public.hotels_room_categories rc ON rr.room_category_id = rc.id
LEFT JOIN public.guests g ON r.guest_id = g.id
LEFT JOIN public.hotels_rooms assigned_room ON rr.room_id = assigned_room.id
WHERE r.tenant_id = public.get_tenant_id() -- RLS için tenant kontrolü
  AND r.status = 'confirmed'
  AND r.check_in_date = CURRENT_DATE;

-- Beklenen Ayrılışlar View'ı (Bugün)
CREATE OR REPLACE VIEW public.view_expected_departures_today AS
SELECT r.id as reservation_id,
       r.booking_reference,
       r.check_out_date,
       g.full_name as guest_name,
       rr.id as reservation_room_id,
       rc.name as room_category_name,
       assigned_room.room_number as assigned_room_number,
       r.total_amount,
       (r.total_amount - r.paid_amount) as balance_due
FROM public.res_reservations r
JOIN public.res_reservation_rooms rr ON r.id = rr.reservation_id AND rr.check_out_date = r.check_out_date -- Sadece son segmenti al (split stay için)
JOIN public.hotels_room_categories rc ON rr.room_category_id = rc.id
LEFT JOIN public.guests g ON r.guest_id = g.id
LEFT JOIN public.hotels_rooms assigned_room ON rr.room_id = assigned_room.id
WHERE r.tenant_id = public.get_tenant_id() -- RLS için tenant kontrolü
  AND r.status = 'checked_in'
  AND r.check_out_date = CURRENT_DATE;

-- Oda Durum Panosu View'ı
CREATE OR REPLACE VIEW public.view_room_status_dashboard AS
SELECT r.id as room_id,
       r.room_number,
       r.floor,
       rc.name as category_name,
       r.status as room_status,
       res.id as current_reservation_id,
       res.check_in_date as current_check_in,
       res.check_out_date as current_check_out,
       current_guest.full_name as current_guest_name,
       next_res.id as next_reservation_id,
       next_res.check_in_date as next_arrival_date,
       hk_task.id as hk_task_id,
       hk_task.task_type as hk_task_type,
       hk_task.status as hk_task_status
FROM public.hotels_rooms r
JOIN public.hotels_room_categories rc ON r.category_id = rc.id
-- Aktif konaklama bilgisi
LEFT JOIN public.res_reservation_rooms rr_current ON rr_current.room_id = r.id AND CURRENT_DATE BETWEEN rr_current.check_in_date AND rr_current.check_out_date - INTERVAL '1 day'
LEFT JOIN public.res_reservations res ON rr_current.reservation_id = res.id AND res.status = 'checked_in'
LEFT JOIN public.guests current_guest ON res.guest_id = current_guest.id
-- Sonraki rezervasyon bilgisi
LEFT JOIN (
    -- Her oda için en erken check-in tarihli gelecek rezervasyonu bul
    SELECT DISTINCT ON (rr_next.room_id) rr_next.room_id, res_next.id as next_res_id
    FROM public.res_reservation_rooms rr_next
    JOIN public.res_reservations res_next ON rr_next.reservation_id = res_next.id
    WHERE res_next.status IN ('confirmed', 'pending') AND res_next.check_in_date >= CURRENT_DATE
    ORDER BY rr_next.room_id, res_next.check_in_date ASC -- En erken tarihi seçmek için sırala
) next_booking ON next_booking.room_id = r.id
LEFT JOIN public.res_reservations next_res ON next_booking.next_res_id = next_res.id
-- Açık housekeeping görevi
LEFT JOIN public.hk_tasks hk_task ON hk_task.room_id = r.id AND hk_task.status IN ('pending', 'in_progress')
WHERE r.tenant_id = public.get_tenant_id(); -- RLS için tenant kontrolü

-- ======================================
-- Materyalize View'lar (Performans için Örnekler)
-- ======================================
-- Not: Materyalize view'ların periyodik olarak REFRESH edilmesi gerekir.

-- Otel Doluluk Oranları (Materyalize)
-- CREATE MATERIALIZED VIEW public.mview_hotel_occupancy_trends AS
-- SELECT
--     h.id as hotel_id,
--     h.name as hotel_name,
--     d.date,
--     COUNT(DISTINCT r.id) as total_rooms,
--     SUM(CASE WHEN pdr.is_closed = false AND r.status != 'out_of_order' THEN 1 ELSE 0 END) as available_rooms,
--     SUM(CASE WHEN res_room.id IS NOT NULL THEN 1 ELSE 0 END) as occupied_rooms,
--     ROUND((SUM(CASE WHEN res_room.id IS NOT NULL THEN 1 ELSE 0 END)::numeric * 100) /
--           NULLIF(SUM(CASE WHEN pdr.is_closed = false AND r.status != 'out_of_order' THEN 1 ELSE 0 END), 0), 2) as occupancy_rate
-- FROM public.hotels h
-- CROSS JOIN generate_series(CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE, '1 day')::date d(date)
-- JOIN public.hotels_rooms r ON r.hotel_id = h.id
-- LEFT JOIN public.price_daily_rates pdr ON pdr.hotel_id = h.id AND pdr.room_category_id = r.category_id AND pdr.date = d.date
-- LEFT JOIN public.res_reservation_rooms res_room ON res_room.room_id = r.id AND d.date BETWEEN res_room.check_in_date AND res_room.check_out_date - INTERVAL '1 day'
-- LEFT JOIN public.res_reservations res ON res_room.reservation_id = res.id AND res.status IN ('checked_in', 'confirmed') -- Duruma göre değişebilir
-- WHERE h.tenant_id = public.get_tenant_id() -- Tenant kontrolü
-- GROUP BY h.id, h.name, d.date
-- ORDER BY h.name, d.date;

-- Materyalize View'ı Yenileme Fonksiyonu (Örnek)
-- CREATE OR REPLACE FUNCTION refresh_occupancy_trends()
-- RETURNS void AS $$
-- BEGIN
--     REFRESH MATERIALIZED VIEW CONCURRENTLY public.mview_hotel_occupancy_trends;
-- END;
-- $$ LANGUAGE plpgsql;

-- Not: View ve Materyalize View tanımları, RLS politikaları etkinleştirildikten sonra
-- çalıştırıldığında, view'ı oluşturan kullanıcının izinlerine tabi olabilir.
-- SECURITY DEFINER veya SECURITY INVOKER kullanımı dikkatlice değerlendirilmelidir.
