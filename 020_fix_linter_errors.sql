-- Migration to fix Supabase linter errors reported in supabase/Errors.md

-- Fix: security_definer_view
-- Change views to use SECURITY INVOKER instead of SECURITY DEFINER for better security alignment with RLS.
-- If SECURITY DEFINER is strictly required, ensure the defining role has minimal privileges and RLS policies are robust.

ALTER VIEW public.view_active_reservations SET (security_invoker = true);
ALTER VIEW public.view_expected_arrivals_today SET (security_invoker = true);
ALTER VIEW public.view_expected_departures_today SET (security_invoker = true);
ALTER VIEW public.view_room_status_dashboard SET (security_invoker = true);

-- Next steps will involve enabling RLS for tables listed in the linter report.
-- ALTER TABLE public.table_name ENABLE ROW LEVEL SECURITY;
-- Followed by defining appropriate RLS policies if they don't exist in supabase/rls/.

-- Fix: rls_disabled_in_public
-- Enable Row Level Security for all tables reported by the linter.
-- Corresponding RLS policies should exist in the supabase/rls/ directory or need to be created.

ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.localization_languages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.localization_translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_item_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_modifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_item_modifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_item_modifier_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services_catalog_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_post_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_room_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_room_category_amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_room_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotels_sustainability_features ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_anonymous_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personalization_user_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personalization_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personalization_user_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personalization_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.res_rate_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.res_seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.res_cancellation_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.res_rate_plan_cancellation_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_daily_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tax_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_availability_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.res_reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.res_reservation_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_gateways ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.res_reservation_daily_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.res_reservation_guests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.res_cancellations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.res_modifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.extra_charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.extra_charge_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_stay_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_stay_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_account_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_stay_transitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_stay_guests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_stay_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_promotion_usages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_stay_amenities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revenue_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.revenue_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_register_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commission_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commission_invoice_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dynamic_pricing_strategies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_payment_gateways ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dynamic_pricing_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dynamic_pricing_factors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dynamic_pricing_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dynamic_pricing_competitor_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personalization_recommendation_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dynamic_pricing_rate_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dynamic_pricing_simulation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_coupon_usages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_program_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_program_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.communication_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_communications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_member_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_benefits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_point_expiry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hk_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hk_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hk_room_status_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hk_inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hk_inventory_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_partner_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_tier_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hk_inspection_checklists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hk_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hk_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hk_staff_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hk_staff_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_special_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hk_guest_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hk_report_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_work_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_preventive_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_parts_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_parts_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_service_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_conversions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personalization_content_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_order_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_order_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_post_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_post_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_menus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_subscribers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consent_user_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consent_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consent_dsr_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consent_dsr_request_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_daily_hotel_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_daily_room_category_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_daily_channel_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_guest_segment_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_guest_ltv ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_website_traffic_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logs_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_booking_funnel_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logs_error ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logs_api_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logs_communication ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logs_reservation_changes ENABLE ROW LEVEL SECURITY;

-- Migration to fix Supabase linter warnings reported in supabase/Warning.txt

-- Fix: function_search_path_mutable
-- Set a fixed search_path for functions to prevent potential security issues and ensure predictable behavior.
-- Setting search_path to 'public' as these functions primarily interact with the public schema.
-- Adjust if functions need access to other schemas like 'auth' or 'storage'.

ALTER FUNCTION public.get_tenant_id() SET search_path = public;
ALTER FUNCTION public.merge_guest_records(uuid, uuid) SET search_path = public;
ALTER FUNCTION public.update_guest_preferences(uuid, jsonb) SET search_path = public;
ALTER FUNCTION public.handle_new_user() SET search_path = public;
ALTER FUNCTION public.get_user_id() SET search_path = public;
ALTER FUNCTION public.get_user_role() SET search_path = public;
ALTER FUNCTION public.get_user_hotel_ids() SET search_path = public;
ALTER FUNCTION public.is_admin() SET search_path = public;
ALTER FUNCTION public.has_hotel_access(uuid) SET search_path = public;
ALTER FUNCTION public.get_current_guest_id() SET search_path = public;
ALTER FUNCTION public.handle_reservation_status_change() SET search_path = public;
ALTER FUNCTION public.calculate_room_price(UUID, DATE, DATE, UUID, UUID, INT, INT, DATE) SET search_path = public; -- Corrected signature
ALTER FUNCTION public.validate_split_stay_reservation() SET search_path = public;
ALTER FUNCTION public.update_updated_at_column() SET search_path = public;
-- ALTER FUNCTION public.generate_booking_reference() SET search_path = public; -- This function is commented out in the source
