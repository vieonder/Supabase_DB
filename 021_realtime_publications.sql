-- ##########################################################
-- 021_realtime_publications.sql
-- Supabase Realtime için Yayın (Publication) Tanımları
-- ##########################################################

-- Supabase Realtime için varsayılan yayını oluştur/yapılandır.
-- Bu genellikle Supabase tarafından otomatik olarak yönetilir, ancak özel ihtiyaçlar için
-- buraya eklenebilir veya değiştirilebilir.

-- Örnek: Tüm public tablolardaki değişiklikleri yayınla (varsayılan olabilir)
-- DROP PUBLICATION IF EXISTS supabase_realtime;
-- CREATE PUBLICATION supabase_realtime FOR ALL TABLES;

-- Örnek: Sadece belirli tablolardaki değişiklikleri yayınla
DROP PUBLICATION IF EXISTS supabase_realtime;
CREATE PUBLICATION supabase_realtime;

-- Önemli veya sık güncellenen tabloları yayına ekle:

-- Rezervasyonlar
ALTER PUBLICATION supabase_realtime ADD TABLE public.res_reservations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.res_reservation_rooms;

-- Odalar ve Durumları
ALTER PUBLICATION supabase_realtime ADD TABLE public.hotels_rooms; -- Genel oda bilgisi/durumu
ALTER PUBLICATION supabase_realtime ADD TABLE public.hk_room_status_log; -- Housekeeping durumu (RFC_008) - Corrected table name

-- Görevler
ALTER PUBLICATION supabase_realtime ADD TABLE public.hk_tasks; -- Housekeeping görevleri (RFC_008) - Assignments are in this table via assigned_staff_id
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.hk_task_assignments; -- Removed non-existent table
ALTER PUBLICATION supabase_realtime ADD TABLE public.maintenance_work_orders; -- Bakım görevleri (RFC_008)

-- Misafir Talepleri (Eğer varsa)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.hk_guest_requests; -- Bu tablo şemada var mı kontrol edilmeli

-- Sohbet/Mesajlaşma (RFC_015, RFC_028)
--ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages; -- Tablo adı kontrol edilmeli

-- Bildirimler (RFC_029, RFC_028)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications; -- Temporarily commented out due to dependency order

-- Folyo İşlemleri (Performans/Güvenlik Değerlendirilmeli)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.folio_transactions; -- Tablo adı kontrol edilmeli

-- Fiyat ve Müsaitlik (Dikkat: Çok sık güncelleniyorsa performansı etkileyebilir, genellikle önerilmez)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.price_daily_rates;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.price_availability_rules;


-- Not: RLS politikaları, realtime üzerinden gönderilen veriler için de geçerlidir.
-- Kullanıcılar sadece görme yetkisi olan değişiklikleri alacaktır.
-- Ayrıca, REPLICA IDENTITY ayarları UPDATE/DELETE olayları için önemlidir.
