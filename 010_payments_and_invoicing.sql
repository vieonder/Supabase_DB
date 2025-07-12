-- ##########################################################
-- 010_payments_and_invoicing.sql (Yeniden Düzenlenmiş)
-- Ödemeler, Faturalandırma ve İlgili Tablolar
-- ##########################################################

BEGIN; -- İşlemleri tek bir transaction içinde yap

-- ======================================\n-- Tablo Tanımlamaları (Doğru Sırada)\n-- ======================================\n

-- 1. payment_methods
CREATE TABLE public.payment_methods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    method_name TEXT NOT NULL, -- 'Credit Card', 'Bank Transfer', 'Cash', 'PayPal'
    method_type TEXT, -- 'online', 'offline'
    provider TEXT, -- 'Stripe', 'iyzico', 'Manual'
    account_details JSONB, -- Ağ geçidi anahtarları, banka hesap bilgileri (şifreli?)
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, method_name)
);

-- 2. tax_rates
CREATE TABLE public.tax_rates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    tax_name TEXT NOT NULL, -- 'KDV', 'Konaklama Vergisi'
    rate_percentage NUMERIC(5, 2) NOT NULL CHECK (rate_percentage >= 0),
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, tax_name)
);

-- 3. payment_gateways
CREATE TABLE public.payment_gateways (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    gateway_name TEXT NOT NULL, -- 'Stripe', 'iyzico', 'PayPal'
    api_key TEXT, -- Şifreli saklanmalı
    secret_key TEXT, -- Şifreli saklanmalı
    webhook_secret TEXT, -- Şifreli saklanmalı
    environment TEXT DEFAULT 'test', -- 'test', 'production'
    is_active BOOLEAN DEFAULT true,
    supported_currencies CHAR(3)[],
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, gateway_name)
);

-- 4. invoices (Müşteri/Misafir için)
CREATE TABLE public.invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    reservation_id UUID, -- FK sonda eklenecek (DEFERRABLE)
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    invoice_number TEXT UNIQUE NOT NULL,
    invoice_date DATE DEFAULT CURRENT_DATE,
    due_date DATE,
    status public.invoice_status DEFAULT 'draft',
    subtotal_amount NUMERIC(12, 2) DEFAULT 0,
    tax_amount NUMERIC(12, 2) DEFAULT 0,
    discount_amount NUMERIC(12, 2) DEFAULT 0,
    total_amount NUMERIC(12, 2) GENERATED ALWAYS AS (subtotal_amount + tax_amount - discount_amount) STORED,
    paid_amount NUMERIC(12, 2) DEFAULT 0,
    balance_due NUMERIC(12, 2) GENERATED ALWAYS AS ((subtotal_amount + tax_amount - discount_amount) - paid_amount) STORED,
    currency CHAR(3) NOT NULL,
    billing_address JSONB,
    notes TEXT,
    pdf_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. invoice_items (Müşteri/Misafir için)
CREATE TABLE public.invoice_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL, -- 'Room Charge', 'Service', 'Product', 'Extra Charge', 'Discount', 'Tax'
    description TEXT NOT NULL,
    quantity NUMERIC(10, 2) DEFAULT 1,
    unit_price NUMERIC(12, 2) NOT NULL,
    total_amount NUMERIC(12, 2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    tax_rate_id UUID REFERENCES public.tax_rates(id) ON DELETE SET NULL,
    related_item_id UUID,
    reservation_id UUID, -- FK sonda eklenecek (DEFERRABLE)
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 6. payments
CREATE TABLE public.payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    reservation_id UUID REFERENCES public.res_reservations(id) ON DELETE SET NULL,
    payment_method_id UUID REFERENCES public.payment_methods(id) ON DELETE SET NULL,
    payment_gateway_id UUID REFERENCES public.payment_gateways(id) ON DELETE SET NULL,
    amount NUMERIC(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL,
    payment_date TIMESTAMPTZ DEFAULT now(),
    status public.payment_status DEFAULT 'pending',
    transaction_reference TEXT,
    gateway_response JSONB,
    notes TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 7. extra_charges
CREATE TABLE public.extra_charges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    charge_name TEXT NOT NULL,
    charge_code TEXT UNIQUE,
    description TEXT,
    charge_type public.extra_charge_type NOT NULL,
    default_price NUMERIC(10, 2) NOT NULL,
    tax_rate_id UUID REFERENCES public.tax_rates(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(hotel_id, charge_name)
);

-- 8. extra_charge_items
CREATE TABLE public.extra_charge_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    extra_charge_id UUID NOT NULL REFERENCES public.extra_charges(id) ON DELETE CASCADE,
    reservation_id UUID REFERENCES public.res_reservations(id) ON DELETE CASCADE,
    guest_id UUID REFERENCES public.guests(id) ON DELETE CASCADE,
    invoice_item_id UUID REFERENCES public.invoice_items(id) ON DELETE SET NULL,
    description TEXT,
    quantity INTEGER DEFAULT 1,
    unit_price NUMERIC(10, 2),
    charge_date TIMESTAMPTZ DEFAULT now(),
    notes TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CHECK (reservation_id IS NOT NULL OR guest_id IS NOT NULL)
);

-- 9. customer_accounts
CREATE TABLE public.customer_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    guest_id UUID UNIQUE REFERENCES public.guests(id) ON DELETE CASCADE NOT NULL,
    account_number TEXT UNIQUE NOT NULL,
    account_type TEXT,
    balance NUMERIC(12, 2) DEFAULT 0,
    credit_limit NUMERIC(12, 2),
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 10. customer_account_entries
CREATE TABLE public.customer_account_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES public.customer_accounts(id) ON DELETE CASCADE,
    entry_type TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    description TEXT,
    related_document_type TEXT,
    related_document_id UUID,
    entry_date TIMESTAMPTZ DEFAULT now(),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
    -- Bu tabloda genellikle updated_at olmaz.
);

-- 11. payment_promotions
CREATE TABLE public.payment_promotions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    promotion_name TEXT NOT NULL,
    promotion_code TEXT UNIQUE,
    description TEXT,
    discount_type TEXT CHECK (discount_type IN ('percentage', 'fixed_amount')),
    discount_value NUMERIC(10, 2) NOT NULL,
    applicable_items JSONB,
    min_purchase_amount NUMERIC(12, 2),
    max_discount_amount NUMERIC(12, 2),
    start_date DATE,
    end_date DATE,
    max_usages INTEGER,
    current_usages INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, promotion_name)
);

-- 12. payment_promotion_usages
CREATE TABLE public.payment_promotion_usages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    promotion_id UUID NOT NULL REFERENCES public.payment_promotions(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL,
    reservation_id UUID REFERENCES public.res_reservations(id) ON DELETE SET NULL,
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    usage_time TIMESTAMPTZ DEFAULT now(),
    discount_applied NUMERIC(12, 2),
    created_at TIMESTAMPTZ DEFAULT now()
    -- Bu tabloda genellikle updated_at olmaz.
);

-- 13. revenue_sources
CREATE TABLE public.revenue_sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    source_name TEXT NOT NULL,
    description TEXT,
    gl_account_code TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, source_name)
);

-- 14. revenue_entries
CREATE TABLE public.revenue_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    revenue_source_id UUID NOT NULL REFERENCES public.revenue_sources(id) ON DELETE CASCADE,
    invoice_item_id UUID REFERENCES public.invoice_items(id) ON DELETE SET NULL,
    payment_id UUID REFERENCES public.payments(id) ON DELETE SET NULL,
    amount NUMERIC(12, 2) NOT NULL,
    entry_date DATE NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 15. cash_register_entries
CREATE TABLE public.cash_register_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID NOT NULL REFERENCES public.hotels(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    entry_type TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    reason TEXT,
    related_document_type TEXT,
    related_document_id UUID,
    entry_time TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
    -- Bu tabloda genellikle updated_at olmaz.
);

-- 16. commission_invoices (Inntegrate Komisyon Faturaları)
CREATE TABLE public.commission_invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    invoice_number TEXT NOT NULL UNIQUE,
    status public.invoice_status DEFAULT 'draft' NOT NULL,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    period_start_date DATE,
    period_end_date DATE,
    currency CHAR(3) NOT NULL DEFAULT 'TRY',
    subtotal_amount DECIMAL(12, 2) DEFAULT 0.00,
    tax_amount DECIMAL(12, 2) DEFAULT 0.00,
    total_amount DECIMAL(12, 2) GENERATED ALWAYS AS (subtotal_amount + tax_amount) STORED,
    paid_amount DECIMAL(12, 2) DEFAULT 0.00,
    payment_status public.payment_status DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 17. commission_invoice_line_items (Komisyon Faturası Kalemleri)
CREATE TABLE public.commission_invoice_line_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    commission_invoice_id UUID NOT NULL REFERENCES public.commission_invoices(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL,
    description TEXT NOT NULL,
    reservation_id UUID, -- FK sonda eklenecek (DEFERRABLE)
    amount NUMERIC(12, 2) NOT NULL,
    related_data JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 18. tenant_payment_gateways (Tenant Ödeme Ağ Geçidi Ayarları)
CREATE TABLE public.tenant_payment_gateways (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    gateway_provider TEXT NOT NULL,
    display_name TEXT,
    is_active BOOLEAN DEFAULT true,
    is_primary BOOLEAN DEFAULT false,
    config_data JSONB NOT NULL,
    supported_currencies TEXT[],
    supported_installments INT[],
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, display_name)
);
COMMENT ON COLUMN public.tenant_payment_gateways.config_data IS 'Bankaya veya sağlayıcıya özel API anahtarları, mağaza kodları, 3D Secure anahtarları gibi hassas olmayan ama gerekli konfigürasyon verileri. Hassas anahtarlar Vault/Secrets Manager ile yönetilmelidir.';

-- ======================================\n-- İndeksler\n-- ======================================\n
CREATE INDEX idx_invoices_tenant_status ON public.commission_invoices(tenant_id, status);
CREATE INDEX idx_commission_invoice_line_items_invoice ON public.commission_invoice_line_items(commission_invoice_id);
CREATE INDEX idx_commission_invoice_line_items_reservation ON public.commission_invoice_line_items(reservation_id);
-- Not: Diğer tablolar için indeksler 021_indexes.sql dosyasında tanımlanmıştır.
-- Eğer bu dosyadaki tablolar için ek indeks gerekiyorsa buraya eklenebilir.


-- ======================================\n-- TETİKLEYİCİLER (Triggers - Toplu Halde)\n-- ======================================\n

CREATE TRIGGER trg_payment_methods_updated_at
BEFORE UPDATE ON public.payment_methods
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_tax_rates_updated_at
BEFORE UPDATE ON public.tax_rates
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_payment_gateways_updated_at
BEFORE UPDATE ON public.payment_gateways
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_invoices_updated_at
BEFORE UPDATE ON public.invoices
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_invoice_items_updated_at
BEFORE UPDATE ON public.invoice_items
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_payments_updated_at
BEFORE UPDATE ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_extra_charges_updated_at
BEFORE UPDATE ON public.extra_charges
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_extra_charge_items_updated_at
BEFORE UPDATE ON public.extra_charge_items
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_customer_accounts_updated_at
BEFORE UPDATE ON public.customer_accounts
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_payment_promotions_updated_at
BEFORE UPDATE ON public.payment_promotions
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_revenue_sources_updated_at
BEFORE UPDATE ON public.revenue_sources
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_revenue_entries_updated_at
BEFORE UPDATE ON public.revenue_entries
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_commission_invoices_updated_at
BEFORE UPDATE ON public.commission_invoices
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_commission_invoice_line_items_updated_at
BEFORE UPDATE ON public.commission_invoice_line_items
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_tenant_payment_gateways_updated_at
BEFORE UPDATE ON public.tenant_payment_gateways
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Not: customer_account_entries, payment_promotion_usages, cash_register_entries
-- tablolarında genellikle updated_at kolonu ve trigger'ı bulunmaz.


-- ##########################################################\n-- Döngüsel Bağımlılıkları ve Eksik FK'ları Çözmek İçin Tanımlamalar\n-- ##########################################################\n

-- Bu ALTER TABLE komutları, 004 (res_reservations) ve bu dosyadaki (010)\n-- tablolar oluşturulduktan sonra çalıştırılır.\n

-- 004 ve 010 arasındaki döngüsel bağımlılık FK'ları:
ALTER TABLE public.res_reservations
    ADD CONSTRAINT fk_res_reservations_invoice_id
    FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE SET NULL
    DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE public.invoices
    ADD CONSTRAINT fk_invoices_reservation_id
    FOREIGN KEY (reservation_id) REFERENCES public.res_reservations(id) ON DELETE SET NULL
    DEFERRABLE INITIALLY DEFERRED;

-- invoice_items.reservation_id için FK (invoice_items bu dosyada tanımlandı)
ALTER TABLE public.invoice_items
    ADD CONSTRAINT fk_invoice_items_reservation_id
    FOREIGN KEY (reservation_id) REFERENCES public.res_reservations(id) ON DELETE SET NULL
    DEFERRABLE INITIALLY DEFERRED;

-- commission_invoice_line_items.reservation_id için FK (bu dosyada tanımlandı)
ALTER TABLE public.commission_invoice_line_items
    ADD CONSTRAINT fk_commission_invoice_line_items_reservation_id
    FOREIGN KEY (reservation_id) REFERENCES public.res_reservations(id) ON DELETE SET NULL
    DEFERRABLE INITIALLY DEFERRED;

COMMIT; -- Başlatılan transaction'ı onayla