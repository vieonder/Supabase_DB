-- ##########################################################
-- 001_tenants_and_auth.sql
-- Tenant, Kullanıcı Profilleri ve Yetkilendirme Tabloları
-- ##########################################################

-- ======================================
-- Tenant Yönetimi
-- ======================================

-- Tenant tablosu
CREATE TABLE public.tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    subdomain TEXT UNIQUE NOT NULL, -- Yönetim paneli/API erişimi için (örn: viecappadocia)
    website_domain TEXT UNIQUE,     -- Müşterinin web sitesi için özel alan adı (örn: www.viecappadocia.com)
    logo_url TEXT,
    status public.tenant_status DEFAULT 'active',
    plan public.tenant_plan DEFAULT 'standard',
    max_hotels INTEGER DEFAULT 3,
    contact_name TEXT,
    contact_email TEXT NOT NULL,
    contact_phone TEXT,
    billing_email TEXT CHECK (billing_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
    billing_address JSONB,
    tax_id TEXT,
    company_name TEXT,
    subscription_id TEXT,
    subscription_status TEXT,
    subscription_start_date DATE,
    subscription_end_date DATE,
    commission_rate_percentage NUMERIC(5, 2) DEFAULT 0.00 CHECK (commission_rate_percentage >= 0 AND commission_rate_percentage <= 100),
    trial_ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Tenant Üyelikleri (Güncellenmiş)
CREATE TABLE public.tenant_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL, -- Enum yerine TEXT kullanılıyor
    permissions JSONB, -- Role ek olarak özel izinler
    hotel_ids UUID[], -- Erişebileceği oteller, NULL veya {} ise hepsi
    invite_status TEXT DEFAULT 'accepted',
    invited_by UUID REFERENCES auth.users(id),
    invited_at TIMESTAMPTZ DEFAULT now(),
    joined_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, user_id)
);

-- Tenant Ayarları
CREATE TABLE public.tenant_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    setting_key TEXT NOT NULL,
    setting_value JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, setting_key)
);

-- ======================================
-- Kullanıcı Profilleri (Güncellenmiş)
-- ======================================
-- public.users tablosu kaldırıldı, auth.users doğrudan kullanılıyor.

-- Kullanıcı profilleri (Tenant'tan bağımsız)
CREATE TABLE public.user_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    full_name TEXT GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    avatar_url TEXT,
    title TEXT,
    language TEXT DEFAULT 'tr',
    theme TEXT DEFAULT 'light',
    timezone TEXT DEFAULT 'Europe/Istanbul',
    preferences JSONB DEFAULT '{}', -- Genel UI tercihleri
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- Yetkilendirme (Auth)
-- ======================================

-- Kullanıcı Rolleri (Tenant Bazlı)
CREATE TABLE public.auth_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    role_name TEXT NOT NULL,
    description TEXT,
    is_system_role BOOLEAN DEFAULT false,
    -- permissions JSONB NOT NULL DEFAULT '{}', -- İzinler artık tenant_members veya auth_role_permissions'da
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, role_name)
);

-- Kullanıcı İzinleri (Tenant Bazlı)
CREATE TABLE public.auth_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    permission_name TEXT NOT NULL, -- Örn: 'manage:reservations', 'view:reports'
    description TEXT,
    resource_type TEXT, -- Örn: 'reservations', 'guests', 'settings'
    action TEXT, -- Örn: 'create', 'read', 'update', 'delete', 'list'
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, permission_name)
);

-- Role Verilen İzinler
CREATE TABLE public.auth_role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    role_id UUID REFERENCES public.auth_roles(id) ON DELETE CASCADE NOT NULL,
    permission_id UUID REFERENCES public.auth_permissions(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, role_id, permission_id)
);

-- Kullanıcıya Doğrudan Verilen İzinler (tenant_members tablosu bunun yerine kullanılabilir)
-- Bu tablo, rol bazlı yetkilendirme modelini karmaşıklaştırabilir. Şimdilik yorum satırı yapıldı.
-- CREATE TABLE public.auth_user_permissions (
--     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--     tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
--     user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
--     permission_id UUID REFERENCES public.auth_permissions(id) ON DELETE CASCADE NOT NULL,
--     hotel_id UUID REFERENCES public.hotels(id) ON DELETE CASCADE,
--     granted_by UUID REFERENCES auth.users(id),
--     created_at TIMESTAMPTZ DEFAULT now(),
--     UNIQUE(tenant_id, user_id, permission_id, hotel_id)
-- );

-- API Anahtarları (Tenant Bazlı)
CREATE TABLE public.auth_api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Hangi kullanıcı oluşturdu
    key_name TEXT NOT NULL,
    key_prefix VARCHAR(8) UNIQUE NOT NULL, -- İlk 8 karakteri gösterilecek
    hashed_key TEXT NOT NULL, -- Tam anahtarın hash'i
    permissions JSONB NOT NULL DEFAULT '{}', -- Bu anahtarın sahip olduğu izinler
    last_used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Oturum Kayıtları (İsteğe bağlı, Supabase kendi yönetiyor olabilir)
-- CREATE TABLE public.auth_sessions (
--     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--     tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
--     user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
--     session_token TEXT NOT NULL,
--     expires_at TIMESTAMPTZ NOT NULL,
--     ip_address INET,
--     user_agent TEXT,
--     login_at TIMESTAMPTZ DEFAULT now(),
--     logout_at TIMESTAMPTZ,
--     is_active BOOLEAN DEFAULT true,
--     created_at TIMESTAMPTZ DEFAULT now(),
--     device_info JSONB
-- );

-- MFA Kayıtları (İsteğe bağlı, Supabase kendi yönetiyor olabilir)
-- CREATE TABLE public.auth_mfa (
--     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--     tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
--     user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
--     factor_type TEXT CHECK (factor_type IN ('totp', 'sms', 'email', 'recovery')) NOT NULL,
--     is_verified BOOLEAN DEFAULT false,
--     is_primary BOOLEAN DEFAULT false,
--     is_active BOOLEAN DEFAULT true,
--     secret TEXT,
--     backup_codes TEXT[],
--     created_at TIMESTAMPTZ DEFAULT now(),
--     updated_at TIMESTAMPTZ DEFAULT now(),
--     UNIQUE(tenant_id, user_id, factor_type)
-- );

-- Şifre Sıfırlama İstekleri (İsteğe bağlı, Supabase kendi yönetiyor olabilir)
-- CREATE TABLE public.auth_password_resets (
--     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--     tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
--     user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
--     reset_token TEXT NOT NULL,
--     expires_at TIMESTAMPTZ NOT NULL,
--     is_used BOOLEAN DEFAULT false,
--     created_at TIMESTAMPTZ DEFAULT now(),
--     used_at TIMESTAMPTZ,
--     ip_address INET,
--     user_agent TEXT
-- );

-- E-posta Doğrulama Kayıtları (İsteğe bağlı, Supabase kendi yönetiyor olabilir)
-- CREATE TABLE public.auth_email_verifications (
--     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--     tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
--     user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
--     email TEXT NOT NULL,
--     verification_token TEXT NOT NULL,
--     expires_at TIMESTAMPTZ NOT NULL,
--     is_used BOOLEAN DEFAULT false,
--     created_at TIMESTAMPTZ DEFAULT now(),
--     verified_at TIMESTAMPTZ,
--     ip_address INET
-- );

-- Kullanıcı Ayarları (user_profiles.preferences yerine daha detaylı ayarlar için)
-- CREATE TABLE public.user_settings (
--     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--     tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
--     user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
--     setting_key TEXT NOT NULL,
--     setting_value JSONB NOT NULL,
--     created_at TIMESTAMPTZ DEFAULT now(),
--     updated_at TIMESTAMPTZ DEFAULT now(),
--     UNIQUE(tenant_id, user_id, setting_key)
-- );

-- Kullanıcı Davetleri
CREATE TABLE public.auth_invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT NOT NULL,
    hotel_ids UUID[],
    invited_by UUID REFERENCES auth.users(id),
    invitation_token TEXT UNIQUE NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, accepted, expired, revoked
    expires_at TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    accepted_by_user_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, email)
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

-- Not: `updated_at` tetikleyicileri `016_functions_and_triggers.sql` dosyasına taşınmıştır.
-- Not: `handle_new_user` tetikleyicisi de `016` dosyasına taşınmıştır.
