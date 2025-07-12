-- ##########################################################
-- 008_housekeeping_and_maintenance.sql
-- Kat Hizmetleri ve Bakım Tabloları
-- ##########################################################

-- ======================================
-- Kat Hizmetleri (Housekeeping)
-- ======================================

-- Housekeeping Personeli
CREATE TABLE public.hk_staff (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    user_profile_id UUID UNIQUE NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    employee_id TEXT UNIQUE, -- Personel Numarası
    shift TEXT, -- Çalışma Vardiyası
    assigned_floors TEXT[], -- Atanan Katlar
    is_supervisor BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Housekeeping Görevleri
CREATE TABLE public.hk_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    room_id UUID REFERENCES public.hotels_rooms(id) ON DELETE CASCADE,
    task_type TEXT NOT NULL, -- 'Full Clean', 'Tidy Up', 'Linen Change', 'Inspection'
    assigned_staff_id UUID REFERENCES public.hk_staff(id) ON DELETE SET NULL,
    status public.hk_task_status DEFAULT 'pending',
    priority INTEGER DEFAULT 0,
    scheduled_date DATE,
    scheduled_time TIME,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    duration_minutes INTEGER,
    notes TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Oda Durum Logları (Housekeeping tarafından güncellenen)
-- Bu, hotels_rooms.status'tan daha detaylı olabilir veya onun yerine geçebilir.
CREATE TABLE public.hk_room_status_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.hotels_rooms(id) ON DELETE CASCADE,
    status public.room_status NOT NULL,
    reason TEXT,
    changed_by UUID REFERENCES public.hk_staff(id) ON DELETE SET NULL,
    changed_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Housekeeping Envanter Öğeleri (Temizlik Malzemeleri, Linen vb.)
CREATE TABLE public.hk_inventory_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    item_name TEXT NOT NULL,
    item_code TEXT UNIQUE,
    description TEXT,
    category TEXT, -- 'Cleaning Supplies', 'Linen', 'Guest Amenities'
    unit_of_measure TEXT, -- 'piece', 'bottle', 'set'
    stock_level INTEGER DEFAULT 0,
    reorder_level INTEGER,
    location TEXT, -- Depo konumu
    supplier_info JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, item_name)
);

-- Housekeeping Envanter Hareketleri
CREATE TABLE public.hk_inventory_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    item_id UUID NOT NULL REFERENCES public.hk_inventory_items(id) ON DELETE CASCADE,
    transaction_type public.hk_inventory_transaction_type NOT NULL,
    quantity INTEGER NOT NULL,
    staff_id UUID REFERENCES public.hk_staff(id) ON DELETE SET NULL,
    task_id UUID REFERENCES public.hk_tasks(id) ON DELETE SET NULL,
    transaction_date TIMESTAMPTZ DEFAULT now(),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Housekeeping Denetim Kontrol Listeleri (Şablonlar)
CREATE TABLE public.hk_inspection_checklists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    checklist_name TEXT NOT NULL,
    description TEXT,
    checklist_items JSONB NOT NULL, -- [{ "area": "Bathroom", "item": "Clean sink", "points": 5 }, ...]
    total_points INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(hotel_id, checklist_name)
);

-- Gerçekleştirilen Denetimler
CREATE TABLE public.hk_inspections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    checklist_id UUID NOT NULL REFERENCES public.hk_inspection_checklists(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.hotels_rooms(id) ON DELETE CASCADE,
    inspector_staff_id UUID REFERENCES public.hk_staff(id) ON DELETE SET NULL,
    task_id UUID REFERENCES public.hk_tasks(id) ON DELETE SET NULL,
    inspection_date TIMESTAMPTZ DEFAULT now(),
    status public.hk_inspection_status DEFAULT 'pending',
    score INTEGER,
    results JSONB, -- [{ "item_id": "xyz", "status": "passed", "notes": "..." }, ...]
    notes TEXT,
    follow_up_required BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Housekeeping Personel Vardiyaları
CREATE TABLE public.hk_shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    shift_name TEXT NOT NULL, -- 'Morning', 'Evening', 'Night'
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(hotel_id, shift_name)
);

-- Housekeeping Personel Programı
CREATE TABLE public.hk_staff_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    staff_id UUID NOT NULL REFERENCES public.hk_staff(id) ON DELETE CASCADE,
    shift_id UUID REFERENCES public.hk_shifts(id) ON DELETE SET NULL,
    work_date DATE NOT NULL,
    start_time TIME,
    end_time TIME,
    assigned_area TEXT, -- 'Floor 3', 'Public Areas'
    notes TEXT,
    is_off_day BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(staff_id, work_date)
);

-- Housekeeping Personel Performans Kayıtları (Opsiyonel)
CREATE TABLE public.hk_staff_performance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    staff_id UUID NOT NULL REFERENCES public.hk_staff(id) ON DELETE CASCADE,
    period_start_date DATE NOT NULL,
    period_end_date DATE NOT NULL,
    tasks_assigned INTEGER,
    tasks_completed INTEGER,
    avg_completion_time_minutes INTEGER,
    inspection_scores JSONB, -- {"avg": 85, "count": 10}
    guest_feedback_score FLOAT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(staff_id, period_start_date)
);

-- Misafir Talepleri (Housekeeping ile ilgili)
CREATE TABLE public.hk_guest_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    reservation_room_id UUID REFERENCES public.res_reservation_rooms(id) ON DELETE SET NULL,
    request_type TEXT NOT NULL, -- 'Extra Towels', 'Toiletries', 'Room Cleaning'
    request_details TEXT,
    status TEXT DEFAULT 'pending', -- 'pending', 'in_progress', 'completed', 'cancelled'
    priority INTEGER DEFAULT 0,
    requested_at TIMESTAMPTZ DEFAULT now(),
    assigned_staff_id UUID REFERENCES public.hk_staff(id) ON DELETE SET NULL,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Housekeeping Rapor Şablonları (Opsiyonel)
CREATE TABLE public.hk_report_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    report_name TEXT NOT NULL,
    description TEXT,
    query TEXT NOT NULL, -- Raporu üretecek SQL sorgusu
    parameters JSONB, -- Rapor parametreleri
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(hotel_id, report_name)
);

-- ======================================
-- Bakım (Maintenance)
-- ======================================

-- Bakım Varlıkları (Ekipmanlar, Odalar vb.)
CREATE TABLE public.maintenance_assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    asset_name TEXT NOT NULL,
    asset_tag TEXT UNIQUE,
    description TEXT,
    category TEXT, -- 'HVAC', 'Plumbing', 'Electrical', 'Room Fixture'
    location TEXT, -- 'Room 101', 'Boiler Room'
    room_id UUID REFERENCES public.hotels_rooms(id) ON DELETE SET NULL,
    manufacturer TEXT,
    model_number TEXT,
    serial_number TEXT,
    purchase_date DATE,
    warranty_expiry_date DATE,
    last_maintenance_date DATE,
    next_maintenance_date DATE,
    status TEXT DEFAULT 'operational', -- 'operational', 'under_maintenance', 'out_of_service'
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Bakım İş Emirleri
CREATE TABLE public.maintenance_work_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    work_order_number TEXT UNIQUE NOT NULL, -- Otomatik artan veya oluşturulan numara
    asset_id UUID REFERENCES public.maintenance_assets(id) ON DELETE SET NULL,
    room_id UUID REFERENCES public.hotels_rooms(id) ON DELETE SET NULL,
    description TEXT NOT NULL, -- Yapılacak işin tanımı
    reported_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reported_at TIMESTAMPTZ DEFAULT now(),
    priority INTEGER DEFAULT 0, -- 0: Low, 1: Medium, 2: High
    status public.maintenance_work_order_status DEFAULT 'open',
    assigned_technician_id UUID REFERENCES public.user_profiles(user_id) ON DELETE SET NULL,
    scheduled_date DATE,
    estimated_duration_hours NUMERIC(5, 2),
    actual_start_time TIMESTAMPTZ,
    actual_end_time TIMESTAMPTZ,
    work_details TEXT, -- Yapılan işlerin detayı
    parts_used JSONB, -- Kullanılan parçalar [{part_id: uuid, quantity: 2}, ...]
    cost NUMERIC(10, 2),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Önleyici Bakım Programı
CREATE TABLE public.maintenance_preventive_schedule (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    asset_id UUID NOT NULL REFERENCES public.maintenance_assets(id) ON DELETE CASCADE,
    task_description TEXT NOT NULL,
    frequency_interval INTERVAL, -- '1 month', '3 months', '1 year'
    frequency_unit TEXT, -- 'day', 'week', 'month', 'year'
    frequency_value INTEGER,
    next_due_date DATE,
    last_performed_date DATE,
    assigned_technician_id UUID REFERENCES public.user_profiles(user_id) ON DELETE SET NULL,
    estimated_duration_hours NUMERIC(5, 2),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Bakım Parça Envanteri
CREATE TABLE public.maintenance_parts_inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    part_name TEXT NOT NULL,
    part_number TEXT UNIQUE,
    description TEXT,
    category TEXT,
    unit_of_measure TEXT,
    stock_level INTEGER DEFAULT 0,
    reorder_level INTEGER,
    location TEXT,
    supplier_info JSONB,
    unit_cost NUMERIC(10, 2),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (hotel_id, part_name)
);

-- Bakım Parça Hareketleri
CREATE TABLE public.maintenance_parts_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    part_id UUID NOT NULL REFERENCES public.maintenance_parts_inventory(id) ON DELETE CASCADE,
    work_order_id UUID REFERENCES public.maintenance_work_orders(id) ON DELETE SET NULL,
    transaction_type public.maintenance_parts_transaction_type NOT NULL,
    quantity INTEGER NOT NULL,
    technician_id UUID REFERENCES public.user_profiles(user_id) ON DELETE SET NULL,
    transaction_date TIMESTAMPTZ DEFAULT now(),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Dış Servis Sağlayıcıları (Bakım için)
CREATE TABLE public.maintenance_service_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    provider_name TEXT NOT NULL,
    contact_person TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    specialization TEXT, -- 'HVAC', 'Plumbing', 'Electrical'
    contract_details JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, provider_name)
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

CREATE TRIGGER trg_hk_staff_updated_at
BEFORE UPDATE ON public.hk_staff
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hk_tasks_updated_at
BEFORE UPDATE ON public.hk_tasks
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- hk_room_status_log için updated_at genellikle gereksizdir, sadece created_at yeterli.

CREATE TRIGGER trg_hk_inventory_items_updated_at
BEFORE UPDATE ON public.hk_inventory_items
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- hk_inventory_transactions için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_hk_inspection_checklists_updated_at
BEFORE UPDATE ON public.hk_inspection_checklists
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hk_inspections_updated_at
BEFORE UPDATE ON public.hk_inspections
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hk_shifts_updated_at
BEFORE UPDATE ON public.hk_shifts
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hk_staff_schedules_updated_at
BEFORE UPDATE ON public.hk_staff_schedules
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hk_staff_performance_updated_at
BEFORE UPDATE ON public.hk_staff_performance
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hk_guest_requests_updated_at
BEFORE UPDATE ON public.hk_guest_requests
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_hk_report_templates_updated_at
BEFORE UPDATE ON public.hk_report_templates
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_maintenance_assets_updated_at
BEFORE UPDATE ON public.maintenance_assets
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_maintenance_work_orders_updated_at
BEFORE UPDATE ON public.maintenance_work_orders
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_maintenance_preventive_schedule_updated_at
BEFORE UPDATE ON public.maintenance_preventive_schedule
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_maintenance_parts_inventory_updated_at
BEFORE UPDATE ON public.maintenance_parts_inventory
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- maintenance_parts_transactions için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_maintenance_service_providers_updated_at
BEFORE UPDATE ON public.maintenance_service_providers
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
