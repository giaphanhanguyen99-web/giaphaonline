-- Review gate for family account registration.
-- This file only defines SQL. It does not execute itself.
-- Review request status constraints, RLS, and Data API exposed schemas before applying.
-- Keep the private schema out of the Data API exposed schemas list.
BEGIN;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;

-- This internal helper is not directly exposed through the Data API.
-- It is callable only through the public invoker wrapper below and still checks
-- the caller's identity before touching registration or permission records.
CREATE OR REPLACE FUNCTION private.family_review_registration_request_privileged(
  p_request_id uuid,
  p_decision text,
  p_role text DEFAULT 'member'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  v_request public.family_registration_requests%ROWTYPE;
  v_user_id uuid;
  v_existing_status text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid THEN
    RAISE EXCEPTION 'ROOT_ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  IF p_decision IS NULL OR p_decision NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'INVALID_DECISION';
  END IF;

  IF p_decision = 'approve' AND (p_role IS NULL OR p_role NOT IN ('member', 'editor')) THEN
    RAISE EXCEPTION 'INVALID_ROLE';
  END IF;

  SELECT r.* INTO v_request
  FROM public.family_registration_requests AS r
  WHERE r.id = p_request_id
    AND r.status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REQUEST_NOT_PENDING';
  END IF;

  IF p_decision = 'approve' THEN
    SELECT u.id INTO v_user_id
    FROM auth.users AS u
    WHERE pg_catalog.lower(u.email) = pg_catalog.lower(v_request.email)
      AND u.email_confirmed_at IS NOT NULL
    ORDER BY u.created_at ASC
    LIMIT 1;

    IF v_user_id IS NULL THEN
      RAISE EXCEPTION 'AUTH_ACCOUNT_NOT_FOUND';
    END IF;

    SELECT p.status INTO v_existing_status
    FROM public.family_user_permissions AS p
    WHERE p.user_id = v_user_id
    FOR UPDATE;

    IF FOUND THEN
      IF v_existing_status <> 'pending' THEN
        RAISE EXCEPTION 'ACCOUNT_STATUS_CONFLICT';
      END IF;

      UPDATE public.family_user_permissions
      SET role = p_role,
          status = 'active',
          granted_by = auth.uid(),
          updated_at = pg_catalog.now()
      WHERE user_id = v_user_id;
    ELSE
      INSERT INTO public.family_user_permissions
        (user_id, role, status, granted_by)
      VALUES
        (v_user_id, p_role, 'active', auth.uid());
    END IF;

    UPDATE public.family_registration_requests
    SET status = 'approved',
        reviewed_at = pg_catalog.now(),
        reviewed_by = auth.uid()
    WHERE id = v_request.id;
  ELSE
    UPDATE public.family_registration_requests
    SET status = 'rejected',
        reviewed_at = pg_catalog.now(),
        reviewed_by = auth.uid()
    WHERE id = v_request.id;
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'request_id', v_request.id,
    'email', v_request.email,
    'decision', p_decision,
    'role', CASE WHEN p_decision = 'approve' THEN p_role ELSE NULL END
  );
END;
$$;

-- The public list RPC runs as the caller and relies on the existing Root SELECT policy.
CREATE OR REPLACE FUNCTION public.family_admin_list_registration_requests()
RETURNS TABLE (
  id uuid,
  email text,
  full_name text,
  phone text,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
  SELECT r.id, r.email, r.full_name, r.phone, r.created_at
  FROM public.family_registration_requests AS r
  WHERE r.status = 'pending'
    AND auth.uid() = '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid
  ORDER BY r.created_at ASC;
$$;

-- The public review RPC is invoker-only. Privileged work is isolated in the
-- non-exposed helper, which performs its own Root Admin check.
CREATE OR REPLACE FUNCTION public.family_review_registration_request(
  p_request_id uuid,
  p_decision text,
  p_role text DEFAULT 'member'
)
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
  SELECT private.family_review_registration_request_privileged(
    p_request_id, p_decision, p_role
  );
$$;

REVOKE ALL ON FUNCTION private.family_review_registration_request_privileged(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.family_review_registration_request_privileged(uuid, text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.family_admin_list_registration_requests() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.family_review_registration_request(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.family_admin_list_registration_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.family_review_registration_request(uuid, text, text) TO authenticated;

COMMIT;
