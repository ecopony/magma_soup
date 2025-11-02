// ABOUTME: Database model for messages
// ABOUTME: Handles CRUD operations for message records with automatic sequencing

import { getPool } from '../config/database.js';
import type { Message as MessageContent } from '../types/index.js';

export interface StoredMessage {
  id: string;
  conversation_id: string;
  role: 'user' | 'assistant';
  content: MessageContent['content'];
  created_at: Date;
  sequence_number: number;
  metadata?: Record<string, any>;
}

export async function createMessage(
  conversationId: string,
  role: 'user' | 'assistant',
  content: MessageContent['content'],
  metadata?: Record<string, any>
): Promise<StoredMessage> {
  const pool = getPool();

  // Get next sequence number
  const seqResult = await pool.query(
    'SELECT COALESCE(MAX(sequence_number), 0) + 1 as next_seq FROM messages WHERE conversation_id = $1',
    [conversationId]
  );
  const sequenceNumber = seqResult.rows[0].next_seq;

  const result = await pool.query(
    `INSERT INTO messages (conversation_id, role, content, sequence_number, metadata)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [conversationId, role, JSON.stringify(content), sequenceNumber, metadata ? JSON.stringify(metadata) : null]
  );

  return result.rows[0];
}

export async function getConversationMessages(
  conversationId: string
): Promise<StoredMessage[]> {
  const pool = getPool();
  const result = await pool.query(
    'SELECT * FROM messages WHERE conversation_id = $1 ORDER BY sequence_number ASC',
    [conversationId]
  );
  return result.rows;
}

export async function getMessage(id: string): Promise<StoredMessage | null> {
  const pool = getPool();
  const result = await pool.query(
    'SELECT * FROM messages WHERE id = $1',
    [id]
  );
  return result.rows[0] || null;
}
