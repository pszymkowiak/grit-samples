import { query } from "./db";

// ── Notification system ──

export async function createNotification(userId: string, type: string, message: string): Promise<string> {
  const id = crypto.randomUUID();
  await query("INSERT INTO notifications (id, user_id, type, message) VALUES ($1, $2, $3, $4)", [id, userId, type, message]);
  return id;
}

export async function getNotification(id: string): Promise<any> {
  const rows = await query("SELECT * FROM notifications WHERE id = $1", [id]);
  return rows[0] || null;
}

export async function markAsRead(id: string): Promise<void> {
  await query("UPDATE notifications SET read = true, read_at = NOW() WHERE id = $1", [id]);
}

export async function markAllAsRead(userId: string): Promise<void> {
  await query("UPDATE notifications SET read = true, read_at = NOW() WHERE user_id = $1 AND read = false", [userId]);
}

export async function getUnreadCount(userId: string): Promise<number> {
  const rows = await query("SELECT COUNT(*) as count FROM notifications WHERE user_id = $1 AND read = false", [userId]);
  return rows[0].count;
}

export async function listNotifications(userId: string, limit: number = 50): Promise<any[]> {
  return await query("SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2", [userId, limit]);
}

export async function deleteNotification(id: string): Promise<void> {
  await query("DELETE FROM notifications WHERE id = $1", [id]);
}

export async function deleteOldNotifications(days: number = 30): Promise<number> {
  const result = await query("DELETE FROM notifications WHERE created_at < NOW() - INTERVAL '$1 days'", [days]);
  return result.length;
}

export async function sendBulkNotification(userIds: string[], type: string, message: string): Promise<void> {
  for (const userId of userIds) {
    await createNotification(userId, type, message);
  }
}

export async function getNotificationStats(userId: string): Promise<any> {
  const rows = await query(
    "SELECT type, COUNT(*) as count, SUM(CASE WHEN read THEN 1 ELSE 0 END) as read_count FROM notifications WHERE user_id = $1 GROUP BY type",
    [userId]
  );
  return rows;
}
