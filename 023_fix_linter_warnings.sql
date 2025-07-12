-- Migration to fix Supabase linter warnings

-- Fix: extension_in_public (pg_trgm)
-- Move pg_trgm extension to the 'extensions' schema.

-- 1. Create the 'extensions' schema if it doesn't exist.
CREATE SCHEMA IF NOT EXISTS extensions;

-- 2. Move the pg_trgm extension to the 'extensions' schema.
-- Note: This assumes pg_trgm was previously created in the 'public' schema.
ALTER EXTENSION pg_trgm SET SCHEMA extensions;

-- Fix: function_search_path_mutable (generate_booking_reference)
-- Set a specific search_path for the function to avoid potential issues.

-- Note: We are altering the function defined in 000_setup.sql
-- Ensure the function signature matches the one in 000_setup.sql
-- Based on 000_setup.sql content previously read:
ALTER FUNCTION public.generate_booking_reference(prefix TEXT, len INT) SET search_path = public;

-- If the function was the one from db_schema/00_extensions_enums.sql (no arguments):
-- ALTER FUNCTION public.generate_booking_reference() SET search_path = public;
-- Please verify which function definition is currently active in your database and uncomment/adjust accordingly. 