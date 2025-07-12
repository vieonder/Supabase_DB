-- ##########################################################
-- 007_communications.sql
-- İletişim Şablonları ve Misafir İletişim Geçmişi
-- ##########################################################

-- ======================================
-- İletişim Şablonları
-- ======================================
CREATE TABLE public.communication_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    template_name TEXT NOT NULL,
    template_type public.communication_type NOT NULL, -- email, sms
    subject TEXT, -- E-posta için konu
    body_html TEXT, -- E-posta için HTML içerik
    body_text TEXT, -- E-posta (alternatif) veya SMS için metin içerik
    language_code TEXT DEFAULT 'tr',
    variables JSONB, -- Şablonda kullanılabilecek değişkenler (örn: {{guest_name}}, {{booking_reference}})
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, template_name, language_code)
);

-- ======================================
-- Misafir İletişim Geçmişi
-- ======================================

-- Misafir iletişim geçmişi
CREATE TABLE public.guest_communications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    guest_id UUID NOT NULL REFERENCES public.guests(id) ON DELETE CASCADE,
    comm_type public.communication_type NOT NULL,
    direction public.communication_direction NOT NULL,
    subject TEXT,
    content TEXT,
    template_id UUID REFERENCES public.communication_templates(id) ON DELETE SET NULL, -- Kullanılan şablon ID'si
    channel_id TEXT, -- Hangi kanal üzerinden (e-posta adresi, telefon numarası vb.)
    status public.communication_status,
    scheduled_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    response_received_at TIMESTAMPTZ,
    related_reservation_id UUID REFERENCES public.res_reservations(id) ON DELETE SET NULL, -- `res_reservations` 003'te tanımlandı
    metadata JSONB,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

CREATE TRIGGER trg_communication_templates_updated_at
BEFORE UPDATE ON public.communication_templates
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Not: guest_communications için updated_at trigger'ı 017'de eklenecek.

-- Not: Eğer `template_id` için ayrı bir `communication_templates` tablosu varsa,
-- o tablonun da bu dosyadan ÖNCE veya SONRA uygun bir migration dosyasında tanımlanması gerekir.
-- --> ÖNCE tanımlandı.
-- Enum tipleri (`communication_type`, `communication_direction`, `communication_status`)
-- `000_setup.sql` dosyasında tanımlanmış olmalıdır. 