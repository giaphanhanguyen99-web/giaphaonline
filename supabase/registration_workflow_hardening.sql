-- Harden the existing registration workflow without changing tables or rows.
-- Apply only to the Supabase project explicitly authorized by the project owner.
BEGIN;

CREATE OR REPLACE FUNCTION public.submit_family_registration(
  p_email text,
  p_full_name text,
  p_phone text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  v_email text;
  v_id uuid;
BEGIN
  v_email := pg_catalog.lower(pg_catalog.btrim(COALESCE(p_email, '')));

  IF v_email = '' THEN
    RAISE EXCEPTION 'Email không hợp lệ';
  END IF;

  IF p_full_name IS NULL
     OR pg_catalog.btrim(p_full_name) = ''
     OR p_phone IS NULL
     OR pg_catalog.btrim(p_phone) = ''
  THEN
    RAISE EXCEPTION 'Vui lòng nhập đầy đủ thông tin';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM auth.users AS u
    WHERE pg_catalog.lower(u.email) = v_email
  ) THEN
    RAISE EXCEPTION 'EMAIL_ACCOUNT_EXISTS';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.family_registration_requests AS r
    WHERE r.email = v_email
      AND r.status = 'pending'
  ) THEN
    RAISE EXCEPTION 'EMAIL_PENDING_EXISTS';
  END IF;

  INSERT INTO public.family_registration_requests (
    email,
    full_name,
    phone,
    status
  )
  VALUES (
    v_email,
    pg_catalog.btrim(p_full_name),
    pg_catalog.btrim(p_phone),
    'pending'
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_family_registration(p_request_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  v_request public.family_registration_requests%ROWTYPE;
  v_user_id uuid;
  v_permission_status text;
BEGIN
  IF auth.uid() IS DISTINCT FROM '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid THEN
    RAISE EXCEPTION 'ROOT_ONLY' USING ERRCODE = '42501';
  END IF;

  SELECT r.* INTO v_request
  FROM public.family_registration_requests AS r
  WHERE r.id = p_request_id
    AND r.status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REQUEST_NOT_PENDING';
  END IF;

  SELECT u.id INTO v_user_id
  FROM auth.users AS u
  WHERE pg_catalog.lower(u.email) = pg_catalog.lower(pg_catalog.btrim(v_request.email))
    AND u.email_confirmed_at IS NOT NULL
  ORDER BY u.created_at ASC
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_ACCOUNT_NOT_FOUND';
  END IF;

  SELECT p.status INTO v_permission_status
  FROM public.family_user_permissions AS p
  WHERE p.user_id = v_user_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_permission_status <> 'pending' THEN
      RAISE EXCEPTION 'ACCOUNT_STATUS_CONFLICT';
    END IF;

    UPDATE public.family_user_permissions
    SET role = 'member',
        status = 'active',
        granted_by = auth.uid(),
        updated_at = pg_catalog.now()
    WHERE user_id = v_user_id;
  ELSE
    INSERT INTO public.family_user_permissions (
      user_id,
      role,
      status,
      linked_member_id,
      granted_by
    )
    VALUES (
      v_user_id,
      'member',
      'active',
      NULL,
      auth.uid()
    );
  END IF;

  UPDATE public.family_registration_requests
  SET status = 'approved',
      reviewed_at = pg_catalog.now(),
      reviewed_by = auth.uid()
  WHERE id = v_request.id;

  RETURN v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_family_registration(p_request_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
BEGIN
  IF auth.uid() IS DISTINCT FROM '4f442010-a8ae-4339-9748-554ce5c281e7'::uuid THEN
    RAISE EXCEPTION 'ROOT_ONLY' USING ERRCODE = '42501';
  END IF;

  UPDATE public.family_registration_requests
  SET status = 'rejected',
      reviewed_at = pg_catalog.now(),
      reviewed_by = auth.uid()
  WHERE id = p_request_id
    AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REQUEST_NOT_PENDING';
  END IF;

  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_family_registration(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_family_registration(text, text, text) TO anon, authenticated;

REVOKE ALL ON FUNCTION public.approve_family_registration(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_family_registration(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.reject_family_registration(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reject_family_registration(uuid) TO authenticated;

COMMIT;
