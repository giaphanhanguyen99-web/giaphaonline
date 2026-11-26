-- P2.3.4.4.4.1: role-based RLS for the archive metadata tables.
-- Review and run manually in Supabase SQL Editor only after explicit approval.
-- This migration does NOT change Storage object policies; those are handled in P2.3.4.4.4.2.
--
-- Role matrix:
--   Visitor/anon: read public archives and their file metadata only.
--   Active Member: read public and private archives and file metadata.
--   Active Editor: Member read + create/update archives and file metadata.
--   Active Admin: Editor permissions + delete archives and file metadata.
--   Root Admin: full access, identified by family_is_root_admin().
--
-- Existing permission helpers are defined in p2-3-4-1-user-permissions.sql.
-- family_current_role() returns 'admin' for Root Admin; Root is also checked explicitly.

BEGIN;

-- Remove the previous Root-only and duplicate archive-table policies.
DROP POLICY IF EXISTS "Public can read public family archives" ON public.family_archives;
DROP POLICY IF EXISTS "Admin can insert family archives" ON public.family_archives;
DROP POLICY IF EXISTS "Admin can update family archives" ON public.family_archives;
DROP POLICY IF EXISTS "Admin can delete family archives" ON public.family_archives;
DROP POLICY IF EXISTS "Admin can delete archives" ON public.family_archives;
DROP POLICY IF EXISTS "Admin can insert archives" ON public.family_archives;
DROP POLICY IF EXISTS "Admin can update archives" ON public.family_archives;

DROP POLICY IF EXISTS "Public can view files of public archives" ON public.family_archive_files;
DROP POLICY IF EXISTS "Admin can insert archive files" ON public.family_archive_files;
DROP POLICY IF EXISTS "Admin can update archive files" ON public.family_archive_files;
DROP POLICY IF EXISTS "Admin can delete archive files" ON public.family_archive_files;

-- Make this migration safely re-runnable.
DROP POLICY IF EXISTS family_archives_public_read ON public.family_archives;
DROP POLICY IF EXISTS family_archives_active_read_private ON public.family_archives;
DROP POLICY IF EXISTS family_archives_editor_admin_insert ON public.family_archives;
DROP POLICY IF EXISTS family_archives_editor_admin_update ON public.family_archives;
DROP POLICY IF EXISTS family_archives_admin_delete ON public.family_archives;

DROP POLICY IF EXISTS family_archive_files_public_read ON public.family_archive_files;
DROP POLICY IF EXISTS family_archive_files_active_read_private ON public.family_archive_files;
DROP POLICY IF EXISTS family_archive_files_editor_admin_insert ON public.family_archive_files;
DROP POLICY IF EXISTS family_archive_files_editor_admin_update ON public.family_archive_files;
DROP POLICY IF EXISTS family_archive_files_admin_delete ON public.family_archive_files;

-- Public visitors may read only public archive rows.
CREATE POLICY family_archives_public_read
ON public.family_archives
FOR SELECT
TO anon, authenticated
USING (is_public = true);

-- Active family accounts may read private archives; Root Admin always can.
CREATE POLICY family_archives_active_read_private
ON public.family_archives
FOR SELECT
TO authenticated
USING (
  public.family_is_root_admin()
  OR (
    public.family_current_status() = 'active'
    AND public.family_current_role() IN ('member', 'editor', 'admin')
  )
);

-- Editors and Admins may create archive rows; Root Admin retains full control.
CREATE POLICY family_archives_editor_admin_insert
ON public.family_archives
FOR INSERT
TO authenticated
WITH CHECK (
  public.family_is_root_admin()
  OR (
    public.family_current_status() = 'active'
    AND public.family_current_role() IN ('editor', 'admin')
    AND (created_by IS NULL OR created_by = auth.uid())
  )
);

-- Editors and Admins may update archive rows; only Admin and Root may delete.
CREATE POLICY family_archives_editor_admin_update
ON public.family_archives
FOR UPDATE
TO authenticated
USING (
  public.family_is_root_admin()
  OR (
    public.family_current_status() = 'active'
    AND public.family_current_role() IN ('editor', 'admin')
  )
)
WITH CHECK (
  public.family_is_root_admin()
  OR (
    public.family_current_status() = 'active'
    AND public.family_current_role() IN ('editor', 'admin')
  )
);

CREATE POLICY family_archives_admin_delete
ON public.family_archives
FOR DELETE
TO authenticated
USING (
  public.family_is_root_admin()
  OR (
    public.family_current_status() = 'active'
    AND public.family_current_role() = 'admin'
  )
);

-- File metadata follows the visibility of its parent archive.
CREATE POLICY family_archive_files_public_read
ON public.family_archive_files
FOR SELECT
TO anon, authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.family_archives a
    WHERE a.id = family_archive_files.archive_id
      AND a.is_public = true
  )
);

CREATE POLICY family_archive_files_active_read_private
ON public.family_archive_files
FOR SELECT
TO authenticated
USING (
  public.family_is_root_admin()
  OR (
    public.family_current_status() = 'active'
    AND public.family_current_role() IN ('member', 'editor', 'admin')
    AND EXISTS (
      SELECT 1
      FROM public.family_archives a
      WHERE a.id = family_archive_files.archive_id
    )
  )
);

-- Editors and Admins may add file metadata for an existing archive.
CREATE POLICY family_archive_files_editor_admin_insert
ON public.family_archive_files
FOR INSERT
TO authenticated
WITH CHECK (
  public.family_is_root_admin()
  OR (
    public.family_current_status() = 'active'
    AND public.family_current_role() IN ('editor', 'admin')
    AND EXISTS (
      SELECT 1
      FROM public.family_archives a
      WHERE a.id = family_archive_files.archive_id
    )
  )
);

-- Editors and Admins may update file metadata; only Admin and Root may delete it.
CREATE POLICY family_archive_files_editor_admin_update
ON public.family_archive_files
FOR UPDATE
TO authenticated
USING (
  public.family_is_root_admin()
  OR (
    public.family_current_status() = 'active'
    AND public.family_current_role() IN ('editor', 'admin')
  )
)
WITH CHECK (
  public.family_is_root_admin()
  OR (
    public.family_current_status() = 'active'
    AND public.family_current_role() IN ('editor', 'admin')
  )
);

CREATE POLICY family_archive_files_admin_delete
ON public.family_archive_files
FOR DELETE
TO authenticated
USING (
  public.family_is_root_admin()
  OR (
    public.family_current_status() = 'active'
    AND public.family_current_role() = 'admin'
  )
);

-- Keep SQL privileges aligned with the RLS policies.
GRANT SELECT ON public.family_archives TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.family_archives TO authenticated;
GRANT SELECT ON public.family_archive_files TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.family_archive_files TO authenticated;

COMMIT;
