-- ##########################################################
-- 003_guests_and_crm.sql
-- Misafir Kayıtları ve CRM Tabloları
-- ##########################################################

-- ======================================
-- Misafir Kayıtları (Güncellenmiş Model)
-- ======================================

-- Misafirler tablosu (Tenant bazlı misafir kaydı)
CREATE TABLE public.guests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_profile_id UUID REFERENCES public.user_profiles(user_id) ON DELETE SET NULL, -- Sisteme kayıtlı kullanıcı profili (opsiyonel)
    first_name TEXT NOT NULL CHECK (length(trim(first_name)) >= 1),
    last_name TEXT NOT NULL CHECK (length(trim(last_name)) >= 1),
    full_name TEXT GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    date_of_birth DATE CHECK (date_of_birth <= CURRENT_DATE),
    gender public.guest_gender,
    identity_type public.guest_identity_type,
    identity_number TEXT, -- Şifreleme eklenebilir (pgcrypto ile)
    nationality TEXT,
    email TEXT CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
    phone TEXT CHECK (phone IS NULL OR phone ~ '^\\+?[0-9\\s-\\(-\\)]{6,}$'),
    preferred_language TEXT DEFAULT 'tr',
    vip_status public.guest_vip_status DEFAULT 'none',
    notes TEXT, -- Genel misafir notları
    blacklist_reason TEXT, -- Kara listeye alınma sebebi (NULL değilse kara listede)
    privacy_consent BOOLEAN DEFAULT false,
    marketing_consent BOOLEAN DEFAULT false,
    -- Şirket ve grup bilgileri (guest_profiles yerine)
    company_name TEXT,
    company_tax_id TEXT,
    company_tax_office TEXT,
    company_invoice_address JSONB,
    group_identifier TEXT, -- Grup rezervasyonları için opsiyonel tanımlayıcı
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    -- E-posta veya kimlik numarası ile tenant içinde benzersizlik (opsiyonel, veri kalitesine bağlı)
    -- UNIQUE(tenant_id, email),
    CONSTRAINT company_info_consistency CHECK (
        (company_name IS NULL AND company_tax_id IS NULL AND company_tax_office IS NULL AND company_invoice_address IS NULL) OR
        (company_name IS NOT NULL AND company_tax_id IS NOT NULL AND company_tax_office IS NOT NULL AND company_invoice_address IS NOT NULL)
    )
);

-- Kısmi benzersiz index tanımı (WHERE ile)
CREATE UNIQUE INDEX guests_partial_unique_identity_idx
ON public.guests (tenant_id, identity_type, identity_number)
WHERE identity_number IS NOT NULL AND identity_type IS NOT NULL;

-- Misafir adresleri
CREATE TABLE public.guest_addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    guest_id UUID NOT NULL REFERENCES public.guests(id) ON DELETE CASCADE, -- Misafire bağlı
    address_type public.address_type DEFAULT 'home',
    primary_address BOOLEAN DEFAULT false,
    address_line1 TEXT NOT NULL,
    address_line2 TEXT,
    city TEXT NOT NULL,
    state TEXT,
    postal_code TEXT,
    country TEXT NOT NULL,
    country_code CHAR(2),
    geo_location JSONB, -- {lat: x, lng: y}
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- CRM - Misafir Detayları
-- ======================================

-- Misafir tercihleri
CREATE TABLE public.guest_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    guest_id UUID NOT NULL REFERENCES public.guests(id) ON DELETE CASCADE,
    preference_type public.preference_type NOT NULL,
    preference_value TEXT NOT NULL,
    preference_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(guest_id, preference_type)
);

-- Misafir belgeleri
CREATE TABLE public.guest_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    guest_id UUID NOT NULL REFERENCES public.guests(id) ON DELETE CASCADE,
    document_type public.document_type NOT NULL,
    document_number TEXT NOT NULL,
    issuing_country TEXT NOT NULL,
    issue_date DATE,
    expiry_date DATE CHECK (expiry_date IS NULL OR issue_date IS NULL OR expiry_date > issue_date),
    document_scan_url TEXT, -- Taranmış belge URL'si (Storage'da)
    verification_status TEXT CHECK (verification_status IN ('pending', 'verified', 'rejected')),
    verification_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(guest_id, document_type, document_number)
);

-- Misafir notları (Personel tarafından eklenen)
CREATE TABLE public.guest_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    guest_id UUID NOT NULL REFERENCES public.guests(id) ON DELETE CASCADE,
    note_type public.note_type DEFAULT 'general',
    note_title TEXT,
    note_content TEXT NOT NULL,
    is_important BOOLEAN DEFAULT false,
    is_private BOOLEAN DEFAULT true, -- Sadece belirli roller mi görebilir?
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Misafir ilişkileri (Aile, arkadaş, iş vb.)
CREATE TABLE public.guest_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    guest_id UUID NOT NULL REFERENCES public.guests(id) ON DELETE CASCADE,
    related_guest_id UUID NOT NULL REFERENCES public.guests(id) ON DELETE CASCADE,
    relationship_type public.relationship_type NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CHECK (guest_id <> related_guest_id),
    UNIQUE(guest_id, related_guest_id, relationship_type)
);

-- ======================================
-- Anonim Kullanıcı Eşleştirme
-- ======================================

CREATE TABLE public.user_anonymous_map (
    anonymous_user_id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id) -- Bir kullanıcı sadece bir anonim ID ile eşleşmeli
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

-- Not: `updated_at` tetikleyicileri `016_functions_and_triggers.sql` dosyasına taşınmıştır.

-- guests tablosu için foreign key referansını ekle (guest_profiles oluşturulduktan sonra)
-- ALTER TABLE public.guests
-- ADD CONSTRAINT fk_guests_guest_profile FOREIGN KEY (id) REFERENCES public.guest_profiles(primary_guest_id) DEFERRABLE INITIALLY DEFERRED;
-- Bu FK ilişkisi gözden geçirilmeli, guest_profiles tablosunun yapısına göre güncellenmeli veya kaldırılmalı.
-- --> guest_profiles tablosu kaldırıldığı için bu yorum satırı da kaldırıldı.
