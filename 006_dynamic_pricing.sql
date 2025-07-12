-- ##########################################################
-- 006_dynamic_pricing.sql
-- Dinamik Fiyatlandırma Stratejileri, Kuralları ve Faktörleri
-- ##########################################################

-- ======================================
-- Dinamik Fiyatlandırma Stratejileri
-- ======================================

CREATE TABLE public.dynamic_pricing_strategies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    base_rate_plan_id UUID REFERENCES public.res_rate_plans(id) ON DELETE SET NULL, -- Hangi temel plana uygulanacak?
    strategy_type TEXT DEFAULT 'rule_based', -- 'rule_based', 'ml_based'
    priority INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(hotel_id, name)
);

-- ======================================
-- Dinamik Fiyatlandırma Kuralları
-- ======================================

CREATE TABLE public.dynamic_pricing_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    strategy_id UUID NOT NULL REFERENCES public.dynamic_pricing_strategies(id) ON DELETE CASCADE,
    rule_name TEXT NOT NULL,
    description TEXT,
    conditions JSONB NOT NULL, -- Kural koşulları (örn: occupancy > 80%, days_until_arrival < 7)
    action_type TEXT CHECK (action_type IN ('adjust_percentage', 'adjust_fixed', 'set_price', 'close_rate')), -- 'adjust_percentage', 'adjust_fixed', 'set_price', 'close_rate'
    action_value NUMERIC(10, 2), -- Ayarlama değeri veya yeni fiyat
    target_rate_plans UUID[], -- Hangi fiyat planlarını etkileyecek (NULL ise hepsi)
    target_room_categories UUID[], -- Hangi oda kategorilerini etkileyecek (NULL ise hepsi)
    start_date DATE,
    end_date DATE,
    days_of_week INTEGER[], -- Haftanın günleri (1-7)
    priority INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

-- ======================================
-- Dinamik Fiyatlandırma Faktörleri
-- ======================================

-- Fiyatlandırmayı etkileyen faktörler (veri kaynağı)
CREATE TABLE public.dynamic_pricing_factors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    factor_name TEXT NOT NULL, -- 'occupancy', 'lead_time', 'competitor_rate', 'event_nearby', 'day_of_week'
    data_source TEXT, -- Verinin kaynağı (örn: 'internal_calculation', 'external_api')
    last_updated TIMESTAMPTZ,
    current_value JSONB, -- Faktörün mevcut değeri
    historical_data JSONB, -- Geçmiş veri (opsiyonel)
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, factor_name)
);

-- Yakındaki Etkinlikler
CREATE TABLE public.dynamic_pricing_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    event_name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    location TEXT,
    expected_impact TEXT, -- 'high', 'medium', 'low'
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CHECK (end_date >= start_date)
);

-- Rakip Fiyatları (manuel veya entegrasyon ile)
CREATE TABLE public.dynamic_pricing_competitor_rates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    competitor_name TEXT NOT NULL,
    competitor_hotel_id TEXT, -- Rakip otel ID'si (varsa)
    room_category_เทียบ TEXT, -- Karşılaştırılabilir oda kategorisi
    date DATE NOT NULL,
    price NUMERIC(10, 2),
    currency CHAR(3),
    source TEXT, -- 'manual', 'api_integration'
    fetched_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, competitor_name, date, room_category_เทียบ)
);

-- ======================================
-- Fiyat Önerileri ve Simülasyon
-- ======================================

-- Sistem tarafından üretilen fiyat önerileri
CREATE TABLE public.dynamic_pricing_rate_recommendations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    room_category_id UUID NOT NULL REFERENCES public.hotels_room_categories(id) ON DELETE CASCADE,
    rate_plan_id UUID REFERENCES public.res_rate_plans(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    recommended_price NUMERIC(10, 2),
    reasoning JSONB, -- Neden bu fiyat önerildi?
    confidence_score FLOAT,
    status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'applied'
    applied_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, room_category_id, rate_plan_id, date)
);

-- Fiyat stratejilerinin simülasyon sonuçları
CREATE TABLE public.dynamic_pricing_simulation (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    strategy_id UUID REFERENCES public.dynamic_pricing_strategies(id) ON DELETE SET NULL,
    simulation_name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    parameters JSONB, -- Simülasyon parametreleri
    results JSONB, -- Simülasyon sonuçları (tahmini gelir, doluluk vb.)
    status TEXT DEFAULT 'running', -- 'running', 'completed', 'failed'
    run_at TIMESTAMPTZ DEFAULT now(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

CREATE TRIGGER trg_dynamic_pricing_strategies_updated_at
BEFORE UPDATE ON public.dynamic_pricing_strategies
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_dynamic_pricing_rules_updated_at
BEFORE UPDATE ON public.dynamic_pricing_rules
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_dynamic_pricing_factors_updated_at
BEFORE UPDATE ON public.dynamic_pricing_factors
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_dynamic_pricing_events_updated_at
BEFORE UPDATE ON public.dynamic_pricing_events
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_dynamic_pricing_competitor_rates_updated_at
BEFORE UPDATE ON public.dynamic_pricing_competitor_rates
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_dynamic_pricing_rate_recommendations_updated_at
BEFORE UPDATE ON public.dynamic_pricing_rate_recommendations
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_dynamic_pricing_simulation_updated_at
BEFORE UPDATE ON public.dynamic_pricing_simulation
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
