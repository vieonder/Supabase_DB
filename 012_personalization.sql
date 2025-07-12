-- ##########################################################
-- 012_personalization.sql
-- Kullanıcı/Misafir Kişiselleştirme Tabloları
-- ##########################################################

-- ======================================
-- Kullanıcı/Misafir Etkileşimleri
-- ======================================

-- Kayıtlı ve anonim kullanıcıların etkileşimlerini izler
CREATE TABLE public.personalization_user_interactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Kayıtlı kullanıcı
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL, -- Misafir kaydı (varsa)
    anonymous_user_id UUID, -- Anonim kullanıcı ID'si (localStorage'dan)
    session_id TEXT, -- Tarayıcı oturum ID'si
    interaction_type TEXT NOT NULL, -- 'page_view', 'search', 'room_view', 'add_to_cart', 'booking_attempt'
    interaction_data JSONB NOT NULL, -- Etkileşim detayları (örn: {"query": "antalya hotel", "dates": ["2024-08-10", "2024-08-15"]})
    url TEXT,
    referrer TEXT,
    device_info JSONB, -- {"browser": "Chrome", "os": "Windows", "isMobile": false}
    ip_address INET,
    created_at TIMESTAMPTZ DEFAULT now(),
    -- User veya anonymous ID olmalı, ikisi birden veya hiçbiri olmamalı?
    CHECK (
        (user_id IS NOT NULL AND anonymous_user_id IS NULL) OR
        (user_id IS NULL AND anonymous_user_id IS NOT NULL)
        -- Giriş yapınca anonim ID'nin user ID'ye bağlanması user_anonymous_map ile yapılır.
    )
);

-- ======================================
-- Kullanıcı/Misafir Segmentasyonu
-- ======================================

-- Tanımlı Müşteri Segmentleri
CREATE TABLE public.personalization_segments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    segment_name TEXT NOT NULL,
    description TEXT,
    segment_type TEXT DEFAULT 'dynamic', -- 'dynamic', 'static'
    rules JSONB, -- Dinamik segmentler için kurallar (örn: { "loyalty_tier": "Gold", "total_spend_gt": 1000 })
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, segment_name)
);

-- Kullanıcıların/Misafirlerin Ait Olduğu Segmentler
CREATE TABLE public.personalization_user_segments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    segment_id UUID NOT NULL REFERENCES public.personalization_segments(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    guest_id UUID REFERENCES public.guests(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT now(), -- Statik segmentler için eklenme tarihi
    reason TEXT, -- Neden bu segmente eklendi?
    created_at TIMESTAMPTZ DEFAULT now(),
    CHECK (user_id IS NOT NULL OR guest_id IS NOT NULL)
);

-- ======================================
-- Kişiselleştirilmiş Öneriler
-- ======================================

-- Kullanıcılara/Misafirlere sunulan öneriler
CREATE TABLE public.personalization_recommendations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    anonymous_user_id UUID,
    recommendation_type TEXT NOT NULL, -- 'room_category', 'rate_plan', 'service', 'offer', 'destination'
    recommended_item_ids UUID[], -- Önerilen öğelerin ID'leri
    recommended_items_data JSONB, -- Önerilen öğelerin detayları (cache için)
    recommendation_source TEXT, -- 'collaborative_filtering', 'rule_based', 'content_based'
    context TEXT, -- Önerinin sunulduğu bağlam (örn: 'homepage', 'booking_engine')
    score FLOAT, -- Öneri skoru/güvenilirliği
    shown_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ,
    converted_at TIMESTAMPTZ, -- Öneri sonucunda dönüşüm oldu mu?
    created_at TIMESTAMPTZ DEFAULT now(),
    CHECK (
        (user_id IS NOT NULL AND anonymous_user_id IS NULL) OR
        (user_id IS NULL AND anonymous_user_id IS NOT NULL) OR
        (user_id IS NULL AND anonymous_user_id IS NULL AND guest_id IS NOT NULL)
    )
);

-- Önerilere verilen geri bildirimler
CREATE TABLE public.personalization_recommendation_feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    recommendation_id UUID NOT NULL REFERENCES public.personalization_recommendations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    anonymous_user_id UUID,
    feedback_type TEXT NOT NULL, -- 'like', 'dislike', 'irrelevant', 'already_booked'
    feedback_text TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    CHECK (
        (user_id IS NOT NULL AND anonymous_user_id IS NULL) OR
        (user_id IS NULL AND anonymous_user_id IS NOT NULL) OR
        (user_id IS NULL AND anonymous_user_id IS NULL AND guest_id IS NOT NULL)
    )
);

-- ======================================
-- İçerik Varyasyonları (A/B Testi için - Opsiyonel)
-- ======================================

CREATE TABLE public.personalization_content_variants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    experiment_name TEXT NOT NULL,
    variant_name TEXT NOT NULL,
    description TEXT,
    target_element TEXT, -- Hedeflenen UI öğesi (örn: 'homepage_banner', 'booking_button_text')
    content JSONB NOT NULL, -- Varyasyonun içeriği
    allocation_percentage NUMERIC(5, 2) DEFAULT 50.0,
    metrics JSONB, -- {"views": 1000, "clicks": 100, "conversion_rate": 0.1}
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, experiment_name, variant_name)
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

-- personalization_user_interactions için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_personalization_segments_updated_at
BEFORE UPDATE ON public.personalization_segments
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- personalization_user_segments için updated_at genellikle gereksizdir.

-- personalization_recommendations için updated_at gerekli olabilir (shown_at, clicked_at vb güncellendiğinde)
CREATE TRIGGER trg_personalization_recommendations_updated_at
BEFORE UPDATE ON public.personalization_recommendations
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- personalization_recommendation_feedback için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_personalization_content_variants_updated_at
BEFORE UPDATE ON public.personalization_content_variants
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
