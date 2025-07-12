-- ##########################################################
-- 004_reservations_and_pricing.sql
-- Rezervasyonlar, Fiyat Planları ve Temel Fiyatlandırma Tabloları
-- ##########################################################

-- ======================================
-- Fiyat Planları ve Sezonlar
-- ======================================

CREATE TABLE public.res_rate_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    code TEXT NOT NULL, -- Kısa kod (örn: 'BAR', 'CORP')
    is_base_plan BOOLEAN DEFAULT false, -- Temel fiyat planı mı?
    based_on_plan_id UUID REFERENCES public.res_rate_plans(id) ON DELETE SET NULL,
    adjustment_type TEXT CHECK (adjustment_type IN ('percentage', 'fixed_amount', 'none')), -- percentage, fixed_amount, none
    adjustment_value NUMERIC(10, 2),
    min_los INTEGER, -- Minimum konaklama süresi
    max_los INTEGER, -- Maximum konaklama süresi
    booking_window_start INTEGER, -- Rezervasyon penceresi başlangıcı (gün)
    booking_window_end INTEGER, -- Rezervasyon penceresi bitişi (gün)
    included_services TEXT[],
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, code)
);

CREATE TABLE public.res_seasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    color_code TEXT, -- Takvimde göstermek için renk kodu
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, name),
    CHECK (end_date >= start_date)
);

-- ======================================
-- İptal Politikaları
-- ======================================

CREATE TABLE public.res_cancellation_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    penalty_type TEXT CHECK (penalty_type IN ('percentage', 'fixed_amount', 'nights', 'none')), -- percentage, fixed_amount, nights, none
    penalty_value NUMERIC(10, 2),
    days_before_checkin INTEGER, -- Check-in'den kaç gün öncesine kadar cezasız iptal
    time_before_checkin TIME, -- İptal için son saat
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, name)
);

-- Fiyat planlarına atanan iptal politikaları
CREATE TABLE public.res_rate_plan_cancellation_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    rate_plan_id UUID NOT NULL REFERENCES public.res_rate_plans(id) ON DELETE CASCADE,
    cancellation_policy_id UUID NOT NULL REFERENCES public.res_cancellation_policies(id) ON DELETE CASCADE,
    is_default BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (rate_plan_id, cancellation_policy_id)
);

-- ======================================
-- Günlük Fiyatlar ve Müsaitlik (Temel)
-- ======================================

CREATE TABLE public.price_daily_rates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    room_category_id UUID NOT NULL REFERENCES public.hotels_room_categories(id) ON DELETE CASCADE,
    rate_plan_id UUID REFERENCES public.res_rate_plans(id) ON DELETE CASCADE, -- NULL ise base rate
    date DATE NOT NULL,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    currency CHAR(3) DEFAULT 'TRY',
    is_closed BOOLEAN DEFAULT false, -- O tarihte bu kategori/plan kapalı mı?
    restriction_min_los INTEGER,
    restriction_max_los INTEGER,
    restriction_closed_arrival BOOLEAN DEFAULT false,
    restriction_closed_departure BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, room_category_id, rate_plan_id, date)
);

-- Müsaitlik Kuralları (manuel override)
CREATE TABLE public.price_availability_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    room_category_id UUID REFERENCES public.hotels_room_categories(id) ON DELETE CASCADE, -- NULL ise tüm otel
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    override_availability INTEGER, -- NULL değilse, normal sayım yerine bu değer kullanılır
    close_category BOOLEAN DEFAULT false,
    reason TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CHECK (end_date >= start_date)
);

-- ======================================
-- Rezervasyonlar
-- ======================================

CREATE TABLE public.res_reservations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    user_profile_id UUID REFERENCES public.user_profiles(user_id) ON DELETE SET NULL, -- Rezervasyonu yapan kullanıcı (eğer kayıtlıysa)
    anonymous_user_id UUID, -- Rezervasyonu yapan anonim kullanıcı
    rate_plan_id UUID REFERENCES public.res_rate_plans(id) ON DELETE SET NULL,
    cancellation_policy_id UUID REFERENCES public.res_cancellation_policies(id) ON DELETE SET NULL,
    booking_reference TEXT NOT NULL, -- Sistem tarafından üretilen eşsiz referans
    external_reference TEXT, -- OTA veya diğer dış sistem referansı
    channel TEXT DEFAULT 'direct', -- Rezervasyon kaynağı (direct, booking.com, expedia, gds, call_center)
    status reservation_status DEFAULT 'pending' NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    original_check_in_date DATE,
    original_check_out_date DATE,
    adults INT DEFAULT 1 NOT NULL CHECK (adults >= 0),
    children INT DEFAULT 0 NOT NULL CHECK (children >= 0),
    infants INT DEFAULT 0 NOT NULL CHECK (infants >= 0),
    total_guests INT GENERATED ALWAYS AS (adults + children) STORED,
    -- Fiyat ve Ödeme
    currency CHAR(3) NOT NULL,
    base_amount DECIMAL(12, 2) DEFAULT 0.00, -- Vergiler ve ekstralar hariç temel oda fiyatı toplamı
    taxes_amount DECIMAL(12, 2) DEFAULT 0.00,
    extras_amount DECIMAL(12, 2) DEFAULT 0.00,
    discount_amount DECIMAL(12, 2) DEFAULT 0.00,
    total_amount DECIMAL(12, 2) GENERATED ALWAYS AS (base_amount + taxes_amount + extras_amount - discount_amount) STORED,
    paid_amount DECIMAL(12, 2) DEFAULT 0.00,
    payment_status payment_status DEFAULT 'pending' NOT NULL,
    payment_method_preference TEXT,
    -- Inntegrate Komisyonu ve Faturalama
    inntegrate_commission_amount DECIMAL(12, 2), -- Hesaplanan komisyon tutarı (trigger ile)
    invoice_id UUID, -- Komisyonun faturalandırıldığı fatura ID'si (FK SONRA EKLENECEK)
    -- Misafir Bilgileri (Ana misafir)
    guest_name TEXT, -- guest_id NULL ise kullanılabilir
    guest_email TEXT,
    guest_phone TEXT,
    guest_notes TEXT,
    special_requests TEXT,
    estimated_arrival_time TIME,
    -- Durum ve Meta Veri
    is_split_stay BOOLEAN DEFAULT false,
    is_modifiable BOOLEAN DEFAULT true,
    is_cancellable BOOLEAN DEFAULT true,
    booked_at TIMESTAMPTZ DEFAULT now(),
    confirmed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    checked_in_at TIMESTAMPTZ,
    checked_out_at TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    -- Kısıtlamalar
    CHECK (check_out_date > check_in_date),
    UNIQUE (tenant_id, booking_reference)
);

CREATE TABLE public.res_reservation_rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    reservation_id UUID NOT NULL REFERENCES public.res_reservations(id) ON DELETE CASCADE,
    room_id UUID REFERENCES public.hotels_rooms(id) ON DELETE SET NULL, -- Atanan oda
    room_category_id UUID NOT NULL REFERENCES public.hotels_room_categories(id) ON DELETE CASCADE,
    rate_plan_id UUID NOT NULL REFERENCES public.res_rate_plans(id) ON DELETE CASCADE,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    number_of_adults INTEGER NOT NULL CHECK (number_of_adults > 0),
    number_of_children INTEGER DEFAULT 0 CHECK (number_of_children >= 0),
    room_price NUMERIC(10, 2) NOT NULL CHECK (room_price >= 0),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CHECK (check_out_date > check_in_date)
);

-- Her rezervasyon odasının günlük fiyat dökümü
CREATE TABLE public.res_reservation_daily_rates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    reservation_room_id UUID NOT NULL REFERENCES public.res_reservation_rooms(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (reservation_room_id, date)
);

-- Rezervasyon misafirleri (rezervasyona bağlı misafirler)
CREATE TABLE public.res_reservation_guests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    reservation_id UUID NOT NULL REFERENCES public.res_reservations(id) ON DELETE CASCADE,
    reservation_room_id UUID REFERENCES public.res_reservation_rooms(id) ON DELETE CASCADE,
    guest_id UUID REFERENCES public.guests(id) ON DELETE CASCADE, -- Mevcut misafir kaydı
    first_name TEXT, -- Eğer guest_id yoksa
    last_name TEXT, -- Eğer guest_id yoksa
    email TEXT, -- Eğer guest_id yoksa
    phone TEXT, -- Eğer guest_id yoksa
    is_primary_guest BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (reservation_room_id, guest_id)
);

-- ======================================
-- Rezervasyon İptalleri ve Değişiklikleri
-- ======================================

CREATE TABLE public.res_cancellations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    reservation_id UUID NOT NULL REFERENCES public.res_reservations(id) ON DELETE CASCADE,
    cancellation_policy_id UUID REFERENCES public.res_cancellation_policies(id),
    penalty_amount NUMERIC(12, 2) DEFAULT 0,
    reason TEXT,
    cancelled_by_user_id UUID REFERENCES auth.users(id),
    cancelled_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.res_modifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    reservation_id UUID NOT NULL REFERENCES public.res_reservations(id) ON DELETE CASCADE,
    modification_type TEXT NOT NULL, -- 'date_change', 'room_change', 'guest_change', 'other'
    description TEXT NOT NULL,
    old_value JSONB,
    new_value JSONB,
    price_difference NUMERIC(12, 2) DEFAULT 0,
    modified_by_user_id UUID REFERENCES auth.users(id),
    modified_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

CREATE TRIGGER trg_res_rate_plans_updated_at
BEFORE UPDATE ON public.res_rate_plans
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_res_seasons_updated_at
BEFORE UPDATE ON public.res_seasons
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_res_cancellation_policies_updated_at
BEFORE UPDATE ON public.res_cancellation_policies
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_res_rate_plan_cancellation_policies_updated_at
BEFORE UPDATE ON public.res_rate_plan_cancellation_policies
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_price_daily_rates_updated_at
BEFORE UPDATE ON public.price_daily_rates
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_price_availability_rules_updated_at
BEFORE UPDATE ON public.price_availability_rules
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_res_reservations_updated_at
BEFORE UPDATE ON public.res_reservations
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_res_reservation_rooms_updated_at
BEFORE UPDATE ON public.res_reservation_rooms
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_res_reservation_daily_rates_updated_at
BEFORE UPDATE ON public.res_reservation_daily_rates
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_res_reservation_guests_updated_at
BEFORE UPDATE ON public.res_reservation_guests
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_res_cancellations_updated_at
BEFORE UPDATE ON public.res_cancellations
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_res_modifications_updated_at
BEFORE UPDATE ON public.res_modifications
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
