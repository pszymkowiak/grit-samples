import { query } from "./db";

// ── Analytics & reporting ──

export async function trackEvent(userId: string, event: string, metadata: any): Promise<void> {
  await query("INSERT INTO events (user_id, event, metadata) VALUES ($1, $2, $3)", [userId, event, JSON.stringify(metadata)]);
}

export async function getEventCount(event: string, startDate: string, endDate: string): Promise<number> {
  const rows = await query(
    "SELECT COUNT(*) as count FROM events WHERE event = $1 AND created_at BETWEEN $2 AND $3",
    [event, startDate, endDate]
  );
  return rows[0].count;
}

export async function getActiveUsers(days: number = 30): Promise<number> {
  const rows = await query(
    "SELECT COUNT(DISTINCT user_id) as count FROM events WHERE created_at > NOW() - INTERVAL '$1 days'",
    [days]
  );
  return rows[0].count;
}

export async function getUserEvents(userId: string, limit: number = 100): Promise<any[]> {
  return await query("SELECT * FROM events WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2", [userId, limit]);
}

export async function getDailyStats(startDate: string, endDate: string): Promise<any[]> {
  return await query(
    "SELECT DATE(created_at) as day, COUNT(*) as events, COUNT(DISTINCT user_id) as users FROM events WHERE created_at BETWEEN $1 AND $2 GROUP BY day ORDER BY day",
    [startDate, endDate]
  );
}

export async function getTopEvents(limit: number = 10): Promise<any[]> {
  return await query("SELECT event, COUNT(*) as count FROM events GROUP BY event ORDER BY count DESC LIMIT $1", [limit]);
}

export async function getRetentionRate(cohortDate: string, days: number): Promise<number> {
  const rows = await query(
    "SELECT COUNT(DISTINCT e2.user_id)::float / NULLIF(COUNT(DISTINCT e1.user_id), 0) as rate FROM events e1 LEFT JOIN events e2 ON e1.user_id = e2.user_id AND e2.created_at > e1.created_at + INTERVAL '$2 days' WHERE DATE(e1.created_at) = $1",
    [cohortDate, days]
  );
  return rows[0]?.rate || 0;
}

export async function generateReport(startDate: string, endDate: string): Promise<any> {
  const events = await getEventCount("*", startDate, endDate);
  const users = await getActiveUsers(30);
  const top = await getTopEvents(5);
  return { period: { startDate, endDate }, totalEvents: events, activeUsers: users, topEvents: top };
}

export async function purgeOldEvents(days: number = 90): Promise<number> {
  const result = await query("DELETE FROM events WHERE created_at < NOW() - INTERVAL '$1 days'", [days]);
  return result.length;
}

export async function exportEvents(startDate: string, endDate: string): Promise<string> {
  const rows = await query("SELECT * FROM events WHERE created_at BETWEEN $1 AND $2 ORDER BY created_at", [startDate, endDate]);
  return JSON.stringify(rows);
}
