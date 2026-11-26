# Prototype Cội Nguồn — theo dõi tiến độ

**Branch:** `prototype-gia-pha-from-scratch-2026-11-26`  
**Baseline:** `gia-pha-development-2026-11-25`  
**Production/main:** không thay đổi  
**Supabase:** chưa kết nối; cần dự án Supabase độc lập trước khi sử dụng dữ liệu thực.

## 0 — Isolation and discovery
- [x] Tạo nhánh prototype độc lập
- [x] Dựng khung UI và điều hướng ban đầu
- [x] Ghi rõ dữ liệu giả, không có ghi DB/không có secrets
- [ ] Kiểm tra scaffold trên trình duyệt của người dùng
- [ ] Chốt lựa chọn Supabase project riêng

## 1 — UI foundation
- [x] Dashboard scaffold
- [x] Navigation: dashboard, tree, members, notifications, archive, saints, admin
- [x] Responsive breakpoints cơ bản
- [ ] User test UI/navigation on desktop and mobile
- [x] Add a prototype rule demo for sibling ordering (age-based left-to-right, manual override, restore automatic; controls use left/right arrows)\n- [x] Prototype tree layout controls: compact spacing, collapse descendant generation, focus-mode visual demo (mock only)\n- [ ] Review visual design and accessibility

## 2 — Member data and genealogy
- [ ] Database model, member CRUD
- [ ] Family relationship model
- [ ] Tree navigation/layout (vertical and horizontal)\n- [ ] Adaptive subtree spacing to avoid large gaps in wide trees\n- [ ] Collapsible descendant branches and descendant-count indicators\n- [ ] Focus/subtree view and return-to-whole-tree navigation\n- [ ] Zoom/pan optimized for desktop and touch\n- [x] Define sibling display rule: oldest-to-youngest, left-to-right by default\n- [x] Prototype manual ordering override and restore automatic sorting (mock only)\n- [ ] Implement persisted sibling order, including missing-date handling and equal-date tie-breaker
- [ ] Search/autocomplete and profile details
- [ ] Age/date conventions and anniversaries

## 3 — Archive and saints
- [ ] Isolated storage and archive UI upload/download
- [ ] Metadata, previews, audio/video/document support as applicable
- [ ] Import/seed 62 saints into isolated environment
- [ ] Search/edit/add and validate persistence

## 4 — Notification system
- [ ] General notification/event schema and categories
- [ ] Priority levels (urgent/important/normal)
- [ ] Funeral notice multi-step confirmation and audit trail
- [ ] Funeral schedule later-update flow
- [ ] Display, dismiss and retained archive
- [ ] Notification delivery feasibility (push/mobile later)

## 5 — Security/admin
- [ ] Authentication
- [ ] RLS review and least privilege
- [ ] Role permissions
- [ ] Activity/audit history
- [ ] Edit history and restoration
- [ ] Backup and restore test

## 6 — Mobile and enhancements
- [ ] Mobile UX
- [ ] Push notifications and vibration feasibility
- [ ] Historical timeline
- [ ] Photo albums
- [ ] Charts/statistics

## 7 — Acceptance and release
- [ ] Full test checklist
- [ ] Browser/device tests
- [ ] Security and data recovery review
- [ ] Deployment plan
- [ ] User approval before any merge/release to production

## Principle
Each feature is marked complete only after user tests and confirms it. Prototype commits stay isolated; main/production are not altered without explicit approval.
