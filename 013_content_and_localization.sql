-- ##########################################################
-- 013_content_and_localization.sql
-- İçerik Yönetimi ve Lokalizasyon Tabloları
-- ##########################################################

-- ======================================
-- Lokalizasyon (Dil ve Çeviriler)
-- ======================================

-- Sistemde desteklenen diller (Tenant bazlı olabilir veya genel)
CREATE TABLE public.localization_languages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE, -- NULL ise genel dil
    language_code CHAR(2) NOT NULL, -- 'en', 'tr', 'de'
    language_name TEXT NOT NULL, -- 'English', 'Türkçe', 'Deutsch'
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, language_code)
);

-- Çeviri metinleri
CREATE TABLE public.localization_translations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES public.tenants(id) ON DELETE CASCADE, -- NULL ise genel çeviri
    language_code CHAR(2) NOT NULL,
    translation_key TEXT NOT NULL, -- Çeviri anahtarı (örn: 'homepage.welcome_message')
    translation_value TEXT NOT NULL, -- Çevrilmiş metin
    context TEXT, -- Çevirinin kullanıldığı yer (örn: 'web', 'admin', 'email')
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, language_code, translation_key),
    FOREIGN KEY (tenant_id, language_code) REFERENCES public.localization_languages(tenant_id, language_code) ON DELETE CASCADE -- Denemek için FK eklendi (NULL tenant_id durumu test edilmeli)
    -- Alternatif: Ayrı bir FK veya uygulama katmanında kontrol.
);

-- ======================================
-- İçerik Yönetimi (CMS)
-- ======================================

-- İçerik Tipleri (Blog Yazısı, Sayfa, Etkinlik vb.)
CREATE TABLE public.content_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    type_name TEXT NOT NULL, -- 'post', 'page', 'event', 'testimonial'
    slug_prefix TEXT UNIQUE, -- URL ön eki (örn: 'blog', 'pages')
    description TEXT,
    fields JSONB, -- Bu içerik tipine özgü alanlar (örn: [{"name": "event_date", "type": "date"}])
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, type_name)
);

-- İçerik Yazıları (Postlar, Sayfalar vb.)
CREATE TABLE public.content_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    hotel_id UUID REFERENCES public.hotels(id) ON DELETE CASCADE, -- Belirli bir otele ait olabilir
    content_type_id UUID NOT NULL REFERENCES public.content_types(id) ON DELETE CASCADE,
    author_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    slug TEXT NOT NULL, -- URL için benzersiz kısa ad
    excerpt TEXT, -- Kısa özet
    body_content TEXT, -- Ana içerik (Markdown veya HTML)
    body_json JSONB, -- Yapılandırılmış içerik (örn: block editor)
    featured_image_url TEXT,
    status public.content_status DEFAULT 'draft',
    published_at TIMESTAMPTZ,
    visibility TEXT DEFAULT 'public', -- 'public', 'private', 'password_protected'
    password TEXT, -- Eğer password_protected ise
    meta_data JSONB, -- SEO başlığı, açıklaması, özel alanlar vb.
    language_code CHAR(2) DEFAULT 'tr',
    translation_of UUID REFERENCES public.content_posts(id) ON DELETE SET NULL, -- Başka bir yazının çevirisi mi?
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (tenant_id, content_type_id, slug)
);

-- İçerik Kategorileri
CREATE TABLE public.content_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    category_name TEXT NOT NULL,
    slug TEXT NOT NULL,
    description TEXT,
    parent_category_id UUID REFERENCES public.content_categories(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, slug)
);

-- İçerik Etiketleri
CREATE TABLE public.content_tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    tag_name TEXT NOT NULL,
    slug TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, slug)
);

-- Yazı - Kategori İlişkisi (Çoka Çok)
CREATE TABLE public.content_post_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.content_posts(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.content_categories(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(post_id, category_id)
);

-- Yazı - Etiket İlişkisi (Çoka Çok)
CREATE TABLE public.content_post_tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.content_posts(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES public.content_tags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(post_id, tag_id)
);

-- İçerik Bölümleri (Sayfa şablonları için, örn: Hero, About Us, Contact Form)
CREATE TABLE public.content_sections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    section_name TEXT NOT NULL,
    section_key TEXT UNIQUE NOT NULL, -- Kod içinde kullanmak için anahtar
    description TEXT,
    content JSONB, -- Bölümün varsayılan içeriği veya yapısı
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, section_key)
);

-- Yazı/Sayfa - Bölüm İlişkisi (Sayfa oluşturucu için)
CREATE TABLE public.content_post_sections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.content_posts(id) ON DELETE CASCADE,
    section_id UUID NOT NULL REFERENCES public.content_sections(id) ON DELETE CASCADE,
    section_data JSONB, -- Bölüm için özelleştirilmiş veri
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Yüklenen Medya Dosyaları (Görseller, PDF'ler vb. - Storage ile entegre)
CREATE TABLE public.content_media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL, -- Storage'daki dosya yolu
    file_type TEXT, -- Mime type (örn: image/jpeg)
    file_size INTEGER,
    alt_text TEXT,
    caption TEXT,
    uploaded_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- İçerik Yorumları
CREATE TABLE public.content_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.content_posts(id) ON DELETE CASCADE,
    author_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    author_guest_id UUID REFERENCES public.guests(id) ON DELETE SET NULL,
    author_name TEXT, -- Eğer giriş yapmamışsa
    author_email TEXT, -- Eğer giriş yapmamışsa
    comment_content TEXT NOT NULL,
    parent_comment_id UUID REFERENCES public.content_comments(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending', -- 'pending', 'approved', 'spam', 'trash'
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Web Sitesi Menüleri (Header, Footer vb.)
CREATE TABLE public.content_menus (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    menu_name TEXT NOT NULL,
    menu_location TEXT UNIQUE NOT NULL, -- 'header_main', 'footer_legal'
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, menu_location)
);

-- Menü Öğeleri
CREATE TABLE public.content_menu_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    menu_id UUID NOT NULL REFERENCES public.content_menus(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    url TEXT, -- İç veya dış bağlantı
    target TEXT DEFAULT '_self', -- '_self', '_blank'
    icon TEXT, -- İkon sınıfı veya URL'si
    parent_item_id UUID REFERENCES public.content_menu_items(id) ON DELETE CASCADE,
    sort_order INTEGER DEFAULT 0,
    css_classes TEXT,
    related_post_id UUID REFERENCES public.content_posts(id) ON DELETE SET NULL,
    related_category_id UUID REFERENCES public.content_categories(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Bülten Aboneleri
CREATE TABLE public.content_subscribers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    email TEXT NOT NULL CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
    first_name TEXT,
    last_name TEXT,
    status TEXT DEFAULT 'subscribed', -- 'subscribed', 'unsubscribed', 'pending'
    subscribed_at TIMESTAMPTZ DEFAULT now(),
    unsubscribed_at TIMESTAMPTZ,
    source TEXT, -- 'Website Footer', 'Popup Form'
    tags TEXT[],
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, email)
);

-- Bildirim Şablonları (CMS ile ilgili, örn: yeni yorum bildirimi)
CREATE TABLE public.content_notification_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    template_name TEXT NOT NULL,
    event_trigger TEXT NOT NULL, -- 'new_comment', 'new_subscriber', 'post_published'
    channel TEXT DEFAULT 'email', -- 'email', 'sms', 'in_app'
    recipient_type TEXT, -- 'admin', 'author', 'subscriber'
    subject TEXT, -- E-posta konusu
    body TEXT NOT NULL, -- Şablon içeriği
    variables TEXT[],
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, event_trigger, channel)
);

-- ======================================
-- TETİKLEYİCİLER
-- ======================================

CREATE TRIGGER trg_localization_languages_updated_at
BEFORE UPDATE ON public.localization_languages
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_localization_translations_updated_at
BEFORE UPDATE ON public.localization_translations
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_content_types_updated_at
BEFORE UPDATE ON public.content_types
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_content_posts_updated_at
BEFORE UPDATE ON public.content_posts
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_content_categories_updated_at
BEFORE UPDATE ON public.content_categories
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_content_tags_updated_at
BEFORE UPDATE ON public.content_tags
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- content_post_categories için updated_at genellikle gereksizdir.

-- content_post_tags için updated_at genellikle gereksizdir.

CREATE TRIGGER trg_content_sections_updated_at
BEFORE UPDATE ON public.content_sections
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- content_post_sections için updated_at gerekli olabilir.
CREATE TRIGGER trg_content_post_sections_updated_at
BEFORE UPDATE ON public.content_post_sections
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_content_media_updated_at
BEFORE UPDATE ON public.content_media
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_content_comments_updated_at
BEFORE UPDATE ON public.content_comments
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_content_menus_updated_at
BEFORE UPDATE ON public.content_menus
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_content_menu_items_updated_at
BEFORE UPDATE ON public.content_menu_items
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_content_subscribers_updated_at
BEFORE UPDATE ON public.content_subscribers
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_content_notification_templates_updated_at
BEFORE UPDATE ON public.content_notification_templates
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
