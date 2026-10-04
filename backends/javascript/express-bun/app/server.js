// Express app; one worker process per CPU the benchmark assigns (BENCH_CPUS),
// the usual way to run Node/Bun on more than one core in production.
const cluster = require('node:cluster');
const fs = require('node:fs');

const workers = parseInt(process.env.BENCH_CPUS || '1', 10);

if (cluster.isPrimary && workers > 1) {
  for (let i = 0; i < workers; i++) cluster.fork();
  cluster.on('exit', (worker, code) => {
    console.error(`worker ${worker.process.pid} exited with ${code}`);
    process.exit(1);
  });
} else {
  startWorker();
}

function startWorker() {
  const express = require('express');
  const { Pool } = require('pg');

  const pool = new Pool({
    user: process.env.DATABASE_USER || 'postgres',
    host: process.env.DATABASE_HOST || 'db',
    database: process.env.DATABASE_NAME || 'postgres',
    password: process.env.DATABASE_PASSWORD || 'postgres',
    port: parseInt(process.env.DATABASE_PORT || '5432', 10),
    max: Math.max(1, Math.floor(20 / workers)),
  });
  const migration = fs.readFileSync(`${__dirname}/migration.sql`).toString();

  const app = express();
  app.set('etag', false);
  app.set('x-powered-by', false);
  app.use(express.json());

  const intParam = (value, fallback) => {
    const n = parseInt(value, 10);
    return Number.isInteger(n) && n >= 0 ? n : fallback;
  };

  app.get('/health', async (req, res) => {
    try {
      await pool.query(migration);
      res.send('ok');
    } catch (err) {
      res.status(503).send(`not ready: ${err.message}`);
    }
  });

  app.get('/no_db_endpoint/', (req, res) => {
    res.json({ message: 'No db endpoint' });
  });

  app.get('/notes/', async (req, res) => {
    try {
      const result = await pool.query({
        name: 'list-notes',
        text: 'SELECT id, title, content FROM note ORDER BY id LIMIT $1 OFFSET $2',
        values: [intParam(req.query.limit, 20), intParam(req.query.offset, 0)],
      });
      res.json(result.rows);
    } catch (err) {
      res.status(500).send(err.message);
    }
  });

  app.get('/notes/:id', async (req, res) => {
    const id = parseInt(req.params.id, 10);
    if (!Number.isInteger(id)) return res.status(404).send('not found');
    try {
      const result = await pool.query({
        name: 'get-note',
        text: 'SELECT id, title, content FROM note WHERE id = $1',
        values: [id],
      });
      if (result.rows.length === 0) return res.status(404).send('not found');
      res.json(result.rows[0]);
    } catch (err) {
      res.status(500).send(err.message);
    }
  });

  app.post('/notes/', async (req, res) => {
    try {
      const { title, content } = req.body;
      const result = await pool.query({
        name: 'create-note',
        text: 'INSERT INTO note (title, content) VALUES ($1, $2) RETURNING id, title, content',
        values: [title, content],
      });
      res.status(201).json(result.rows[0]);
    } catch (err) {
      res.status(500).send(err.message);
    }
  });

  app.listen(8000, '0.0.0.0', () => console.log(`worker ${process.pid} listening on 8000`));
}
