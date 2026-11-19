import 'dotenv/config';
import express, {
  type ErrorRequestHandler,
  type NextFunction,
  type Request,
  type RequestHandler,
  type Response,
} from 'express';
import type { PoolClient } from 'pg';
import { initializeDatabase, pool } from './db.js';

type GameStatus = 'desejo' | 'fila' | 'jogando' | 'zerado' | 'abandonado';

class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

const app = express();
const allowedOrigins = (process.env.CORS_ORIGINS ?? '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use((req, res, next) => {
  const origin = req.header('origin');
  const localOrigin =
    origin === 'null' ||
    (origin !== undefined &&
      /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin));

  if (!origin || localOrigin || allowedOrigins.includes(origin)) {
    if (origin) res.header('Access-Control-Allow-Origin', origin);
    res.header('Vary', 'Origin');
    res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type');
  }

  if (req.method === 'OPTIONS') {
    res.sendStatus(204);
    return;
  }
  next();
});
app.use(express.json({ limit: '1mb' }));

const asyncRoute =
  (handler: (req: Request, res: Response) => Promise<void>): RequestHandler =>
  (req, res, next: NextFunction) => {
    void handler(req, res).catch(next);
  };

function bodyObject(req: Request): Record<string, unknown> {
  if (req.body === null || typeof req.body !== 'object' || Array.isArray(req.body)) {
    throw new HttpError(400, 'O corpo da requisição deve ser um objeto JSON.');
  }
  return req.body as Record<string, unknown>;
}

function requiredString(
  body: Record<string, unknown>,
  key: string,
): string {
  const value = body[key];
  if (typeof value !== 'string' || value.trim() === '') {
    throw new HttpError(400, `O campo "${key}" é obrigatório.`);
  }
  return value.trim();
}

function optionalString(
  body: Record<string, unknown>,
  key: string,
): string | null {
  const value = body[key];
  if (value == null) return null;
  if (typeof value !== 'string') {
    throw new HttpError(400, `O campo "${key}" deve ser texto.`);
  }
  return value;
}

function requiredNumber(
  body: Record<string, unknown>,
  key: string,
): number {
  const value = body[key];
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new HttpError(400, `O campo "${key}" deve ser numérico.`);
  }
  return value;
}

function optionalNumber(
  body: Record<string, unknown>,
  key: string,
): number | null {
  const value = body[key];
  if (value == null) return null;
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new HttpError(400, `O campo "${key}" deve ser numérico.`);
  }
  return value;
}

function isoDate(
  body: Record<string, unknown>,
  key: string,
  optional = false,
): string | null {
  const value = body[key];
  if (value == null && optional) return null;
  if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) {
    throw new HttpError(400, `O campo "${key}" deve conter uma data válida.`);
  }
  return value;
}

function parseId(value: unknown, field = 'id'): number {
  if (typeof value !== 'string') {
    throw new HttpError(400, `O campo "${field}" deve ser um inteiro positivo.`);
  }
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id < 1) {
    throw new HttpError(400, `O campo "${field}" deve ser um inteiro positivo.`);
  }
  return id;
}

function gameValues(req: Request) {
  const body = bodyObject(req);
  const status = requiredString(body, 'status') as GameStatus;
  if (!['desejo', 'fila', 'jogando', 'zerado', 'abandonado'].includes(status)) {
    throw new HttpError(400, 'Status de jogo inválido.');
  }

  const horasEstimadas = requiredNumber(body, 'horas_estimadas');
  if (horasEstimadas < 0.5 || horasEstimadas > 2000) {
    throw new HttpError(400, 'A duração estimada deve ficar entre 0,5 e 2000 horas.');
  }

  const notaPessoal = optionalNumber(body, 'nota_pessoal');
  const metacritic = optionalNumber(body, 'metacritic');
  if (notaPessoal !== null && (notaPessoal < 0 || notaPessoal > 10)) {
    throw new HttpError(400, 'A nota deve ficar entre 0 e 10.');
  }

  if (body.generos != null && typeof body.generos !== 'string') {
    throw new HttpError(400, 'O campo "generos" deve ser texto.');
  }
  if (metacritic !== null && (metacritic < 0 || metacritic > 100)) {
    throw new HttpError(400, 'A nota Metacritic deve ficar entre 0 e 100.');
  }

  const rawgId = requiredNumber(body, 'rawg_id');
  const horasApi = requiredNumber(body, 'horas_api');
  if (!Number.isSafeInteger(rawgId) || rawgId < 1) {
    throw new HttpError(400, 'O id da RAWG deve ser um inteiro positivo.');
  }
  if (!Number.isSafeInteger(horasApi) || horasApi < 0) {
    throw new HttpError(400, 'A duração da RAWG deve ser um inteiro não negativo.');
  }
  if (metacritic !== null && !Number.isSafeInteger(metacritic)) {
    throw new HttpError(400, 'A nota Metacritic deve ser um número inteiro.');
  }

  return {
    rawgId,
    nome: requiredString(body, 'nome'),
    capaUrl: optionalString(body, 'capa_url'),
    generos: typeof body.generos === 'string' ? body.generos : '',
    metacritic,
    lancamento: isoDate(body, 'lancamento', true),
    horasApi,
    horasEstimadas,
    status,
    notaPessoal,
    plataforma: optionalString(body, 'plataforma'),
    anotacoes: optionalString(body, 'anotacoes'),
    adicionadoEm: isoDate(body, 'adicionado_em')!,
    concluidoEm: isoDate(body, 'concluido_em', true),
  };
}

/** Roda [fn] numa transação: tudo ou nada. */
async function transacao<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const resultado = await fn(client);
    await client.query('COMMIT');
    return resultado;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/** Devolve o id da plataforma pelo nome, cadastrando se for nova. */
async function idDaPlataforma(
  client: PoolClient,
  nome: string | null,
): Promise<number | null> {
  const limpo = nome?.trim();
  if (!limpo) return null;
  const { rows } = await client.query(
    `INSERT INTO plataformas (nome) VALUES ($1)
     ON CONFLICT (nome) DO UPDATE SET nome = EXCLUDED.nome
     RETURNING id`,
    [limpo],
  );
  return rows[0].id as number;
}

/** Troca os gêneros do jogo. O app manda "A|B"; o primeiro é o principal. */
async function gravarGeneros(
  client: PoolClient,
  jogoId: number,
  generos: string,
): Promise<void> {
  const nomes = [
    ...new Set(generos.split('|').map((g) => g.trim()).filter(Boolean)),
  ];
  await client.query('DELETE FROM jogo_generos WHERE jogo_id = $1', [jogoId]);
  for (const [i, nome] of nomes.entries()) {
    const { rows } = await client.query(
      `INSERT INTO generos (nome) VALUES ($1)
       ON CONFLICT (nome) DO UPDATE SET nome = EXCLUDED.nome
       RETURNING id`,
      [nome],
    );
    await client.query(
      'INSERT INTO jogo_generos (jogo_id, genero_id, ordem) VALUES ($1, $2, $3)',
      [jogoId, rows[0].id, i + 1],
    );
  }
}

function queryDate(value: unknown, name: string): string {
  if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) {
    throw new HttpError(400, `O parâmetro "${name}" deve ser uma data válida.`);
  }
  return value;
}

app.get(
  '/api/health',
  asyncRoute(async (_req, res) => {
    await pool.query('SELECT 1');
    res.json({ status: 'ok' });
  }),
);

app.get(
  '/api/jogos',
  asyncRoute(async (_req, res) => {
    const { rows } = await pool.query(
      'SELECT * FROM vw_jogos_acervo ORDER BY adicionado_em DESC',
    );
    res.json(rows);
  }),
);

app.get(
  '/api/jogos/rawg/:rawgId/exists',
  asyncRoute(async (req, res) => {
    const rawgId = parseId(req.params.rawgId, 'rawgId');
    const { rowCount } = await pool.query(
      'SELECT 1 FROM jogos WHERE rawg_id = $1 LIMIT 1',
      [rawgId],
    );
    res.json({ exists: (rowCount ?? 0) > 0 });
  }),
);

app.get(
  '/api/jogos/:id/sessoes',
  asyncRoute(async (req, res) => {
    const jogoId = parseId(req.params.id);
    const { rows } = await pool.query(
      'SELECT * FROM sessoes WHERE jogo_id = $1 ORDER BY data DESC, id DESC',
      [jogoId],
    );
    res.json(rows);
  }),
);

app.get(
  '/api/jogos/:id',
  asyncRoute(async (req, res) => {
    const id = parseId(req.params.id);
    const { rows } = await pool.query(
      'SELECT * FROM vw_jogos_acervo WHERE id = $1',
      [id],
    );
    if (rows.length === 0) throw new HttpError(404, 'Jogo não encontrado.');
    res.json(rows[0]);
  }),
);

app.post(
  '/api/jogos',
  asyncRoute(async (req, res) => {
    const game = gameValues(req);
    const id = await transacao(async (client) => {
      const plataformaId = await idDaPlataforma(client, game.plataforma);
      const { rows } = await client.query(
        `INSERT INTO jogos (
           rawg_id, nome, capa_url, metacritic, lancamento, horas_api,
           horas_estimadas, status, nota_pessoal, plataforma_id, anotacoes,
           adicionado_em, concluido_em
         ) VALUES (
           $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
         )
         RETURNING id`,
        [
          game.rawgId,
          game.nome,
          game.capaUrl,
          game.metacritic,
          game.lancamento,
          game.horasApi,
          game.horasEstimadas,
          game.status,
          game.notaPessoal,
          plataformaId,
          game.anotacoes,
          game.adicionadoEm,
          game.concluidoEm,
        ],
      );
      const novoId = rows[0].id as number;
      await gravarGeneros(client, novoId, game.generos);
      return novoId;
    });
    res.status(201).json({ id });
  }),
);

app.put(
  '/api/jogos/:id',
  asyncRoute(async (req, res) => {
    const id = parseId(req.params.id);
    const game = gameValues(req);
    await transacao(async (client) => {
      const plataformaId = await idDaPlataforma(client, game.plataforma);
      const result = await client.query(
        `UPDATE jogos
            SET rawg_id = $1, nome = $2, capa_url = $3, metacritic = $4,
                lancamento = $5, horas_api = $6, horas_estimadas = $7,
                status = $8, nota_pessoal = $9, plataforma_id = $10,
                anotacoes = $11, adicionado_em = $12, concluido_em = $13
          WHERE id = $14`,
        [
          game.rawgId,
          game.nome,
          game.capaUrl,
          game.metacritic,
          game.lancamento,
          game.horasApi,
          game.horasEstimadas,
          game.status,
          game.notaPessoal,
          plataformaId,
          game.anotacoes,
          game.adicionadoEm,
          game.concluidoEm,
          id,
        ],
      );
      if (result.rowCount === 0) throw new HttpError(404, 'Jogo não encontrado.');
      await gravarGeneros(client, id, game.generos);
    });
    res.sendStatus(204);
  }),
);

// Guarda a descrição vinda da RAWG, para não consultá-la de novo.
app.put(
  '/api/jogos/:id/descricao',
  asyncRoute(async (req, res) => {
    const id = parseId(req.params.id);
    const body = bodyObject(req);
    if (typeof body.descricao !== 'string') {
      throw new HttpError(400, 'O campo "descricao" deve ser texto.');
    }
    const result = await pool.query(
      'UPDATE jogos SET descricao = $1 WHERE id = $2',
      [body.descricao, id],
    );
    if (result.rowCount === 0) throw new HttpError(404, 'Jogo não encontrado.');
    res.sendStatus(204);
  }),
);

app.delete(
  '/api/jogos/:id',
  asyncRoute(async (req, res) => {
    const id = parseId(req.params.id);
    const result = await pool.query('DELETE FROM jogos WHERE id = $1', [id]);
    if (result.rowCount === 0) throw new HttpError(404, 'Jogo não encontrado.');
    res.sendStatus(204);
  }),
);

app.get(
  '/api/sessoes',
  asyncRoute(async (_req, res) => {
    const { rows } = await pool.query(
      'SELECT * FROM sessoes ORDER BY data DESC, id DESC',
    );
    res.json(rows);
  }),
);

app.get(
  '/api/sessoes/minutos-no-dia',
  asyncRoute(async (req, res) => {
    const dia = queryDate(req.query.dia, 'dia');
    const { rows } = await pool.query(
      'SELECT fn_minutos_no_dia($1::date) AS total',
      [dia],
    );
    res.json({ total: rows[0].total });
  }),
);

app.get(
  '/api/sessoes/minutos-por-jogo',
  asyncRoute(async (req, res) => {
    const desde = queryDate(req.query.desde, 'desde');
    const { rows } = await pool.query(
      `SELECT jogo_id, SUM(minutos)::integer AS total
         FROM sessoes
        WHERE data >= $1::timestamptz
        GROUP BY jogo_id`,
      [desde],
    );
    res.json(rows);
  }),
);

app.get(
  '/api/sessoes/:id',
  asyncRoute(async (req, res) => {
    const id = parseId(req.params.id);
    const { rows } = await pool.query(
      'SELECT * FROM sessoes WHERE id = $1',
      [id],
    );
    if (rows.length === 0) throw new HttpError(404, 'Sessão não encontrada.');
    res.json(rows[0]);
  }),
);

app.post(
  '/api/sessoes',
  asyncRoute(async (req, res) => {
    const body = bodyObject(req);
    const jogoId = requiredNumber(body, 'jogo_id');
    const minutos = requiredNumber(body, 'minutos');
    const data = isoDate(body, 'data')!;
    if (!Number.isSafeInteger(jogoId) || jogoId < 1) {
      throw new HttpError(400, 'O jogo da sessão é inválido.');
    }
    if (!Number.isSafeInteger(minutos) || minutos < 5 || minutos > 960) {
      throw new HttpError(400, 'Uma sessão dura de 5 minutos a 16 horas.');
    }
    if (Date.parse(data) > Date.now()) {
      throw new HttpError(400, 'A sessão não pode ser no futuro.');
    }

    const { rows } = await pool.query(
      `INSERT INTO sessoes (jogo_id, data, minutos, comentario)
       VALUES ($1, $2, $3, $4)
       RETURNING id`,
      [jogoId, data, minutos, optionalString(body, 'comentario')],
    );
    res.status(201).json({ id: rows[0].id });
  }),
);

app.delete(
  '/api/sessoes/:id',
  asyncRoute(async (req, res) => {
    const id = parseId(req.params.id);
    const result = await pool.query('DELETE FROM sessoes WHERE id = $1', [id]);
    if (result.rowCount === 0) throw new HttpError(404, 'Sessão não encontrada.');
    res.sendStatus(204);
  }),
);

app.get(
  '/api/configuracoes/:chave',
  asyncRoute(async (req, res) => {
    const chave = req.params.chave;
    if (typeof chave !== 'string') {
      throw new HttpError(400, 'A chave da configuração é inválida.');
    }
    const { rows } = await pool.query(
      'SELECT valor FROM configuracoes WHERE chave = $1',
      [chave],
    );
    res.json({ valor: rows[0]?.valor ?? null });
  }),
);

app.put(
  '/api/configuracoes/:chave',
  asyncRoute(async (req, res) => {
    const chave = req.params.chave;
    if (typeof chave !== 'string') {
      throw new HttpError(400, 'A chave da configuração é inválida.');
    }
    const valor = requiredString(bodyObject(req), 'valor');
    await pool.query(
      `INSERT INTO configuracoes (chave, valor) VALUES ($1, $2)
       ON CONFLICT (chave) DO UPDATE SET valor = EXCLUDED.valor`,
      [chave, valor],
    );
    res.sendStatus(204);
  }),
);

app.use((_req, _res, next) => next(new HttpError(404, 'Rota não encontrada.')));

const errorHandler: ErrorRequestHandler = (error, _req, res, _next) => {
  if (error instanceof HttpError) {
    res.status(error.status).json({ error: error.message });
    return;
  }
  if (typeof error === 'object' && error !== null && 'code' in error) {
    const code = (error as { code?: string }).code;
    if (code === '23505') {
      res.status(409).json({ error: 'Este jogo já está no acervo.' });
      return;
    }
    // Regra de negócio recusada por um trigger (RAISE EXCEPTION).
    if (code === 'P0001') {
      res.status(400).json({ error: (error as Error).message });
      return;
    }
    if (code === '23503') {
      res.status(404).json({ error: 'O jogo associado não foi encontrado.' });
      return;
    }
    console.error('Falha na consulta ao PostgreSQL:', error);
    res.status(500).json({ error: 'Falha ao acessar o banco de dados.' });
    return;
  }
  console.error('Falha não tratada na API:', error);
  res.status(500).json({ error: 'Erro interno na API.' });
};
app.use(errorHandler);

const port = Number(process.env.PORT ?? 3000);
const host = process.env.HOST ?? '127.0.0.1';

try {
  await initializeDatabase();
  app.listen(port, host, () => {
    console.log(`API Engrenário em http://${host}:${port}/api`);
  });
} catch (error) {
  console.error(
    'Não foi possível iniciar a API. Confira se o PostgreSQL está ativo e se DATABASE_URL está correto.',
    error,
  );
  await pool.end();
  process.exitCode = 1;
}

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => {
    void pool.end().then(() => process.exit(0));
  });
}
