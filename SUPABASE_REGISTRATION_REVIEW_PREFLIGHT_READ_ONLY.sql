-- READ-ONLY PREFLIGHT. This file only inspects catalog metadata.
-- It does not read registration rows or modify schema/data.
-- Run only if authorized for the intended Development Supabase project.

-- Check whether registration status values are constrained by a CHECK constraint.
SELECT
  c.conname AS constraint_name,
  pg_get_constraintdef(c.oid) AS definition
FROM pg_constraint AS c
WHERE c.conrelid = 'public.family_registration_requests'::regclass
  AND c.contype = 'c'
ORDER BY c.conname;

-- Check whether RLS is enabled/forced on both workflow tables.
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  c.relrowsecurity AS row_level_security_enabled,
  c.relforcerowsecurity AS row_level_security_forced
FROM pg_class AS c
JOIN pg_namespace AS n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('family_registration_requests', 'family_user_permissions')
ORDER BY c.relname;

-- Inspect policies without exposing table rows.
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('family_registration_requests', 'family_user_permissions')
ORDER BY tablename, policyname;
