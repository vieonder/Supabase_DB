-- ##########################################################
-- 029_chat_tables.sql
-- Canlı Sohbet Sistemi Tabloları
-- ##########################################################

-- ======================================
-- Sohbet Konuşmaları
-- ======================================
CREATE TABLE public.chat_conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID REFERENCES public.hotels(id) ON DELETE CASCADE, -- Opsiyonel, otele özgü ise
    guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL, -- İlişkili misafir
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- İlişkili kayıtlı kullanıcı (misafir veya personel)
    anonymous_user_id TEXT, -- Anonim ziyaretçi ID'si (örn. localStorage UUID)
    assigned_agent_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Konuşmaya atanan personel (opsiyonel)
    status TEXT DEFAULT 'open' NOT NULL CHECK (status IN ('open', 'closed', 'pending', 'offline_message')), -- 'pending' çevrimdışı mesajlar için kullanılabilir
    started_at TIMESTAMPTZ DEFAULT now(),
    ended_at TIMESTAMPTZ,
    last_message_at TIMESTAMPTZ,
    metadata JSONB, -- Başlangıç URL'si, tarayıcı bilgisi, ön form verileri vb.
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    -- En az bir kimlik bilgisi olmalı (anonim, misafir veya kullanıcı)
    CHECK (guest_id IS NOT NULL OR user_id IS NOT NULL OR anonymous_user_id IS NOT NULL)
);

-- İndeksler
CREATE INDEX idx_chat_conversations_tenant_status ON public.chat_conversations(tenant_id, status, last_message_at DESC);
CREATE INDEX idx_chat_conversations_guest ON public.chat_conversations(guest_id);
CREATE INDEX idx_chat_conversations_user ON public.chat_conversations(user_id);
CREATE INDEX idx_chat_conversations_anon ON public.chat_conversations(anonymous_user_id);
CREATE INDEX idx_chat_conversations_agent ON public.chat_conversations(assigned_agent_id);

-- updated_at trigger'ı
CREATE TRIGGER trg_chat_conversations_updated_at
BEFORE UPDATE ON public.chat_conversations
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ======================================
-- Sohbet Mesajları
-- ======================================
CREATE TABLE public.chat_messages (
    id BIGSERIAL PRIMARY KEY,
    conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
    sender_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Gönderen personel
    sender_guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL, -- Gönderen misafir
    sender_anonymous_id TEXT, -- Gönderen anonim ziyaretçi
    sender_type TEXT NOT NULL CHECK (sender_type IN ('agent', 'guest', 'system')), -- 'system' otomatik mesajlar için
    message_text TEXT NOT NULL, -- MVP için sadece metin
    sent_at TIMESTAMPTZ DEFAULT now(),
    read_at TIMESTAMPTZ, -- Okundu bilgisi (opsiyonel)
    -- En az bir gönderen ID'si olmalı
    CHECK (sender_user_id IS NOT NULL OR sender_guest_id IS NOT NULL OR sender_anonymous_id IS NOT NULL OR sender_type = 'system')
);

-- İndeksler
CREATE INDEX idx_chat_messages_conversation_sent ON public.chat_messages(conversation_id, sent_at DESC);
CREATE INDEX idx_chat_messages_sender_user ON public.chat_messages(sender_user_id);
CREATE INDEX idx_chat_messages_sender_guest ON public.chat_messages(sender_guest_id);

-- Not: chat_messages genellikle immutable'dır, updated_at trigger'ı eklenmedi.

-- ======================================
-- Sohbet Katılımcıları (Personel)
-- ======================================
CREATE TABLE public.chat_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, -- Katılan personel
    joined_at TIMESTAMPTZ DEFAULT now(),
    left_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (conversation_id, user_id) -- Bir personel bir konuşmaya bir kez katılabilir
);

-- İndeksler
CREATE INDEX idx_chat_participants_user ON public.chat_participants(user_id);

-- updated_at trigger'ı
CREATE TRIGGER trg_chat_participants_updated_at
BEFORE UPDATE ON public.chat_participants
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ======================================
-- Realtime Yayınları (021'de tanımlı)
-- ======================================
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_conversations; -- Durum değişiklikleri için eklenebilir
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_participants; -- Katılımcı değişiklikleri için eklenebilir
