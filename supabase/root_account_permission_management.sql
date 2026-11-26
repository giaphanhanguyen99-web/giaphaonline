-- Root-only account role and status management.
-- Function definitions only: no table, policy, or row changes.
BEGIN;

CREATE OR REPLACE FUNCTION public.root_list_family_account_permissions()
RETURNS TABLE (
  user_id uuid,
  email text,
  email_confirmed boolean,
  role text,
  status text,
  linked_member_id text,
  created_at timestamp with time zone,
  updated_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
BEGIN
  IF auth.uid() IS DISTINCT FROM '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid THEN
    RAISE EXCEPTION 'ROOT_ONLY' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    p.user_id,
    u.email::text,
    (u.email_confirmed_at IS NOT NULL),
    p.role,
    p.status,
    p.linked_member_id,
    p.created_at,
    p.updated_at
  FROM public.family_user_permissions AS p
  JOIN auth.users AS u ON u.id = p.user_id
  WHERE p.user_id <> '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
  ORDER BY p.created_at DESC, u.email ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.root_update_family_account_permission(
  p_user_id uuid,
  p_role text,
  p_status text,
  p_expected_role text,
  p_expected_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
BEGIN
  IF auth.uid() IS DISTINCT FROM '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid THEN
    RAISE EXCEPTION 'ROOT_ONLY' USING ERRCODE = '42501';
  END IF;

  IF p_user_id IS NULL
     OR p_user_id = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
  THEN
    RAISE EXCEPTION 'PROTECTED_ACCOUNT';
  END IF;

  IF p_role IS NULL OR p_role NOT IN ('member', 'editor', 'admin') THEN
    RAISE EXCEPTION 'INVALID_ROLE';
  END IF;

  IF p_status IS NULL OR p_status NOT IN ('pending', 'active', 'suspended', 'revoked') THEN
    RAISE EXCEPTION 'INVALID_STATUS';
  END IF;

  IF p_expected_role IS NULL
     OR p_expected_role NOT IN ('member', 'editor', 'admin')
     OR p_expected_status IS NULL
     OR p_expected_status NOT IN ('pending', 'active', 'suspended', 'revoked')
  THEN
    RAISE EXCEPTION 'INVALID_EXPECTED_STATE';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM auth.users AS u
    WHERE u.id = p_user_id
  ) THEN
    RAISE EXCEPTION 'ACCOUNT_NOT_FOUND';
  END IF;

  IF p_status = 'active' AND EXISTS (
    SELECT 1
    FROM auth.users AS u
    WHERE u.id = p_user_id
      AND u.email_confirmed_at IS NULL
  ) THEN
    RAISE EXCEPTION 'EMAIL_UNVERIFIED';
  END IF;

  UPDATE public.family_user_permissions AS p
  SET role = p_role,
      status = p_status,
      granted_by = auth.uid(),
      updated_at = pg_catalog.now()
  WHERE p.user_id = p_user_id
    AND p.user_id <> '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
    AND p.role = p_expected_role
    AND p.status = p_expected_status;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ACCOUNT_CHANGED_REFRESH';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.root_list_family_account_permissions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.root_list_family_account_permissions() TO authenticated;

REVOKE ALL ON FUNCTION public.root_update_family_account_permission(uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.root_update_family_account_permission(uuid, text, text, text, text) TO authenticated;

COMMIT;
