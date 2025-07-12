-- ##########################################################
-- RLS Policies for 002_hotels_and_rooms.sql
-- ##########################################################

-- Enable RLS
ALTER TABLE public.hotels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_room_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_room_category_amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_room_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_sustainability_features ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (if any)
DO $$
DECLARE
  tbl_name TEXT;
  policy_name TEXT;
BEGIN
  FOR tbl_name IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename IN 
    ('hotels', 'hotels_room_categories', 'hotels_rooms', 'hotels_amenities', 'hotels_room_category_amenities', 'hotels_media', 'hotels_room_media', 'hotels_sustainability_features')
  LOOP
    FOR policy_name IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = tbl_name
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS "%s" ON public.%I;', policy_name, tbl_name);
    END LOOP;
  END LOOP;
END;
$$;

-- ======================================
-- public.hotels Politikaları
-- ======================================
-- Superadmins can manage all hotels
CREATE POLICY "Superadmins can manage all hotels" ON public.hotels
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Users can view hotels they have access to via tenant membership
CREATE POLICY "Users can view hotels they have access to" ON public.hotels
    FOR SELECT
    -- Check tenant membership first, then use has_hotel_access which includes admin/specific list check
    USING ( tenant_id = public.get_tenant_id() AND public.has_hotel_access(id) );

-- Tenant Admins can manage hotels in their tenant (is_admin includes super_admin)
CREATE POLICY "Admins can manage hotels in their tenant" ON public.hotels
    FOR ALL
    USING ( tenant_id = public.get_tenant_id() AND public.is_admin() )
    WITH CHECK ( tenant_id = public.get_tenant_id() );

-- ======================================
-- public.hotels_rooms Politikaları
-- ======================================
-- Superadmins can manage all rooms
CREATE POLICY "Superadmins can manage all rooms" ON public.hotels_rooms
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Users can view room data for accessible hotels
CREATE POLICY "Users can view room data for accessible hotels" ON public.hotels_rooms
    FOR SELECT
    USING ( tenant_id = public.get_tenant_id() AND public.has_hotel_access(hotel_id) );

-- Admins/Managers can manage room data for accessible hotels
CREATE POLICY "Admins/Managers can manage room data for accessible hotels" ON public.hotels_rooms
    FOR ALL
    USING ( tenant_id = public.get_tenant_id() AND public.has_hotel_access(hotel_id) AND (public.get_user_role() IN ('admin', 'manager')) )
    WITH CHECK ( tenant_id = public.get_tenant_id() AND public.has_hotel_access(hotel_id) );

-- ======================================
-- public.hotels_room_categories Politikaları
-- ======================================
-- Superadmins can manage all room categories
CREATE POLICY "Superadmins can manage all room categories" ON public.hotels_room_categories
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Users can view room category data for accessible hotels
CREATE POLICY "Users can view room category data for accessible hotels" ON public.hotels_room_categories
    FOR SELECT
    USING ( tenant_id = public.get_tenant_id() AND public.has_hotel_access(hotel_id) );

-- Admins/Managers can manage room category data for accessible hotels
CREATE POLICY "Admins/Managers can manage room category data for accessible hotels" ON public.hotels_room_categories
    FOR ALL
    USING ( tenant_id = public.get_tenant_id() AND public.has_hotel_access(hotel_id) AND (public.get_user_role() IN ('admin', 'manager')) )
    WITH CHECK ( tenant_id = public.get_tenant_id() AND public.has_hotel_access(hotel_id) );

-- ======================================
-- public.hotels_amenities Politikaları
-- ======================================
-- Superadmins can manage all amenities
CREATE POLICY "Superadmins can manage all amenities" ON public.hotels_amenities
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Users can view amenities in their tenant
CREATE POLICY "Users can view amenities in their tenant" ON public.hotels_amenities
    FOR SELECT
    USING ( tenant_id = public.get_tenant_id() );

-- Tenant Admins can manage amenities in their tenant
CREATE POLICY "Admins can manage amenities in their tenant" ON public.hotels_amenities
    FOR ALL
    USING ( tenant_id = public.get_tenant_id() AND public.is_admin() )
    WITH CHECK ( tenant_id = public.get_tenant_id() );

-- ======================================
-- public.hotels_room_category_amenities Politikaları
-- ======================================
-- Superadmins can manage all room category amenities
CREATE POLICY "Superadmins can manage all room category amenities" ON public.hotels_room_category_amenities
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Users can view room category amenities for accessible hotels
CREATE POLICY "Users can view room category amenities for accessible hotels" ON public.hotels_room_category_amenities
    FOR SELECT
    USING (
        tenant_id = public.get_tenant_id() AND
        EXISTS (
            SELECT 1 FROM public.hotels_room_categories cat
            WHERE cat.id = room_category_id AND public.has_hotel_access(cat.hotel_id)
        )
    );

-- Admins/Managers can manage room category amenities for accessible hotels
CREATE POLICY "Admins/Managers can manage room category amenities for accessible hotels" ON public.hotels_room_category_amenities
    FOR ALL
    USING (
        tenant_id = public.get_tenant_id() AND
        EXISTS (
            SELECT 1 FROM public.hotels_room_categories cat
            WHERE cat.id = room_category_id AND public.has_hotel_access(cat.hotel_id) AND (public.get_user_role() IN ('admin', 'manager'))
        )
    )
    WITH CHECK (
        tenant_id = public.get_tenant_id() AND
        EXISTS (
            SELECT 1 FROM public.hotels_room_categories cat
            WHERE cat.id = room_category_id AND public.has_hotel_access(cat.hotel_id)
        )
        AND EXISTS (SELECT 1 FROM public.hotels_amenities a WHERE a.id = amenity_id AND a.tenant_id = public.get_tenant_id())
    );

-- ======================================
-- public.hotels_media Politikaları
-- ======================================
-- Superadmins can manage all hotel media
CREATE POLICY "Superadmins can manage all hotel media" ON public.hotels_media
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Users can view media for accessible hotels
CREATE POLICY "Users can view media for accessible hotels" ON public.hotels_media
    FOR SELECT
    USING ( tenant_id = public.get_tenant_id() AND public.has_hotel_access(hotel_id) );

-- Admins/Managers can manage media for accessible hotels
CREATE POLICY "Admins/Managers can manage media for accessible hotels" ON public.hotels_media
    FOR ALL
    USING ( tenant_id = public.get_tenant_id() AND public.has_hotel_access(hotel_id) AND (public.get_user_role() IN ('admin', 'manager')) )
    WITH CHECK ( tenant_id = public.get_tenant_id() AND public.has_hotel_access(hotel_id) );

-- ======================================
-- public.hotels_room_media Politikaları
-- ======================================
-- Superadmins can manage all room media
CREATE POLICY "Superadmins can manage all room media" ON public.hotels_room_media
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Users can view room media for accessible hotels
CREATE POLICY "Users can view room media for accessible hotels" ON public.hotels_room_media
    FOR SELECT
    USING (
        tenant_id = public.get_tenant_id() AND
        EXISTS ( -- Check access via room_category_id -> hotel_id
            SELECT 1 FROM public.hotels_room_categories cat
            WHERE cat.id = hotels_room_media.room_category_id AND public.has_hotel_access(cat.hotel_id)
        )
    );

-- Admins/Managers can manage room media for accessible hotels
CREATE POLICY "Admins/Managers can manage room media for accessible hotels" ON public.hotels_room_media
    FOR ALL
    USING (
        tenant_id = public.get_tenant_id() AND
        EXISTS ( -- Check access via room_category_id -> hotel_id
            SELECT 1 FROM public.hotels_room_categories cat
            WHERE cat.id = hotels_room_media.room_category_id AND public.has_hotel_access(cat.hotel_id) AND (public.get_user_role() IN ('admin', 'manager'))
        )
    )
    WITH CHECK (
        tenant_id = public.get_tenant_id() AND
        EXISTS ( -- Check access via room_category_id -> hotel_id
            SELECT 1 FROM public.hotels_room_categories cat
            WHERE cat.id = hotels_room_media.room_category_id AND public.has_hotel_access(cat.hotel_id)
        )
    );

-- ======================================
-- public.hotels_sustainability_features Politikaları
-- ======================================
-- Superadmins can manage all sustainability features
CREATE POLICY "Superadmins can manage all sustainability features" ON public.hotels_sustainability_features
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Users can view sustainability features for accessible hotels
CREATE POLICY "Users can view sustainability features for accessible hotels" ON public.hotels_sustainability_features
    FOR SELECT
    USING (
        tenant_id = public.get_tenant_id() AND
        EXISTS (SELECT 1 FROM public.hotels h WHERE h.id = hotel_id AND public.has_hotel_access(h.id))
    );

-- Admins/Managers can manage sustainability features for accessible hotels
CREATE POLICY "Admins/Managers can manage sustainability features" ON public.hotels_sustainability_features
    FOR ALL
    USING (
        tenant_id = public.get_tenant_id() AND
        EXISTS (SELECT 1 FROM public.hotels h WHERE h.id = hotel_id AND public.has_hotel_access(h.id) AND public.get_user_role() IN ('admin', 'manager'))
    )
    WITH CHECK (
        tenant_id = public.get_tenant_id() AND
        EXISTS (SELECT 1 FROM public.hotels h WHERE h.id = hotel_id AND public.has_hotel_access(h.id))
    );
