// ABOUTME: Database model for LLM history entries
// ABOUTME: Stores detailed interaction history including tool calls and results

import { getPool } from '../config/database.js';
import type { LLMHistoryEntry } from '../types/index.js';

export interface StoredLLMHistoryEntry {
  id: string;
  message_id: string;
  entry_type: LLMHistoryEntry['type'];
  sequence_number: number;
  timestamp: Date;
  content: Record<string, any>;
  stop_reason?: string;
  tool_name?: string;
}

export async function createLLMHistoryEntry(
  messageId: string,
  entry: LLMHistoryEntry,
  sequenceNumber: number
): Promise<StoredLLMHistoryEntry> {
  const pool = getPool();
  const result = await pool.query(
    `INSERT INTO llm_history (
      message_id, entry_type, sequence_number, timestamp, content, stop_reason, tool_name
    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    RETURNING *`,
    [
      messageId,
      entry.type,
      sequenceNumber,
      entry.timestamp,
      JSON.stringify(entry.content || {}),
      entry.stop_reason || null,
      entry.tool_name || null
    ]
  );
  return result.rows[0];
}

export async function getMessageLLMHistory(
  messageId: string
): Promise<StoredLLMHistoryEntry[]> {
  const pool = getPool();
  const result = await pool.query(
    'SELECT * FROM llm_history WHERE message_id = $1 ORDER BY sequence_number ASC',
    [messageId]
  );
  return result.rows;
}
