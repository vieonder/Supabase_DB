-- ##########################################################
-- 009_inventory_services_and_menu.sql
-- Genel Envanter, Hizmetler ve Menü Yönetimi Tabloları
-- ##########################################################

-- ======================================
-- ENUM Tipi (Hizmet Fiyatlandırma)
-- ======================================
-- Not: İdeal olarak bu ENUM 000_Setup.sql'de olmalıydı.
DO $$ BEGIN
    CREATE TYPE public.service_pricing_type AS ENUM (
        'per_stay',
        'per_night',
        'per_person',
        'per_person_per_night',
        'per_item'
     );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ======================================
-- Genel Envanter Yönetimi
-- ======================================

-- Envanter Öğeleri (Satılabilir ürünler, F&B malzemeleri vb.)
CREATE TABLE public.inventory_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    item_code TEXT UNIQUE,
    description TEXT,
    category TEXT, -- 'F&B', 'Retail', 'Office Supplies'
    type TEXT, -- 'Stockable', 'Consumable', 'Service'
    unit_of_measure TEXT, -- 'kg', 'litre', 'piece', 'hour'
    purchase_unit_of_measure TEXT,
    purchase_price NUMERIC(10, 2),
    selling_price NUMERIC(10, 2),
    tax_rate_id UUID,
    stock_level NUMERIC(10, 2) DEFAULT 0,
    reorder_level NUMERIC(10, 2),
    location TEXT, -- Depo veya satış noktası
    supplier_id UUID,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, item_name)
);

-- Envanter Hareketleri
CREATE TABLE public.inventory_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
    movement_type public.inventory_movement_type NOT NULL,
    quantity NUMERIC(10, 2) NOT NULL,
    unit_price NUMERIC(10, 2), -- Hareket anındaki birim fiyat
    related_document_type TEXT, -- 'Purchase Order', 'Sale', 'Transfer', 'Adjustment'
    related_document_id UUID,
    location_from TEXT,
    location_to TEXT,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    movement_date TIMESTAMPTZ DEFAULT now(),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Envanter Uyarıları (Düşük stok vb.)
CREATE TABLE public.inventory_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
    alert_type TEXT NOT NULL, -- 'Low Stock', 'Expired'
    threshold_value NUMERIC(10, 2),
    current_value NUMERIC(10, 2),
    message TEXT,
    status TEXT DEFAULT 'active', -- 'active', 'resolved', 'ignored'
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Satın Alma Siparişleri
CREATE TABLE public.inventory_order_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    supplier_id UUID, -- Tedarikçi bağlantısı
    order_number TEXT UNIQUE NOT NULL,
    order_date DATE DEFAULT CURRENT_DATE,
    expected_delivery_date DATE,
    actual_delivery_date DATE,
    status TEXT DEFAULT 'draft', -- 'draft', 'submitted', 'partially_received', 'received', 'cancelled'
    total_amount NUMERIC(12, 2),
    notes TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Satın Alma Sipariş Detayları
CREATE TABLE public.inventory_order_request_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    order_request_id UUID NOT NULL REFERENCES public.inventory_order_requests(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
    quantity NUMERIC(10, 2) NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    received_quantity NUMERIC(10, 2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(order_request_id, item_id)
);

-- Tedarikçiler
CREATE TABLE public.inventory_suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID REFERENCES public.hotels(id) ON DELETE CASCADE, -- Belirli bir otele mi özel?
    supplier_name TEXT NOT NULL,
    contact_person TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    tax_id TEXT,
    payment_terms TEXT,
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, supplier_name)
);

-- ======================================
-- Menü Yönetimi (Restoran/Kafe için)
-- ======================================

-- Menü Kategorileri (Kahvaltılıklar, Ana Yemekler, İçecekler vb.)
CREATE TABLE public.menu_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    category_name TEXT NOT NULL,
    description TEXT,
    parent_category_id UUID REFERENCES public.menu_categories(id) ON DELETE SET NULL,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(hotel_id, category_name)
);

-- Menü Öğeleri
CREATE TABLE public.menu_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.menu_categories(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL,
    item_code TEXT UNIQUE,
    image_url TEXT,
    allergens TEXT[],
    dietary_info TEXT[], -- 'Vegan', 'Gluten-Free'
    preparation_time_minutes INTEGER,
    is_available BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(category_id, item_name)
);

-- Menü Öğesi ve Envanter İlişkisi (Reçete)
CREATE TABLE public.menu_item_inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
    inventory_item_id UUID NOT NULL REFERENCES public.inventory_items(id) ON DELETE CASCADE,
    quantity_used NUMERIC(10, 2) NOT NULL, -- Bir menü öğesi için ne kadar envanter öğesi kullanılıyor
    unit_of_measure TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(menu_item_id, inventory_item_id)
);

-- Menü Satışları (POS Entegrasyonu veya Manuel Giriş)
CREATE TABLE public.menu_sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
    reservation_id UUID REFERENCES public.res_reservations(id) ON DELETE SET NULL,
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price NUMERIC(10, 2) NOT NULL,
    total_price NUMERIC(12, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    sale_time TIMESTAMPTZ DEFAULT now(),
    order_id TEXT, -- POS sipariş numarası
    table_number TEXT,
    server_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    payment_status public.payment_status DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Menü Öğesi Değiştiricileri (Ekstra Peynir, Sos Yok vb.)
CREATE TABLE public.menu_modifiers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    modifier_group_name TEXT NOT NULL, -- 'Ekstralar', 'Soslar', 'Pişirme Derecesi'
    min_selection INTEGER DEFAULT 0,
    max_selection INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(hotel_id, modifier_group_name)
);

CREATE TABLE public.menu_item_modifiers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    modifier_group_id UUID NOT NULL REFERENCES public.menu_modifiers(id) ON DELETE CASCADE,
    modifier_name TEXT NOT NULL,
    price_adjustment NUMERIC(10, 2) DEFAULT 0,
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(modifier_group_id, modifier_name)
);

-- Menü öğelerine atanmış değiştirici grupları
CREATE TABLE public.menu_item_modifier_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
    modifier_group_id UUID NOT NULL REFERENCES public.menu_modifiers(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(menu_item_id, modifier_group_id)
);

-- ======================================
-- Sunulan Hizmetler (Spa, Tur vb.)
-- ======================================

CREATE TABLE public.services_catalog (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    service_name TEXT NOT NULL,
    description TEXT,
    category TEXT, -- 'Spa', 'Tours', 'Activities', 'Transfer'
    duration_minutes INTEGER,
    pricing_type public.service_pricing_type NOT NULL DEFAULT 'per_item', -- Yeni eklendi
    unit_price NUMERIC(10, 2), -- 'price' -> 'unit_price' olarak değiştirildi
    currency CHAR(3),
    requires_booking BOOLEAN DEFAULT true,
    booking_lead_time_hours INTEGER,
    image_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(hotel_id, service_name)
);

-- Hizmet Sağlayıcıları (Personel veya Dış Firma)
CREATE TABLE public.services_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    provider_name TEXT NOT NULL,
    provider_type TEXT, -- 'Internal Staff', 'External Company'
    user_profile_id UUID REFERENCES public.user_profiles(user_id) ON DELETE SET NULL, -- Eğer personel ise
    external_provider_id UUID REFERENCES public.maintenance_service_providers(id) ON DELETE SET NULL, -- Eğer dış firma ise
    specialization TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(hotel_id, provider_name)
);

-- Hizmet ve Sağlayıcı İlişkisi
CREATE TABLE public.services_catalog_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    service_id UUID NOT NULL REFERENCES public.services_catalog(id) ON DELETE CASCADE,
    provider_id UUID NOT NULL REFERENCES public.services_providers(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(service_id, provider_id)
);

-- Hizmet Rezervasyonları
CREATE TABLE public.services_bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    service_id UUID NOT NULL REFERENCES public.services_catalog(id) ON DELETE CASCADE,
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    reservation_id UUID REFERENCES public.res_reservations(id) ON DELETE SET NULL,
    provider_id UUID REFERENCES public.services_providers(id) ON DELETE SET NULL,
    booking_time TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER,
    status TEXT DEFAULT 'confirmed', -- 'confirmed', 'cancelled', 'completed', 'no_show'
    price_paid NUMERIC(10, 2),
    notes TEXT,
    booked_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Hizmet Müsaitliği (Özellikle sağlayıcı bazlı ise)
CREATE TABLE public.services_availability (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    service_id UUID REFERENCES public.services_catalog(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES public.services_providers(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_available BOOLEAN DEFAULT true,
    booked_by_booking_id UUID REFERENCES public.services_bookings(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(provider_id, date, start_time)
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

CREATE TRIGGER trg_inventory_items_updated_at
BEFORE UPDATE ON public.inventory_items
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- inventory_movements için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_inventory_alerts_updated_at
BEFORE UPDATE ON public.inventory_alerts
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_inventory_order_requests_updated_at
BEFORE UPDATE ON public.inventory_order_requests
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_inventory_order_request_items_updated_at
BEFORE UPDATE ON public.inventory_order_request_items
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_inventory_suppliers_updated_at
BEFORE UPDATE ON public.inventory_suppliers
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_menu_categories_updated_at
BEFORE UPDATE ON public.menu_categories
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_menu_items_updated_at
BEFORE UPDATE ON public.menu_items
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- menu_item_inventory için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_menu_sales_updated_at
BEFORE UPDATE ON public.menu_sales
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_menu_modifiers_updated_at
BEFORE UPDATE ON public.menu_modifiers
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_menu_item_modifiers_updated_at
BEFORE UPDATE ON public.menu_item_modifiers
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- menu_item_modifier_groups için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_services_catalog_updated_at
BEFORE UPDATE ON public.services_catalog
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_services_providers_updated_at
BEFORE UPDATE ON public.services_providers
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- services_catalog_providers için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_services_bookings_updated_at
BEFORE UPDATE ON public.services_bookings
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_services_availability_updated_at
BEFORE UPDATE ON public.services_availability
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Eksik updated_at trigger'ları
CREATE TRIGGER trg_inventory_movements_updated_at
BEFORE UPDATE ON public.inventory_movements
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_menu_item_inventory_updated_at
BEFORE UPDATE ON public.menu_item_inventory
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_menu_item_modifier_groups_updated_at
BEFORE UPDATE ON public.menu_item_modifier_groups
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_services_catalog_providers_updated_at
BEFORE UPDATE ON public.services_catalog_providers
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Eksik FK Tanımlamaları (İlgili tablolar oluşturulduktan sonra)
-- Bu komutlar idealde 010_payments_and_invoicing.sql (tax_rates için)
-- ve bu dosyanın sonu (suppliers için) birleştikten sonra çalıştırılmalı
-- veya ayrı bir migrasyonda yapılmalıdır.
-- Şimdilik buraya ekliyoruz, ancak çalışması için 010'un uygulanmış olması gerekir.
-- Daha güvenli yöntem: Bu ALTER'ları 010 dosyasının sonuna taşımak.
