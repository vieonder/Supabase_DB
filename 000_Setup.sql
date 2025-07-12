-- ##########################################################
-- 000_setup.sql
-- PostgreSQL Eklentileri, Enum Tipleri ve Ortak Fonksiyonlar
-- ##########################################################

-- ======================================
-- EKLENTİLER
-- ======================================

-- UUID üretimi için
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;

-- Kriptografik fonksiyonlar için (örneğin şifreleme)
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA public;

-- ======================================
-- ENUM TİPLERİ
-- ======================================

-- Tenant Durumları
CREATE TYPE public.tenant_status AS ENUM ('active', 'inactive', 'suspended', 'pending');

-- Tenant Planları
CREATE TYPE public.tenant_plan AS ENUM ('basic', 'standard', 'premium', 'enterprise');

-- Oda Durumları
CREATE TYPE public.room_status AS ENUM ('available', 'occupied', 'dirty', 'cleaning', 'out_of_order', 'maintenance', 'blocked');

-- Rezervasyon Durumları
CREATE TYPE public.reservation_status AS ENUM ('pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled', 'no_show', 'waitlist');

-- Misafir Cinsiyet Seçenekleri
CREATE TYPE public.guest_gender AS ENUM ('male', 'female', 'other', 'prefer_not_to_say');

-- Misafir Kimlik Tipleri
CREATE TYPE public.guest_identity_type AS ENUM ('passport', 'national_id', 'driving_license');

-- Misafir VIP Statüleri
CREATE TYPE public.guest_vip_status AS ENUM ('none', 'silver', 'gold', 'platinum');

-- Adres Tipleri
CREATE TYPE public.address_type AS ENUM ('home', 'work', 'billing', 'other');

-- Tercih Tipleri
CREATE TYPE public.preference_type AS ENUM ('room_type', 'pillow', 'bed', 'newspaper', 'allergy', 'other');

-- Misafir Belge Tipleri
CREATE TYPE public.document_type AS ENUM ('passport', 'national_id', 'driving_license', 'visa', 'other');

-- Misafir Not Tipleri
CREATE TYPE public.note_type AS ENUM ('general', 'preference', 'complaint', 'special_request', 'alert');

-- Misafir İletişim Tipleri
CREATE TYPE public.communication_type AS ENUM ('email', 'sms', 'phone', 'in_person', 'letter');

-- İletişim Yönü
CREATE TYPE public.communication_direction AS ENUM ('inbound', 'outbound');

-- İletişim Durumu
CREATE TYPE public.communication_status AS ENUM ('draft', 'scheduled', 'sent', 'delivered', 'opened', 'clicked', 'failed');

-- Misafir Hesap Durumu
CREATE TYPE public.account_status AS ENUM ('active', 'inactive', 'pending', 'locked');

-- Misafir İlişki Tipleri
CREATE TYPE public.relationship_type AS ENUM ('spouse', 'child', 'parent', 'sibling', 'friend', 'colleague', 'other');

-- Housekeeping Görev Durumları
CREATE TYPE public.hk_task_status AS ENUM ('pending', 'in_progress', 'completed', 'cancelled', 'on_hold');

-- Housekeeping Envanter İşlem Tipleri
CREATE TYPE public.hk_inventory_transaction_type AS ENUM ('issue', 'return', 'adjustment', 'disposal');

-- Housekeeping Denetim Durumları
CREATE TYPE public.hk_inspection_status AS ENUM ('passed', 'failed', 'pending');

-- Bakım İş Emri Durumları
CREATE TYPE public.maintenance_work_order_status AS ENUM ('open', 'in_progress', 'on_hold', 'completed', 'cancelled', 'closed');

-- Bakım Parça İşlem Tipleri
CREATE TYPE public.maintenance_parts_transaction_type AS ENUM ('receive', 'issue', 'return', 'adjustment', 'disposal');

-- Envanter Hareket Tipleri
CREATE TYPE public.inventory_movement_type AS ENUM ('inbound', 'outbound', 'adjustment', 'transfer', 'consumption', 'loss', 'return');

-- Ödeme Durumları
CREATE TYPE public.payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded', 'partially_refunded', 'cancelled', 'authorized');

-- Fatura Durumları
CREATE TYPE public.invoice_status AS ENUM ('draft', 'sent', 'paid', 'partially_paid', 'overdue', 'voided', 'cancelled');

-- Ekstra Ücret Tipleri
CREATE TYPE public.extra_charge_type AS ENUM ('per_stay', 'per_night', 'per_person', 'per_item');

-- Sadakat İşlem Tipleri
CREATE TYPE public.loyalty_transaction_type AS ENUM ('earn_points', 'redeem_points', 'adjust_points', 'expire_points', 'transfer_points', 'bonus_points');

-- İçerik Durumları
CREATE TYPE public.content_status AS ENUM ('draft', 'published', 'archived', 'pending_review', 'scheduled');

-- İzin Durumları
CREATE TYPE public.consent_status AS ENUM ('granted', 'denied', 'expired', 'revoked');

-- Günlük Seviyeleri
CREATE TYPE public.log_level AS ENUM ('debug', 'info', 'warning', 'error', 'critical', 'audit');

-- ======================================
-- ORTAK FONKSİYONLAR
-- ======================================

-- updated_at sütununu otomatik güncellemek için fonksiyon
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = now();
   RETURN NEW;
END;
$$ language 'plpgsql';

-- Benzersiz, okunabilir rezervasyon referansı oluşturma fonksiyonu
CREATE OR REPLACE FUNCTION public.generate_booking_reference(prefix TEXT DEFAULT 'BK', len INT DEFAULT 8)
RETURNS TEXT AS $$
DECLARE
    chars TEXT[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z}';
    result TEXT := prefix;
    i INT := 0;
    random_int INT;
BEGIN
    -- İstenen uzunlukta rastgele karakterler ekle
    FOR i IN 1..len LOOP
        -- 0 ile chars dizisinin uzunluğu-1 arasında rastgele bir tamsayı al
        random_int := floor(random() * array_length(chars, 1))::int + 1;
        result := result || chars[random_int];
    END LOOP;

    -- Referansın benzersizliğini kontrol et (res_reservations tablosu varsa)
    -- Bu kontrolü ilgili trigger veya tablo tanımına taşımak daha iyi olabilir.
    -- IF EXISTS (SELECT 1 FROM public.res_reservations WHERE booking_reference = result) THEN
    --    RETURN public.generate_booking_reference(prefix, len); -- Tekrar dene
    -- END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql VOLATILE;
