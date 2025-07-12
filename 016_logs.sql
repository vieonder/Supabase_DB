-- ##########################################################
-- 016_logs.sql
-- Sistem Loglama Tabloları
-- ##########################################################

-- ======================================
-- Denetim Logları (Audit Logs)
-- ======================================

CREATE TABLE public.logs_audit (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    ip_address INET,
    user_agent TEXT,
    action TEXT NOT NULL, -- 'login', 'logout', 'create_user', 'update_settings', 'delete_reservation'
    entity_type TEXT, -- İşlemin yapıldığı varlık tipi (örn: 'reservations', 'users', 'settings')
    entity_id TEXT, -- İşlemin yapıldığı varlık ID'si
    old_value JSONB, -- Önceki değer (opsiyonel)
    new_value JSONB, -- Yeni değer (opsiyonel)
    description TEXT, -- Eylem açıklaması
    status TEXT DEFAULT 'success', -- 'success', 'failure'
    failure_reason TEXT, -- Hata sebebi (varsa)
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- Hata Logları (Error Logs)
-- ======================================

CREATE TABLE public.logs_error (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    source TEXT NOT NULL, -- 'backend_api', 'frontend_app', 'database_trigger', 'edge_function'
    error_code TEXT,
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    request_data JSONB, -- Hataya neden olan istek verisi
    context_data JSONB, -- Hata anındaki ek bağlam bilgisi
    severity public.log_level DEFAULT 'error', -- Hata seviyesi
    is_resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- API İstek/Yanıt Logları (API Request/Response Logs)
-- ======================================

CREATE TABLE public.logs_api_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    api_key_id UUID REFERENCES public.auth_api_keys(id) ON DELETE SET NULL,
    ip_address INET,
    user_agent TEXT,
    http_method TEXT NOT NULL, -- 'GET', 'POST', 'PUT', 'DELETE'
    endpoint TEXT NOT NULL,
    request_headers JSONB,
    request_body JSONB,
    response_status_code INTEGER,
    response_headers JSONB,
    response_body JSONB,
    duration_ms INTEGER, -- İstek süresi (milisaniye)
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- E-posta/SMS Gönderim Logları
-- ======================================

CREATE TABLE public.logs_communication (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    communication_id UUID REFERENCES public.guest_communications(id) ON DELETE SET NULL,
    campaign_id UUID REFERENCES public.marketing_campaigns(id) ON DELETE SET NULL,
    recipient_email TEXT,
    recipient_phone TEXT,
    channel TEXT NOT NULL, -- 'email', 'sms'
    provider TEXT, -- 'SendGrid', 'Twilio', 'Supabase Auth'
    status TEXT NOT NULL, -- 'sent', 'delivered', 'failed', 'opened', 'clicked'
    provider_message_id TEXT,
    error_message TEXT,
    event_time TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- Veritabanı Değişiklik Logları (Trigger ile - Opsiyonel)
-- Belirli kritik tablolar için değişiklikleri loglamak amacıyla kullanılabilir.
-- ======================================

-- Örnek: Rezervasyon değişikliklerini loglama
CREATE TABLE public.logs_reservation_changes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    reservation_id UUID NOT NULL REFERENCES public.res_reservations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    change_type TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    column_changed TEXT,
    old_value TEXT,
    new_value TEXT,
    changed_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ======================================
-- TETİKLEYİCİLER
-- Not: Log tabloları genellikle INSERT odaklıdır, updated_at trigger'ları gerekmeyebilir.
-- Ancak, logs_error.is_resolved gibi alanlar güncellenebilir.
-- ======================================

CREATE TRIGGER trg_logs_error_updated_at
BEFORE UPDATE ON public.logs_error
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Örnek Trigger Fonksiyonu (logs_reservation_changes için - 016'ya taşınabilir)
-- CREATE OR REPLACE FUNCTION log_reservation_changes()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     IF (TG_OP = 'DELETE') THEN
--         INSERT INTO public.logs_reservation_changes (tenant_id, reservation_id, user_id, change_type, old_value)
--         VALUES (OLD.tenant_id, OLD.id, auth.uid(), TG_OP, row_to_json(OLD));
--         RETURN OLD;
--     ELSIF (TG_OP = 'UPDATE') THEN
--         -- Sadece belirli sütunlar değiştiğinde logla veya tüm değişiklikleri logla
--         INSERT INTO public.logs_reservation_changes (tenant_id, reservation_id, user_id, change_type, old_value, new_value)
--         VALUES (NEW.tenant_id, NEW.id, auth.uid(), TG_OP, row_to_json(OLD), row_to_json(NEW));
--         RETURN NEW;
--     ELSIF (TG_OP = 'INSERT') THEN
--         INSERT INTO public.logs_reservation_changes (tenant_id, reservation_id, user_id, change_type, new_value)
--         VALUES (NEW.tenant_id, NEW.id, auth.uid(), TG_OP, row_to_json(NEW));
--         RETURN NEW;
--     END IF;
--     RETURN NULL;
-- END;
-- $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Örnek Trigger Tanımı
-- CREATE TRIGGER reservation_changes_trigger
-- AFTER INSERT OR UPDATE OR DELETE ON public.res_reservations
-- FOR EACH ROW EXECUTE FUNCTION log_reservation_changes();
