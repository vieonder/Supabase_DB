-- ##########################################################
-- 025_notifications_table.sql
-- Uygulama İçi Bildirimler Tablosu
-- ##########################################################

-- Bildirimler tablosu (Panel içi/Uygulama içi)
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,

    -- Hedefleme: Ya belirli bir kullanıcı ya da bir rol hedeflenir
    target_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    target_role_name TEXT, -- Hedef rol (örn: 'reception', 'manager')

    event_type TEXT NOT NULL, -- Bildirimi tetikleyen olay (örn: 'new_booking', 'guest_message', 'low_stock')
    title TEXT NOT NULL, -- Bildirimin başlığı (panelde gösterilecek)
    message TEXT, -- Bildirimin kısa içeriği/özeti
    icon TEXT, -- Bildirimle ilişkilendirilecek ikon (opsiyonel)
    action_url TEXT, -- Bildirime tıklandığında gidilecek URL (panel içinde)

    -- İlişkili Varlık: Bildirimin ilgili olduğu kaydı belirtir
    related_entity_type TEXT, -- (örn: 'reservations', 'guests', 'chat_conversations')
    related_entity_id UUID,

    -- Durum Yönetimi
    status TEXT DEFAULT 'unread' NOT NULL CHECK (status IN ('unread', 'read', 'archived')),
    created_at TIMESTAMPTZ DEFAULT now(),
    read_at TIMESTAMPTZ, -- Okundu olarak işaretlendiği zaman

    -- Hedefleme kontrolü
    CHECK (target_user_id IS NOT NULL OR target_role_name IS NOT NULL)
);

-- İndeksler (Performans için)
CREATE INDEX idx_notifications_tenant_target_user_status ON public.notifications(tenant_id, target_user_id, status, created_at DESC);
CREATE INDEX idx_notifications_tenant_target_role_status ON public.notifications(tenant_id, target_role_name, status, created_at DESC);
CREATE INDEX idx_notifications_event_type ON public.notifications(tenant_id, event_type);
CREATE INDEX idx_notifications_related_entity ON public.notifications(tenant_id, related_entity_type, related_entity_id);

-- updated_at trigger'ı (Eğer status/read_at güncellenecekse)
-- Not: Bu trigger 017_functions_and_triggers.sql dosyasında tanımlanan genel fonksiyonu kullanır.
CREATE TRIGGER trg_notifications_updated_at
BEFORE UPDATE ON public.notifications
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Realtime için yayına ekleme (021_realtime_publications.sql dosyasında yapıldı, burada tekrar etmeye gerek yok ama not olarak kalsın)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
