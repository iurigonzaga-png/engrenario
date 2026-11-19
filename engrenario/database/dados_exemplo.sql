-- =====================================================================
-- Engrenário: dados de exemplo
-- =====================================================================
-- Gerado por database/gerar_dados_exemplo.py em 18/11/2026 12:10.
-- Jogos, gêneros, plataformas, notas e durações: reais, da API RAWG
-- (70 jogos). Sessões, status e notas pessoais: simulados
-- (um ano de uso), seguindo as regras dos triggers.
-- Resultado: 6 abandonado, 12 desejo, 29 fila, 1 jogando, 22 zerado;
-- 130 sessões.
--
-- Rode depois do schema.sql:  psql -d engrenario -f database/dados_exemplo.sql
-- Não toca nos jogos que já estão no acervo.
-- =====================================================================

BEGIN;

-- Muda o status de um jogo (passando pelos triggers de transição e de
-- histórico) e acerta a data do registro para o momento simulado.
CREATE FUNCTION pg_temp.mudar_status(p_rawg INT, p_status TEXT,
                                     p_quando TIMESTAMPTZ, p_nota NUMERIC)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE v_id INT;
BEGIN
  SELECT id INTO v_id FROM jogos WHERE rawg_id = p_rawg;
  UPDATE jogos
     SET status = p_status,
         nota_pessoal = COALESCE(p_nota, nota_pessoal),
         concluido_em = CASE WHEN p_status = 'zerado' THEN p_quando END
   WHERE id = v_id;
  UPDATE historico_status SET alterado_em = p_quando
   WHERE jogo_id = v_id
     AND sequencia = (SELECT MAX(sequencia) FROM historico_status
                       WHERE jogo_id = v_id);
END $$;

-- Registra uma sessão (passa pelo trigger de validação de sessão).
CREATE FUNCTION pg_temp.sessao(p_rawg INT, p_data TIMESTAMPTZ,
                               p_minutos INT, p_comentario TEXT)
RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO sessoes (jogo_id, data, minutos, comentario)
  SELECT id, p_data, p_minutos, p_comentario FROM jogos WHERE rawg_id = p_rawg;
$$;

INSERT INTO generos (nome) VALUES
  ('Action'),
  ('Adventure'),
  ('Arcade'),
  ('Casual'),
  ('Fighting'),
  ('Indie'),
  ('Massively Multiplayer'),
  ('Platformer'),
  ('Puzzle'),
  ('RPG'),
  ('Shooter'),
  ('Simulation'),
  ('Strategy')
ON CONFLICT (nome) DO NOTHING;

INSERT INTO plataformas (nome) VALUES
  ('Android'),
  ('Dreamcast'),
  ('Linux'),
  ('Nintendo 3DS'),
  ('Nintendo Switch'),
  ('PC'),
  ('PS Vita'),
  ('PlayStation 2'),
  ('PlayStation 3'),
  ('PlayStation 4'),
  ('PlayStation 5'),
  ('Web'),
  ('Wii U'),
  ('Xbox'),
  ('Xbox 360'),
  ('Xbox One'),
  ('Xbox Series S/X'),
  ('iOS'),
  ('macOS')
ON CONFLICT (nome) DO NOTHING;

-- The Walking Dead: Season 1 (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (23027, 'The Walking Dead: Season 1', 'https://media.rawg.io/media/games/8d6/8d69eb6c32ed6acfd75f82d532144993.jpg', 92, '2012-04-23', 8, 8.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-05-27T22:51-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 23027;
SELECT pg_temp.mudar_status(23027, 'jogando', '2026-07-10T07:29-03:00', NULL);
SELECT pg_temp.sessao(23027, '2026-07-10T22:45-03:00', 60, NULL);
SELECT pg_temp.sessao(23027, '2026-07-12T12:45-03:00', 90, NULL);
SELECT pg_temp.sessao(23027, '2026-07-16T21:45-03:00', 120, NULL);
SELECT pg_temp.sessao(23027, '2026-07-18T20:45-03:00', 228, 'Finalmente entendi o sistema de combate.');
SELECT pg_temp.mudar_status(23027, 'zerado', '2026-07-19T00:38-03:00', 8.0);

-- Metal Gear Solid V: The Phantom Pain (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (3192, 'Metal Gear Solid V: The Phantom Pain', 'https://media.rawg.io/media/games/490/49016e06ae2103881ff6373248843069.jpg', 91, '2015-09-01', 22, 22.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-09-06T03:42-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 3192;
SELECT pg_temp.mudar_status(3192, 'jogando', '2026-10-17T22:34-03:00', NULL);
SELECT pg_temp.sessao(3192, '2026-10-18T19:45-03:00', 90, NULL);
SELECT pg_temp.sessao(3192, '2026-10-24T20:00-03:00', 240, NULL);
SELECT pg_temp.sessao(3192, '2026-10-26T12:45-03:00', 240, NULL);
SELECT pg_temp.sessao(3192, '2026-11-01T20:15-03:00', 120, NULL);
SELECT pg_temp.sessao(3192, '2026-11-07T12:30-03:00', 240, NULL);
SELECT pg_temp.sessao(3192, '2026-11-09T14:45-03:00', 60, 'Chefe final derrotado depois de várias tentativas.');
SELECT pg_temp.sessao(3192, '2026-11-10T20:00-03:00', 45, NULL);
SELECT pg_temp.sessao(3192, '2026-11-11T12:00-03:00', 90, NULL);
SELECT pg_temp.sessao(3192, '2026-11-13T14:00-03:00', 126, NULL);
SELECT pg_temp.mudar_status(3192, 'zerado', '2026-11-13T16:11-03:00', 9.0);

-- Prey (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (39, 'Prey', 'https://media.rawg.io/media/games/e6d/e6de699bd788497f4b52e2f41f9698f2.jpg', 80, '2017-05-05', 10, 10.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-07-04T16:39-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2), ('RPG', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 39;
SELECT pg_temp.mudar_status(39, 'jogando', '2026-07-26T12:08-03:00', NULL);
SELECT pg_temp.sessao(39, '2026-07-26T14:08-03:00', 120, NULL);
SELECT pg_temp.sessao(39, '2026-07-27T21:45-03:00', 120, NULL);
SELECT pg_temp.sessao(39, '2026-07-28T20:00-03:00', 90, NULL);
SELECT pg_temp.sessao(39, '2026-07-30T12:30-03:00', 60, NULL);
SELECT pg_temp.sessao(39, '2026-08-05T12:45-03:00', 45, NULL);
SELECT pg_temp.sessao(39, '2026-08-07T19:00-03:00', 58, NULL);
SELECT pg_temp.mudar_status(39, 'zerado', '2026-08-07T20:03-03:00', 8.0);

-- Spec Ops: The Line (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (4332, 'Spec Ops: The Line', 'https://media.rawg.io/media/games/b49/b4912b5dbfc7ed8927b65f05b8507f6c.jpg', 76, '2012-06-26', 5, 5.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-01-08T18:05-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 4332;
SELECT pg_temp.mudar_status(4332, 'jogando', '2026-01-24T13:21-03:00', NULL);
SELECT pg_temp.sessao(4332, '2026-01-24T21:45-03:00', 60, 'Sessão curta antes de dormir.');
SELECT pg_temp.sessao(4332, '2026-01-25T20:15-03:00', 45, NULL);
SELECT pg_temp.sessao(4332, '2026-01-29T14:15-03:00', 45, NULL);
SELECT pg_temp.sessao(4332, '2026-02-01T14:15-03:00', 75, NULL);
SELECT pg_temp.sessao(4332, '2026-02-03T12:45-03:00', 98, NULL);
SELECT pg_temp.mudar_status(4332, 'zerado', '2026-02-03T14:28-03:00', 6.5);

-- BioShock Remastered (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (10754, 'BioShock Remastered', 'https://media.rawg.io/media/games/be0/be01c3d7d8795a45615da139322ca080.jpg', NULL, '2016-09-15', 4, 4.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-05-02T05:51-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Shooter', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 10754;
SELECT pg_temp.mudar_status(10754, 'jogando', '2026-05-23T19:45-03:00', NULL);
SELECT pg_temp.sessao(10754, '2026-05-23T21:45-03:00', 223, NULL);
SELECT pg_temp.mudar_status(10754, 'zerado', '2026-05-24T01:33-03:00', 8.0);

-- Deus Ex: Mankind Divided (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (1447, 'Deus Ex: Mankind Divided', 'https://media.rawg.io/media/games/00d/00d374f12a3ab5f96c500a2cfa901e15.jpg', 83, '2016-08-22', 7, 7.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-08-25T16:41-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('RPG', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 1447;
SELECT pg_temp.mudar_status(1447, 'jogando', '2026-10-04T08:30-03:00', NULL);
SELECT pg_temp.sessao(1447, '2026-10-04T21:15-03:00', 180, NULL);
SELECT pg_temp.sessao(1447, '2026-10-06T19:15-03:00', 75, 'Finalmente entendi o sistema de combate.');
SELECT pg_temp.sessao(1447, '2026-10-09T21:30-03:00', 90, NULL);
SELECT pg_temp.sessao(1447, '2026-10-13T12:30-03:00', 75, 'História ficou ótima nesse capítulo.');
SELECT pg_temp.sessao(1447, '2026-10-14T22:00-03:00', 44, NULL);
SELECT pg_temp.mudar_status(1447, 'zerado', '2026-10-14T22:49-03:00', 9.0);

-- BioShock (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (4286, 'BioShock', 'https://media.rawg.io/media/games/bc0/bc06a29ceac58652b684deefe7d56099.jpg', 96, '2007-08-21', 3, 3.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-05-05T02:18-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 4286;
SELECT pg_temp.mudar_status(4286, 'jogando', '2026-05-18T21:38-03:00', NULL);
SELECT pg_temp.sessao(4286, '2026-05-18T23:38-03:00', 120, 'Finalmente entendi o sistema de combate.');
SELECT pg_temp.sessao(4286, '2026-05-20T12:00-03:00', 45, 'Finalmente entendi o sistema de combate.');
SELECT pg_temp.sessao(4286, '2026-05-21T22:30-03:00', 30, NULL);
SELECT pg_temp.mudar_status(4286, 'zerado', '2026-05-21T23:05-03:00', 9.5);

-- Terraria (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (422, 'Terraria', 'https://media.rawg.io/media/games/f46/f466571d536f2e3ea9e815ad17177501.jpg', 81, '2011-05-16', 15, 15.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-09-20T02:02-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Indie', 2), ('Platformer', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 422;
SELECT pg_temp.mudar_status(422, 'jogando', '2026-10-11T10:36-03:00', NULL);
SELECT pg_temp.sessao(422, '2026-10-11T22:30-03:00', 60, NULL);
SELECT pg_temp.sessao(422, '2026-10-15T20:30-03:00', 120, NULL);
SELECT pg_temp.sessao(422, '2026-10-17T22:45-03:00', 45, NULL);
SELECT pg_temp.sessao(422, '2026-10-19T19:00-03:00', 150, NULL);
SELECT pg_temp.sessao(422, '2026-10-21T21:00-03:00', 150, NULL);
SELECT pg_temp.sessao(422, '2026-10-23T21:00-03:00', 90, NULL);
SELECT pg_temp.sessao(422, '2026-10-24T21:00-03:00', 75, 'Sessão curta antes de dormir.');
SELECT pg_temp.sessao(422, '2026-10-27T21:30-03:00', 150, 'Fim de semana livre: maratona.');
SELECT pg_temp.sessao(422, '2026-10-28T20:45-03:00', 150, NULL);
SELECT pg_temp.sessao(422, '2026-11-03T22:15-03:00', 169, NULL);
SELECT pg_temp.mudar_status(422, 'zerado', '2026-11-04T01:09-03:00', 8.0);

-- Super Meat Boy (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (3144, 'Super Meat Boy', 'https://media.rawg.io/media/games/e04/e04963f3ac4c4fa83a1dc0b9231e50db.jpg', 87, '2010-10-20', 3, 3.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-07-13T16:10-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Indie', 1), ('Platformer', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 3144;
SELECT pg_temp.mudar_status(3144, 'jogando', '2026-08-22T19:06-03:00', NULL);
SELECT pg_temp.sessao(3144, '2026-08-22T21:06-03:00', 90, NULL);
SELECT pg_temp.sessao(3144, '2026-08-24T19:30-03:00', 122, 'Fim de semana livre: maratona.');
SELECT pg_temp.mudar_status(3144, 'zerado', '2026-08-24T21:37-03:00', 9.5);

-- Don't Starve Together (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (9882, 'Don''t Starve Together', 'https://media.rawg.io/media/games/dd5/dd50d4266915d56dd5b63ae1bf72606a.jpg', 83, '2016-04-21', 7, 7.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2025-12-01T14:23-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Simulation', 2), ('Indie', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 9882;
SELECT pg_temp.mudar_status(9882, 'jogando', '2026-01-07T16:10-03:00', NULL);
SELECT pg_temp.sessao(9882, '2026-01-07T18:10-03:00', 150, NULL);
SELECT pg_temp.sessao(9882, '2026-01-08T12:15-03:00', 240, NULL);
SELECT pg_temp.sessao(9882, '2026-01-14T22:45-03:00', 30, NULL);
SELECT pg_temp.mudar_status(9882, 'zerado', '2026-01-14T23:20-03:00', 9.5);

-- Hitman: Absolution (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (5583, 'Hitman: Absolution', 'https://media.rawg.io/media/games/d46/d46373f39458670305704ef089387520.jpg', 79, '2012-11-19', 7, 7.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'Nintendo Switch'), '2026-05-23T05:36-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 5583;
SELECT pg_temp.mudar_status(5583, 'jogando', '2026-06-09T17:19-03:00', NULL);
SELECT pg_temp.sessao(5583, '2026-06-09T21:45-03:00', 240, NULL);
SELECT pg_temp.sessao(5583, '2026-06-13T14:15-03:00', 120, NULL);
SELECT pg_temp.sessao(5583, '2026-06-14T12:30-03:00', 61, NULL);
SELECT pg_temp.mudar_status(5583, 'zerado', '2026-06-14T13:36-03:00', 8.0);

-- DOOM (2016) (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (2454, 'DOOM (2016)', 'https://media.rawg.io/media/games/587/587588c64afbff80e6f444eb2e46f9da.jpg', 85, '2016-05-12', 10, 10.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-08-08T11:18-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 2454;
SELECT pg_temp.mudar_status(2454, 'fila', '2026-08-26T12:26-03:00', NULL);
SELECT pg_temp.mudar_status(2454, 'jogando', '2026-09-28T16:23-03:00', NULL);
SELECT pg_temp.sessao(2454, '2026-09-28T18:23-03:00', 60, NULL);
SELECT pg_temp.sessao(2454, '2026-10-02T21:00-03:00', 120, NULL);
SELECT pg_temp.sessao(2454, '2026-10-04T21:00-03:00', 75, 'História ficou ótima nesse capítulo.');
SELECT pg_temp.sessao(2454, '2026-10-06T19:00-03:00', 120, NULL);
SELECT pg_temp.sessao(2454, '2026-10-10T14:30-03:00', 90, NULL);
SELECT pg_temp.sessao(2454, '2026-10-12T14:45-03:00', 30, 'Chefe final derrotado depois de várias tentativas.');
SELECT pg_temp.mudar_status(2454, 'zerado', '2026-10-12T15:20-03:00', 8.5);

-- Half-Life 2: Episode One (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (19710, 'Half-Life 2: Episode One', 'https://media.rawg.io/media/games/7a2/7a2500ee8b2c0e1ff268bb4479463dea.jpg', 87, '2006-06-01', 4, 4.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-09-24T20:54-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 19710;
SELECT pg_temp.mudar_status(19710, 'jogando', '2026-10-30T00:51-03:00', NULL);
SELECT pg_temp.sessao(19710, '2026-10-30T22:00-03:00', 75, 'Completei a área inicial.');
SELECT pg_temp.sessao(19710, '2026-10-31T12:00-03:00', 75, NULL);
SELECT pg_temp.sessao(19710, '2026-11-04T19:00-03:00', 45, NULL);
SELECT pg_temp.sessao(19710, '2026-11-05T21:15-03:00', 75, 'Muito grind hoje.');
SELECT pg_temp.sessao(19710, '2026-11-07T22:00-03:00', 30, NULL);
SELECT pg_temp.mudar_status(19710, 'zerado', '2026-11-07T22:35-03:00', 8.0);

-- Half-Life Deathmatch: Source (jogando)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (11935, 'Half-Life Deathmatch: Source', 'https://media.rawg.io/media/games/174/174fabfca02d5730531bab2153a7dfcb.jpg', NULL, '2006-05-01', 1, 2.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-03-13T20:11-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 11935;
SELECT pg_temp.mudar_status(11935, 'fila', '2026-04-06T00:06-03:00', NULL);
SELECT pg_temp.mudar_status(11935, 'jogando', '2026-10-24T12:10-03:00', NULL);
SELECT pg_temp.sessao(11935, '2026-10-27T12:00-03:00', 65, NULL);

-- Half-Life 2 (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (13537, 'Half-Life 2', 'https://media.rawg.io/media/games/b8c/b8c243eaa0fbac8115e0cdccac3f91dc.jpg', 96, '2004-11-16', 7, 7.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-08-02T15:12-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 13537;
SELECT pg_temp.mudar_status(13537, 'jogando', '2026-08-11T00:58-03:00', NULL);
SELECT pg_temp.sessao(13537, '2026-08-11T19:45-03:00', 150, NULL);
SELECT pg_temp.sessao(13537, '2026-08-12T20:15-03:00', 90, NULL);
SELECT pg_temp.sessao(13537, '2026-08-14T20:45-03:00', 150, 'Travei num puzzle por meia hora.');
SELECT pg_temp.sessao(13537, '2026-08-18T20:30-03:00', 30, NULL);
SELECT pg_temp.mudar_status(13537, 'zerado', '2026-08-18T21:05-03:00', 9.0);

-- Hellblade: Senua's Sacrifice (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (12536, 'Hellblade: Senua''s Sacrifice', 'https://media.rawg.io/media/games/63f/63f0e68688cad279ed38cde931dbfcdb.jpg', 83, '2017-08-07', 6, 6.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-02-13T23:19-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2), ('Indie', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 12536;
SELECT pg_temp.mudar_status(12536, 'jogando', '2026-03-01T13:40-03:00', NULL);
SELECT pg_temp.sessao(12536, '2026-03-01T19:30-03:00', 60, NULL);
SELECT pg_temp.sessao(12536, '2026-03-05T20:00-03:00', 180, NULL);
SELECT pg_temp.sessao(12536, '2026-03-07T19:00-03:00', 58, NULL);
SELECT pg_temp.mudar_status(12536, 'zerado', '2026-03-07T20:03-03:00', 9.5);

-- Alan Wake (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (19487, 'Alan Wake', 'https://media.rawg.io/media/games/5c0/5c0dd63002cb23f804aab327d40ef119.jpg', 83, '2010-05-14', 5, 5.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-04-08T01:35-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2), ('Adventure', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 19487;
SELECT pg_temp.mudar_status(19487, 'fila', '2026-04-27T01:23-03:00', NULL);
SELECT pg_temp.mudar_status(19487, 'jogando', '2026-05-05T16:02-03:00', NULL);
SELECT pg_temp.sessao(19487, '2026-05-05T18:02-03:00', 120, NULL);
SELECT pg_temp.sessao(19487, '2026-05-08T20:45-03:00', 149, NULL);
SELECT pg_temp.mudar_status(19487, 'zerado', '2026-05-08T23:19-03:00', 9.0);

-- Garry's Mod (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (9721, 'Garry''s Mod', 'https://media.rawg.io/media/games/48c/48cb04ca483be865e3a83119c94e6097.jpg', NULL, '2004-12-24', 14, 14.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-06-25T02:22-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2), ('Simulation', 3), ('Casual', 4)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 9721;
SELECT pg_temp.mudar_status(9721, 'jogando', '2026-07-30T09:48-03:00', NULL);
SELECT pg_temp.sessao(9721, '2026-07-30T21:30-03:00', 120, 'Joguei com amigos online.');
SELECT pg_temp.sessao(9721, '2026-08-02T12:15-03:00', 45, NULL);
SELECT pg_temp.sessao(9721, '2026-08-03T14:15-03:00', 240, NULL);
SELECT pg_temp.sessao(9721, '2026-08-04T22:15-03:00', 180, 'Finalmente entendi o sistema de combate.');
SELECT pg_temp.sessao(9721, '2026-08-06T14:15-03:00', 45, NULL);
SELECT pg_temp.sessao(9721, '2026-08-08T19:30-03:00', 150, NULL);
SELECT pg_temp.sessao(9721, '2026-08-10T20:30-03:00', 120, NULL);
SELECT pg_temp.sessao(9721, '2026-08-11T14:00-03:00', 95, NULL);
SELECT pg_temp.mudar_status(9721, 'zerado', '2026-08-11T15:40-03:00', 6.5);

-- Grand Theft Auto IV (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (4459, 'Grand Theft Auto IV', 'https://media.rawg.io/media/games/4a0/4a0a1316102366260e6f38fd2a9cfdce.jpg', 95, '2008-04-29', 10, 10.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-01-23T11:46-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 4459;
SELECT pg_temp.mudar_status(4459, 'jogando', '2026-02-11T02:06-03:00', NULL);
SELECT pg_temp.sessao(4459, '2026-02-11T20:00-03:00', 45, NULL);
SELECT pg_temp.sessao(4459, '2026-02-15T20:00-03:00', 120, NULL);
SELECT pg_temp.sessao(4459, '2026-02-18T20:30-03:00', 150, NULL);
SELECT pg_temp.sessao(4459, '2026-02-20T12:15-03:00', 75, NULL);
SELECT pg_temp.sessao(4459, '2026-02-26T22:00-03:00', 132, NULL);
SELECT pg_temp.mudar_status(4459, 'zerado', '2026-02-27T00:17-03:00', 8.0);

-- Amnesia: The Dark Descent (abandonado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (13668, 'Amnesia: The Dark Descent', 'https://media.rawg.io/media/games/b54/b54598d1d5cc31899f4f0a7e3122a7b0.jpg', 85, '2010-09-08', 2, 2.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-01-27T03:48-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2), ('Indie', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 13668;
SELECT pg_temp.mudar_status(13668, 'jogando', '2026-02-19T18:15-03:00', NULL);
SELECT pg_temp.sessao(13668, '2026-02-19T22:45-03:00', 40, 'Muito grind hoje.');
SELECT pg_temp.mudar_status(13668, 'abandonado', '2026-03-11T22:16-03:00', NULL);

-- Half-Life 2: Deathmatch (abandonado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (11936, 'Half-Life 2: Deathmatch', 'https://media.rawg.io/media/games/ec3/ec3a7db7b8ab5a71aad622fe7c62632f.jpg', NULL, '2004-11-01', 1, 2.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-05-13T19:31-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 11936;
SELECT pg_temp.mudar_status(11936, 'fila', '2026-06-09T01:13-03:00', NULL);
SELECT pg_temp.mudar_status(11936, 'jogando', '2026-07-11T01:30-03:00', NULL);
SELECT pg_temp.sessao(11936, '2026-07-11T14:00-03:00', 30, NULL);
SELECT pg_temp.mudar_status(11936, 'abandonado', '2026-07-15T04:35-03:00', NULL);

-- Saints Row: The Third (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (4386, 'Saints Row: The Third', 'https://media.rawg.io/media/games/d69/d69810315bd7e226ea2d21f9156af629.jpg', 84, '2011-11-15', 14, 14.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-09-25T09:44-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 4386;
SELECT pg_temp.mudar_status(4386, 'jogando', '2026-10-20T04:19-03:00', NULL);
SELECT pg_temp.sessao(4386, '2026-10-20T14:15-03:00', 240, NULL);
SELECT pg_temp.sessao(4386, '2026-10-26T22:15-03:00', 75, NULL);
SELECT pg_temp.sessao(4386, '2026-10-29T21:00-03:00', 240, NULL);
SELECT pg_temp.sessao(4386, '2026-11-01T21:00-03:00', 150, NULL);
SELECT pg_temp.sessao(4386, '2026-11-05T14:30-03:00', 89, 'Completei a área inicial.');
SELECT pg_temp.mudar_status(4386, 'zerado', '2026-11-05T16:04-03:00', 8.0);

-- Sid Meier's Civilization V (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (13633, 'Sid Meier''s Civilization V', 'https://media.rawg.io/media/games/55e/55ee6432ac2bf224610fa17e4c652107.jpg', 90, '2010-09-21', 27, 27.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2025-12-20T05:21-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Strategy', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 13633;
SELECT pg_temp.mudar_status(13633, 'jogando', '2026-01-26T00:22-03:00', NULL);
SELECT pg_temp.sessao(13633, '2026-01-26T14:15-03:00', 45, NULL);
SELECT pg_temp.sessao(13633, '2026-01-27T22:45-03:00', 180, 'Sessão curta antes de dormir.');
SELECT pg_temp.sessao(13633, '2026-01-28T22:45-03:00', 90, 'Sessão curta antes de dormir.');
SELECT pg_temp.sessao(13633, '2026-01-31T22:45-03:00', 180, NULL);
SELECT pg_temp.sessao(13633, '2026-02-02T19:45-03:00', 90, NULL);
SELECT pg_temp.sessao(13633, '2026-02-05T12:15-03:00', 240, NULL);
SELECT pg_temp.sessao(13633, '2026-02-06T19:15-03:00', 60, 'Joguei com amigos online.');
SELECT pg_temp.sessao(13633, '2026-02-10T14:45-03:00', 180, 'Sessão curta antes de dormir.');
SELECT pg_temp.sessao(13633, '2026-02-14T19:30-03:00', 120, NULL);
SELECT pg_temp.sessao(13633, '2026-02-16T19:30-03:00', 240, NULL);
SELECT pg_temp.sessao(13633, '2026-02-17T14:15-03:00', 30, NULL);
SELECT pg_temp.mudar_status(13633, 'zerado', '2026-02-17T14:50-03:00', 8.5);

-- Counter-Strike: Source (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (11934, 'Counter-Strike: Source', 'https://media.rawg.io/media/games/48e/48e63bbddeddbe9ba81942772b156664.jpg', 88, '2004-11-01', 7, 7.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-09-22T03:33-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Shooter', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 11934;
SELECT pg_temp.mudar_status(11934, 'jogando', '2026-10-04T08:41-03:00', NULL);
SELECT pg_temp.sessao(11934, '2026-10-06T21:00-03:00', 150, NULL);
SELECT pg_temp.sessao(11934, '2026-10-08T12:00-03:00', 45, 'Travei num puzzle por meia hora.');
SELECT pg_temp.sessao(11934, '2026-10-11T20:45-03:00', 60, NULL);
SELECT pg_temp.sessao(11934, '2026-10-14T14:30-03:00', 45, 'Explorando o mapa e fazendo missões secundárias.');
SELECT pg_temp.sessao(11934, '2026-10-16T14:30-03:00', 60, 'Chefe final derrotado depois de várias tentativas.');
SELECT pg_temp.sessao(11934, '2026-10-20T21:00-03:00', 60, NULL);
SELECT pg_temp.sessao(11934, '2026-10-30T19:45-03:00', 52, 'Travei num puzzle por meia hora.');
SELECT pg_temp.mudar_status(11934, 'zerado', '2026-10-30T20:42-03:00', 8.0);

-- Far Cry 3 (zerado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (4161, 'Far Cry 3', 'https://media.rawg.io/media/games/15c/15c95a4915f88a3e89c821526afe05fc.jpg', 88, '2012-11-28', 16, 16.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-05-07T16:49-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 4161;
SELECT pg_temp.mudar_status(4161, 'jogando', '2026-05-30T05:09-03:00', NULL);
SELECT pg_temp.sessao(4161, '2026-05-30T14:00-03:00', 240, NULL);
SELECT pg_temp.sessao(4161, '2026-06-02T20:00-03:00', 180, NULL);
SELECT pg_temp.sessao(4161, '2026-06-03T22:00-03:00', 180, NULL);
SELECT pg_temp.sessao(4161, '2026-06-09T19:15-03:00', 75, NULL);
SELECT pg_temp.sessao(4161, '2026-06-11T20:00-03:00', 120, NULL);
SELECT pg_temp.sessao(4161, '2026-06-17T21:00-03:00', 75, NULL);
SELECT pg_temp.sessao(4161, '2026-06-23T21:00-03:00', 90, NULL);
SELECT pg_temp.sessao(4161, '2026-06-25T12:00-03:00', 74, NULL);
SELECT pg_temp.mudar_status(4161, 'zerado', '2026-06-25T13:19-03:00', 8.5);

-- Apex Legends (abandonado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (290856, 'Apex Legends', 'https://media.rawg.io/media/games/737/737ea5662211d2e0bbd6f5989189e4f1.jpg', 80, '2019-02-04', 5, 5.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-02-07T11:27-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 290856;
SELECT pg_temp.mudar_status(290856, 'jogando', '2026-02-15T21:54-03:00', NULL);
SELECT pg_temp.sessao(290856, '2026-02-15T23:54-03:00', 53, 'Chefe final derrotado depois de várias tentativas.');
SELECT pg_temp.mudar_status(290856, 'abandonado', '2026-03-03T01:06-03:00', NULL);

-- Stardew Valley (abandonado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (654, 'Stardew Valley', 'https://media.rawg.io/media/games/713/713269608dc8f2f40f5a670a14b2de94.jpg', 89, '2016-02-25', 13, 13.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-09-11T18:38-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('RPG', 1), ('Simulation', 2), ('Indie', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 654;
SELECT pg_temp.mudar_status(654, 'fila', '2026-10-20T08:58-03:00', NULL);
SELECT pg_temp.mudar_status(654, 'jogando', '2026-11-15T12:10-03:00', NULL);
SELECT pg_temp.sessao(654, '2026-11-15T14:45-03:00', 45, 'Explorando o mapa e fazendo missões secundárias.');
SELECT pg_temp.sessao(654, '2026-11-16T19:15-03:00', 60, 'Fim de semana livre: maratona.');
SELECT pg_temp.mudar_status(654, 'abandonado', '2026-11-18T11:10-03:00', NULL);

-- Team Fortress 2 (abandonado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (11859, 'Team Fortress 2', 'https://media.rawg.io/media/games/46d/46d98e6910fbc0706e2948a7cc9b10c5.jpg', 92, '2007-10-10', 8, 8.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2025-12-12T13:09-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 11859;
SELECT pg_temp.mudar_status(11859, 'jogando', '2026-01-06T15:16-03:00', NULL);
SELECT pg_temp.sessao(11859, '2026-01-06T20:00-03:00', 90, NULL);
SELECT pg_temp.sessao(11859, '2026-01-07T20:00-03:00', 32, 'Chefe final derrotado depois de várias tentativas.');
SELECT pg_temp.mudar_status(11859, 'abandonado', '2026-01-17T09:57-03:00', NULL);

-- Hotline Miami (abandonado)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (3612, 'Hotline Miami', 'https://media.rawg.io/media/games/9fa/9fa63622543e5d4f6d99aa9d73b043de.jpg', 85, '2012-10-22', 5, 5.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-04-13T13:40-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2), ('Arcade', 3), ('Indie', 4)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 3612;
SELECT pg_temp.mudar_status(3612, 'fila', '2026-04-24T07:55-03:00', NULL);
SELECT pg_temp.mudar_status(3612, 'jogando', '2026-05-04T02:27-03:00', NULL);
SELECT pg_temp.sessao(3612, '2026-05-04T19:15-03:00', 98, NULL);
SELECT pg_temp.mudar_status(3612, 'abandonado', '2026-05-13T17:22-03:00', NULL);

-- Middle-earth: Shadow of Mordor (desejo)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (11973, 'Middle-earth: Shadow of Mordor', 'https://media.rawg.io/media/games/d1a/d1a2e99ade53494c6330a0ed945fe823.jpg', 85, '2014-09-30', 13, 13.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-08-13T08:35-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('RPG', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 11973;

-- Life is Strange (desejo)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (3439, 'Life is Strange', 'https://media.rawg.io/media/games/562/562553814dd54e001a541e4ee83a591c.jpg', 83, '2015-01-29', 6, 6.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-09-21T06:49-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Adventure', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 3439;

-- BioShock 2 (desejo)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (4427, 'BioShock 2', 'https://media.rawg.io/media/games/157/15742f2f67eacff546738e1ab5c19d20.jpg', 88, '2010-02-09', 3, 3.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-09-23T22:19-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 4427;

-- God of War (2018) (desejo)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (58175, 'God of War (2018)', 'https://media.rawg.io/media/games/4be/4be6a6ad0364751a96229c56bf69be59.jpg', 94, '2018-04-20', 15, 15.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-01-20T08:29-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 58175;

-- Hitman (desejo)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (10035, 'Hitman', 'https://media.rawg.io/media/games/16b/16b1b7b36e2042d1128d5a3e852b3b2f.jpg', 83, '2016-03-11', 7, 7.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2025-11-19T11:17-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2), ('Simulation', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 10035;

-- Half-Life 2: Episode Two (desejo)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (19709, 'Half-Life 2: Episode Two', 'https://media.rawg.io/media/games/198/1988a337305e008b41d7f536ce9b73f6.jpg', 90, '2007-10-10', 5, 5.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-06-30T09:33-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2), ('Puzzle', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 19709;

-- L.A. Noire (desejo)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (4514, 'L.A. Noire', 'https://media.rawg.io/media/games/e2d/e2d3f396b16dded0f841c17c9799a882.jpg', 83, '2011-05-17', 7, 7.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-05-19T19:11-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 4514;

-- Half-Life (desejo)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (18080, 'Half-Life', 'https://media.rawg.io/media/games/6c5/6c55e22185876626881b76c11922b073.jpg', 96, '1998-11-19', 3, 3.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-07-07T18:01-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 18080;

-- The Witcher: Enhanced Edition Director's Cut (desejo)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (17822, 'The Witcher: Enhanced Edition Director''s Cut', 'https://media.rawg.io/media/games/ee3/ee3e10193aafc3230ba1cae426967d10.jpg', 86, '2008-09-16', 5, 5.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-09-26T15:34-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('RPG', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 17822;

-- Dark Souls III (desejo)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (2551, 'Dark Souls III', 'https://media.rawg.io/media/games/da1/da1b267764d77221f07a4386b6548e5a.jpg', 89, '2016-04-11', 29, 29.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-07-16T19:10-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('RPG', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 2551;

-- Dead Space (2008) (desejo)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (4570, 'Dead Space (2008)', 'https://media.rawg.io/media/games/ebd/ebdbb7eb52bd58b0e7fa4538d9757b60.jpg', 86, '2008-10-13', 3, 3.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-03-07T21:56-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 4570;

-- Half-Life 2: Lost Coast (desejo)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (19103, 'Half-Life 2: Lost Coast', 'https://media.rawg.io/media/games/b7b/b7b8381707152afc7d91f5d95de70e39.jpg', NULL, '2005-10-27', 1, 2.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-03-20T15:07-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 19103;

-- Company of Heroes 2 (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (10243, 'Company of Heroes 2', 'https://media.rawg.io/media/games/0bd/0bd5646a3d8ee0ac3314bced91ea306d.jpg', 80, '2013-06-25', 4, 4.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-06-01T13:41-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Strategy', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 10243;

-- Control (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (58812, 'Control', 'https://media.rawg.io/media/games/253/2534a46f3da7fa7c315f1387515ca393.jpg', 84, '2019-08-27', 6, 6.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-09-30T01:25-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2), ('Adventure', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 58812;
SELECT pg_temp.mudar_status(58812, 'jogando', '2026-10-02T04:05-03:00', NULL);
SELECT pg_temp.sessao(58812, '2026-10-02T14:45-03:00', 53, NULL);
SELECT pg_temp.mudar_status(58812, 'fila', '2026-10-04T15:38-03:00', NULL);

-- Dishonored (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (4248, 'Dishonored', 'https://media.rawg.io/media/games/4e6/4e6e8e7f50c237d76f38f3c885dae3d2.jpg', 91, '2012-09-25', 9, 9.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-06-07T21:19-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2), ('RPG', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 4248;

-- Fallout 4 (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (3070, 'Fallout 4', 'https://media.rawg.io/media/games/d82/d82990b9c67ba0d2d09d4e6fa88885a7.jpg', 84, '2015-11-09', 38, 38.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-05-31T15:51-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('RPG', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 3070;

-- Little Nightmares (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (41, 'Little Nightmares', 'https://media.rawg.io/media/games/8a0/8a02f84a5916ede2f923b88d5f8217ba.jpg', 81, '2017-04-27', 3, 3.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-08-25T04:26-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2), ('Platformer', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 41;

-- Limbo (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (1030, 'Limbo', 'https://media.rawg.io/media/games/942/9424d6bb763dc38d9378b488603c87fa.jpg', 88, '2010-07-21', 3, 3.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-02-09T19:50-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2), ('Indie', 3), ('Puzzle', 4)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 1030;

-- Destiny 2 (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (32, 'Destiny 2', 'https://media.rawg.io/media/games/34b/34b1f1850a1c06fd971bc6ab3ac0ce0e.jpg', 82, '2017-09-06', 6, 6.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-08-15T19:54-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 32;

-- Detroit: Become Human (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (29177, 'Detroit: Become Human', 'https://media.rawg.io/media/games/951/951572a3dd1e42544bd39a5d5b42d234.jpg', 79, '2018-05-25', 10, 10.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-07-12T04:17-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 29177;

-- Left 4 Dead 2 (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (12020, 'Left 4 Dead 2', 'https://media.rawg.io/media/games/d58/d588947d4286e7b5e0e12e1bea7d9844.jpg', 89, '2009-11-17', 9, 9.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-01-12T14:31-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 12020;

-- Death Stranding (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (50738, 'Death Stranding', 'https://media.rawg.io/media/games/2ad/2ad87a4a69b1104f02435c14c5196095.jpg', 84, '2019-11-08', 11, 11.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-01-26T12:10-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 50738;

-- Mass Effect 2 (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (4806, 'Mass Effect 2', 'https://media.rawg.io/media/games/3cf/3cff89996570cf29a10eb9cd967dcf73.jpg', 94, '2010-01-26', 22, 22.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-07-05T19:37-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('RPG', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 4806;

-- Marvel's Spider-Man (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (58134, 'Marvel''s Spider-Man', 'https://media.rawg.io/media/games/9aa/9aa42d16d425fa6f179fc9dc2f763647.jpg', 87, '2018-09-07', 6, 6.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-02-26T16:36-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 58134;

-- Injustice: Gods Among Us Ultimate Edition (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (17540, 'Injustice: Gods Among Us Ultimate Edition', 'https://media.rawg.io/media/games/234/23410661770ae13eac11066980834367.jpg', 80, '2013-11-12', 5, 5.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-06-28T00:25-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Arcade', 2), ('Fighting', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 17540;

-- Borderlands (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (4828, 'Borderlands', 'https://media.rawg.io/media/games/c6b/c6bfece1daf8d06bc0a60632ac78e5bf.jpg', 81, '2009-10-20', 10, 10.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-06-08T22:20-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2), ('RPG', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 4828;

-- Outlast (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (3790, 'Outlast', 'https://media.rawg.io/media/games/9dd/9ddabb34840ea9227556670606cf8ea3.jpg', 80, '2013-09-03', 3, 3.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-08-21T21:57-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Indie', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 3790;

-- Assassin’s Creed IV: Black Flag (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (3841, 'Assassin’s Creed IV: Black Flag', 'https://media.rawg.io/media/games/849/849414b978db37d4563ff9e4b0d3a787.jpg', 85, '2013-10-29', 25, 25.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-08-10T09:33-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 3841;

-- The Elder Scrolls V: Skyrim Special Edition (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (12447, 'The Elder Scrolls V: Skyrim Special Edition', 'https://media.rawg.io/media/games/62c/62c7c8b28a27b83680b22fb9d33fc619.jpg', 74, '2016-10-27', 9, 9.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-07-24T21:07-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('RPG', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 12447;
SELECT pg_temp.mudar_status(12447, 'fila', '2026-08-17T06:42-03:00', NULL);

-- Fallout: New Vegas (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (5563, 'Fallout: New Vegas', 'https://media.rawg.io/media/games/995/9951d9d55323d08967640f7b9ab3e342.jpg', 84, '2010-10-19', 12, 12.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-08-27T21:45-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2), ('RPG', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 5563;

-- Star Wars Jedi: Fallen Order (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (257201, 'Star Wars Jedi: Fallen Order', 'https://media.rawg.io/media/games/559/559bc0768f656ad0c63c54b80a82d680.jpg', 80, '2019-11-15', 8, 8.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2025-12-24T04:49-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Adventure', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 257201;

-- PlayerUnknown’s Battlegrounds (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (10142, 'PlayerUnknown’s Battlegrounds', 'https://media.rawg.io/media/games/1bd/1bd2657b81eb0c99338120ad444b24ff.jpg', 81, '2017-12-20', 29, 29.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-04-11T14:02-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2), ('Massively Multiplayer', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 10142;
SELECT pg_temp.mudar_status(10142, 'fila', '2026-04-19T13:05-03:00', NULL);
SELECT pg_temp.mudar_status(10142, 'jogando', '2026-04-27T15:09-03:00', NULL);
SELECT pg_temp.sessao(10142, '2026-04-27T20:30-03:00', 60, NULL);
SELECT pg_temp.sessao(10142, '2026-05-01T20:15-03:00', 60, NULL);
SELECT pg_temp.sessao(10142, '2026-05-02T12:30-03:00', 60, NULL);
SELECT pg_temp.sessao(10142, '2026-05-04T12:00-03:00', 81, NULL);
SELECT pg_temp.mudar_status(10142, 'fila', '2026-05-06T13:21-03:00', NULL);

-- Path of Exile (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (10533, 'Path of Exile', 'https://media.rawg.io/media/games/d0f/d0f91fe1d92332147e5db74e207cfc7a.jpg', 86, '2013-10-23', 6, 6.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'Xbox One'), '2026-08-29T16:19-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('RPG', 2), ('Massively Multiplayer', 3), ('Indie', 4)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 10533;
SELECT pg_temp.mudar_status(10533, 'fila', '2026-09-06T17:03-03:00', NULL);

-- Dishonored 2 (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (864, 'Dishonored 2', 'https://media.rawg.io/media/games/f6b/f6bed028b02369d4cab548f4f9337e81.jpg', 86, '2016-11-10', 12, 12.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-04-21T22:04-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('RPG', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 864;
SELECT pg_temp.mudar_status(864, 'fila', '2026-05-31T20:25-03:00', NULL);

-- Grand Theft Auto: Vice City (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (430, 'Grand Theft Auto: Vice City', 'https://media.rawg.io/media/games/13a/13a528ac9cf48bbb6be5d35fe029336d.jpg', 94, '2002-10-27', 2, 2.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-07-25T13:21-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 430;
SELECT pg_temp.mudar_status(430, 'fila', '2026-08-15T18:55-03:00', NULL);

-- Mirror's Edge (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (4252, 'Mirror''s Edge', 'https://media.rawg.io/media/games/8e4/8e4de3f54ac659e08a7ba6a2b731682a.jpg', 81, '2008-11-11', 3, 3.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-04-13T15:31-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 4252;

-- The Witcher 2: Assassins of Kings Enhanced Edition (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (16944, 'The Witcher 2: Assassins of Kings Enhanced Edition', 'https://media.rawg.io/media/games/6cd/6cd653e0aaef5ff8bbd295bf4bcb12eb.jpg', 88, '2012-04-16', 7, 7.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PC'), '2026-04-02T11:20-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('RPG', 1)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 16944;
SELECT pg_temp.mudar_status(16944, 'fila', '2026-05-02T10:09-03:00', NULL);

-- For Honor (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (362, 'For Honor', 'https://media.rawg.io/media/games/4e0/4e0e7b6d6906a131307c94266e5c9a1c.jpg', 76, '2017-02-13', 8, 8.0, 'desejo', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2025-12-25T00:57-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Massively Multiplayer', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 362;
SELECT pg_temp.mudar_status(362, 'fila', '2026-01-03T23:56-03:00', NULL);

-- Uncharted 4: A Thief’s End (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (2462, 'Uncharted 4: A Thief’s End', 'https://media.rawg.io/media/games/709/709bf81f874ce5d25d625b37b014cb63.jpg', 93, '2016-05-10', 0, 12.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-02-12T05:20-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 2462;

-- Wolfenstein: The New Order (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (3696, 'Wolfenstein: The New Order', 'https://media.rawg.io/media/games/c80/c80bcf321da44d69b18a06c04d942662.jpg', 81, '2014-05-19', 12, 12.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-09-22T15:27-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Shooter', 2)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 3696;
SELECT pg_temp.mudar_status(3696, 'jogando', '2026-10-16T03:45-03:00', NULL);
SELECT pg_temp.sessao(3696, '2026-10-16T19:45-03:00', 107, NULL);
SELECT pg_temp.mudar_status(3696, 'fila', '2026-10-18T21:32-03:00', NULL);

-- Hollow Knight (fila)
INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, horas_api, horas_estimadas, status, plataforma_id, adicionado_em) VALUES (9767, 'Hollow Knight', 'https://media.rawg.io/media/games/4cf/4cfc6b7f1850590a4634b08bfab308ab.jpg', 88, '2017-02-23', 7, 7.0, 'fila', (SELECT id FROM plataformas WHERE nome = 'PlayStation 4'), '2026-02-04T05:53-03:00');
INSERT INTO jogo_generos (jogo_id, genero_id, ordem) SELECT j.id, g.id, x.ordem FROM jogos j CROSS JOIN (VALUES ('Action', 1), ('Indie', 2), ('Platformer', 3)) AS x (nome, ordem) JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = 9767;

COMMIT;
