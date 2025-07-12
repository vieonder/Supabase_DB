-- ##########################################################
-- 014_consent_management.sql
-- Kullanıcı/Misafir İzin Yönetimi Tabloları (KVKK/GDPR)
-- ##########################################################

-- ======================================
-- İzin Tanımları (Consent Types)
-- ======================================

CREATE TABLE public.consent_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    consent_key TEXT NOT NULL, -- 'marketing_email', 'personalization', 'cookies_analytics', 'terms_and_conditions'
    name TEXT NOT NULL, -- İzin adı (kullanıcıya gösterilecek)
    description TEXT NOT NULL, -- İzin açıklaması (detaylı)
    version INTEGER DEFAULT 1, -- İzin metni versiyonu
    is_mandatory BOOLEAN DEFAULT false, -- Bu izin zorunlu mu?
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, consent_key, version)
);

-- ======================================
-- Kullanıcıların verdiği onaylar
-- ======================================

CREATE TABLE public.consent_user_consents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    consent_type_id UUID NOT NULL REFERENCES public.consent_types(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    guest_id UUID REFERENCES public.guests(id) ON DELETE CASCADE,
    anonymous_user_id TEXT, -- Takip edilen anonim kullanıcı ID'si
    status public.consent_status NOT NULL, -- 'granted', 'denied', 'revoked', 'pending'. DEFAULT kaldırıldı, uygulama atamalı.
    granted_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    denied_at TIMESTAMPTZ,
    consent_source TEXT, -- 'website_popup', 'user_profile', 'booking_process'
    ip_address INET,
    user_agent TEXT,
    version_granted INTEGER, -- Onay verilen consent_types versiyonu
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    -- Bir kullanıcı/misafir/anonim ID belirtilmeli
    CHECK (
        (user_id IS NOT NULL AND guest_id IS NULL AND anonymous_user_id IS NULL) OR
        (user_id IS NULL AND guest_id IS NOT NULL AND anonymous_user_id IS NULL) OR
        (user_id IS NULL AND guest_id IS NULL AND anonymous_user_id IS NOT NULL)
    )
    -- UNIQUE kısıtlamaları CREATE INDEX ile aşağıda tanımlanacak
);

-- Status sütunu için DEFAULT değeri sonradan ekleniyor - KALDIRILDI.

-- Koşullu Benzersiz İndeksler (Partial Unique Indexes)
CREATE UNIQUE INDEX idx_unique_user_consent ON public.consent_user_consents (consent_type_id, user_id) WHERE user_id IS NOT NULL;
CREATE UNIQUE INDEX idx_unique_guest_consent ON public.consent_user_consents (consent_type_id, guest_id) WHERE guest_id IS NOT NULL;
CREATE UNIQUE INDEX idx_unique_anon_consent ON public.consent_user_consents (consent_type_id, anonymous_user_id) WHERE anonymous_user_id IS NOT NULL;

-- ======================================
-- Veri Sahibi Hakları Talepleri (DSR - Data Subject Rights)
-- ======================================

CREATE TABLE public.consent_dsr_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    request_type TEXT NOT NULL, -- 'access', 'rectification', 'erasure', 'portability', 'restriction', 'objection'
    requester_email TEXT CHECK (requester_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
    requester_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    requester_guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    request_details TEXT,
    status TEXT DEFAULT 'pending', -- 'pending', 'in_progress', 'completed', 'rejected', 'on_hold'
    requested_at TIMESTAMPTZ DEFAULT now(),
    due_date DATE, -- Yanıt için son tarih
    completed_at TIMESTAMPTZ,
    assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Talebi işleyen kişi
    resolution_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- DSR Talepleri ile İlgili Loglar
CREATE TABLE public.consent_dsr_request_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID NOT NULL REFERENCES public.consent_dsr_requests(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Logu oluşturan kullanıcı
    action TEXT NOT NULL, -- 'created', 'assigned', 'status_changed', 'notes_added', 'completed'
    details JSONB,
    log_time TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

CREATE TRIGGER trg_consent_types_updated_at
BEFORE UPDATE ON public.consent_types
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_consent_user_consents_updated_at
BEFORE UPDATE ON public.consent_user_consents
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_consent_dsr_requests_updated_at
BEFORE UPDATE ON public.consent_dsr_requests
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- consent_dsr_request_logs için updated_at genellikle gereksizdir.
