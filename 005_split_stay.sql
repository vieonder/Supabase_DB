-- ##########################################################
-- 005_split_stay.sql
-- Bölünmüş Konaklama (Split Stay) Tabloları
-- ##########################################################

-- ======================================
-- Split Stay Bağlantıları ve Segmentleri
-- ======================================

-- Bölünmüş konaklamaları gruplayan ana tablo
CREATE TABLE public.split_stay_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    original_reservation_id UUID REFERENCES public.res_reservations(id) ON DELETE SET NULL, -- Başlangıç rezervasyonu
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    total_nights INTEGER,
    total_price NUMERIC(12, 2),
    status TEXT, -- 'active', 'completed', 'cancelled'
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Bölünmüş konaklamanın her bir parçasını temsil eder
CREATE TABLE public.split_stay_segments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    split_stay_link_id UUID NOT NULL REFERENCES public.split_stay_links(id) ON DELETE CASCADE,
    reservation_room_id UUID UNIQUE REFERENCES public.res_reservation_rooms(id) ON DELETE CASCADE, -- İlgili rezervasyon odası
    room_category_id UUID NOT NULL REFERENCES public.hotels_room_categories(id) ON DELETE CASCADE,
    assigned_room_id UUID REFERENCES public.hotels_rooms(id) ON DELETE SET NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    segment_order INTEGER NOT NULL,
    segment_price NUMERIC(10, 2),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CHECK (check_out_date > check_in_date)
);

-- ======================================
-- Segmentler Arası Geçişler
-- ======================================

-- Segmentler arasındaki geçiş detayları (oda değişikliği vb.)
CREATE TABLE public.split_stay_transitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    split_stay_link_id UUID NOT NULL REFERENCES public.split_stay_links(id) ON DELETE CASCADE,
    from_segment_id UUID NOT NULL REFERENCES public.split_stay_segments(id) ON DELETE CASCADE,
    to_segment_id UUID NOT NULL REFERENCES public.split_stay_segments(id) ON DELETE CASCADE,
    transition_date DATE NOT NULL,
    transition_type TEXT DEFAULT 'room_change', -- 'room_change', 'luggage_transfer'
    status TEXT, -- 'pending', 'confirmed', 'completed'
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CHECK (from_segment_id <> to_segment_id)
);

-- ======================================
-- Split Stay İlişkili Diğer Tablolar
-- ======================================

-- Bölünmüş konaklamaya bağlı misafirler (ana rezervasyondan farklıysa)
CREATE TABLE public.split_stay_guests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    split_stay_link_id UUID NOT NULL REFERENCES public.split_stay_links(id) ON DELETE CASCADE,
    segment_id UUID REFERENCES public.split_stay_segments(id) ON DELETE CASCADE,
    guest_id UUID REFERENCES public.guests(id) ON DELETE CASCADE,
    first_name TEXT,
    last_name TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (split_stay_link_id, guest_id, segment_id)
);

-- Bölünmüş konaklama geçmişi/logları
CREATE TABLE public.split_stay_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    split_stay_link_id UUID NOT NULL REFERENCES public.split_stay_links(id) ON DELETE CASCADE,
    segment_id UUID REFERENCES public.split_stay_segments(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL, -- 'created', 'segment_added', 'room_assigned', 'transition_confirmed'
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Bölünmüş konaklama segmentlerine özel olanaklar/hizmetler
CREATE TABLE public.split_stay_amenities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    segment_id UUID NOT NULL REFERENCES public.split_stay_segments(id) ON DELETE CASCADE,
    amenity_name TEXT NOT NULL,
    quantity INTEGER DEFAULT 1,
    price NUMERIC(10, 2) DEFAULT 0,
    notes TEXT,
    added_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

CREATE TRIGGER trg_split_stay_links_updated_at
BEFORE UPDATE ON public.split_stay_links
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_split_stay_segments_updated_at
BEFORE UPDATE ON public.split_stay_segments
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_split_stay_transitions_updated_at
BEFORE UPDATE ON public.split_stay_transitions
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_split_stay_guests_updated_at
BEFORE UPDATE ON public.split_stay_guests
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
