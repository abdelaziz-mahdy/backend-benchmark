const express = require('express');
const { Pool } = require('pg');
const fs = require('fs');
const app = express();
app.use(express.json());

const pool = new Pool({
  user: process.env.DATABASE_USER,
  host: process.env.DATABASE_HOST,
  database: process.env.DATABASE_NAME,
  password: process.env.DATABASE_PASSWORD,
  port: process.env.DATABASE_PORT,
});

const runMigration = async () => {
    try {
      const migrationScript = fs.readFileSync('./migration.sql').toString();
      await pool.query(migrationScript);
      serverReady = true;  // Set the server as ready after successful migration
    } catch (err) {
      console.error('Failed to run migration:', err);
      serverReady = false;
    }
  };
  
app.get('/', (req, res) => {
    if (serverReady) {
      res.status(200).send('Server is ready');
    } else {
      res.status(500).send('Server is not ready');
    }
  });

app.get('/no_db_endpoint', async (req, res) => {
  res.status(200).send('No db endpoint');
});
app.get('/no_db_endpoint2', async (req, res) => {
  res.status(200).send('No db endpoint2');
});
app.get('/notes', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM note ORDER BY id DESC LIMIT 100');
    res.json(result.rows);
  } catch (err) {
    res.status(500).send('Error fetching notes');
  }
});

app.post('/notes', async (req, res) => {
  try {
    const { title, content } = req.body;
    await pool.query('INSERT INTO note (title, content) VALUES ($1, $2)', [title, content]);
    res.status(201).send('Note created');
  } catch (err) {
    res.status(500).send('Error creating note');
  }
});

const startServer = async () => {
  await runMigration();
  app.listen(8000, () => console.log('Server running on port 8000'));
};

startServer();
