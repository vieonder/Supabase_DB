-- ##########################################################
-- 022_indexes.sql
-- Performans için Veritabanı İndeksleri
-- ##########################################################

-- Not: Foreign key'ler genellikle otomatik olarak indekslenir.
-- Burada sorgularda sık kullanılan veya performansı kritik olan sütunlar için ek indeksler tanımlanmıştır.

-- ======================================
-- Tenant ve Auth İndeksleri
-- ======================================
CREATE INDEX idx_tenant_members_user_id ON public.tenant_members(user_id);
CREATE INDEX idx_tenant_settings_key ON public.tenant_settings(tenant_id, setting_key);
CREATE INDEX idx_user_profiles_names ON public.user_profiles(first_name, last_name); -- İsimle arama için
CREATE INDEX idx_auth_roles_tenant_name ON public.auth_roles(tenant_id, role_name);
CREATE INDEX idx_auth_permissions_tenant_name ON public.auth_permissions(tenant_id, permission_name);
CREATE INDEX idx_auth_role_permissions_role_perm ON public.auth_role_permissions(role_id, permission_id);
CREATE INDEX idx_auth_api_keys_prefix ON public.auth_api_keys(key_prefix);
CREATE INDEX idx_auth_invitations_token ON public.auth_invitations(invitation_token);
CREATE INDEX idx_auth_invitations_email ON public.auth_invitations(tenant_id, email);

-- ======================================
-- Otel ve Oda İndeksleri
-- ======================================
CREATE INDEX idx_hotels_tenant_name ON public.hotels(tenant_id, name);
CREATE INDEX idx_hotels_room_categories_hotel ON public.hotels_room_categories(hotel_id);
CREATE INDEX idx_hotels_rooms_hotel_category ON public.hotels_rooms(hotel_id, category_id);
CREATE INDEX idx_hotels_rooms_number ON public.hotels_rooms(hotel_id, room_number);
CREATE INDEX idx_hotels_amenities_tenant_name ON public.hotels_amenities(tenant_id, name);
CREATE INDEX idx_hotels_room_category_amenities_cat_amen ON public.hotels_room_category_amenities(room_category_id, amenity_id);
CREATE INDEX idx_hotels_media_hotel ON public.hotels_media(hotel_id);
CREATE INDEX idx_hotels_room_media_category ON public.hotels_room_media(room_category_id);

-- ======================================
-- Rezervasyon ve Fiyatlandırma İndeksleri
-- ======================================
CREATE INDEX idx_res_rate_plans_hotel_code ON public.res_rate_plans(hotel_id, code);
CREATE INDEX idx_res_seasons_hotel_dates ON public.res_seasons(hotel_id, start_date, end_date);
CREATE INDEX idx_res_cancellation_policies_hotel ON public.res_cancellation_policies(hotel_id);
CREATE INDEX idx_price_daily_rates_cat_plan_date ON public.price_daily_rates(room_category_id, rate_plan_id, date);
CREATE INDEX idx_price_daily_rates_date ON public.price_daily_rates(date); -- Tarih bazlı sorgular için
CREATE INDEX idx_price_availability_rules_cat_dates ON public.price_availability_rules(room_category_id, start_date, end_date);
CREATE INDEX idx_res_reservations_hotel_dates ON public.res_reservations(hotel_id, check_in_date, check_out_date);
CREATE INDEX idx_res_reservations_status ON public.res_reservations(hotel_id, status);
CREATE INDEX idx_res_reservations_guest ON public.res_reservations(guest_id);
CREATE INDEX idx_res_reservations_ref ON public.res_reservations(booking_reference);
CREATE INDEX idx_res_reservation_rooms_res ON public.res_reservation_rooms(reservation_id);
CREATE INDEX idx_res_reservation_rooms_room ON public.res_reservation_rooms(room_id);
CREATE INDEX idx_res_reservation_rooms_dates ON public.res_reservation_rooms(room_category_id, check_in_date, check_out_date); -- Müsaitlik kontrolü için
CREATE INDEX idx_res_reservation_daily_rates_res_room ON public.res_reservation_daily_rates(reservation_room_id);
CREATE INDEX idx_res_reservation_guests_res_room ON public.res_reservation_guests(reservation_room_id);
CREATE INDEX idx_res_reservation_guests_guest ON public.res_reservation_guests(guest_id);
CREATE INDEX idx_res_cancellations_res ON public.res_cancellations(reservation_id);
CREATE INDEX idx_res_modifications_res ON public.res_modifications(reservation_id);

-- ======================================
-- Split Stay İndeksleri
-- ======================================
CREATE INDEX idx_split_stay_links_res ON public.split_stay_links(original_reservation_id);
CREATE INDEX idx_split_stay_segments_link ON public.split_stay_segments(split_stay_link_id);
CREATE INDEX idx_split_stay_segments_res_room ON public.split_stay_segments(reservation_room_id);
CREATE INDEX idx_split_stay_transitions_link ON public.split_stay_transitions(split_stay_link_id);
CREATE INDEX idx_split_stay_history_link ON public.split_stay_history(split_stay_link_id);

-- ======================================
-- Dinamik Fiyatlandırma İndeksleri
-- ======================================
CREATE INDEX idx_dynamic_pricing_strategies_hotel ON public.dynamic_pricing_strategies(hotel_id);
CREATE INDEX idx_dynamic_pricing_rules_strategy ON public.dynamic_pricing_rules(strategy_id);
CREATE INDEX idx_dynamic_pricing_factors_hotel_name ON public.dynamic_pricing_factors(hotel_id, factor_name);
CREATE INDEX idx_dynamic_pricing_events_hotel_dates ON public.dynamic_pricing_events(hotel_id, start_date, end_date);
CREATE INDEX idx_dynamic_pricing_competitor_rates_hotel_comp_date ON public.dynamic_pricing_competitor_rates(hotel_id, competitor_name, date);
CREATE INDEX idx_dynamic_pricing_rate_recommendations_cat_plan_date ON public.dynamic_pricing_rate_recommendations(room_category_id, rate_plan_id, date);

-- ======================================
-- Misafir ve CRM İndeksleri
-- ======================================
CREATE INDEX idx_guests_tenant_user_profile ON public.guests(tenant_id, user_profile_id);
CREATE INDEX idx_guests_tenant_email ON public.guests(tenant_id, email) WHERE email IS NOT NULL;
CREATE INDEX idx_guests_tenant_phone ON public.guests(tenant_id, phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_guests_tenant_fullname ON public.guests(tenant_id, full_name); -- İsimle arama için (trigram indeksi daha iyi olabilir)
CREATE EXTENSION IF NOT EXISTS pg_trgm; -- Enable trigram extension for fuzzy string matching
CREATE INDEX idx_guests_tenant_fullname_trgm ON public.guests USING gin (full_name gin_trgm_ops); -- Index for faster full_name search
-- Removed index on non-existent table: guest_profiles
CREATE INDEX idx_guest_addresses_guest ON public.guest_addresses(guest_id);
-- Removed index on non-existent column: guest_addresses.guest_profile_id
CREATE INDEX idx_guest_preferences_guest ON public.guest_preferences(guest_id);
CREATE INDEX idx_guest_documents_guest ON public.guest_documents(guest_id);
CREATE INDEX idx_guest_notes_guest ON public.guest_notes(guest_id);
CREATE INDEX idx_guest_communications_guest ON public.guest_communications(guest_id);
CREATE INDEX idx_guest_relationships_guest ON public.guest_relationships(guest_id);
CREATE INDEX idx_guest_relationships_related ON public.guest_relationships(related_guest_id);
CREATE INDEX idx_user_anonymous_map_user ON public.user_anonymous_map(user_id);

-- ======================================
-- Housekeeping ve Bakım İndeksleri
-- ======================================
CREATE INDEX idx_hk_staff_hotel_user ON public.hk_staff(hotel_id, user_profile_id);
CREATE INDEX idx_hk_tasks_hotel_room ON public.hk_tasks(hotel_id, room_id);
CREATE INDEX idx_hk_tasks_status_date ON public.hk_tasks(hotel_id, status, scheduled_date);
CREATE INDEX idx_hk_tasks_assigned_staff ON public.hk_tasks(assigned_staff_id);
-- Removed indexes on non-existent table: hk_task_assignments
CREATE INDEX idx_hk_room_status_log_room_time ON public.hk_room_status_log(room_id, changed_at DESC);
CREATE INDEX idx_hk_inventory_items_hotel ON public.hk_inventory_items(hotel_id);
CREATE INDEX idx_hk_inventory_transactions_item ON public.hk_inventory_transactions(item_id);
CREATE INDEX idx_hk_inspection_checklists_hotel ON public.hk_inspection_checklists(hotel_id);
CREATE INDEX idx_hk_inspections_room ON public.hk_inspections(room_id);
CREATE INDEX idx_hk_inspections_inspector ON public.hk_inspections(inspector_staff_id);
CREATE INDEX idx_hk_shifts_hotel ON public.hk_shifts(hotel_id);
CREATE INDEX idx_hk_staff_schedules_staff_date ON public.hk_staff_schedules(staff_id, work_date);
CREATE INDEX idx_hk_guest_requests_room ON public.hk_guest_requests(reservation_room_id);
CREATE INDEX idx_hk_guest_requests_tenant_status ON public.hk_guest_requests(tenant_id, status); -- Fixed: Removed hotel_id, added tenant_id

CREATE INDEX idx_maintenance_assets_hotel ON public.maintenance_assets(hotel_id);
CREATE INDEX idx_maintenance_assets_room ON public.maintenance_assets(room_id);
CREATE INDEX idx_maintenance_work_orders_hotel_asset ON public.maintenance_work_orders(hotel_id, asset_id);
CREATE INDEX idx_maintenance_work_orders_status ON public.maintenance_work_orders(hotel_id, status);
CREATE INDEX idx_maintenance_work_orders_status_priority_date ON public.maintenance_work_orders(tenant_id, status, priority, scheduled_date); -- Fixed: Renamed scheduled_start_date to scheduled_date
CREATE INDEX idx_maintenance_work_orders_assigned ON public.maintenance_work_orders(assigned_technician_id);
CREATE INDEX idx_maintenance_preventive_schedule_asset ON public.maintenance_preventive_schedule(asset_id);
CREATE INDEX idx_maintenance_parts_inventory_hotel ON public.maintenance_parts_inventory(hotel_id);
CREATE INDEX idx_maintenance_parts_transactions_part ON public.maintenance_parts_transactions(part_id);
CREATE INDEX idx_maintenance_parts_transactions_wo ON public.maintenance_parts_transactions(work_order_id);
CREATE INDEX idx_maintenance_service_providers_tenant ON public.maintenance_service_providers(tenant_id);

-- ======================================
-- Envanter, Hizmetler ve Menü İndeksleri
-- ======================================
CREATE INDEX idx_inventory_items_hotel_category ON public.inventory_items(hotel_id, category);
CREATE INDEX idx_inventory_movements_item ON public.inventory_movements(item_id);
CREATE INDEX idx_inventory_movements_related_doc ON public.inventory_movements(related_document_type, related_document_id);
CREATE INDEX idx_inventory_alerts_item ON public.inventory_alerts(item_id);
CREATE INDEX idx_inventory_order_requests_hotel_supplier ON public.inventory_order_requests(hotel_id, supplier_id);
CREATE INDEX idx_inventory_order_request_items_order ON public.inventory_order_request_items(order_request_id);
CREATE INDEX idx_inventory_suppliers_tenant_name ON public.inventory_suppliers(tenant_id, supplier_name);
CREATE INDEX idx_menu_categories_hotel ON public.menu_categories(hotel_id);
CREATE INDEX idx_menu_items_category ON public.menu_items(category_id);
CREATE INDEX idx_menu_item_inventory_menu_item ON public.menu_item_inventory(menu_item_id);
CREATE INDEX idx_menu_item_inventory_inv_item ON public.menu_item_inventory(inventory_item_id);
CREATE INDEX idx_menu_sales_hotel_item ON public.menu_sales(hotel_id, menu_item_id);
CREATE INDEX idx_menu_sales_res ON public.menu_sales(reservation_id);
CREATE INDEX idx_menu_modifiers_hotel ON public.menu_modifiers(hotel_id);
CREATE INDEX idx_menu_item_modifiers_group ON public.menu_item_modifiers(modifier_group_id);
CREATE INDEX idx_menu_item_modifier_groups_item ON public.menu_item_modifier_groups(menu_item_id);
CREATE INDEX idx_menu_item_modifier_groups_group ON public.menu_item_modifier_groups(modifier_group_id);
CREATE INDEX idx_services_catalog_hotel ON public.services_catalog(hotel_id);
CREATE INDEX idx_services_providers_hotel ON public.services_providers(hotel_id);
CREATE INDEX idx_services_catalog_providers_service ON public.services_catalog_providers(service_id);
CREATE INDEX idx_services_catalog_providers_provider ON public.services_catalog_providers(provider_id);
CREATE INDEX idx_services_bookings_service ON public.services_bookings(service_id);
CREATE INDEX idx_services_bookings_guest ON public.services_bookings(guest_id);
CREATE INDEX idx_services_bookings_res ON public.services_bookings(reservation_id);
CREATE INDEX idx_services_availability_provider_date ON public.services_availability(provider_id, date);

-- ======================================
-- Ödemeler ve Faturalandırma İndeksleri
-- ======================================
CREATE INDEX idx_payment_methods_tenant ON public.payment_methods(tenant_id);
CREATE INDEX idx_payments_res ON public.payments(reservation_id); -- Fixed: Renamed table payment_transactions to payments
CREATE INDEX idx_payments_invoice ON public.payments(invoice_id); -- Fixed: Renamed table payment_transactions to payments
CREATE INDEX idx_payments_ref ON public.payments(transaction_reference); -- Fixed: Renamed table payment_transactions to payments
CREATE INDEX idx_invoices_res ON public.invoices(reservation_id);
CREATE INDEX idx_invoices_guest ON public.invoices(guest_id);
-- Removed index on non-existent column: invoices.guest_profile_id
CREATE INDEX idx_invoices_number ON public.invoices(invoice_number);
CREATE INDEX idx_invoice_items_invoice ON public.invoice_items(invoice_id);
CREATE INDEX idx_tax_rates_tenant ON public.tax_rates(tenant_id);
CREATE INDEX idx_extra_charges_hotel ON public.extra_charges(hotel_id);
CREATE INDEX idx_extra_charge_items_res ON public.extra_charge_items(reservation_id);
CREATE INDEX idx_extra_charge_items_guest ON public.extra_charge_items(guest_id);
CREATE INDEX idx_payment_gateways_tenant ON public.payment_gateways(tenant_id);
CREATE INDEX idx_customer_accounts_guest ON public.customer_accounts(guest_id);
-- Removed index on non-existent column: customer_accounts.guest_profile_id
CREATE INDEX idx_customer_account_entries_account ON public.customer_account_entries(account_id);
CREATE INDEX idx_payment_promotions_tenant_code ON public.payment_promotions(tenant_id, promotion_code);
CREATE INDEX idx_payment_promotion_usages_promo ON public.payment_promotion_usages(promotion_id);
CREATE INDEX idx_revenue_sources_tenant ON public.revenue_sources(tenant_id);
CREATE INDEX idx_revenue_entries_source_date ON public.revenue_entries(revenue_source_id, entry_date);
CREATE INDEX idx_cash_register_entries_user_time ON public.cash_register_entries(user_id, entry_time DESC);

-- ======================================
-- Pazarlama ve Sadakat İndeksleri
-- ======================================
CREATE INDEX idx_marketing_coupons_code ON public.marketing_coupons(coupon_code);
CREATE INDEX idx_marketing_coupon_usages_coupon ON public.marketing_coupon_usages(coupon_id);
CREATE INDEX idx_marketing_coupon_usages_res ON public.marketing_coupon_usages(reservation_id);
CREATE INDEX idx_loyalty_program_config_tenant ON public.loyalty_program_config(tenant_id);
CREATE INDEX idx_loyalty_program_tiers_config ON public.loyalty_program_tiers(config_id);
CREATE INDEX idx_loyalty_member_profiles_guest ON public.loyalty_member_profiles(guest_id);
CREATE INDEX idx_loyalty_member_profiles_number ON public.loyalty_member_profiles(member_number);
CREATE INDEX idx_loyalty_transactions_member ON public.loyalty_transactions(member_id);
CREATE INDEX idx_loyalty_transactions_type ON public.loyalty_transactions(transaction_type);
CREATE INDEX idx_loyalty_benefits_config ON public.loyalty_benefits(config_id);
CREATE INDEX idx_loyalty_redemptions_member ON public.loyalty_redemptions(member_id);
CREATE INDEX idx_loyalty_point_expiry_member_date ON public.loyalty_point_expiry(member_id, expiry_date);
CREATE INDEX idx_loyalty_tier_history_member ON public.loyalty_tier_history(member_id);
CREATE INDEX idx_marketing_special_offers_hotel ON public.marketing_special_offers(hotel_id);
CREATE INDEX idx_marketing_campaigns_tenant ON public.marketing_campaigns(tenant_id);
CREATE INDEX idx_marketing_email_templates_tenant ON public.marketing_email_templates(tenant_id);
CREATE INDEX idx_marketing_conversions_campaign ON public.marketing_conversions(campaign_id);
CREATE INDEX idx_marketing_conversions_res ON public.marketing_conversions(reservation_id);

-- ======================================
-- Kişiselleştirme İndeksleri
-- ======================================
CREATE INDEX idx_pers_user_interactions_user ON public.personalization_user_interactions(user_id, created_at DESC);
CREATE INDEX idx_pers_user_interactions_anon ON public.personalization_user_interactions(anonymous_user_id, created_at DESC);
CREATE INDEX idx_pers_user_interactions_session ON public.personalization_user_interactions(session_id);
CREATE INDEX idx_pers_segments_tenant ON public.personalization_segments(tenant_id);
CREATE INDEX idx_pers_user_segments_user ON public.personalization_user_segments(user_id);
CREATE INDEX idx_pers_user_segments_guest ON public.personalization_user_segments(guest_id);
CREATE INDEX idx_pers_recommendations_user ON public.personalization_recommendations(user_id);
CREATE INDEX idx_pers_recommendations_anon ON public.personalization_recommendations(anonymous_user_id);
CREATE INDEX idx_pers_rec_feedback_rec ON public.personalization_recommendation_feedback(recommendation_id);
CREATE INDEX idx_pers_content_variants_exp ON public.personalization_content_variants(tenant_id, experiment_name);

-- ======================================
-- İçerik ve Lokalizasyon İndeksleri
-- ======================================
CREATE INDEX idx_loc_languages_tenant_code ON public.localization_languages(tenant_id, language_code);
CREATE INDEX idx_loc_translations_tenant_lang_key ON public.localization_translations(tenant_id, language_code, translation_key);
CREATE INDEX idx_content_types_tenant ON public.content_types(tenant_id);
CREATE INDEX idx_content_posts_tenant_type_slug ON public.content_posts(tenant_id, content_type_id, slug);
CREATE INDEX idx_content_posts_status_published ON public.content_posts(status, published_at DESC);
CREATE INDEX idx_content_categories_tenant_slug ON public.content_categories(tenant_id, slug);
CREATE INDEX idx_content_tags_tenant_slug ON public.content_tags(tenant_id, slug);
CREATE INDEX idx_content_post_categories_post ON public.content_post_categories(post_id);
CREATE INDEX idx_content_post_categories_cat ON public.content_post_categories(category_id);
CREATE INDEX idx_content_post_tags_post ON public.content_post_tags(post_id);
CREATE INDEX idx_content_post_tags_tag ON public.content_post_tags(tag_id);
CREATE INDEX idx_content_sections_tenant_key ON public.content_sections(tenant_id, section_key);
CREATE INDEX idx_content_post_sections_post ON public.content_post_sections(post_id);
CREATE INDEX idx_content_media_tenant ON public.content_media(tenant_id);
CREATE INDEX idx_content_comments_post_status ON public.content_comments(post_id, status);
CREATE INDEX idx_content_menus_tenant_location ON public.content_menus(tenant_id, menu_location);
CREATE INDEX idx_content_menu_items_menu ON public.content_menu_items(menu_id);
CREATE INDEX idx_content_subscribers_tenant_email ON public.content_subscribers(tenant_id, email);
CREATE INDEX idx_content_notification_templates_tenant ON public.content_notification_templates(tenant_id);

-- ======================================
-- İzin Yönetimi İndeksleri
-- ======================================
CREATE INDEX idx_consent_types_tenant_key_version ON public.consent_types(tenant_id, consent_key, version);
CREATE INDEX idx_consent_user_consents_user ON public.consent_user_consents(user_id, consent_type_id);
CREATE INDEX idx_consent_user_consents_guest ON public.consent_user_consents(guest_id, consent_type_id);
CREATE INDEX idx_consent_user_consents_anon ON public.consent_user_consents(anonymous_user_id, consent_type_id);
CREATE INDEX idx_consent_dsr_requests_tenant_status ON public.consent_dsr_requests(tenant_id, status);
CREATE INDEX idx_consent_dsr_requests_requester ON public.consent_dsr_requests(requester_email);
CREATE INDEX idx_consent_dsr_request_logs_req ON public.consent_dsr_request_logs(request_id);

-- ======================================
-- Analiz ve Log İndeksleri
-- ======================================
CREATE INDEX idx_analytics_daily_hotel_summary_hotel_date ON public.analytics_daily_hotel_summary(hotel_id, summary_date DESC);
CREATE INDEX idx_analytics_daily_room_category_summary_cat_date ON public.analytics_daily_room_category_summary(room_category_id, summary_date DESC);
CREATE INDEX idx_analytics_daily_channel_summary_hotel_date_chan ON public.analytics_daily_channel_summary(hotel_id, summary_date DESC, booking_channel);
CREATE INDEX idx_analytics_guest_segment_summary_segment ON public.analytics_guest_segment_summary(segment_id);
CREATE INDEX idx_analytics_guest_ltv_guest ON public.analytics_guest_ltv(guest_id);
CREATE INDEX idx_analytics_website_traffic_summary_tenant_date ON public.analytics_website_traffic_summary(tenant_id, summary_date DESC);
CREATE INDEX idx_analytics_booking_funnel_summary_tenant_period ON public.analytics_booking_funnel_summary(tenant_id, period_start_date DESC, summary_period);

CREATE INDEX idx_logs_audit_tenant_time ON public.logs_audit(tenant_id, created_at DESC);
CREATE INDEX idx_logs_audit_user_time ON public.logs_audit(user_id, created_at DESC);
CREATE INDEX idx_logs_audit_entity ON public.logs_audit(entity_type, entity_id);
CREATE INDEX idx_logs_error_tenant_time ON public.logs_error(tenant_id, created_at DESC);
CREATE INDEX idx_logs_error_source ON public.logs_error(source);
CREATE INDEX idx_logs_error_resolved ON public.logs_error(is_resolved);
CREATE INDEX idx_logs_api_requests_tenant_time ON public.logs_api_requests(tenant_id, created_at DESC);
CREATE INDEX idx_logs_api_requests_user ON public.logs_api_requests(user_id);
CREATE INDEX idx_logs_api_requests_endpoint ON public.logs_api_requests(endpoint);
CREATE INDEX idx_logs_communication_tenant_time ON public.logs_communication(tenant_id, created_at DESC);
CREATE INDEX idx_logs_communication_channel_status ON public.logs_communication(channel, status);
CREATE INDEX idx_logs_reservation_changes_res ON public.logs_reservation_changes(reservation_id, changed_at DESC);

-- ======================================
-- Bildirim İndeksleri (RFC_029)
-- ======================================
--CREATE INDEX idx_notifications_user_status_created ON public.notifications(user_id, status, created_at DESC); -- Added for fetching user notifications
