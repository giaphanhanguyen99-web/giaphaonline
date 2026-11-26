-- P2.3.4.4.3.1: role-based RLS for family_members.
-- Review and run manually in Supabase SQL Editor; this file does not execute itself.
-- Existing Root Admin policies are preserved. PostgreSQL permissive policies are OR-combined.
--
-- The Root Admin's family_members.id is not derivable from auth.uid().
-- Set the Root Admin permission row's linked_member_id to the correct family_members.id
-- before enabling non-root writes. The helper below fails closed while it is NULL.

BEGIN;

CREATE OR REPLACE FUNCTION public.family_is_protected_root_member(p_member_id text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.family_user_permissions p
    WHERE p.user_id = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
      AND (
        p.linked_member_id IS NULL
        OR p.linked_member_id = p_member_id
      )
  );
$$;

REVOKE ALL ON FUNCTION public.family_is_protected_root_member(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.family_is_protected_root_member(text) TO authenticated;

DROP POLICY IF EXISTS family_members_editor_admin_insert ON public.family_members;
CREATE POLICY family_members_editor_admin_insert
ON public.family_members FOR INSERT TO authenticated
WITH CHECK (
  NOT public.family_is_root_admin()
  AND public.family_current_status() = 'active'
  AND public.family_current_role() IN ('editor', 'admin')
  AND NOT public.family_is_protected_root_member(id)
);

DROP POLICY IF EXISTS family_members_editor_admin_update ON public.family_members;
CREATE POLICY family_members_editor_admin_update
ON public.family_members FOR UPDATE TO authenticated
USING (
  NOT public.family_is_root_admin()
  AND public.family_current_status() = 'active'
  AND public.family_current_role() IN ('editor', 'admin')
  AND NOT public.family_is_protected_root_member(id)
)
WITH CHECK (
  NOT public.family_is_root_admin()
  AND public.family_current_status() = 'active'
  AND public.family_current_role() IN ('editor', 'admin')
  AND NOT public.family_is_protected_root_member(id)
);

DROP POLICY IF EXISTS family_members_admin_delete ON public.family_members;
CREATE POLICY family_members_admin_delete
ON public.family_members FOR DELETE TO authenticated
USING (
  NOT public.family_is_root_admin()
  AND public.family_current_status() = 'active'
  AND public.family_current_role() = 'admin'
  AND NOT public.family_is_protected_root_member(id)
);

COMMIT;
