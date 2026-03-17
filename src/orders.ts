import { query } from "./db";

// ── Order management ──

export async function createOrder(userId: string, items: any[]): Promise<string> {
  const id = crypto.randomUUID();
  const total = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  await query("INSERT INTO orders (id, user_id, total, status) VALUES ($1, $2, $3, 'pending')", [id, userId, total]);
  for (const item of items) {
    await query("INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ($1, $2, $3, $4)",
      [id, item.productId, item.quantity, item.price]);
  }
  return id;
}

export async function getOrderById(id: string): Promise<any> {
  const rows = await query("SELECT * FROM orders WHERE id = $1", [id]);
  return rows[0] || null;
}

export async function getOrderItems(orderId: string): Promise<any[]> {
  return await query("SELECT * FROM order_items WHERE order_id = $1", [orderId]);
}

export async function updateOrderStatus(id: string, status: string): Promise<void> {
  await query("UPDATE orders SET status = $1, updated_at = NOW() WHERE id = $2", [status, id]);
}

export async function cancelOrder(id: string): Promise<void> {
  await query("UPDATE orders SET status = 'cancelled', updated_at = NOW() WHERE id = $1", [id]);
}

export async function listOrdersByUser(userId: string): Promise<any[]> {
  return await query("SELECT * FROM orders WHERE user_id = $1 ORDER BY created_at DESC", [userId]);
}

export async function getOrderTotal(id: string): Promise<number> {
  const rows = await query("SELECT total FROM orders WHERE id = $1", [id]);
  return rows[0]?.total || 0;
}

export async function countOrdersByStatus(status: string): Promise<number> {
  const rows = await query("SELECT COUNT(*) as count FROM orders WHERE status = $1", [status]);
  return rows[0].count;
}

export async function getRecentOrders(limit: number = 20): Promise<any[]> {
  return await query("SELECT * FROM orders ORDER BY created_at DESC LIMIT $1", [limit]);
}

export async function calculateRevenue(startDate: string, endDate: string): Promise<number> {
  const rows = await query(
    "SELECT SUM(total) as revenue FROM orders WHERE status = 'completed' AND created_at BETWEEN $1 AND $2",
    [startDate, endDate]
  );
  return rows[0]?.revenue || 0;
}
