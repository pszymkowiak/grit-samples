import { query } from "./db";

// ── User management ──

export async function createUser(email: string, name: string, role: string): Promise<string> {
  const id = crypto.randomUUID();
  await query("INSERT INTO users (id, email, name, role) VALUES ($1, $2, $3, $4)", [id, email, name, role]);
  return id;
}

export async function getUserById(id: string): Promise<any> {
  const rows = await query("SELECT * FROM users WHERE id = $1", [id]);
  return rows[0] || null;
}

export async function getUserByEmail(email: string): Promise<any> {
  const rows = await query("SELECT * FROM users WHERE email = $1", [email]);
  return rows[0] || null;
}

export async function updateUserName(id: string, name: string): Promise<void> {
  await query("UPDATE users SET name = $1, updated_at = NOW() WHERE id = $2", [name, id]);
}

export async function updateUserRole(id: string, role: string): Promise<void> {
  await query("UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2", [role, id]);
}

export async function deleteUser(id: string): Promise<void> {
  await query("DELETE FROM users WHERE id = $1", [id]);
}

export async function listUsers(limit: number = 50, offset: number = 0): Promise<any[]> {
  return await query("SELECT * FROM users ORDER BY created_at DESC LIMIT $1 OFFSET $2", [limit, offset]);
}

export async function countUsers(): Promise<number> {
  const rows = await query("SELECT COUNT(*) as count FROM users", []);
  return rows[0].count;
}

export async function searchUsers(term: string): Promise<any[]> {
  return await query("SELECT * FROM users WHERE name ILIKE $1 OR email ILIKE $1", [`%${term}%`]);
}

export async function deactivateUser(id: string): Promise<void> {
  await query("UPDATE users SET active = false, updated_at = NOW() WHERE id = $1", [id]);
}
