# Prototype Cội Nguồn (độc lập)

## An toàn
- Prototype nằm trong thư mục `prototype/` trên nhánh `prototype-gia-pha-from-scratch-2026-11-26`.
- Không chỉnh `main`, không chỉnh website đang chạy.
- Không kết nối Supabase, không chứa dữ liệu thật hoặc secrets.
- UI và dữ liệu minh họa, các thao tác đang là placeholders, không coi là chức năng hoàn chỉnh.

## Phases
1. Prototype UI + navigation and mock data (initial scaffold).
2. Architecture review and member/tree CRUD design.
3. Authentication and isolated Supabase environment (requires separate Supabase project or explicitly approved isolated schema, never re-use production tables by default).
4. Real genealogy/member/tree CRUD, relationships, date rules.
5. Archive/storage, saints, notifications, multi-stage funeral workflow.
6. Admin/security audit, backup/restore, activity log, role permissions.
7. Testing, mobile polish, deployment review.

## Preview
Open `prototype/index.html` directly or serve the prototype directory using a static server. GitHub Pages can be configured later, without touching production site deployment.

## Current state
The UI is only a visual/interactive navigation scaffold. Buttons that indicate future functionality display explanatory placeholders. No Supabase writes, authentication, data CRUD, upload, or notification delivery are implemented yet.
