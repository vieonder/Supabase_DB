-- ##########################################################
-- 011_marketing_and_loyalty.sql
-- Pazarlama Kampanyaları, Kuponlar ve Sadakat Programı Tabloları
-- ##########################################################

-- ======================================
-- Pazarlama Kuponları
-- ======================================

CREATE TABLE public.marketing_coupons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID REFERENCES public.hotels(id) ON DELETE CASCADE, -- Belirli bir otele özel olabilir
    coupon_code TEXT UNIQUE NOT NULL,
    description TEXT,
    discount_type TEXT CHECK (discount_type IN ('percentage', 'fixed_amount')), -- 'percentage', 'fixed_amount'
    discount_value NUMERIC(10, 2) NOT NULL,
    applicable_scope JSONB, -- {"type": "rate_plan", "ids": [uuid1]} veya {"type": "total_booking"}
    min_booking_value NUMERIC(12, 2),
    min_nights INTEGER,
    valid_from DATE,
    valid_until DATE,
    max_usages INTEGER,
    usages_per_guest INTEGER DEFAULT 1,
    current_usages INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until >= valid_from)
);

-- Kupon Kullanımları
CREATE TABLE public.marketing_coupon_usages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    coupon_id UUID NOT NULL REFERENCES public.marketing_coupons(id) ON DELETE CASCADE,
    reservation_id UUID UNIQUE NOT NULL REFERENCES public.res_reservations(id) ON DELETE CASCADE,
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    usage_time TIMESTAMPTZ DEFAULT now(),
    discount_amount NUMERIC(12, 2),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- Sadakat Programı
-- ======================================

-- Sadakat Programı Yapılandırması (Tenant bazlı)
CREATE TABLE public.loyalty_program_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID UNIQUE NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    program_name TEXT NOT NULL,
    description TEXT,
    points_currency_name TEXT DEFAULT 'Points',
    earn_rate NUMERIC(10, 4) DEFAULT 1, -- Harcanan 1 birim para için kaç puan kazanılacak?
    redeem_rate NUMERIC(10, 4) DEFAULT 0.01, -- 1 puan kaç birim para değerinde?
    point_expiry_months INTEGER, -- Puanların geçerlilik süresi (ay)
    tiers_enabled BOOLEAN DEFAULT false,
    welcome_bonus_points INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Sadakat Programı Seviyeleri (Tiers)
CREATE TABLE public.loyalty_program_tiers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_id UUID NOT NULL REFERENCES public.loyalty_program_config(id) ON DELETE CASCADE,
    tier_name TEXT NOT NULL,
    min_points INTEGER DEFAULT 0,
    min_nights INTEGER DEFAULT 0,
    min_spend NUMERIC(12, 2) DEFAULT 0,
    earn_multiplier NUMERIC(5, 2) DEFAULT 1.0, -- Bu seviyedeki puan kazanma çarpanı
    tier_benefits TEXT[], -- Seviye avantajları (örn: 'Free Breakfast', 'Late Checkout')
    level INTEGER NOT NULL, -- Seviye sırası (0'dan başlayarak)
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(config_id, tier_name),
    UNIQUE(config_id, level)
);

-- Sadakat Üye Profilleri
CREATE TABLE public.loyalty_member_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_id UUID NOT NULL REFERENCES public.loyalty_program_config(id) ON DELETE CASCADE,
    guest_id UUID UNIQUE NOT NULL REFERENCES public.guests(id) ON DELETE CASCADE,
    member_number TEXT UNIQUE NOT NULL, -- Üye numarası
    current_tier_id UUID REFERENCES public.loyalty_program_tiers(id) ON DELETE SET NULL,
    current_points INTEGER DEFAULT 0,
    lifetime_points INTEGER DEFAULT 0,
    lifetime_nights INTEGER DEFAULT 0,
    lifetime_spend NUMERIC(14, 2) DEFAULT 0,
    joined_date DATE DEFAULT CURRENT_DATE,
    last_activity_date DATE,
    preferences JSONB, -- Sadakat programı tercihleri
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Sadakat Puan İşlemleri
CREATE TABLE public.loyalty_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    member_id UUID NOT NULL REFERENCES public.loyalty_member_profiles(id) ON DELETE CASCADE,
    transaction_type public.loyalty_transaction_type NOT NULL,
    points_change INTEGER NOT NULL,
    related_reservation_id UUID REFERENCES public.res_reservations(id) ON DELETE SET NULL,
    related_activity TEXT, -- 'Booking', 'Redemption', 'Bonus', 'Adjustment', 'Expiry'
    description TEXT,
    transaction_date TIMESTAMPTZ DEFAULT now(),
    expiry_date DATE, -- Kazanılan puanların son kullanma tarihi
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Sadakat Avantajları Tanımları (Tier'lardan bağımsız olabilir)
CREATE TABLE public.loyalty_benefits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_id UUID NOT NULL REFERENCES public.loyalty_program_config(id) ON DELETE CASCADE,
    benefit_name TEXT NOT NULL,
    description TEXT,
    benefit_code TEXT UNIQUE,
    applicable_tiers UUID[],
    redemption_cost_points INTEGER, -- Eğer puanla alınabiliyorsa
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(config_id, benefit_name)
);

-- Sadakat Puan Kullanımları (Avantaj kullanma)
CREATE TABLE public.loyalty_redemptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    member_id UUID NOT NULL REFERENCES public.loyalty_member_profiles(id) ON DELETE CASCADE,
    benefit_id UUID REFERENCES public.loyalty_benefits(id) ON DELETE SET NULL,
    redemption_type TEXT NOT NULL, -- 'Benefit', 'Discount', 'Free Night'
    points_spent INTEGER NOT NULL,
    value_redeemed NUMERIC(10, 2), -- Parasal karşılığı (varsa)
    related_reservation_id UUID REFERENCES public.res_reservations(id) ON DELETE SET NULL,
    redemption_date TIMESTAMPTZ DEFAULT now(),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Puan Son Kullanma Tarihi Takibi (Opsiyonel, periyodik iş ile yönetilebilir)
CREATE TABLE public.loyalty_point_expiry (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID UNIQUE NOT NULL REFERENCES public.loyalty_transactions(id) ON DELETE CASCADE,
    member_id UUID NOT NULL REFERENCES public.loyalty_member_profiles(id) ON DELETE CASCADE,
    points_to_expire INTEGER NOT NULL,
    expiry_date DATE NOT NULL,
    status TEXT DEFAULT 'active', -- 'active', 'expired', 'used'
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Sadakat İş Ortağı Programları (Opsiyonel)
CREATE TABLE public.loyalty_partner_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_id UUID NOT NULL REFERENCES public.loyalty_program_config(id) ON DELETE CASCADE,
    partner_name TEXT NOT NULL,
    description TEXT,
    conversion_rate_to_partner NUMERIC(10, 4), -- 1 otel puanı = X partner puanı
    conversion_rate_from_partner NUMERIC(10, 4), -- 1 partner puanı = Y otel puanı
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(config_id, partner_name)
);

-- Üye Seviye Geçmişi
CREATE TABLE public.loyalty_tier_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    member_id UUID NOT NULL REFERENCES public.loyalty_member_profiles(id) ON DELETE CASCADE,
    old_tier_id UUID REFERENCES public.loyalty_program_tiers(id) ON DELETE SET NULL,
    new_tier_id UUID REFERENCES public.loyalty_program_tiers(id) ON DELETE SET NULL,
    change_date DATE DEFAULT CURRENT_DATE,
    reason TEXT, -- 'Points Threshold', 'Nights Threshold', 'Manual Adjustment'
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- Diğer Pazarlama Aktiviteleri
-- ======================================

-- Özel Teklifler (Kuponlardan farklı, örn: 3 Gece Kal 2 Öde)
CREATE TABLE public.marketing_special_offers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID REFERENCES public.hotels(id) ON DELETE CASCADE,
    offer_name TEXT NOT NULL,
    description TEXT,
    offer_type TEXT NOT NULL, -- 'Discount', 'Package', 'Free Night'
    details JSONB NOT NULL, -- Teklifin detayları (örn: { required_nights: 3, free_nights: 1 })
    applicable_rate_plans UUID[],
    applicable_room_categories UUID[],
    valid_from DATE,
    valid_until DATE,
    booking_date_from DATE,
    booking_date_until DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until >= valid_from),
    CHECK (booking_date_until IS NULL OR booking_date_from IS NULL OR booking_date_until >= booking_date_from)
);

-- Pazarlama Kampanyaları (E-posta, SMS vb.)
CREATE TABLE public.marketing_campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    campaign_name TEXT NOT NULL,
    description TEXT,
    campaign_type TEXT NOT NULL, -- 'Email', 'SMS', 'Social Media'
    target_segment JSONB, -- Hedef kitle tanımı (örn: { tier: ['Gold'], last_stay_before: '2023-01-01' })
    template_id UUID,
    status TEXT DEFAULT 'draft', -- 'draft', 'scheduled', 'sending', 'completed', 'cancelled'
    scheduled_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    metrics JSONB, -- {"sent": 1000, "opened": 250, "clicked": 50, "converted": 5}
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- E-posta Şablonları (Pazarlama ve İşlemsel)
CREATE TABLE public.marketing_email_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    template_name TEXT NOT NULL,
    template_type TEXT DEFAULT 'marketing', -- 'marketing', 'transactional' (booking_confirmation etc.)
    subject TEXT NOT NULL,
    body_html TEXT NOT NULL,
    body_text TEXT,
    variables TEXT[], -- Şablonda kullanılan değişkenler (örn: '{{guest_name}}')
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, template_name)
);

-- Pazarlama Dönüşüm İzleme (Opsiyonel)
CREATE TABLE public.marketing_conversions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    campaign_id UUID REFERENCES public.marketing_campaigns(id) ON DELETE SET NULL,
    coupon_id UUID REFERENCES public.marketing_coupons(id) ON DELETE SET NULL,
    offer_id UUID REFERENCES public.marketing_special_offers(id) ON DELETE SET NULL,
    reservation_id UUID REFERENCES public.res_reservations(id) ON DELETE SET NULL,
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    conversion_type TEXT NOT NULL, -- 'Booking', 'Lead', 'Signup'
    conversion_value NUMERIC(12, 2),
    conversion_time TIMESTAMPTZ DEFAULT now(),
    source_channel TEXT, -- 'Email', 'Website Banner', 'Social Media Ad'
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

CREATE TRIGGER trg_marketing_coupons_updated_at
BEFORE UPDATE ON public.marketing_coupons
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- marketing_coupon_usages için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_loyalty_program_config_updated_at
BEFORE UPDATE ON public.loyalty_program_config
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_loyalty_program_tiers_updated_at
BEFORE UPDATE ON public.loyalty_program_tiers
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_loyalty_member_profiles_updated_at
BEFORE UPDATE ON public.loyalty_member_profiles
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- loyalty_transactions için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_loyalty_benefits_updated_at
BEFORE UPDATE ON public.loyalty_benefits
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- loyalty_redemptions için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_loyalty_point_expiry_updated_at
BEFORE UPDATE ON public.loyalty_point_expiry
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_loyalty_partner_programs_updated_at
BEFORE UPDATE ON public.loyalty_partner_programs
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- loyalty_tier_history için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_marketing_special_offers_updated_at
BEFORE UPDATE ON public.marketing_special_offers
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_marketing_campaigns_updated_at
BEFORE UPDATE ON public.marketing_campaigns
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_marketing_email_templates_updated_at
BEFORE UPDATE ON public.marketing_email_templates
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- marketing_conversions için updated_at genellikle gereksizdir.

-- Eksik updated_at triggerları
CREATE TRIGGER trg_marketing_coupon_usages_updated_at
BEFORE UPDATE ON public.marketing_coupon_usages
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_loyalty_transactions_updated_at
BEFORE UPDATE ON public.loyalty_transactions
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_loyalty_redemptions_updated_at
BEFORE UPDATE ON public.loyalty_redemptions
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_loyalty_tier_history_updated_at
BEFORE UPDATE ON public.loyalty_tier_history
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_marketing_conversions_updated_at
BEFORE UPDATE ON public.marketing_conversions
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Eksik FK Tanımlamaları
ALTER TABLE public.marketing_campaigns
    ADD CONSTRAINT fk_marketing_campaigns_template_id
    FOREIGN KEY (template_id) REFERENCES public.marketing_email_templates(id) ON DELETE SET NULL
    DEFERRABLE INITIALLY DEFERRED;
