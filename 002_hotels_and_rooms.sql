-- ##########################################################
-- 002_hotels_and_rooms.sql
-- Otel, Oda Kategorileri, Odalar ve İlgili Tablolar
-- ##########################################################

-- ======================================
-- Otel Tanımları
-- ======================================

CREATE TABLE public.hotels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    address_line1 TEXT,
    address_line2 TEXT,
    city TEXT,
    state TEXT,
    postal_code TEXT,
    country TEXT,
    country_code CHAR(2),
    timezone TEXT DEFAULT 'Europe/Istanbul',
    phone TEXT,
    email TEXT CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
    website TEXT,
    currency CHAR(3) DEFAULT 'TRY',
    check_in_time TIME DEFAULT '14:00:00',
    check_out_time TIME DEFAULT '12:00:00',
    star_rating INTEGER CHECK (star_rating BETWEEN 1 AND 5),
    logo_url TEXT,
    banner_url TEXT,
    geo_location JSONB, -- {lat: x, lng: y}
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- Oda Kategorileri ve Odalar
-- ======================================

CREATE TABLE public.hotels_room_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    max_occupancy INTEGER NOT NULL CHECK (max_occupancy > 0),
    default_price NUMERIC(10, 2) CHECK (default_price >= 0),
    size_sqm NUMERIC(6, 2),
    bed_type TEXT, -- Örn: 'King', 'Queen', 'Twin'
    view_type TEXT, -- Örn: 'Sea View', 'Garden View'
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, name)
);

CREATE TABLE public.hotels_rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.hotels_room_categories(id) ON DELETE CASCADE,
    room_number TEXT NOT NULL,
    floor TEXT,
    status public.room_status DEFAULT 'available',
    current_status_reason TEXT,
    is_smoking BOOLEAN DEFAULT false,
    is_pet_friendly BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, room_number)
);

-- ======================================
-- Olanaklar (Amenities)
-- ======================================

CREATE TABLE public.hotels_amenities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID REFERENCES public.hotels(id) ON DELETE CASCADE, -- NULL ise genel olanak
    name TEXT NOT NULL,
    description TEXT,
    category TEXT, -- Örn: 'Room', 'Bathroom', 'General', 'Technology'
    icon_url TEXT,
    is_chargeable BOOLEAN DEFAULT false,
    price NUMERIC(10, 2),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, name)
);

-- Oda kategorilerine atanan olanaklar
CREATE TABLE public.hotels_room_category_amenities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    room_category_id UUID NOT NULL REFERENCES public.hotels_room_categories(id) ON DELETE CASCADE,
    amenity_id UUID NOT NULL REFERENCES public.hotels_amenities(id) ON DELETE CASCADE,
    quantity INTEGER DEFAULT 1,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (room_category_id, amenity_id)
);

-- ======================================
-- Medya (Görseller)
-- ======================================

CREATE TABLE public.hotels_media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    media_url TEXT NOT NULL,
    media_type TEXT DEFAULT 'image', -- 'image', 'video', 'virtual_tour'
    description TEXT,
    alt_text TEXT,
    sort_order INTEGER DEFAULT 0,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE public.hotels_room_media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    room_category_id UUID NOT NULL REFERENCES public.hotels_room_categories(id) ON DELETE CASCADE,
    media_url TEXT NOT NULL,
    media_type TEXT DEFAULT 'image',
    description TEXT,
    alt_text TEXT,
    sort_order INTEGER DEFAULT 0,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- Sürdürülebilirlik Özellikleri
-- ======================================

CREATE TABLE public.hotels_sustainability_features (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    feature_name TEXT NOT NULL,
    description TEXT,
    category TEXT, -- Örn: 'Energy', 'Water', 'Waste', 'Community'
    certification TEXT,
    icon_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(hotel_id, feature_name)
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

CREATE TRIGGER trg_hotels_updated_at
BEFORE UPDATE ON public.hotels
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hotels_room_categories_updated_at
BEFORE UPDATE ON public.hotels_room_categories
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hotels_rooms_updated_at
BEFORE UPDATE ON public.hotels_rooms
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hotels_amenities_updated_at
BEFORE UPDATE ON public.hotels_amenities
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hotels_room_category_amenities_updated_at
BEFORE UPDATE ON public.hotels_room_category_amenities
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hotels_media_updated_at
BEFORE UPDATE ON public.hotels_media
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hotels_room_media_updated_at
BEFORE UPDATE ON public.hotels_room_media
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hotels_sustainability_features_updated_at
BEFORE UPDATE ON public.hotels_sustainability_features
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
