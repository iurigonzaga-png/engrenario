import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { Pool } from 'pg';

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  host: process.env.PGHOST,
  port: process.env.PGPORT ? Number(process.env.PGPORT) : undefined,
  user: process.env.PGUSER,
  password: process.env.PGPASSWORD,
  database: process.env.PGDATABASE,
});

export async function initializeDatabase(): Promise<void> {
  const schemaPath = fileURLToPath(
    new URL('../../database/schema.sql', import.meta.url),
  );
  const schema = await readFile(schemaPath, 'utf8');
  await pool.query(schema);
}
