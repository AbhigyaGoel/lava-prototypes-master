import { SCHEMA } from "./schema";

/**
 * Minimal database interface so the same code runs on:
 *  - PGlite (Postgres in WASM) for local dev, mock mode and tests: no install needed
 *  - Supabase / any Postgres via DATABASE_URL in deployed environments
 */
export interface Queryable {
  query<T = any>(sql: string, params?: unknown[]): Promise<T[]>;
}
export interface Db extends Queryable {
  tx<T>(fn: (q: Queryable) => Promise<T>): Promise<T>;
  close(): Promise<void>;
}

export async function createPgliteDb(dataDir?: string): Promise<Db> {
  const { PGlite } = await import("@electric-sql/pglite");
  if (dataDir) (await import("node:fs")).mkdirSync(dataDir, { recursive: true });
  const pg = dataDir ? new PGlite(dataDir) : new PGlite();
  await pg.exec(SCHEMA);
  return {
    async query(sql, params = []) {
      const r = await pg.query(sql, params as any[]);
      return r.rows as any[];
    },
    async tx(fn) {
      return pg.transaction(async (t) =>
        fn({ query: async (sql, params = []) => (await t.query(sql, params as any[])).rows as any[] }),
      );
    },
    close: () => pg.close(),
  };
}

export async function createPostgresDb(url: string): Promise<Db> {
  const { Pool } = await import("pg");
  const pool = new Pool({ connectionString: url, max: 5 });
  await pool.query(SCHEMA);
  return {
    async query(sql, params = []) {
      return (await pool.query(sql, params as any[])).rows;
    },
    async tx(fn) {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        const out = await fn({ query: async (sql, params = []) => (await client.query(sql, params as any[])).rows });
        await client.query("COMMIT");
        return out;
      } catch (e) {
        await client.query("ROLLBACK").catch(() => {});
        throw e;
      } finally {
        client.release();
      }
    },
    close: () => pool.end(),
  };
}

// One instance per server process (survives Next.js hot reloads in dev).
const g = globalThis as unknown as { __unifiDb?: Promise<Db> };

export function getDb(): Promise<Db> {
  if (!g.__unifiDb) {
    g.__unifiDb = (async () => {
      const db = process.env.DATABASE_URL
        ? await createPostgresDb(process.env.DATABASE_URL)
        : await createPgliteDb(process.env.PGLITE_DIR ?? ".data/pglite");
      const { seed, seedDemo } = await import("./seed");
      await seed(db);
      await seedDemo(db);
      return db;
    })();
    g.__unifiDb.catch(() => { g.__unifiDb = undefined; }); // don't cache a failed start
  }
  return g.__unifiDb;
}
