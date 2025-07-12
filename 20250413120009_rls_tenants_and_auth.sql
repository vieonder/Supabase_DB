-- ##########################################################
-- RLS Policies for 001_tenants_and_auth.sql
-- ##########################################################

-- Enable RLS
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_invitations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies (if any)
DO $$
DECLARE
  tbl_name TEXT;
  policy_name TEXT;
BEGIN
  FOR tbl_name IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename IN 
    ('tenants', 'tenant_members', 'tenant_settings', 'user_profiles', 'auth_roles', 'auth_permissions', 'auth_role_permissions', 'auth_api_keys', 'auth_invitations')
  LOOP
    FOR policy_name IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = tbl_name
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS "%s" ON public.%I;', policy_name, tbl_name);
    END LOOP;
  END LOOP;
END;
$$;

-- ======================================
-- public.user_profiles Politikaları
-- ======================================
-- Superadmins can manage all profiles
CREATE POLICY "Superadmins can manage all profiles" ON public.user_profiles
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Allow users to view/update their own profile
CREATE POLICY "Allow users to view/update their own profile" ON public.user_profiles
    FOR ALL
    USING ( user_id = public.get_user_id() )
    WITH CHECK ( user_id = public.get_user_id() );

-- Tenant Admins can view profiles linked to their tenant members (Consider if needed)
-- CREATE POLICY "Tenant Admins can view profiles in their tenant" ON public.user_profiles
--     FOR SELECT
--     USING (
--         public.is_admin() AND
--         EXISTS (
--             SELECT 1 FROM public.tenant_members tm
--             WHERE tm.tenant_id = public.get_tenant_id() AND tm.user_id = public.user_profiles.user_id
--         )
--     );

-- ======================================
-- public.tenants Politikaları
-- ======================================
-- Superadmins can manage all tenants
CREATE POLICY "Superadmins can manage all tenants" ON public.tenants
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Tenant members can view tenants they are members of
CREATE POLICY "Tenant members can view their tenants" ON public.tenants
    FOR SELECT
    USING ( id IN (SELECT tenant_id FROM public.tenant_members WHERE user_id = public.get_user_id()) );

-- Tenant admins can update their own tenant (is_admin already includes super_admin)
CREATE POLICY "Tenant admins can update their own tenant" ON public.tenants
    FOR UPDATE
    USING ( id = public.get_tenant_id() AND public.is_admin() )
    WITH CHECK ( id = public.get_tenant_id() );

-- Note: Tenant creation/deletion might be restricted to Superadmin or handled via RPC.

-- ======================================
-- public.tenant_members Politikaları
-- ======================================
-- Superadmins can manage all memberships
CREATE POLICY "Superadmins can manage all memberships" ON public.tenant_members
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Members can view their own membership
CREATE POLICY "Members can view their own membership" ON public.tenant_members
    FOR SELECT
    USING ( tenant_id = public.get_tenant_id() AND user_id = public.get_user_id() );

-- Admins can manage memberships in their tenant (is_admin includes super_admin)
CREATE POLICY "Admins can manage memberships in their tenant" ON public.tenant_members
    FOR ALL
    USING ( tenant_id = public.get_tenant_id() AND public.is_admin() )
    WITH CHECK ( tenant_id = public.get_tenant_id() );

-- ======================================
-- public.tenant_settings Politikaları
-- ======================================
-- Superadmins can manage all settings
CREATE POLICY "Superadmins can manage all tenant settings" ON public.tenant_settings
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Admins/Managers can manage Tenant Settings in their tenant
CREATE POLICY "Admin/Manager can manage Tenant Settings" ON public.tenant_settings
    FOR ALL
    USING ( tenant_id = public.get_tenant_id() AND public.get_user_role() IN ('admin', 'manager') )
    WITH CHECK ( tenant_id = public.get_tenant_id() );

-- Staff can view Tenant Settings in their tenant
CREATE POLICY "Staff can view Tenant Settings" ON public.tenant_settings
    FOR SELECT
    USING ( tenant_id = public.get_tenant_id() AND public.get_user_role() IS NOT NULL );

-- ======================================
-- Supabase Auth Tabloları İçin Temel Politikalar
-- ======================================

-- auth_roles, auth_permissions, auth_role_permissions
-- Superadmins can manage all roles/permissions
CREATE POLICY "Superadmins can manage all Auth Roles" ON public.auth_roles FOR ALL USING (public.is_super_admin()) WITH CHECK (public.is_super_admin());
CREATE POLICY "Superadmins can manage all Auth Permissions" ON public.auth_permissions FOR ALL USING (public.is_super_admin()) WITH CHECK (public.is_super_admin());
CREATE POLICY "Superadmins can manage all Auth Role Permissions" ON public.auth_role_permissions FOR ALL USING (public.is_super_admin()) WITH CHECK (public.is_super_admin());

-- Tenant Admins can view roles/permissions within their tenant (is_admin includes super_admin)
CREATE POLICY "Tenant Admins can view Auth Roles" ON public.auth_roles
    FOR SELECT
    USING ( tenant_id = public.get_tenant_id() AND public.is_admin() );

CREATE POLICY "Tenant Admins can view Auth Permissions" ON public.auth_permissions
    FOR SELECT
    USING ( tenant_id = public.get_tenant_id() AND public.is_admin() );

CREATE POLICY "Tenant Admins can view Auth Role Permissions" ON public.auth_role_permissions
    FOR SELECT
    USING ( tenant_id = public.get_tenant_id() AND public.is_admin() );

-- Management by Tenant Admins (kept commented out for now - granular control needed)
-- CREATE POLICY "Tenant Admins can manage Auth Roles" ON public.auth_roles FOR ALL USING (tenant_id = public.get_tenant_id() AND public.is_admin()) WITH CHECK (tenant_id = public.get_tenant_id());
-- CREATE POLICY "Tenant Admins can manage Auth Permissions" ON public.auth_permissions FOR ALL USING (tenant_id = public.get_tenant_id() AND public.is_admin()) WITH CHECK (tenant_id = public.get_tenant_id());
-- CREATE POLICY "Tenant Admins can manage Auth Role Permissions" ON public.auth_role_permissions FOR ALL USING (tenant_id = public.get_tenant_id() AND public.is_admin()) WITH CHECK (tenant_id = public.get_tenant_id());

-- auth_api_keys
-- Superadmins can manage all API Keys
CREATE POLICY "Superadmins can manage all API Keys" ON public.auth_api_keys
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Tenant Admins can manage API Keys within their tenant (is_admin includes super_admin)
CREATE POLICY "Tenant Admins can manage API Keys" ON public.auth_api_keys
    FOR ALL
    USING ( tenant_id = public.get_tenant_id() AND public.is_admin() )
    WITH CHECK ( tenant_id = public.get_tenant_id() );

-- auth_invitations
-- Superadmins can manage all Invitations
CREATE POLICY "Superadmins can manage all Invitations" ON public.auth_invitations
    FOR ALL
    USING ( public.is_super_admin() )
    WITH CHECK ( public.is_super_admin() );

-- Tenant Admins can manage Invitations within their tenant (is_admin includes super_admin)
CREATE POLICY "Tenant Admins can manage Invitations" ON public.auth_invitations
    FOR ALL
    USING ( tenant_id = public.get_tenant_id() AND public.is_admin() )
    WITH CHECK ( tenant_id = public.get_tenant_id() );
