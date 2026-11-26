-- P2.3.4.1: account/role foundation for Coi Nguon.
-- Review and run manually in Supabase SQL Editor; this file does NOT execute itself.
BEGIN;

CREATE TABLE IF NOT EXISTS public.family_user_permissions (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member'
    CHECK (role IN ('member','editor','admin')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','active','suspended','revoked')),
  linked_member_id text NULL,
  granted_by uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.family_user_permissions ENABLE ROW LEVEL SECURITY;

-- Users may see only their own permission record; the root administrator may see all.
CREATE OR REPLACE FUNCTION public.family_is_root_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid;
$$;

CREATE OR REPLACE FUNCTION public.family_user_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT public.family_is_root_admin()
    OR EXISTS (
      SELECT 1
      FROM public.family_user_permissions p
      WHERE p.user_id = auth.uid()
        AND p.role = 'admin'
        AND p.status = 'active'
    );
$$;

CREATE OR REPLACE FUNCTION public.family_current_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT CASE
    WHEN public.family_is_root_admin() THEN 'admin'
    ELSE COALESCE((
      SELECT p.role
      FROM public.family_user_permissions p
      WHERE p.user_id = auth.uid()
        AND p.status = 'active'
    ), 'visitor')
  END;
$$;

CREATE OR REPLACE FUNCTION public.family_current_status()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT CASE
    WHEN public.family_is_root_admin() THEN 'active'
    ELSE COALESCE((
      SELECT p.status
      FROM public.family_user_permissions p
      WHERE p.user_id = auth.uid()
    ), 'pending')
  END;
$$;

DROP POLICY IF EXISTS family_permissions_select_self_or_root
  ON public.family_user_permissions;
CREATE POLICY family_permissions_select_self_or_root
  ON public.family_user_permissions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.family_is_root_admin());

-- Only the root administrator can provision/change roles or statuses.
DROP POLICY IF EXISTS family_permissions_root_manage
  ON public.family_user_permissions;
CREATE POLICY family_permissions_root_manage
  ON public.family_user_permissions
  FOR ALL TO authenticated
  USING (public.family_is_root_admin())
  WITH CHECK (public.family_is_root_admin());

REVOKE ALL ON public.family_user_permissions FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.family_user_permissions TO authenticated;

REVOKE ALL ON FUNCTION public.family_is_root_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.family_user_is_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.family_current_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.family_current_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.family_is_root_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.family_user_is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.family_current_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.family_current_status() TO authenticated;

-- Register root admin without overwriting an existing row.
INSERT INTO public.family_user_permissions
  (user_id, role, status, granted_by)
VALUES
  ('4f442010-a8ae-4339-9748-554ce5c281e7'::uuid, 'admin', 'active',
   '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid)
ON CONFLICT (user_id) DO NOTHING;

COMMIT;
