import { query } from "./db";

// ── Product management ──

export async function createProduct(name: string, price: number, category: string): Promise<string> {
  const id = crypto.randomUUID();
  await query("INSERT INTO products (id, name, price, category) VALUES ($1, $2, $3, $4)", [id, name, price, category]);
  return id;
}

export async function getProductById(id: string): Promise<any> {
  const rows = await query("SELECT * FROM products WHERE id = $1", [id]);
  return rows[0] || null;
}

export async function updateProductPrice(id: string, price: number): Promise<void> {
  await query("UPDATE products SET price = $1, updated_at = NOW() WHERE id = $2", [price, id]);
}

export async function deleteProduct(id: string): Promise<void> {
  await query("DELETE FROM products WHERE id = $1", [id]);
}

export async function listProducts(category?: string): Promise<any[]> {
  if (category) {
    return await query("SELECT * FROM products WHERE category = $1 ORDER BY name", [category]);
  }
  return await query("SELECT * FROM products ORDER BY name", []);
}

export async function searchProducts(term: string): Promise<any[]> {
  return await query("SELECT * FROM products WHERE name ILIKE $1", [`%${term}%`]);
}

export async function countProductsByCategory(): Promise<any[]> {
  return await query("SELECT category, COUNT(*) as count FROM products GROUP BY category", []);
}

export async function getTopProducts(limit: number = 10): Promise<any[]> {
  return await query("SELECT * FROM products ORDER BY sales DESC LIMIT $1", [limit]);
}

export async function updateProductStock(id: string, quantity: number): Promise<void> {
  await query("UPDATE products SET stock = $1, updated_at = NOW() WHERE id = $2", [quantity, id]);
}

export async function bulkUpdatePrices(category: string, multiplier: number): Promise<number> {
  const result = await query("UPDATE products SET price = price * $1 WHERE category = $2", [multiplier, category]);
  return result.length;
}
