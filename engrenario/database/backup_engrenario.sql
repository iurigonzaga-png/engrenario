--
-- PostgreSQL database dump
--

\restrict AKnegQ96jsOgZzi23KgO6jg9PQGgkK319BmfDx3EYChqPTfkrqC327BeCDmIdlj

-- Dumped from database version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: fn_horas_restantes(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_horas_restantes(p_jogo_id integer) RETURNS numeric
    LANGUAGE sql STABLE
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


--
-- Name: fn_minutos_no_dia(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_minutos_no_dia(p_dia date) RETURNS integer
    LANGUAGE sql STABLE
    AS $$
  SELECT COALESCE(SUM(minutos), 0)::integer
    FROM sessoes
   WHERE data::date = p_dia;
$$;


--
-- Name: fn_registrar_historico_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_registrar_historico_status() RETURNS trigger
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


--
-- Name: fn_validar_sessao(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_validar_sessao() RETURNS trigger
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


--
-- Name: fn_validar_transicao_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_validar_transicao_status() RETURNS trigger
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: configuracoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.configuracoes (
    chave text NOT NULL,
    valor text NOT NULL
);


--
-- Name: generos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.generos (
    id integer NOT NULL,
    nome text NOT NULL
);


--
-- Name: generos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.generos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: generos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.generos_id_seq OWNED BY public.generos.id;


--
-- Name: historico_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.historico_status (
    jogo_id integer NOT NULL,
    sequencia smallint NOT NULL,
    status text NOT NULL,
    alterado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT historico_status_sequencia_check CHECK ((sequencia >= 1))
);


--
-- Name: jogo_generos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jogo_generos (
    jogo_id integer NOT NULL,
    genero_id integer NOT NULL,
    ordem smallint NOT NULL,
    CONSTRAINT jogo_generos_ordem_check CHECK ((ordem >= 1))
);


--
-- Name: jogos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jogos (
    id integer NOT NULL,
    rawg_id integer NOT NULL,
    nome text NOT NULL,
    capa_url text,
    metacritic integer,
    lancamento date,
    horas_api integer DEFAULT 0 NOT NULL,
    horas_estimadas double precision NOT NULL,
    status text NOT NULL,
    nota_pessoal double precision,
    anotacoes text,
    adicionado_em timestamp with time zone NOT NULL,
    concluido_em timestamp with time zone,
    descricao text,
    plataforma_id integer,
    CONSTRAINT jogos_horas_api_check CHECK ((horas_api >= 0)),
    CONSTRAINT jogos_horas_estimadas_check CHECK (((horas_estimadas >= (0.5)::double precision) AND (horas_estimadas <= (2000)::double precision))),
    CONSTRAINT jogos_nota_pessoal_check CHECK (((nota_pessoal IS NULL) OR ((nota_pessoal >= (0)::double precision) AND (nota_pessoal <= (10)::double precision))))
);


--
-- Name: jogos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jogos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jogos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jogos_id_seq OWNED BY public.jogos.id;


--
-- Name: plataformas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plataformas (
    id integer NOT NULL,
    nome text NOT NULL
);


--
-- Name: plataformas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plataformas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plataformas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plataformas_id_seq OWNED BY public.plataformas.id;


--
-- Name: sessoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessoes (
    id integer NOT NULL,
    jogo_id integer NOT NULL,
    data timestamp with time zone NOT NULL,
    minutos integer NOT NULL,
    comentario text,
    CONSTRAINT sessoes_minutos_check CHECK (((minutos >= 5) AND (minutos <= 960)))
);


--
-- Name: sessoes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessoes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessoes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessoes_id_seq OWNED BY public.sessoes.id;


--
-- Name: status_jogo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.status_jogo (
    codigo text NOT NULL,
    rotulo text NOT NULL,
    ordem smallint NOT NULL,
    pendente boolean NOT NULL
);


--
-- Name: transicoes_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.transicoes_status (
    origem text NOT NULL,
    destino text NOT NULL,
    acao text NOT NULL,
    CONSTRAINT transicoes_status_check CHECK ((origem <> destino))
);


--
-- Name: vw_estatisticas_genero; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_estatisticas_genero AS
 SELECT ge.id AS genero_id,
    ge.nome AS genero,
    count(DISTINCT j.id) AS jogos,
    count(DISTINCT j.id) FILTER (WHERE (j.status = 'zerado'::text)) AS zerados,
    count(DISTINCT j.id) FILTER (WHERE (j.status = 'abandonado'::text)) AS abandonados,
    round((COALESCE(sum(t.minutos), (0)::numeric) / 60.0), 1) AS horas_jogadas,
    round((avg(j.nota_pessoal))::numeric, 1) AS nota_pessoal_media,
    round(avg(j.metacritic), 1) AS metacritic_medio
   FROM (((public.generos ge
     JOIN public.jogo_generos jg ON ((jg.genero_id = ge.id)))
     JOIN public.jogos j ON ((j.id = jg.jogo_id)))
     LEFT JOIN LATERAL ( SELECT sum(s.minutos) AS minutos
           FROM public.sessoes s
          WHERE (s.jogo_id = j.id)) t ON (true))
  GROUP BY ge.id, ge.nome;


--
-- Name: vw_jogos_acervo; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_jogos_acervo AS
 SELECT j.id,
    j.rawg_id,
    j.nome,
    j.capa_url,
    COALESCE(g.generos, ''::text) AS generos,
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
    (COALESCE(s.minutos, (0)::bigint))::integer AS minutos_jogados,
    s.ultima_sessao
   FROM (((public.jogos j
     LEFT JOIN public.plataformas p ON ((p.id = j.plataforma_id)))
     LEFT JOIN LATERAL ( SELECT string_agg(ge.nome, '|'::text ORDER BY jg.ordem) AS generos
           FROM (public.jogo_generos jg
             JOIN public.generos ge ON ((ge.id = jg.genero_id)))
          WHERE (jg.jogo_id = j.id)) g ON (true))
     LEFT JOIN LATERAL ( SELECT sum(se.minutos) AS minutos,
            max(se.data) AS ultima_sessao
           FROM public.sessoes se
          WHERE (se.jogo_id = j.id)) s ON (true));


--
-- Name: vw_tempo_por_plataforma; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_tempo_por_plataforma AS
 SELECT p.id AS plataforma_id,
    p.nome AS plataforma,
    count(DISTINCT j.id) AS jogos,
    count(s.id) AS sessoes,
    round(((COALESCE(sum(s.minutos), (0)::bigint))::numeric / 60.0), 1) AS horas_jogadas,
    round(avg(s.minutos), 0) AS minutos_por_sessao
   FROM ((public.plataformas p
     JOIN public.jogos j ON ((j.plataforma_id = p.id)))
     LEFT JOIN public.sessoes s ON ((s.jogo_id = j.id)))
  GROUP BY p.id, p.nome;


--
-- Name: generos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generos ALTER COLUMN id SET DEFAULT nextval('public.generos_id_seq'::regclass);


--
-- Name: jogos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jogos ALTER COLUMN id SET DEFAULT nextval('public.jogos_id_seq'::regclass);


--
-- Name: plataformas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plataformas ALTER COLUMN id SET DEFAULT nextval('public.plataformas_id_seq'::regclass);


--
-- Name: sessoes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessoes ALTER COLUMN id SET DEFAULT nextval('public.sessoes_id_seq'::regclass);


--
-- Data for Name: configuracoes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.configuracoes (chave, valor) FROM stdin;
limite_simultaneos	1
horas_semanais	8
\.


--
-- Data for Name: generos; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.generos (id, nome) FROM stdin;
1	Massively Multiplayer
2	Racing
3	Sports
5	Action
6	Shooter
8	Puzzle
7	RPG
4	Indie
26	Adventure
27	Arcade
28	Casual
29	Fighting
32	Platformer
36	Simulation
37	Strategy
\.


--
-- Data for Name: historico_status; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.historico_status (jogo_id, sequencia, status, alterado_em) FROM stdin;
20	1	abandonado	2026-11-17 19:25:24.502-03
11	1	fila	2026-11-17 14:28:41.315-03
17	1	fila	2026-11-17 14:29:25.524-03
12	1	fila	2026-11-17 14:28:43.55-03
10	1	fila	2026-11-17 14:28:38.97-03
18	1	fila	2026-11-17 14:29:28.632-03
2	1	fila	2026-11-17 11:36:27.772-03
15	1	fila	2026-11-17 14:28:52.345-03
13	1	fila	2026-11-17 14:28:46.201-03
5	1	fila	2026-11-17 11:38:24.052-03
19	1	fila	2026-11-17 14:29:31.134-03
8	1	fila	2026-11-17 11:38:35.916-03
6	1	desejo	2026-11-17 11:38:31.177-03
16	1	fila	2026-11-17 14:28:54.47-03
4	1	fila	2026-11-17 11:38:22.008-03
1	1	fila	2026-11-17 11:36:23.965-03
3	1	zerado	2026-11-17 11:36:35.673-03
14	1	fila	2026-11-17 14:28:48.988-03
9	1	fila	2026-11-17 14:28:36.814-03
7	1	desejo	2026-11-17 11:38:33.139-03
92	1	fila	2026-05-27 22:51:00-03
92	2	jogando	2026-07-10 07:29:00-03
92	3	zerado	2026-07-19 00:38:00-03
93	1	fila	2026-09-06 03:42:00-03
93	2	jogando	2026-10-17 22:34:00-03
93	3	zerado	2026-11-13 16:11:00-03
94	1	fila	2026-07-04 16:39:00-03
94	2	jogando	2026-07-26 12:08:00-03
94	3	zerado	2026-08-07 20:03:00-03
95	1	fila	2026-01-08 18:05:00-03
95	2	jogando	2026-01-24 13:21:00-03
95	3	zerado	2026-02-03 14:28:00-03
96	1	fila	2026-05-02 05:51:00-03
96	2	jogando	2026-05-23 19:45:00-03
96	3	zerado	2026-05-24 01:33:00-03
97	1	fila	2026-08-25 16:41:00-03
97	2	jogando	2026-10-04 08:30:00-03
97	3	zerado	2026-10-14 22:49:00-03
98	1	fila	2026-05-05 02:18:00-03
98	2	jogando	2026-05-18 21:38:00-03
98	3	zerado	2026-05-21 23:05:00-03
99	1	fila	2026-09-20 02:02:00-03
99	2	jogando	2026-10-11 10:36:00-03
99	3	zerado	2026-11-04 01:09:00-03
100	1	fila	2026-07-13 16:10:00-03
100	2	jogando	2026-08-22 19:06:00-03
100	3	zerado	2026-08-24 21:37:00-03
101	1	fila	2025-12-01 14:23:00-03
101	2	jogando	2026-01-07 16:10:00-03
101	3	zerado	2026-01-14 23:20:00-03
102	1	fila	2026-05-23 05:36:00-03
102	2	jogando	2026-06-09 17:19:00-03
102	3	zerado	2026-06-14 13:36:00-03
103	1	desejo	2026-08-08 11:18:00-03
103	2	fila	2026-08-26 12:26:00-03
103	3	jogando	2026-09-28 16:23:00-03
103	4	zerado	2026-10-12 15:20:00-03
104	1	fila	2026-09-24 20:54:00-03
104	2	jogando	2026-10-30 00:51:00-03
104	3	zerado	2026-11-07 22:35:00-03
105	1	desejo	2026-03-13 20:11:00-03
105	2	fila	2026-04-06 00:06:00-03
105	3	jogando	2026-10-24 12:10:00-03
106	1	fila	2026-08-02 15:12:00-03
106	2	jogando	2026-08-11 00:58:00-03
106	3	zerado	2026-08-18 21:05:00-03
107	1	fila	2026-02-13 23:19:00-03
107	2	jogando	2026-03-01 13:40:00-03
107	3	zerado	2026-03-07 20:03:00-03
108	1	desejo	2026-04-08 01:35:00-03
108	2	fila	2026-04-27 01:23:00-03
108	3	jogando	2026-05-05 16:02:00-03
108	4	zerado	2026-05-08 23:19:00-03
109	1	fila	2026-06-25 02:22:00-03
109	2	jogando	2026-07-30 09:48:00-03
109	3	zerado	2026-08-11 15:40:00-03
110	1	fila	2026-01-23 11:46:00-03
110	2	jogando	2026-02-11 02:06:00-03
110	3	zerado	2026-02-27 00:17:00-03
111	1	fila	2026-01-27 03:48:00-03
111	2	jogando	2026-02-19 18:15:00-03
111	3	abandonado	2026-03-11 22:16:00-03
112	1	desejo	2026-05-13 19:31:00-03
112	2	fila	2026-06-09 01:13:00-03
112	3	jogando	2026-07-11 01:30:00-03
112	4	abandonado	2026-07-15 04:35:00-03
113	1	fila	2026-09-25 09:44:00-03
113	2	jogando	2026-10-20 04:19:00-03
113	3	zerado	2026-11-05 16:04:00-03
114	1	fila	2025-12-20 05:21:00-03
114	2	jogando	2026-01-26 00:22:00-03
114	3	zerado	2026-02-17 14:50:00-03
115	1	fila	2026-09-22 03:33:00-03
115	2	jogando	2026-10-04 08:41:00-03
115	3	zerado	2026-10-30 20:42:00-03
116	1	fila	2026-05-07 16:49:00-03
116	2	jogando	2026-05-30 05:09:00-03
116	3	zerado	2026-06-25 13:19:00-03
117	1	fila	2026-02-07 11:27:00-03
117	2	jogando	2026-02-15 21:54:00-03
117	3	abandonado	2026-03-03 01:06:00-03
118	1	desejo	2026-09-11 18:38:00-03
118	2	fila	2026-10-20 08:58:00-03
118	3	jogando	2026-11-15 12:10:00-03
118	4	abandonado	2026-11-18 11:10:00-03
119	1	fila	2025-12-12 13:09:00-03
119	2	jogando	2026-01-06 15:16:00-03
119	3	abandonado	2026-01-17 09:57:00-03
120	1	desejo	2026-04-13 13:40:00-03
120	2	fila	2026-04-24 07:55:00-03
120	3	jogando	2026-05-04 02:27:00-03
120	4	abandonado	2026-05-13 17:22:00-03
121	1	desejo	2026-08-13 08:35:00-03
122	1	desejo	2026-09-21 06:49:00-03
123	1	desejo	2026-09-23 22:19:00-03
124	1	desejo	2026-01-20 08:29:00-03
125	1	desejo	2025-11-19 11:17:00-03
126	1	desejo	2026-06-30 09:33:00-03
127	1	desejo	2026-05-19 19:11:00-03
128	1	desejo	2026-07-07 18:01:00-03
129	1	desejo	2026-09-26 15:34:00-03
130	1	desejo	2026-07-16 19:10:00-03
131	1	desejo	2026-03-07 21:56:00-03
132	1	desejo	2026-03-20 15:07:00-03
133	1	fila	2026-06-01 13:41:00-03
134	1	fila	2026-09-30 01:25:00-03
134	2	jogando	2026-10-02 04:05:00-03
134	3	fila	2026-10-04 15:38:00-03
135	1	fila	2026-06-07 21:19:00-03
136	1	fila	2026-05-31 15:51:00-03
137	1	fila	2026-08-25 04:26:00-03
138	1	fila	2026-02-09 19:50:00-03
139	1	fila	2026-08-15 19:54:00-03
140	1	fila	2026-07-12 04:17:00-03
141	1	fila	2026-01-12 14:31:00-03
142	1	fila	2026-01-26 12:10:00-03
143	1	fila	2026-07-05 19:37:00-03
144	1	fila	2026-02-26 16:36:00-03
145	1	fila	2026-06-28 00:25:00-03
146	1	fila	2026-06-08 22:20:00-03
147	1	fila	2026-08-21 21:57:00-03
148	1	fila	2026-08-10 09:33:00-03
149	1	desejo	2026-07-24 21:07:00-03
149	2	fila	2026-08-17 06:42:00-03
150	1	fila	2026-08-27 21:45:00-03
151	1	fila	2025-12-24 04:49:00-03
152	1	desejo	2026-04-11 14:02:00-03
152	2	fila	2026-04-19 13:05:00-03
152	3	jogando	2026-04-27 15:09:00-03
152	4	fila	2026-05-06 13:21:00-03
153	1	desejo	2026-08-29 16:19:00-03
153	2	fila	2026-09-06 17:03:00-03
154	1	desejo	2026-04-21 22:04:00-03
154	2	fila	2026-05-31 20:25:00-03
155	1	desejo	2026-07-25 13:21:00-03
155	2	fila	2026-08-15 18:55:00-03
156	1	fila	2026-04-13 15:31:00-03
157	1	desejo	2026-04-02 11:20:00-03
157	2	fila	2026-05-02 10:09:00-03
158	1	desejo	2025-12-25 00:57:00-03
158	2	fila	2026-01-03 23:56:00-03
159	1	fila	2026-02-12 05:20:00-03
160	1	fila	2026-09-22 15:27:00-03
160	2	jogando	2026-10-16 03:45:00-03
160	3	fila	2026-10-18 21:32:00-03
161	1	fila	2026-02-04 05:53:00-03
\.


--
-- Data for Name: jogo_generos; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.jogo_generos (jogo_id, genero_id, ordem) FROM stdin;
1	6	1
1	8	2
2	5	1
3	5	1
3	6	2
4	5	1
5	5	1
5	7	2
6	6	1
8	5	1
7	5	1
7	8	2
9	5	1
10	5	1
11	5	1
12	3	1
12	2	2
12	4	3
13	5	1
13	7	2
14	5	1
14	6	2
15	5	1
15	6	2
15	7	3
15	1	4
16	5	1
16	1	2
17	5	1
17	7	2
18	5	1
18	6	2
19	5	1
19	6	2
19	7	3
20	5	1
20	6	2
20	7	3
92	5	1
92	26	2
93	5	1
93	6	2
94	5	1
94	6	2
94	7	3
95	5	1
95	6	2
96	6	1
97	5	1
97	7	2
98	5	1
98	6	2
99	5	1
99	4	2
99	32	3
100	4	1
100	32	2
101	5	1
101	36	2
101	4	3
102	5	1
102	6	2
103	5	1
103	6	2
104	5	1
104	6	2
105	5	1
106	5	1
106	6	2
107	5	1
107	26	2
107	4	3
108	5	1
108	6	2
108	26	3
109	5	1
109	26	2
109	36	3
109	28	4
110	5	1
110	26	2
111	5	1
111	26	2
111	4	3
112	5	1
113	5	1
113	26	2
114	37	1
115	6	1
116	5	1
116	6	2
117	5	1
117	6	2
118	7	1
118	36	2
118	4	3
119	5	1
119	6	2
120	5	1
120	6	2
120	27	3
120	4	4
121	5	1
121	7	2
122	26	1
123	5	1
123	6	2
124	5	1
125	5	1
125	6	2
125	36	3
126	5	1
126	6	2
126	8	3
127	5	1
127	26	2
128	5	1
128	6	2
129	5	1
129	7	2
130	5	1
130	7	2
131	5	1
131	6	2
132	5	1
133	37	1
134	5	1
134	6	2
134	26	3
135	5	1
135	26	2
135	7	3
136	5	1
136	7	2
137	5	1
137	26	2
137	32	3
138	5	1
138	26	2
138	4	3
138	8	4
139	5	1
139	6	2
140	5	1
140	26	2
141	5	1
141	6	2
142	5	1
142	26	2
143	5	1
143	7	2
144	5	1
145	5	1
145	27	2
145	29	3
146	5	1
146	6	2
146	7	3
147	5	1
147	4	2
148	5	1
149	5	1
149	7	2
150	5	1
150	6	2
150	7	3
151	5	1
151	26	2
152	5	1
152	6	2
152	1	3
153	5	1
153	7	2
153	1	3
153	4	4
154	5	1
154	7	2
155	5	1
156	5	1
157	7	1
158	5	1
158	1	2
159	5	1
159	6	2
160	5	1
160	6	2
161	5	1
161	4	2
161	32	3
\.


--
-- Data for Name: jogos; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.jogos (id, rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, nota_pessoal, anotacoes, adicionado_em, concluido_em, descricao, plataforma_id) FROM stdin;
92	23027	The Walking Dead: Season 1	https://media.rawg.io/media/games/8d6/8d69eb6c32ed6acfd75f82d532144993.jpg	92	2012-04-23	8	8	zerado	8	\N	2026-05-27 22:51:00-03	2026-07-19 00:38:00-03	\N	7
93	3192	Metal Gear Solid V: The Phantom Pain	https://media.rawg.io/media/games/490/49016e06ae2103881ff6373248843069.jpg	91	2015-09-01	22	22	zerado	9	\N	2026-09-06 03:42:00-03	2026-11-13 16:11:00-03	\N	46
94	39	Prey	https://media.rawg.io/media/games/e6d/e6de699bd788497f4b52e2f41f9698f2.jpg	80	2017-05-05	10	10	zerado	8	\N	2026-07-04 16:39:00-03	2026-08-07 20:03:00-03	\N	4
95	4332	Spec Ops: The Line	https://media.rawg.io/media/games/b49/b4912b5dbfc7ed8927b65f05b8507f6c.jpg	76	2012-06-26	5	5	zerado	6.5	\N	2026-01-08 18:05:00-03	2026-02-03 14:28:00-03	\N	7
1	4200	Portal 2	https://media.rawg.io/media/games/2ba/2bac0e87cf45e5b508f227d281c9252a.jpg	95	2011-04-18	11	11	fila	\N	\N	2026-11-17 11:36:23.965-03	\N	\N	5
2	28	Red Dead Redemption 2	https://media.rawg.io/media/games/511/5118aff5091cb3efec399c808f8c598f.jpg	96	2018-10-26	21	21	fila	\N	\N	2026-11-17 11:36:27.772-03	\N	\N	7
3	3939	PAYDAY 2	https://media.rawg.io/media/games/73e/73eecb8909e0c39fb246f457b5d6cbbe.jpg	79	2013-08-13	9	9	zerado	10	\N	2026-11-17 11:36:35.673-03	2026-11-17 11:37:56.249-03	\N	8
4	3498	Grand Theft Auto V	https://media.rawg.io/media/games/20a/20aa03a10cda45239fe22d035c0ebe64.jpg	92	2013-09-17	74	74	fila	\N	\N	2026-11-17 11:38:22.008-03	\N	\N	2
5	3328	The Witcher 3: Wild Hunt	https://media.rawg.io/media/games/618/618c2031a07bbff6b4f611f10b6bcdbc.jpg	92	2015-05-18	43	43	fila	\N	\N	2026-11-17 11:38:24.052-03	\N	\N	2
6	4291	Counter-Strike: Global Offensive	https://media.rawg.io/media/games/736/73619bd336c894d6941d926bfd563946.jpg	81	2012-08-21	64	64	desejo	\N	\N	2026-11-17 11:38:31.177-03	\N	\N	7
8	5286	Tomb Raider	https://media.rawg.io/media/games/021/021c4e21a1824d2526f925eff6324653.jpg	86	2013-03-05	10	10	fila	\N	\N	2026-11-17 11:38:35.916-03	\N	\N	5
7	13536	Portal	https://media.rawg.io/media/games/7fa/7fa0b586293c5861ee32490e953a4996.jpg	90	2007-10-09	4	4	desejo	\N	\N	2026-11-17 11:38:33.139-03	\N	Every single time you click your mouse while holding a gun, you expect bullets to fly and enemies to fall. But here you will try out the FPS game filled with environmental puzzles and engaging story. \r\nSilent template for your adventures, Chell, wakes up in a testing facility. She’s a subject of experiments on instant travel device, supervised by snarky and hostile GLaDOS.\r\nPlayers will have to complete the tests, room by room, expecting either reward, freedom or more tests. By using the gun, that shoots portals (Portal-Gun™), players will move blocks, travel great distance quickly and learn about your current situation, which is unraveled through environmental storytelling. What you will be told might be different from what you will see.\r\nWhite environments will guide the player’s portal placement, forcing them to pay attention to the surroundings.  Portal creates tension, allowing either solving puzzles at your own leisure or moving quickly, due to the time limit or threats.	1
9	416	Grand Theft Auto: San Andreas	https://media.rawg.io/media/games/960/960b601d9541cec776c5fa42a00bf6c4.jpg	93	2004-10-26	2	2	fila	\N	\N	2026-11-17 14:28:36.814-03	\N	\N	1
10	3287	Batman: Arkham Knight	https://media.rawg.io/media/games/310/3106b0e012271c5ffb16497b070be739.jpg	81	2015-06-23	19	19	fila	\N	\N	2026-11-17 14:28:38.97-03	\N	\N	7
11	7689	Rise of the Tomb Raider	https://media.rawg.io/media/games/b45/b45575f34285f2c4479c9a5f719d972e.jpg	86	2015-11-10	14	14	fila	\N	\N	2026-11-17 14:28:41.315-03	\N	\N	4
96	10754	BioShock Remastered	https://media.rawg.io/media/games/be0/be01c3d7d8795a45615da139322ca080.jpg	\N	2016-09-15	4	4	zerado	8	\N	2026-05-02 05:51:00-03	2026-05-24 01:33:00-03	\N	46
97	1447	Deus Ex: Mankind Divided	https://media.rawg.io/media/games/00d/00d374f12a3ab5f96c500a2cfa901e15.jpg	83	2016-08-22	7	7	zerado	9	\N	2026-08-25 16:41:00-03	2026-10-14 22:49:00-03	\N	7
98	4286	BioShock	https://media.rawg.io/media/games/bc0/bc06a29ceac58652b684deefe7d56099.jpg	96	2007-08-21	3	3	zerado	9.5	\N	2026-05-05 02:18:00-03	2026-05-21 23:05:00-03	\N	7
99	422	Terraria	https://media.rawg.io/media/games/f46/f466571d536f2e3ea9e815ad17177501.jpg	81	2011-05-16	15	15	zerado	8	\N	2026-09-20 02:02:00-03	2026-11-04 01:09:00-03	\N	7
100	3144	Super Meat Boy	https://media.rawg.io/media/games/e04/e04963f3ac4c4fa83a1dc0b9231e50db.jpg	87	2010-10-20	3	3	zerado	9.5	\N	2026-07-13 16:10:00-03	2026-08-24 21:37:00-03	\N	4
101	9882	Don't Starve Together	https://media.rawg.io/media/games/dd5/dd50d4266915d56dd5b63ae1bf72606a.jpg	83	2016-04-21	7	7	zerado	9.5	\N	2025-12-01 14:23:00-03	2026-01-14 23:20:00-03	\N	46
102	5583	Hitman: Absolution	https://media.rawg.io/media/games/d46/d46373f39458670305704ef089387520.jpg	79	2012-11-19	7	7	zerado	8	\N	2026-05-23 05:36:00-03	2026-06-14 13:36:00-03	\N	3
103	2454	DOOM (2016)	https://media.rawg.io/media/games/587/587588c64afbff80e6f444eb2e46f9da.jpg	85	2016-05-12	10	10	zerado	8.5	\N	2026-08-08 11:18:00-03	2026-10-12 15:20:00-03	\N	46
104	19710	Half-Life 2: Episode One	https://media.rawg.io/media/games/7a2/7a2500ee8b2c0e1ff268bb4479463dea.jpg	87	2006-06-01	4	4	zerado	8	\N	2026-09-24 20:54:00-03	2026-11-07 22:35:00-03	\N	7
105	11935	Half-Life Deathmatch: Source	https://media.rawg.io/media/games/174/174fabfca02d5730531bab2153a7dfcb.jpg	\N	2006-05-01	1	2	jogando	\N	\N	2026-03-13 20:11:00-03	\N	\N	7
106	13537	Half-Life 2	https://media.rawg.io/media/games/b8c/b8c243eaa0fbac8115e0cdccac3f91dc.jpg	96	2004-11-16	7	7	zerado	9	\N	2026-08-02 15:12:00-03	2026-08-18 21:05:00-03	\N	7
12	3272	Rocket League	https://media.rawg.io/media/games/8cc/8cce7c0e99dcc43d66c8efd42f9d03e3.jpg	86	2015-07-07	21	21	fila	\N	\N	2026-11-17 14:28:43.55-03	\N	\N	3
13	278	Horizon Zero Dawn	https://media.rawg.io/media/games/b7d/b7d3f1715fa8381a4e780173a197a615.jpg	89	2017-02-28	11	11	fila	\N	\N	2026-11-17 14:28:46.201-03	\N	\N	7
14	29028	Metro 2033	https://media.rawg.io/media/games/120/1201a40e4364557b124392ee50317b99.jpg	79	2010-03-16	2	2	fila	\N	\N	2026-11-17 14:28:48.988-03	\N	\N	7
15	766	Warframe	https://media.rawg.io/media/games/f87/f87457e8347484033cb34cde6101d08d.jpg	73	2013-03-25	8	8	fila	\N	\N	2026-11-17 14:28:52.345-03	\N	\N	6
16	10213	Dota 2	https://media.rawg.io/media/games/6fc/6fcf4cd3b17c288821388e6085bb0fc9.jpg	90	2013-07-09	14	14	fila	\N	\N	2026-11-17 14:28:54.47-03	\N	\N	8
17	5679	The Elder Scrolls V: Skyrim	https://media.rawg.io/media/games/7cf/7cfc9220b401b7a300e409e539c9afd5.jpg	94	2011-11-11	46	46	fila	\N	\N	2026-11-17 14:29:25.524-03	\N	\N	2
18	4062	BioShock Infinite	https://media.rawg.io/media/games/fc1/fc1307a2774506b5bd65d7e8424664a7.jpg	94	2013-03-26	12	12	fila	\N	\N	2026-11-17 14:29:28.632-03	\N	\N	4
19	802	Borderlands 2	https://media.rawg.io/media/games/49c/49c3dfa4ce2f6f140cc4825868e858cb.jpg	89	2012-09-18	11	11	fila	\N	\N	2026-11-17 14:29:31.134-03	\N	\N	5
107	12536	Hellblade: Senua's Sacrifice	https://media.rawg.io/media/games/63f/63f0e68688cad279ed38cde931dbfcdb.jpg	83	2017-08-07	6	6	zerado	9.5	\N	2026-02-13 23:19:00-03	2026-03-07 20:03:00-03	\N	46
108	19487	Alan Wake	https://media.rawg.io/media/games/5c0/5c0dd63002cb23f804aab327d40ef119.jpg	83	2010-05-14	5	5	zerado	9	\N	2026-04-08 01:35:00-03	2026-05-08 23:19:00-03	\N	7
109	9721	Garry's Mod	https://media.rawg.io/media/games/48c/48cb04ca483be865e3a83119c94e6097.jpg	\N	2004-12-24	14	14	zerado	6.5	\N	2026-06-25 02:22:00-03	2026-08-11 15:40:00-03	\N	7
110	4459	Grand Theft Auto IV	https://media.rawg.io/media/games/4a0/4a0a1316102366260e6f38fd2a9cfdce.jpg	95	2008-04-29	10	10	zerado	8	\N	2026-01-23 11:46:00-03	2026-02-27 00:17:00-03	\N	46
20	41494	Cyberpunk 2077	https://media.rawg.io/media/games/26d/26d4437715bee60138dab4a7c8c59c92.jpg	73	2020-12-10	29	29	abandonado	\N	\N	2026-11-17 19:25:24.502-03	\N	Cyberpunk 2077 is a science fiction game loosely based on the role-playing game Cyberpunk 2020.\r\n\r\n###Setting\r\nThe game is set in the year 2077 in a fictional futuristic metropolis Night City in California. In the world of the game, there are developed cybernetic augmentations that enhance people's strength, agility, and memory. The city is governed by corporations. Many jobs are taken over by the robots, leaving a lot of people poor and homeless. Night City has a roaring underworld, with black markets, underground surgeons, drug dealers, and street gangs abound.\r\n\r\n###Characters\r\nThe main protagonist is fully customizable, including his or her sex and appearance, and goes by the nickname V. He or she is an underground mercenary who does “dirty business” for the various contractors. An NPC companion named Jackie joins the protagonist early at the game, and various other companions may join the player on certain missions as the plot demands. However, the game has no parties and no companion system.\r\n\r\n###Gameplay\r\nThe player controls V from the first person view, with the third-person view used for cutscenes only. The protagonist can travel across the city on feet or using various vehicles, in a manner some observers compared to GTA series. There are many options for the character customization, including three character classes, and a variety of augmentations V can install to enhance his or her abilities.	3
111	13668	Amnesia: The Dark Descent	https://media.rawg.io/media/games/b54/b54598d1d5cc31899f4f0a7e3122a7b0.jpg	85	2010-09-08	2	2	abandonado	\N	\N	2026-01-27 03:48:00-03	\N	\N	7
112	11936	Half-Life 2: Deathmatch	https://media.rawg.io/media/games/ec3/ec3a7db7b8ab5a71aad622fe7c62632f.jpg	\N	2004-11-01	1	2	abandonado	\N	\N	2026-05-13 19:31:00-03	\N	\N	7
113	4386	Saints Row: The Third	https://media.rawg.io/media/games/d69/d69810315bd7e226ea2d21f9156af629.jpg	84	2011-11-15	14	14	zerado	8	\N	2026-09-25 09:44:00-03	2026-11-05 16:04:00-03	\N	46
114	13633	Sid Meier's Civilization V	https://media.rawg.io/media/games/55e/55ee6432ac2bf224610fa17e4c652107.jpg	90	2010-09-21	27	27	zerado	8.5	\N	2025-12-20 05:21:00-03	2026-02-17 14:50:00-03	\N	7
115	11934	Counter-Strike: Source	https://media.rawg.io/media/games/48e/48e63bbddeddbe9ba81942772b156664.jpg	88	2004-11-01	7	7	zerado	8	\N	2026-09-22 03:33:00-03	2026-10-30 20:42:00-03	\N	7
116	4161	Far Cry 3	https://media.rawg.io/media/games/15c/15c95a4915f88a3e89c821526afe05fc.jpg	88	2012-11-28	16	16	zerado	8.5	\N	2026-05-07 16:49:00-03	2026-06-25 13:19:00-03	\N	7
117	290856	Apex Legends	https://media.rawg.io/media/games/737/737ea5662211d2e0bbd6f5989189e4f1.jpg	80	2019-02-04	5	5	abandonado	\N	\N	2026-02-07 11:27:00-03	\N	\N	7
118	654	Stardew Valley	https://media.rawg.io/media/games/713/713269608dc8f2f40f5a670a14b2de94.jpg	89	2016-02-25	13	13	abandonado	\N	\N	2026-09-11 18:38:00-03	\N	\N	7
119	11859	Team Fortress 2	https://media.rawg.io/media/games/46d/46d98e6910fbc0706e2948a7cc9b10c5.jpg	92	2007-10-10	8	8	abandonado	\N	\N	2025-12-12 13:09:00-03	\N	\N	7
120	3612	Hotline Miami	https://media.rawg.io/media/games/9fa/9fa63622543e5d4f6d99aa9d73b043de.jpg	85	2012-10-22	5	5	abandonado	\N	\N	2026-04-13 13:40:00-03	\N	\N	7
121	11973	Middle-earth: Shadow of Mordor	https://media.rawg.io/media/games/d1a/d1a2e99ade53494c6330a0ed945fe823.jpg	85	2014-09-30	13	13	desejo	\N	\N	2026-08-13 08:35:00-03	\N	\N	46
122	3439	Life is Strange	https://media.rawg.io/media/games/562/562553814dd54e001a541e4ee83a591c.jpg	83	2015-01-29	6	6	desejo	\N	\N	2026-09-21 06:49:00-03	\N	\N	46
123	4427	BioShock 2	https://media.rawg.io/media/games/157/15742f2f67eacff546738e1ab5c19d20.jpg	88	2010-02-09	3	3	desejo	\N	\N	2026-09-23 22:19:00-03	\N	\N	46
124	58175	God of War (2018)	https://media.rawg.io/media/games/4be/4be6a6ad0364751a96229c56bf69be59.jpg	94	2018-04-20	15	15	desejo	\N	\N	2026-01-20 08:29:00-03	\N	\N	4
125	10035	Hitman	https://media.rawg.io/media/games/16b/16b1b7b36e2042d1128d5a3e852b3b2f.jpg	83	2016-03-11	7	7	desejo	\N	\N	2025-11-19 11:17:00-03	\N	\N	7
126	19709	Half-Life 2: Episode Two	https://media.rawg.io/media/games/198/1988a337305e008b41d7f536ce9b73f6.jpg	90	2007-10-10	5	5	desejo	\N	\N	2026-06-30 09:33:00-03	\N	\N	7
127	4514	L.A. Noire	https://media.rawg.io/media/games/e2d/e2d3f396b16dded0f841c17c9799a882.jpg	83	2011-05-17	7	7	desejo	\N	\N	2026-05-19 19:11:00-03	\N	\N	4
128	18080	Half-Life	https://media.rawg.io/media/games/6c5/6c55e22185876626881b76c11922b073.jpg	96	1998-11-19	3	3	desejo	\N	\N	2026-07-07 18:01:00-03	\N	\N	7
129	17822	The Witcher: Enhanced Edition Director's Cut	https://media.rawg.io/media/games/ee3/ee3e10193aafc3230ba1cae426967d10.jpg	86	2008-09-16	5	5	desejo	\N	\N	2026-09-26 15:34:00-03	\N	\N	7
130	2551	Dark Souls III	https://media.rawg.io/media/games/da1/da1b267764d77221f07a4386b6548e5a.jpg	89	2016-04-11	29	29	desejo	\N	\N	2026-07-16 19:10:00-03	\N	\N	46
131	4570	Dead Space (2008)	https://media.rawg.io/media/games/ebd/ebdbb7eb52bd58b0e7fa4538d9757b60.jpg	86	2008-10-13	3	3	desejo	\N	\N	2026-03-07 21:56:00-03	\N	\N	7
132	19103	Half-Life 2: Lost Coast	https://media.rawg.io/media/games/b7b/b7b8381707152afc7d91f5d95de70e39.jpg	\N	2005-10-27	1	2	desejo	\N	\N	2026-03-20 15:07:00-03	\N	\N	7
133	10243	Company of Heroes 2	https://media.rawg.io/media/games/0bd/0bd5646a3d8ee0ac3314bced91ea306d.jpg	80	2013-06-25	4	4	fila	\N	\N	2026-06-01 13:41:00-03	\N	\N	7
134	58812	Control	https://media.rawg.io/media/games/253/2534a46f3da7fa7c315f1387515ca393.jpg	84	2019-08-27	6	6	fila	\N	\N	2026-09-30 01:25:00-03	\N	\N	46
135	4248	Dishonored	https://media.rawg.io/media/games/4e6/4e6e8e7f50c237d76f38f3c885dae3d2.jpg	91	2012-09-25	9	9	fila	\N	\N	2026-06-07 21:19:00-03	\N	\N	4
136	3070	Fallout 4	https://media.rawg.io/media/games/d82/d82990b9c67ba0d2d09d4e6fa88885a7.jpg	84	2015-11-09	38	38	fila	\N	\N	2026-05-31 15:51:00-03	\N	\N	46
137	41	Little Nightmares	https://media.rawg.io/media/games/8a0/8a02f84a5916ede2f923b88d5f8217ba.jpg	81	2017-04-27	3	3	fila	\N	\N	2026-08-25 04:26:00-03	\N	\N	7
138	1030	Limbo	https://media.rawg.io/media/games/942/9424d6bb763dc38d9378b488603c87fa.jpg	88	2010-07-21	3	3	fila	\N	\N	2026-02-09 19:50:00-03	\N	\N	4
139	32	Destiny 2	https://media.rawg.io/media/games/34b/34b1f1850a1c06fd971bc6ab3ac0ce0e.jpg	82	2017-09-06	6	6	fila	\N	\N	2026-08-15 19:54:00-03	\N	\N	4
140	29177	Detroit: Become Human	https://media.rawg.io/media/games/951/951572a3dd1e42544bd39a5d5b42d234.jpg	79	2018-05-25	10	10	fila	\N	\N	2026-07-12 04:17:00-03	\N	\N	4
141	12020	Left 4 Dead 2	https://media.rawg.io/media/games/d58/d588947d4286e7b5e0e12e1bea7d9844.jpg	89	2009-11-17	9	9	fila	\N	\N	2026-01-12 14:31:00-03	\N	\N	7
142	50738	Death Stranding	https://media.rawg.io/media/games/2ad/2ad87a4a69b1104f02435c14c5196095.jpg	84	2019-11-08	11	11	fila	\N	\N	2026-01-26 12:10:00-03	\N	\N	4
143	4806	Mass Effect 2	https://media.rawg.io/media/games/3cf/3cff89996570cf29a10eb9cd967dcf73.jpg	94	2010-01-26	22	22	fila	\N	\N	2026-07-05 19:37:00-03	\N	\N	46
144	58134	Marvel's Spider-Man	https://media.rawg.io/media/games/9aa/9aa42d16d425fa6f179fc9dc2f763647.jpg	87	2018-09-07	6	6	fila	\N	\N	2026-02-26 16:36:00-03	\N	\N	4
145	17540	Injustice: Gods Among Us Ultimate Edition	https://media.rawg.io/media/games/234/23410661770ae13eac11066980834367.jpg	80	2013-11-12	5	5	fila	\N	\N	2026-06-28 00:25:00-03	\N	\N	4
146	4828	Borderlands	https://media.rawg.io/media/games/c6b/c6bfece1daf8d06bc0a60632ac78e5bf.jpg	81	2009-10-20	10	10	fila	\N	\N	2026-06-08 22:20:00-03	\N	\N	7
147	3790	Outlast	https://media.rawg.io/media/games/9dd/9ddabb34840ea9227556670606cf8ea3.jpg	80	2013-09-03	3	3	fila	\N	\N	2026-08-21 21:57:00-03	\N	\N	4
148	3841	Assassin’s Creed IV: Black Flag	https://media.rawg.io/media/games/849/849414b978db37d4563ff9e4b0d3a787.jpg	85	2013-10-29	25	25	fila	\N	\N	2026-08-10 09:33:00-03	\N	\N	4
149	12447	The Elder Scrolls V: Skyrim Special Edition	https://media.rawg.io/media/games/62c/62c7c8b28a27b83680b22fb9d33fc619.jpg	74	2016-10-27	9	9	fila	\N	\N	2026-07-24 21:07:00-03	\N	\N	4
150	5563	Fallout: New Vegas	https://media.rawg.io/media/games/995/9951d9d55323d08967640f7b9ab3e342.jpg	84	2010-10-19	12	12	fila	\N	\N	2026-08-27 21:45:00-03	\N	\N	4
151	257201	Star Wars Jedi: Fallen Order	https://media.rawg.io/media/games/559/559bc0768f656ad0c63c54b80a82d680.jpg	80	2019-11-15	8	8	fila	\N	\N	2025-12-24 04:49:00-03	\N	\N	7
152	10142	PlayerUnknown’s Battlegrounds	https://media.rawg.io/media/games/1bd/1bd2657b81eb0c99338120ad444b24ff.jpg	81	2017-12-20	29	29	fila	\N	\N	2026-04-11 14:02:00-03	\N	\N	7
153	10533	Path of Exile	https://media.rawg.io/media/games/d0f/d0f91fe1d92332147e5db74e207cfc7a.jpg	86	2013-10-23	6	6	fila	\N	\N	2026-08-29 16:19:00-03	\N	\N	46
154	864	Dishonored 2	https://media.rawg.io/media/games/f6b/f6bed028b02369d4cab548f4f9337e81.jpg	86	2016-11-10	12	12	fila	\N	\N	2026-04-21 22:04:00-03	\N	\N	4
155	430	Grand Theft Auto: Vice City	https://media.rawg.io/media/games/13a/13a528ac9cf48bbb6be5d35fe029336d.jpg	94	2002-10-27	2	2	fila	\N	\N	2026-07-25 13:21:00-03	\N	\N	4
156	4252	Mirror's Edge	https://media.rawg.io/media/games/8e4/8e4de3f54ac659e08a7ba6a2b731682a.jpg	81	2008-11-11	3	3	fila	\N	\N	2026-04-13 15:31:00-03	\N	\N	7
157	16944	The Witcher 2: Assassins of Kings Enhanced Edition	https://media.rawg.io/media/games/6cd/6cd653e0aaef5ff8bbd295bf4bcb12eb.jpg	88	2012-04-16	7	7	fila	\N	\N	2026-04-02 11:20:00-03	\N	\N	7
158	362	For Honor	https://media.rawg.io/media/games/4e0/4e0e7b6d6906a131307c94266e5c9a1c.jpg	76	2017-02-13	8	8	fila	\N	\N	2025-12-25 00:57:00-03	\N	\N	4
159	2462	Uncharted 4: A Thief’s End	https://media.rawg.io/media/games/709/709bf81f874ce5d25d625b37b014cb63.jpg	93	2016-05-10	0	12	fila	\N	\N	2026-02-12 05:20:00-03	\N	\N	4
160	3696	Wolfenstein: The New Order	https://media.rawg.io/media/games/c80/c80bcf321da44d69b18a06c04d942662.jpg	81	2014-05-19	12	12	fila	\N	\N	2026-09-22 15:27:00-03	\N	\N	4
161	9767	Hollow Knight	https://media.rawg.io/media/games/4cf/4cfc6b7f1850590a4634b08bfab308ab.jpg	88	2017-02-23	7	7	fila	\N	\N	2026-02-04 05:53:00-03	\N	\N	4
\.


--
-- Data for Name: plataformas; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.plataformas (id, nome) FROM stdin;
1	macOS
2	PlayStation 5
3	Nintendo Switch
4	PlayStation 4
5	PlayStation 3
6	iOS
8	Linux
7	PC
31	Android
32	Dreamcast
34	Nintendo 3DS
37	PS Vita
38	PlayStation 2
42	Web
43	Wii U
44	Xbox
45	Xbox 360
46	Xbox One
47	Xbox Series S/X
\.


--
-- Data for Name: sessoes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sessoes (id, jogo_id, data, minutos, comentario) FROM stdin;
1	3	2026-11-17 11:37:46.255-03	480	\N
79	92	2026-07-10 22:45:00-03	60	\N
80	92	2026-07-12 12:45:00-03	90	\N
81	92	2026-07-16 21:45:00-03	120	\N
82	92	2026-07-18 20:45:00-03	228	Finalmente entendi o sistema de combate.
83	93	2026-10-18 19:45:00-03	90	\N
84	93	2026-10-24 20:00:00-03	240	\N
85	93	2026-10-26 12:45:00-03	240	\N
86	93	2026-11-01 20:15:00-03	120	\N
87	93	2026-11-07 12:30:00-03	240	\N
88	93	2026-11-09 14:45:00-03	60	Chefe final derrotado depois de várias tentativas.
89	93	2026-11-10 20:00:00-03	45	\N
90	93	2026-11-11 12:00:00-03	90	\N
91	93	2026-11-13 14:00:00-03	126	\N
92	94	2026-07-26 14:08:00-03	120	\N
93	94	2026-07-27 21:45:00-03	120	\N
94	94	2026-07-28 20:00:00-03	90	\N
95	94	2026-07-30 12:30:00-03	60	\N
96	94	2026-08-05 12:45:00-03	45	\N
97	94	2026-08-07 19:00:00-03	58	\N
98	95	2026-01-24 21:45:00-03	60	Sessão curta antes de dormir.
99	95	2026-01-25 20:15:00-03	45	\N
100	95	2026-01-29 14:15:00-03	45	\N
101	95	2026-02-01 14:15:00-03	75	\N
102	95	2026-02-03 12:45:00-03	98	\N
103	96	2026-05-23 21:45:00-03	223	\N
104	97	2026-10-04 21:15:00-03	180	\N
105	97	2026-10-06 19:15:00-03	75	Finalmente entendi o sistema de combate.
106	97	2026-10-09 21:30:00-03	90	\N
107	97	2026-10-13 12:30:00-03	75	História ficou ótima nesse capítulo.
108	97	2026-10-14 22:00:00-03	44	\N
109	98	2026-05-18 23:38:00-03	120	Finalmente entendi o sistema de combate.
110	98	2026-05-20 12:00:00-03	45	Finalmente entendi o sistema de combate.
111	98	2026-05-21 22:30:00-03	30	\N
112	99	2026-10-11 22:30:00-03	60	\N
113	99	2026-10-15 20:30:00-03	120	\N
114	99	2026-10-17 22:45:00-03	45	\N
115	99	2026-10-19 19:00:00-03	150	\N
116	99	2026-10-21 21:00:00-03	150	\N
117	99	2026-10-23 21:00:00-03	90	\N
118	99	2026-10-24 21:00:00-03	75	Sessão curta antes de dormir.
119	99	2026-10-27 21:30:00-03	150	Fim de semana livre: maratona.
120	99	2026-10-28 20:45:00-03	150	\N
121	99	2026-11-03 22:15:00-03	169	\N
122	100	2026-08-22 21:06:00-03	90	\N
123	100	2026-08-24 19:30:00-03	122	Fim de semana livre: maratona.
124	101	2026-01-07 18:10:00-03	150	\N
125	101	2026-01-08 12:15:00-03	240	\N
126	101	2026-01-14 22:45:00-03	30	\N
127	102	2026-06-09 21:45:00-03	240	\N
128	102	2026-06-13 14:15:00-03	120	\N
129	102	2026-06-14 12:30:00-03	61	\N
130	103	2026-09-28 18:23:00-03	60	\N
131	103	2026-10-02 21:00:00-03	120	\N
132	103	2026-10-04 21:00:00-03	75	História ficou ótima nesse capítulo.
133	103	2026-10-06 19:00:00-03	120	\N
134	103	2026-10-10 14:30:00-03	90	\N
135	103	2026-10-12 14:45:00-03	30	Chefe final derrotado depois de várias tentativas.
136	104	2026-10-30 22:00:00-03	75	Completei a área inicial.
137	104	2026-10-31 12:00:00-03	75	\N
138	104	2026-11-04 19:00:00-03	45	\N
139	104	2026-11-05 21:15:00-03	75	Muito grind hoje.
140	104	2026-11-07 22:00:00-03	30	\N
141	105	2026-10-27 12:00:00-03	65	\N
142	106	2026-08-11 19:45:00-03	150	\N
143	106	2026-08-12 20:15:00-03	90	\N
144	106	2026-08-14 20:45:00-03	150	Travei num puzzle por meia hora.
145	106	2026-08-18 20:30:00-03	30	\N
146	107	2026-03-01 19:30:00-03	60	\N
147	107	2026-03-05 20:00:00-03	180	\N
148	107	2026-03-07 19:00:00-03	58	\N
149	108	2026-05-05 18:02:00-03	120	\N
150	108	2026-05-08 20:45:00-03	149	\N
151	109	2026-07-30 21:30:00-03	120	Joguei com amigos online.
152	109	2026-08-02 12:15:00-03	45	\N
153	109	2026-08-03 14:15:00-03	240	\N
154	109	2026-08-04 22:15:00-03	180	Finalmente entendi o sistema de combate.
155	109	2026-08-06 14:15:00-03	45	\N
156	109	2026-08-08 19:30:00-03	150	\N
157	109	2026-08-10 20:30:00-03	120	\N
158	109	2026-08-11 14:00:00-03	95	\N
159	110	2026-02-11 20:00:00-03	45	\N
160	110	2026-02-15 20:00:00-03	120	\N
161	110	2026-02-18 20:30:00-03	150	\N
162	110	2026-02-20 12:15:00-03	75	\N
163	110	2026-02-26 22:00:00-03	132	\N
164	111	2026-02-19 22:45:00-03	40	Muito grind hoje.
165	112	2026-07-11 14:00:00-03	30	\N
166	113	2026-10-20 14:15:00-03	240	\N
167	113	2026-10-26 22:15:00-03	75	\N
168	113	2026-10-29 21:00:00-03	240	\N
169	113	2026-11-01 21:00:00-03	150	\N
170	113	2026-11-05 14:30:00-03	89	Completei a área inicial.
171	114	2026-01-26 14:15:00-03	45	\N
172	114	2026-01-27 22:45:00-03	180	Sessão curta antes de dormir.
173	114	2026-01-28 22:45:00-03	90	Sessão curta antes de dormir.
174	114	2026-01-31 22:45:00-03	180	\N
175	114	2026-02-02 19:45:00-03	90	\N
176	114	2026-02-05 12:15:00-03	240	\N
177	114	2026-02-06 19:15:00-03	60	Joguei com amigos online.
178	114	2026-02-10 14:45:00-03	180	Sessão curta antes de dormir.
179	114	2026-02-14 19:30:00-03	120	\N
180	114	2026-02-16 19:30:00-03	240	\N
181	114	2026-02-17 14:15:00-03	30	\N
182	115	2026-10-06 21:00:00-03	150	\N
183	115	2026-10-08 12:00:00-03	45	Travei num puzzle por meia hora.
184	115	2026-10-11 20:45:00-03	60	\N
185	115	2026-10-14 14:30:00-03	45	Explorando o mapa e fazendo missões secundárias.
186	115	2026-10-16 14:30:00-03	60	Chefe final derrotado depois de várias tentativas.
187	115	2026-10-20 21:00:00-03	60	\N
188	115	2026-10-30 19:45:00-03	52	Travei num puzzle por meia hora.
189	116	2026-05-30 14:00:00-03	240	\N
190	116	2026-06-02 20:00:00-03	180	\N
191	116	2026-06-03 22:00:00-03	180	\N
192	116	2026-06-09 19:15:00-03	75	\N
193	116	2026-06-11 20:00:00-03	120	\N
194	116	2026-06-17 21:00:00-03	75	\N
195	116	2026-06-23 21:00:00-03	90	\N
196	116	2026-06-25 12:00:00-03	74	\N
197	117	2026-02-15 23:54:00-03	53	Chefe final derrotado depois de várias tentativas.
198	118	2026-11-15 14:45:00-03	45	Explorando o mapa e fazendo missões secundárias.
199	118	2026-11-16 19:15:00-03	60	Fim de semana livre: maratona.
200	119	2026-01-06 20:00:00-03	90	\N
201	119	2026-01-07 20:00:00-03	32	Chefe final derrotado depois de várias tentativas.
202	120	2026-05-04 19:15:00-03	98	\N
203	134	2026-10-02 14:45:00-03	53	\N
204	152	2026-04-27 20:30:00-03	60	\N
205	152	2026-05-01 20:15:00-03	60	\N
206	152	2026-05-02 12:30:00-03	60	\N
207	152	2026-05-04 12:00:00-03	81	\N
208	160	2026-10-16 19:45:00-03	107	\N
\.


--
-- Data for Name: status_jogo; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.status_jogo (codigo, rotulo, ordem, pendente) FROM stdin;
desejo	Desejado	1	f
fila	Na fila	2	t
jogando	Jogando	3	t
zerado	Zerado	4	f
abandonado	Abandonado	5	f
\.


--
-- Data for Name: transicoes_status; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.transicoes_status (origem, destino, acao) FROM stdin;
desejo	fila	Já tenho: pôr na fila
fila	jogando	Começar a jogar
fila	abandonado	Abandonar
fila	desejo	Mover para desejados
jogando	zerado	Marcar como zerado
jogando	fila	Pausar e devolver à fila
jogando	abandonado	Abandonar
zerado	jogando	Jogar de novo
abandonado	fila	Devolver à fila
\.


--
-- Name: generos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.generos_id_seq', 37, true);


--
-- Name: jogos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.jogos_id_seq', 161, true);


--
-- Name: plataformas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.plataformas_id_seq', 49, true);


--
-- Name: sessoes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.sessoes_id_seq', 208, true);


--
-- Name: configuracoes configuracoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configuracoes
    ADD CONSTRAINT configuracoes_pkey PRIMARY KEY (chave);


--
-- Name: generos generos_nome_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generos
    ADD CONSTRAINT generos_nome_key UNIQUE (nome);


--
-- Name: generos generos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.generos
    ADD CONSTRAINT generos_pkey PRIMARY KEY (id);


--
-- Name: historico_status historico_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historico_status
    ADD CONSTRAINT historico_status_pkey PRIMARY KEY (jogo_id, sequencia);


--
-- Name: jogo_generos jogo_generos_jogo_id_ordem_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jogo_generos
    ADD CONSTRAINT jogo_generos_jogo_id_ordem_key UNIQUE (jogo_id, ordem);


--
-- Name: jogo_generos jogo_generos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jogo_generos
    ADD CONSTRAINT jogo_generos_pkey PRIMARY KEY (jogo_id, genero_id);


--
-- Name: jogos jogos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jogos
    ADD CONSTRAINT jogos_pkey PRIMARY KEY (id);


--
-- Name: jogos jogos_rawg_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jogos
    ADD CONSTRAINT jogos_rawg_id_key UNIQUE (rawg_id);


--
-- Name: plataformas plataformas_nome_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plataformas
    ADD CONSTRAINT plataformas_nome_key UNIQUE (nome);


--
-- Name: plataformas plataformas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plataformas
    ADD CONSTRAINT plataformas_pkey PRIMARY KEY (id);


--
-- Name: sessoes sessoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessoes
    ADD CONSTRAINT sessoes_pkey PRIMARY KEY (id);


--
-- Name: status_jogo status_jogo_ordem_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_jogo
    ADD CONSTRAINT status_jogo_ordem_key UNIQUE (ordem);


--
-- Name: status_jogo status_jogo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_jogo
    ADD CONSTRAINT status_jogo_pkey PRIMARY KEY (codigo);


--
-- Name: status_jogo status_jogo_rotulo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_jogo
    ADD CONSTRAINT status_jogo_rotulo_key UNIQUE (rotulo);


--
-- Name: transicoes_status transicoes_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transicoes_status
    ADD CONSTRAINT transicoes_status_pkey PRIMARY KEY (origem, destino);


--
-- Name: idx_jogo_generos_gen; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jogo_generos_gen ON public.jogo_generos USING btree (genero_id);


--
-- Name: idx_jogos_plataforma; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jogos_plataforma ON public.jogos USING btree (plataforma_id);


--
-- Name: idx_jogos_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_jogos_status ON public.jogos USING btree (status);


--
-- Name: idx_sessoes_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sessoes_data ON public.sessoes USING btree (data);


--
-- Name: idx_sessoes_jogo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sessoes_jogo ON public.sessoes USING btree (jogo_id);


--
-- Name: jogos trg_jogos_historico_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_jogos_historico_insert AFTER INSERT ON public.jogos FOR EACH ROW EXECUTE FUNCTION public.fn_registrar_historico_status();


--
-- Name: jogos trg_jogos_historico_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_jogos_historico_update AFTER UPDATE OF status ON public.jogos FOR EACH ROW WHEN ((old.status IS DISTINCT FROM new.status)) EXECUTE FUNCTION public.fn_registrar_historico_status();


--
-- Name: jogos trg_jogos_valida_transicao; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_jogos_valida_transicao BEFORE UPDATE OF status ON public.jogos FOR EACH ROW WHEN ((old.status IS DISTINCT FROM new.status)) EXECUTE FUNCTION public.fn_validar_transicao_status();


--
-- Name: sessoes trg_sessoes_validar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sessoes_validar BEFORE INSERT OR UPDATE ON public.sessoes FOR EACH ROW EXECUTE FUNCTION public.fn_validar_sessao();


--
-- Name: historico_status historico_status_jogo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historico_status
    ADD CONSTRAINT historico_status_jogo_id_fkey FOREIGN KEY (jogo_id) REFERENCES public.jogos(id) ON DELETE CASCADE;


--
-- Name: historico_status historico_status_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historico_status
    ADD CONSTRAINT historico_status_status_fkey FOREIGN KEY (status) REFERENCES public.status_jogo(codigo);


--
-- Name: jogo_generos jogo_generos_genero_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jogo_generos
    ADD CONSTRAINT jogo_generos_genero_id_fkey FOREIGN KEY (genero_id) REFERENCES public.generos(id);


--
-- Name: jogo_generos jogo_generos_jogo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jogo_generos
    ADD CONSTRAINT jogo_generos_jogo_id_fkey FOREIGN KEY (jogo_id) REFERENCES public.jogos(id) ON DELETE CASCADE;


--
-- Name: jogos jogos_plataforma_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jogos
    ADD CONSTRAINT jogos_plataforma_id_fkey FOREIGN KEY (plataforma_id) REFERENCES public.plataformas(id) ON DELETE SET NULL;


--
-- Name: jogos jogos_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jogos
    ADD CONSTRAINT jogos_status_fkey FOREIGN KEY (status) REFERENCES public.status_jogo(codigo);


--
-- Name: sessoes sessoes_jogo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessoes
    ADD CONSTRAINT sessoes_jogo_id_fkey FOREIGN KEY (jogo_id) REFERENCES public.jogos(id) ON DELETE CASCADE;


--
-- Name: transicoes_status transicoes_status_destino_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transicoes_status
    ADD CONSTRAINT transicoes_status_destino_fkey FOREIGN KEY (destino) REFERENCES public.status_jogo(codigo);


--
-- Name: transicoes_status transicoes_status_origem_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.transicoes_status
    ADD CONSTRAINT transicoes_status_origem_fkey FOREIGN KEY (origem) REFERENCES public.status_jogo(codigo);


--
-- PostgreSQL database dump complete
--

\unrestrict AKnegQ96jsOgZzi23KgO6jg9PQGgkK319BmfDx3EYChqPTfkrqC327BeCDmIdlj

