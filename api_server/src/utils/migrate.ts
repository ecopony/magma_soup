// ABOUTME: Database migration runner for applying SQL schema changes
// ABOUTME: Tracks applied migrations and runs pending ones in order

import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { getPool } from '../config/database.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export async function runMigrations() {
  const pool = getPool();

  // Create migrations tracking table
  await pool.query(`
    CREATE TABLE IF NOT EXISTS migrations (
      id SERIAL PRIMARY KEY,
      filename TEXT NOT NULL UNIQUE,
      applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    )
  `);

  // Get applied migrations
  const appliedResult = await pool.query(
    'SELECT filename FROM migrations ORDER BY id'
  );
  const applied = new Set(appliedResult.rows.map(r => r.filename));

  // Read migration files
  const migrationsDir = path.join(__dirname, '../../migrations');
  const files = await fs.readdir(migrationsDir);
  const sqlFiles = files.filter(f => f.endsWith('.sql')).sort();

  // Apply pending migrations
  for (const filename of sqlFiles) {
    if (applied.has(filename)) {
      console.log(`✓ ${filename} (already applied)`);
      continue;
    }

    console.log(`Applying ${filename}...`);
    const sql = await fs.readFile(path.join(migrationsDir, filename), 'utf-8');

    try {
      await pool.query('BEGIN');
      await pool.query(sql);
      await pool.query('INSERT INTO migrations (filename) VALUES ($1)', [filename]);
      await pool.query('COMMIT');
      console.log(`✓ ${filename} applied`);
    } catch (error) {
      await pool.query('ROLLBACK');
      console.error(`✗ ${filename} failed:`, error);
      throw error;
    }
  }

  console.log('All migrations completed');
}

// Run if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  runMigrations()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('Migration failed:', err);
      process.exit(1);
    });
}
