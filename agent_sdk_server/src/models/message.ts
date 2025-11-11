// ABOUTME: Database model for messages
// ABOUTME: Handles CRUD operations for all message types with automatic sequencing

import { getPool } from '../config/database.js';

export type MessageType =
  | 'user'
  | 'assistant'
  | 'user_prompt'
  | 'llm_response'
  | 'tool_call'
  | 'tool_result'
  | 'tool_error';

export interface StoredMessage {
  id: string;
  conversation_id: string;
  type: MessageType;
  sequence_number: number;
  timestamp: Date;
  content: Record<string, any>;
}

export async function createMessage(
  conversationId: string,
  type: MessageType,
  content: Record<string, any>
): Promise<StoredMessage> {
  const pool = getPool();

  // Get next sequence number
  const seqResult = await pool.query(
    'SELECT COALESCE(MAX(sequence_number), 0) + 1 as next_seq FROM messages WHERE conversation_id = $1',
    [conversationId]
  );
  const sequenceNumber = seqResult.rows[0].next_seq;

  const result = await pool.query(
    `INSERT INTO messages (conversation_id, type, content, sequence_number)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [conversationId, type, JSON.stringify(content), sequenceNumber]
  );

  return result.rows[0];
}

export async function getConversationMessages(
  conversationId: string,
  types?: MessageType[]
): Promise<StoredMessage[]> {
  const pool = getPool();

  let query = 'SELECT * FROM messages WHERE conversation_id = $1';
  const params: any[] = [conversationId];

  if (types && types.length > 0) {
    query += ' AND type = ANY($2)';
    params.push(types);
  }

  query += ' ORDER BY sequence_number ASC';

  const result = await pool.query(query, params);
  return result.rows;
}

export async function getConversationHistory(
  conversationId: string
): Promise<StoredMessage[]> {
  return getConversationMessages(conversationId, ['user', 'assistant']);
}
