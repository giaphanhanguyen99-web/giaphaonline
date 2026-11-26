import * as webpush from "jsr:@negrel/webpush@0.5.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const PUBLISHABLE_KEYS = safeJson(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS"));
const SECRET_KEYS = safeJson(Deno.env.get("SUPABASE_SECRET_KEYS"));
const API_KEY = PUBLISHABLE_KEYS?.default || Deno.env.get("SUPABASE_ANON_KEY") || "";
const SERVICE_KEY = SECRET_KEYS?.default || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const ROOT_ADMIN_ID = "4f442010-a8ae-4339-9748-554ce5c281e7";
const VAPID_SECRET_NAME = "FAMILY_VAPID_KEYS";
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

function safeJson(value: string | undefined): Record<string, string> | null {
  if (!value) return null;
  try { return JSON.parse(value); } catch { return null; }
}
function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: CORS_HEADERS });
}
function dbHeaders() {
  return { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" };
}
async function db(path: string, init: RequestInit = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: { ...dbHeaders(), ...(init.headers as Record<string, string> || {}) },
  });
  const body = await response.text();
  if (!response.ok) throw new Error(`Database request failed (${response.status}): ${body.slice(0, 500)}`);
  return body ? JSON.parse(body) : null;
}
async function identify(token: string) {
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: API_KEY, Authorization: `Bearer ${token}` },
  });
  if (!response.ok) return null;
  return await response.json();
}
function validPushEndpoint(value: unknown): value is string {
  if (typeof value !== "string" || value.length > 4096) return false;
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase();
    const allowed = host === "fcm.googleapis.com" ||
      host === "updates.push.services.mozilla.com" ||
      host === "push.services.mozilla.com" ||
      host === "web.push.apple.com" ||
      host.endsWith(".push.apple.com") ||
      host.endsWith(".notify.windows.com") ||
      host.endsWith(".push.services.microsoft.com");
    return url.protocol === "https:" && !url.username && !url.password &&
      (!url.port || url.port === "443") && allowed;
  } catch { return false; }
}
function validSubscription(value: unknown): value is { endpoint: string; keys: { p256dh: string; auth: string } } {
  if (!value || typeof value !== "object") return false;
  const sub = value as Record<string, unknown>;
  const keys = sub.keys as Record<string, unknown> | undefined;
  return validPushEndpoint(sub.endpoint) &&
    typeof keys?.p256dh === "string" && keys.p256dh.length <= 256 &&
    typeof keys.auth === "string" && keys.auth.length <= 256;
}
async function loadVapid() {
  const raw = Deno.env.get(VAPID_SECRET_NAME);
  if (!raw) throw new Error("Push signing keys are not configured.");
  const exported = JSON.parse(raw);
  const keys = await webpush.importVapidKeys(exported, { extractable: false });
  const server = await webpush.ApplicationServer.new({
    contactInformation: Deno.env.get("FAMILY_VAPID_SUBJECT") || "https://github.com/giaphanhanguyen99-web/giaphaonline",
    vapidKeys: keys,
  });
  return { keys, server, publicKey: await webpush.exportApplicationServerKey(keys) };
}
async function sendToUserIds(userIds: string[], payload: Record<string, unknown>, urgency: webpush.Urgency) {
  if (!userIds.length) return { delivered: 0, failed: 0 };
  const filter = userIds.map(id => `"${id}"`).join(",");
  const rows = await db(`family_push_subscriptions?select=endpoint,user_id,subscription&user_id=in.(${filter})`) as Array<{ endpoint: string; user_id: string; subscription: { endpoint: string; keys: { p256dh: string; auth: string } } }>;
  const { server } = await loadVapid();
  let delivered = 0, failed = 0;
  await Promise.all(rows.map(async row => {
    if (!validSubscription(row.subscription) || row.subscription.endpoint !== row.endpoint) { failed++; return; }
    try {
      await server.subscribe(row.subscription).pushTextMessage(JSON.stringify(payload), { urgency, ttl: 86400 });
      delivered++;
    } catch (error) {
      const status = (error as { response?: Response })?.response?.status;
      if (status === 404 || status === 410) {
        await db(`family_push_subscriptions?endpoint=eq.${encodeURIComponent(row.endpoint)}`, { method: "DELETE" }).catch(() => {});
      } else {
        failed++;
      }
    }
  }));
  return { delivered, failed };
}
async function activePermissions() {
  return await db("family_user_permissions?select=user_id,role,status,linked_member_id&status=eq.active") as Array<{ user_id: string; role: string; status: string; linked_member_id: string | null }>;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (request.method !== "POST") return reply(405, { error: "Method not allowed." });
  if (!SUPABASE_URL || !API_KEY || !SERVICE_KEY) return reply(503, { error: "Push service is not configured." });

  const bearer = request.headers.get("Authorization") || "";
  const token = bearer.startsWith("Bearer ") ? bearer.slice(7) : "";
  const user = token ? await identify(token) : null;
  if (!user?.id) return reply(401, { error: "Đăng nhập để quản lý thông báo đẩy." });

  let input: Record<string, unknown>;
  try { input = await request.json(); } catch { return reply(400, { error: "Request không hợp lệ." }); }
  const action = input.action;

  if (action === "public-key") {
    try {
      const { publicKey } = await loadVapid();
      return reply(200, { publicKey });
    } catch { return reply(503, { error: "Thông báo đẩy chưa được cấu hình trên máy chủ." }); }
  }

  const permissionRows = await db(`family_user_permissions?select=role,status,linked_member_id&user_id=eq.${encodeURIComponent(user.id)}`) as Array<{ role: string; status: string; linked_member_id: string | null }>;
  const permission = permissionRows[0];
  const isRoot = user.id === ROOT_ADMIN_ID;
  const isActive = isRoot || permission?.status === "active";
  if (!isActive) return reply(403, { error: "Tài khoản chưa được kích hoạt." });

  if (action === "subscribe") {
    if (!validSubscription(input.subscription)) return reply(400, { error: "Thông tin đăng ký thiết bị không hợp lệ." });
    const subscription = input.subscription;
    const result = await db("family_push_subscriptions?on_conflict=endpoint", {
      method: "POST",
      headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
      body: JSON.stringify([{ endpoint: subscription.endpoint, user_id: user.id, subscription }]),
    });
    return reply(200, { ok: true, result });
  }

  if (action === "unsubscribe") {
    if (!validPushEndpoint(input.endpoint)) return reply(400, { error: "Thiết bị không hợp lệ." });
    await db(`family_push_subscriptions?endpoint=eq.${encodeURIComponent(input.endpoint)}&user_id=eq.${encodeURIComponent(user.id)}`, { method: "DELETE" });
    return reply(200, { ok: true });
  }

  if (action === "test") {
    const result = await sendToUserIds([user.id], {
      title: "Cội Nguồn · Thông báo thử",
      body: "Thông báo đẩy đã kết nối với thiết bị này.",
      url: "https://raw.githack.com/giaphanhanguyen99-web/giaphaonline/gia-pha-development-2026-11-25/index.html?source=push",
      tag: "coinguon-push-test",
    }, webpush.Urgency.High);
    return reply(200, { ok: true, ...result });
  }

  if (action === "send") {
    if (!isRoot && !(permission?.role === "admin" && permission.status === "active")) {
      return reply(403, { error: "Chỉ quản trị viên mới có thể phát hành thông báo đẩy." });
    }
    if (!/^[0-9a-f-]{36}$/i.test(String(input.id || ""))) return reply(400, { error: "Mã thông báo không hợp lệ." });
    const source = input.source === "funeral" ? "funeral" : "notification";
    const table = source === "funeral" ? "family_funeral_notices" : "family_notifications";
    const id = String(input.id);
    const rows = await db(`${table}?id=eq.${encodeURIComponent(id)}&select=*`) as Array<Record<string, unknown>>;
    const notice = rows[0];
    if (!notice || notice.status !== "published") return reply(409, { error: "Thông báo chưa được phát hành." });
    const sendAt = source === "funeral" ? notice.published_at : notice.send_at;
    if (sendAt && new Date(String(sendAt)).getTime() > Date.now()) return reply(409, { error: "Thông báo được lên lịch gửi sau." });
    if (notice.expires_at && new Date(String(notice.expires_at)).getTime() <= Date.now()) return reply(409, { error: "Thông báo đã hết hạn." });

    const permissions = await activePermissions();
    let recipients = permissions;
    if (source === "notification" && notice.audience_type === "members") {
      const memberIds = Array.isArray(notice.recipient_member_ids) ? notice.recipient_member_ids.map(String) : [];
      recipients = permissions.filter(p => !!p.linked_member_id && memberIds.includes(p.linked_member_id));
    } else if (source === "notification") {
      const roles = Array.isArray(notice.audience_roles) ? notice.audience_roles.map(String) : [];
      recipients = permissions.filter(p => roles.includes(p.role));
    }
    const userIds = new Set(recipients.map(p => p.user_id));
    userIds.add(ROOT_ADMIN_ID);
    const priority = String(notice.priority || (source === "funeral" ? "urgent" : "normal"));
    const level = priority === "urgent" ? "Khẩn cấp" : priority === "important" ? "Quan trọng" : "Thông báo mới";
    const tag = id.replaceAll("-", "").slice(0, 32);
    const result = await sendToUserIds([...userIds], {
      title: `Cội Nguồn · ${level}`,
      body: "Có thông báo mới dành cho gia đình. Chạm để mở Cội Nguồn.",
      url: "https://raw.githack.com/giaphanhanguyen99-web/giaphaonline/gia-pha-development-2026-11-25/index.html?source=push",
      tag: `coinguon-${tag}`,
    }, priority === "urgent" ? webpush.Urgency.High : webpush.Urgency.Normal);
    return reply(200, { ok: true, ...result });
  }

  return reply(400, { error: "Action không được hỗ trợ." });
});
