-- Review gate for family account registration.
-- This file only defines SQL. It does not execute itself.
-- Review status values and table policies against the live Supabase project before applying.
BEGIN;

CREATE OR REPLACE FUNCTION public.family_admin_list_registration_requests()
RETURNS TABLE (
  id uuid,
  email text,
  full_name text,
  phone text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
BEGIN
  IF auth.uid() IS DISTINCT FROM '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid THEN
    RAISE EXCEPTION 'ROOT_ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT r.id, r.email, r.full_name, r.phone, r.created_at
  FROM public.family_registration_requests AS r
  WHERE r.status = 'pending'
  ORDER BY r.created_at ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.family_review_registration_request(
  p_request_id uuid,
  p_decision text,
  p_role text DEFAULT 'member'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
DECLARE
  v_request public.family_registration_requests%ROWTYPE;
  v_user_id uuid;
  v_existing_role text;
  v_existing_status text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid THEN
    RAISE EXCEPTION 'ROOT_ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  IF p_decision NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'INVALID_DECISION';
  END IF;

  IF p_decision = 'approve' AND p_role NOT IN ('member', 'editor') THEN
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
    WHERE lower(u.email) = lower(v_request.email)
      AND u.email_confirmed_at IS NOT NULL
    ORDER BY u.created_at ASC
    LIMIT 1;

    IF v_user_id IS NULL THEN
      RAISE EXCEPTION 'AUTH_ACCOUNT_NOT_FOUND';
    END IF;

    SELECT p.role, p.status INTO v_existing_role, v_existing_status
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
          updated_at = now()
      WHERE user_id = v_user_id;
    ELSE
      INSERT INTO public.family_user_permissions
        (user_id, role, status, granted_by)
      VALUES
        (v_user_id, p_role, 'active', auth.uid());
    END IF;

    UPDATE public.family_registration_requests
    SET status = 'approved',
        reviewed_at = now(),
        reviewed_by = auth.uid()
    WHERE id = v_request.id;
  ELSE
    UPDATE public.family_registration_requests
    SET status = 'rejected',
        reviewed_at = now(),
        reviewed_by = auth.uid()
    WHERE id = v_request.id;
  END IF;

  RETURN jsonb_build_object(
    'request_id', v_request.id,
    'email', v_request.email,
    'decision', p_decision,
    'role', CASE WHEN p_decision = 'approve' THEN p_role ELSE NULL END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.family_admin_list_registration_requests() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.family_review_registration_request(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.family_admin_list_registration_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.family_review_registration_request(uuid, text, text) TO authenticated;

COMMIT;
