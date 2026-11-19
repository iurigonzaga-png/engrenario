-- =====================================================================
-- Engrenário: estrutura do banco de dados PostgreSQL
-- =====================================================================
-- Este arquivo roda a cada inicialização do backend, então é idempotente:
--   * num banco vazio, cria tudo;
--   * num banco da versão anterior (gêneros em texto "A|B", plataforma e
--     status como texto livre), converte os dados para o modelo normalizado.
--
-- Entidades: status_jogo, generos, plataformas, jogos, sessoes,
--            historico_status (entidade fraca), configuracoes.
-- Relacionamentos N:N: jogo_generos, transicoes_status.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Tabelas de domínio
-- ---------------------------------------------------------------------

-- Situações possíveis de um jogo no acervo.
CREATE TABLE IF NOT EXISTS status_jogo (
  codigo    TEXT PRIMARY KEY,
  rotulo    TEXT NOT NULL UNIQUE,
  ordem     SMALLINT NOT NULL UNIQUE,
  -- Conta como backlog (ainda falta jogar)?
  pendente  BOOLEAN NOT NULL
);

INSERT INTO status_jogo (codigo, rotulo, ordem, pendente) VALUES
  ('desejo',     'Desejado',   1, FALSE),
  ('fila',       'Na fila',    2, TRUE),
  ('jogando',    'Jogando',    3, TRUE),
  ('zerado',     'Zerado',     4, FALSE),
  ('abandonado', 'Abandonado', 5, FALSE)
ON CONFLICT (codigo) DO NOTHING;

-- Máquina de estados: para quais status um jogo pode ir a partir de outro.
-- Autorrelacionamento N:N de status_jogo.
CREATE TABLE IF NOT EXISTS transicoes_status (
  origem   TEXT NOT NULL REFERENCES status_jogo (codigo),
  destino  TEXT NOT NULL REFERENCES status_jogo (codigo),
  acao     TEXT NOT NULL,
  PRIMARY KEY (origem, destino),
  CHECK (origem <> destino)
);

INSERT INTO transicoes_status (origem, destino, acao) VALUES
  ('desejo',     'fila',       'Já tenho: pôr na fila'),
  ('fila',       'jogando',    'Começar a jogar'),
  ('fila',       'abandonado', 'Abandonar'),
  ('fila',       'desejo',     'Mover para desejados'),
  ('jogando',    'zerado',     'Marcar como zerado'),
  ('jogando',    'fila',       'Pausar e devolver à fila'),
  ('jogando',    'abandonado', 'Abandonar'),
  ('zerado',     'jogando',    'Jogar de novo'),
  ('abandonado', 'fila',       'Devolver à fila')
ON CONFLICT (origem, destino) DO NOTHING;

CREATE TABLE IF NOT EXISTS generos (
  id    SERIAL PRIMARY KEY,
  nome  TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS plataformas (
  id    SERIAL PRIMARY KEY,
  nome  TEXT NOT NULL UNIQUE
);


-- ---------------------------------------------------------------------
-- 2. Tabelas principais
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS jogos (
  id               SERIAL PRIMARY KEY,
  rawg_id          INTEGER NOT NULL UNIQUE CHECK (rawg_id > 0),
  nome             TEXT NOT NULL,
  capa_url         TEXT,
  metacritic       INTEGER CHECK (metacritic BETWEEN 0 AND 100),
  lancamento       DATE,
  horas_api        INTEGER NOT NULL DEFAULT 0 CHECK (horas_api >= 0),
  -- Texto de apresentação da RAWG, guardado na primeira vez que é lido.
  -- NULL = ainda não buscado; '' = a RAWG não tem descrição.
  descricao        TEXT,
  status           TEXT NOT NULL REFERENCES status_jogo (codigo),
  horas_estimadas  DOUBLE PRECISION NOT NULL
                   CHECK (horas_estimadas BETWEEN 0.5 AND 2000),
  nota_pessoal     DOUBLE PRECISION
                   CHECK (nota_pessoal IS NULL OR nota_pessoal BETWEEN 0 AND 10),
  plataforma_id    INTEGER REFERENCES plataformas (id) ON DELETE SET NULL,
  anotacoes        TEXT,
  adicionado_em    TIMESTAMPTZ NOT NULL,
  concluido_em     TIMESTAMPTZ
);

-- Gêneros de cada jogo (N:N). "ordem" guarda o gênero principal (1).
CREATE TABLE IF NOT EXISTS jogo_generos (
  jogo_id    INTEGER NOT NULL REFERENCES jogos (id) ON DELETE CASCADE,
  genero_id  INTEGER NOT NULL REFERENCES generos (id),
  ordem      SMALLINT NOT NULL CHECK (ordem >= 1),
  PRIMARY KEY (jogo_id, genero_id),
  UNIQUE (jogo_id, ordem)
);

CREATE TABLE IF NOT EXISTS sessoes (
  id          SERIAL PRIMARY KEY,
  jogo_id     INTEGER NOT NULL REFERENCES jogos (id) ON DELETE CASCADE,
  data        TIMESTAMPTZ NOT NULL,
  minutos     INTEGER NOT NULL CHECK (minutos BETWEEN 5 AND 960),
  comentario  TEXT
);

-- Entidade fraca: um registro de histórico só existe e só é identificado
-- dentro do seu jogo. A chave é (jogo_id, sequencia) e ele some junto
-- com o jogo. É preenchido pelo trigger trg_jogos_historico.
CREATE TABLE IF NOT EXISTS historico_status (
  jogo_id      INTEGER NOT NULL REFERENCES jogos (id) ON DELETE CASCADE,
  sequencia    SMALLINT NOT NULL CHECK (sequencia >= 1),
  status       TEXT NOT NULL REFERENCES status_jogo (codigo),
  alterado_em  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (jogo_id, sequencia)
);

CREATE TABLE IF NOT EXISTS configuracoes (
  chave  TEXT PRIMARY KEY,
  valor  TEXT NOT NULL
);


-- ---------------------------------------------------------------------
-- 3. Migração da versão anterior (só age se achar colunas antigas)
-- ---------------------------------------------------------------------

DO $$
BEGIN
  -- Coluna adicionada numa versão intermediária.
  ALTER TABLE jogos ADD COLUMN IF NOT EXISTS descricao TEXT;

  -- Gêneros: texto "Action|RPG" vira linhas em generos + jogo_generos.
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_name = 'jogos' AND column_name = 'generos') THEN
    INSERT INTO generos (nome)
    SELECT DISTINCT trim(g.nome)
      FROM jogos j,
           unnest(string_to_array(j.generos, '|')) AS g (nome)
     WHERE trim(g.nome) <> ''
    ON CONFLICT (nome) DO NOTHING;

    INSERT INTO jogo_generos (jogo_id, genero_id, ordem)
    SELECT j.id, ge.id, g.ordem
      FROM jogos j,
           unnest(string_to_array(j.generos, '|')) WITH ORDINALITY AS g (nome, ordem)
      JOIN generos ge ON ge.nome = trim(g.nome)
     WHERE trim(g.nome) <> ''
    ON CONFLICT DO NOTHING;

    ALTER TABLE jogos DROP COLUMN generos;
  END IF;

  -- Plataforma: texto livre vira referência a plataformas.
  IF EXISTS (SELECT 1 FROM information_schema.columns
              WHERE table_name = 'jogos' AND column_name = 'plataforma') THEN
    ALTER TABLE jogos ADD COLUMN IF NOT EXISTS plataforma_id INTEGER
      REFERENCES plataformas (id) ON DELETE SET NULL;

    INSERT INTO plataformas (nome)
    SELECT DISTINCT trim(plataforma)
      FROM jogos
     WHERE coalesce(trim(plataforma), '') <> ''
    ON CONFLICT (nome) DO NOTHING;

    UPDATE jogos j
       SET plataforma_id = p.id
      FROM plataformas p
     WHERE p.nome = trim(j.plataforma);

    ALTER TABLE jogos DROP COLUMN plataforma;
  END IF;

  -- Status: CHECK com lista fixa vira chave estrangeira para status_jogo.
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
                  WHERE conrelid = 'jogos'::regclass
                    AND contype = 'f'
                    AND conname = 'jogos_status_fkey') THEN
    ALTER TABLE jogos DROP CONSTRAINT IF EXISTS jogos_status_check;
    ALTER TABLE jogos ADD CONSTRAINT jogos_status_fkey
      FOREIGN KEY (status) REFERENCES status_jogo (codigo);
  END IF;

  -- Jogos que já existiam ganham o registro inicial do histórico.
  INSERT INTO historico_status (jogo_id, sequencia, status, alterado_em)
  SELECT j.id, 1, j.status, j.adicionado_em
    FROM jogos j
   WHERE NOT EXISTS (SELECT 1 FROM historico_status h WHERE h.jogo_id = j.id);
END $$;


-- ---------------------------------------------------------------------
-- 4. Functions
-- ---------------------------------------------------------------------

-- Total de minutos jogados (todos os jogos) num dia do calendário.
CREATE OR REPLACE FUNCTION fn_minutos_no_dia(p_dia DATE)
RETURNS INTEGER
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(SUM(minutos), 0)::integer
    FROM sessoes
   WHERE data::date = p_dia;
$$;

-- Horas que ainda faltam para terminar um jogo. Só jogos pendentes
-- (fila ou jogando) têm horas restantes; o resto devolve 0.
CREATE OR REPLACE FUNCTION fn_horas_restantes(p_jogo_id INTEGER)
RETURNS NUMERIC
LANGUAGE sql
STABLE
AS $$
  SELECT CASE
           WHEN st.pendente THEN
             round(GREATEST(
               j.horas_estimadas
               - COALESCE((SELECT SUM(s.minutos) FROM sessoes s
                            WHERE s.jogo_id = j.id), 0) / 60.0,
               0)::numeric, 1)
           ELSE 0
         END
    FROM jogos j
    JOIN status_jogo st ON st.codigo = j.status
   WHERE j.id = p_jogo_id;
$$;


-- ---------------------------------------------------------------------
-- 5. Triggers
-- ---------------------------------------------------------------------

-- 5.1 Só deixa o status mudar por uma transição cadastrada.
CREATE OR REPLACE FUNCTION fn_validar_transicao_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM transicoes_status
                  WHERE origem = OLD.status AND destino = NEW.status) THEN
    RAISE EXCEPTION 'Um jogo "%" não pode ir direto para "%".',
      (SELECT rotulo FROM status_jogo WHERE codigo = OLD.status),
      (SELECT rotulo FROM status_jogo WHERE codigo = NEW.status);
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_jogos_valida_transicao
  BEFORE UPDATE OF status ON jogos
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION fn_validar_transicao_status();

-- 5.2 Registra no histórico a entrada do jogo e cada mudança de status.
CREATE OR REPLACE FUNCTION fn_registrar_historico_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO historico_status (jogo_id, sequencia, status, alterado_em)
  VALUES (
    NEW.id,
    COALESCE((SELECT MAX(sequencia) FROM historico_status
               WHERE jogo_id = NEW.id), 0) + 1,
    NEW.status,
    CASE WHEN TG_OP = 'INSERT' THEN NEW.adicionado_em ELSE now() END
  );
  RETURN NULL;
END;
$$;

CREATE OR REPLACE TRIGGER trg_jogos_historico_insert
  AFTER INSERT ON jogos
  FOR EACH ROW
  EXECUTE FUNCTION fn_registrar_historico_status();

CREATE OR REPLACE TRIGGER trg_jogos_historico_update
  AFTER UPDATE OF status ON jogos
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION fn_registrar_historico_status();

-- 5.3 Regras de uma sessão de jogo: o jogo precisa estar sendo jogado,
-- a data não pode ser futura nem anterior à entrada no acervo, e a soma
-- do dia (todos os jogos) não pode passar de 24 horas.
CREATE OR REPLACE FUNCTION fn_validar_sessao()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_status      TEXT;
  v_adicionado  TIMESTAMPTZ;
  v_ja_no_dia   INTEGER;
BEGIN
  SELECT status, adicionado_em INTO v_status, v_adicionado
    FROM jogos WHERE id = NEW.jogo_id;

  IF v_status IS DISTINCT FROM 'jogando' THEN
    RAISE EXCEPTION 'Só dá para registrar sessão de um jogo que está sendo jogado.';
  END IF;
  IF NEW.data > now() + interval '5 minutes' THEN
    RAISE EXCEPTION 'A sessão não pode ser no futuro.';
  END IF;
  IF NEW.data::date < v_adicionado::date THEN
    RAISE EXCEPTION 'O jogo só entrou no acervo em %.',
      to_char(v_adicionado, 'DD/MM/YYYY');
  END IF;

  v_ja_no_dia := fn_minutos_no_dia(NEW.data::date);
  IF TG_OP = 'UPDATE' AND OLD.data::date = NEW.data::date THEN
    v_ja_no_dia := v_ja_no_dia - OLD.minutos;
  END IF;
  IF v_ja_no_dia + NEW.minutos > 24 * 60 THEN
    RAISE EXCEPTION 'Esse dia já tem % min registrados; com mais % passaria de 24 horas.',
      v_ja_no_dia, NEW.minutos;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_sessoes_validar
  BEFORE INSERT OR UPDATE ON sessoes
  FOR EACH ROW
  EXECUTE FUNCTION fn_validar_sessao();


-- ---------------------------------------------------------------------
-- 6. Views
-- ---------------------------------------------------------------------

-- Jogo completo, no formato que o app consome (gêneros juntados de novo
-- em "A|B", nome da plataforma e totais das sessões).
DROP VIEW IF EXISTS vw_jogos_acervo;
CREATE VIEW vw_jogos_acervo AS
SELECT j.id,
       j.rawg_id,
       j.nome,
       j.capa_url,
       COALESCE(g.generos, '') AS generos,
       j.metacritic,
       j.lancamento,
       j.horas_api,
       j.horas_estimadas,
       j.status,
       j.nota_pessoal,
       p.nome AS plataforma,
       j.anotacoes,
       j.adicionado_em,
       j.concluido_em,
       j.descricao,
       COALESCE(s.minutos, 0)::integer AS minutos_jogados,
       s.ultima_sessao
  FROM jogos j
  LEFT JOIN plataformas p ON p.id = j.plataforma_id
  LEFT JOIN LATERAL (
         SELECT string_agg(ge.nome, '|' ORDER BY jg.ordem) AS generos
           FROM jogo_generos jg
           JOIN generos ge ON ge.id = jg.genero_id
          WHERE jg.jogo_id = j.id
       ) g ON TRUE
  LEFT JOIN LATERAL (
         SELECT SUM(se.minutos) AS minutos, MAX(se.data) AS ultima_sessao
           FROM sessoes se
          WHERE se.jogo_id = j.id
       ) s ON TRUE;

-- Números por gênero: quantos jogos, quantos zerados e abandonados,
-- horas jogadas, nota pessoal média e nota média da crítica.
DROP VIEW IF EXISTS vw_estatisticas_genero;
CREATE VIEW vw_estatisticas_genero AS
SELECT ge.id   AS genero_id,
       ge.nome AS genero,
       COUNT(DISTINCT j.id)                                      AS jogos,
       COUNT(DISTINCT j.id) FILTER (WHERE j.status = 'zerado')     AS zerados,
       COUNT(DISTINCT j.id) FILTER (WHERE j.status = 'abandonado') AS abandonados,
       round(COALESCE(SUM(t.minutos), 0) / 60.0, 1)              AS horas_jogadas,
       round(AVG(j.nota_pessoal)::numeric, 1)                    AS nota_pessoal_media,
       round(AVG(j.metacritic), 1)                               AS metacritic_medio
  FROM generos ge
  JOIN jogo_generos jg ON jg.genero_id = ge.id
  JOIN jogos j         ON j.id = jg.jogo_id
  LEFT JOIN LATERAL (
         SELECT SUM(s.minutos) AS minutos FROM sessoes s WHERE s.jogo_id = j.id
       ) t ON TRUE
 GROUP BY ge.id, ge.nome;

-- Tempo de jogo por plataforma.
DROP VIEW IF EXISTS vw_tempo_por_plataforma;
CREATE VIEW vw_tempo_por_plataforma AS
SELECT p.id   AS plataforma_id,
       p.nome AS plataforma,
       COUNT(DISTINCT j.id)                       AS jogos,
       COUNT(s.id)                                AS sessoes,
       round(COALESCE(SUM(s.minutos), 0) / 60.0, 1) AS horas_jogadas,
       round(AVG(s.minutos), 0)                   AS minutos_por_sessao
  FROM plataformas p
  JOIN jogos j        ON j.plataforma_id = p.id
  LEFT JOIN sessoes s ON s.jogo_id = j.id
 GROUP BY p.id, p.nome;


-- ---------------------------------------------------------------------
-- 7. Índices
-- ---------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_jogos_status       ON jogos (status);
CREATE INDEX IF NOT EXISTS idx_jogos_plataforma   ON jogos (plataforma_id);
CREATE INDEX IF NOT EXISTS idx_jogo_generos_gen   ON jogo_generos (genero_id);
CREATE INDEX IF NOT EXISTS idx_sessoes_jogo       ON sessoes (jogo_id);
CREATE INDEX IF NOT EXISTS idx_sessoes_data       ON sessoes (data);
