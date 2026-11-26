-- P2.3.4.4.4.2: role-based Storage RLS for the private family-archives bucket.
-- Review and run manually in Supabase SQL Editor only after explicit approval.
-- This migration changes only policies for bucket_id = 'family-archives'.
-- It does not change bucket privacy, size limits, MIME allow-list, or photo bucket policies.
--
-- Read access:
--   anon: only objects referenced by public archive records.
--   active Member/Editor/Admin: objects referenced by any archive record.
--   Root Admin: all objects in this bucket.
-- Write access:
--   active Editor/Admin and Root: upload objects.
--   active Admin and Root: update/delete objects.
--
-- Important implementation detail:
-- The current website uploads a new file to Storage BEFORE inserting its
-- family_archives row and family_archive_files metadata. Therefore INSERT
-- cannot safely require an existing parent archive row without first changing
-- that frontend save order. This policy limits uploads to active Editor/Admin
-- accounts and UUID/archive-style folders. Orphan cleanup and stricter
-- parent-to-object binding should be handled alongside the frontend workflow.

BEGIN;

-- Remove only the known legacy archive-bucket policies.
DROP POLICY IF EXISTS "Readers can access public archive files" ON storage.objects;
DROP POLICY IF EXISTS "View permitted family archive files" ON storage.objects;
DROP POLICY IF EXISTS "Admin can upload archive files" ON storage.objects;
DROP POLICY IF EXISTS "Admin can upload family archive files" ON storage.objects;
DROP POLICY IF EXISTS "Admin can update archive files" ON storage.objects;
DROP POLICY IF EXISTS "Admin can delete archive files" ON storage.objects;

-- Make this migration safely re-runnable.
DROP POLICY IF EXISTS family_archive_storage_read ON storage.objects;
DROP POLICY IF EXISTS family_archive_storage_upload ON storage.objects;
DROP POLICY IF EXISTS family_archive_storage_update ON storage.objects;
DROP POLICY IF EXISTS family_archive_storage_delete ON storage.objects;

-- Read only files that are actually referenced by an archive.
-- Supports both the legacy JSON attachments field and the normalized
-- family_archive_files metadata table.
CREATE POLICY family_archive_storage_read
ON storage.objects
FOR SELECT
TO anon, authenticated
USING (
  bucket_id = 'family-archives'
  AND (
    public.family_is_root_admin()
    OR EXISTS (
      SELECT 1
      FROM public.family_archives a
      WHERE
        (
          a.is_public = true
          AND a.attachments @> jsonb_build_array(jsonb_build_object('path', storage.objects.name))
        )
        OR (
          auth.uid() IS NOT NULL
          AND public.family_current_status() = 'active'
          AND public.family_current_role() IN ('member', 'editor', 'admin')
          AND (
            a.attachments @> jsonb_build_array(jsonb_build_object('path', storage.objects.name))
            OR EXISTS (
              SELECT 1
              FROM public.family_archive_files f
              WHERE f.archive_id = a.id
                AND f.storage_path = storage.objects.name
            )
          )
        )
    )
  )
);

-- The current frontend uses <archive UUID>/<generated filename> as object path.
-- Only active Editors/Admins (and Root) may upload to this private bucket.
CREATE POLICY family_archive_storage_upload
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'family-archives'
  AND (
    public.family_is_root_admin()
    OR (
      public.family_current_status() = 'active'
      AND public.family_current_role() IN ('editor', 'admin')
      AND COALESCE(array_length(storage.foldername(name), 1), 0) >= 2
      AND (storage.foldername(name))[1] ~*
        '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    )
  )
);

-- Object replacement/update is reserved for Admin and Root.
CREATE POLICY family_archive_storage_update
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'family-archives'
  AND (
    public.family_is_root_admin()
    OR (
      public.family_current_status() = 'active'
      AND public.family_current_role() = 'admin'
    )
  )
)
WITH CHECK (
  bucket_id = 'family-archives'
  AND (
    public.family_is_root_admin()
    OR (
      public.family_current_status() = 'active'
      AND public.family_current_role() = 'admin'
    )
  )
);

-- Physical object deletion is reserved for Admin and Root.
CREATE POLICY family_archive_storage_delete
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'family-archives'
  AND (
    public.family_is_root_admin()
    OR (
      public.family_current_status() = 'active'
      AND public.family_current_role() = 'admin'
    )
  )
);

COMMIT;
