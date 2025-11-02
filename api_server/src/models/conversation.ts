// ABOUTME: Database model for conversations
// ABOUTME: Handles CRUD operations for conversation records

import { getPool } from '../config/database.js';

export interface Conversation {
  id: string;
  created_at: Date;
  updated_at: Date;
  title?: string;
  metadata?: Record<string, any>;
}

export async function createConversation(
  title?: string,
  metadata?: Record<string, any>
): Promise<Conversation> {
  const pool = getPool();
  const result = await pool.query(
    `INSERT INTO conversations (title, metadata)
     VALUES ($1, $2)
     RETURNING *`,
    [title, metadata ? JSON.stringify(metadata) : null]
  );
  return result.rows[0];
}

export async function getConversation(id: string): Promise<Conversation | null> {
  const pool = getPool();
  const result = await pool.query(
    'SELECT * FROM conversations WHERE id = $1',
    [id]
  );
  return result.rows[0] || null;
}

export async function updateConversationTimestamp(id: string): Promise<void> {
  const pool = getPool();
  await pool.query(
    'UPDATE conversations SET updated_at = NOW() WHERE id = $1',
    [id]
  );
}

export async function listConversations(
  limit: number = 50,
  offset: number = 0
): Promise<Conversation[]> {
  const pool = getPool();
  const result = await pool.query(
    'SELECT * FROM conversations ORDER BY updated_at DESC LIMIT $1 OFFSET $2',
    [limit, offset]
  );
  return result.rows;
}
