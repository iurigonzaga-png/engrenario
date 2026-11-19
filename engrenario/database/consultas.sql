-- =====================================================================
-- Engrenário: 10 consultas de análise do acervo
-- =====================================================================
-- Todas usam JOIN, GROUP BY e HAVING. Cada uma responde a uma pergunta
-- que o usuário do app poderia fazer sobre os próprios hábitos de jogo.
-- =====================================================================


-- 1. Em quais gêneros eu mais termino jogos?
--    Gêneros com pelo menos 3 jogos zerados, com horas jogadas e nota média.
--    As sessões são somadas por jogo antes da junção; sem isso, um jogo
--    com 10 sessões pesaria 10 vezes na média da nota.
SELECT ge.nome                                 AS genero,
       COUNT(j.id)                             AS zerados,
       round(SUM(s.minutos) / 60.0, 1)         AS horas_jogadas,
       round(AVG(j.nota_pessoal)::numeric, 1)  AS nota_media
  FROM generos ge
  JOIN jogo_generos jg ON jg.genero_id = ge.id
  JOIN jogos j         ON j.id = jg.jogo_id
  JOIN (SELECT jogo_id, SUM(minutos) AS minutos
          FROM sessoes
         GROUP BY jogo_id) s ON s.jogo_id = j.id
 WHERE j.status = 'zerado'
 GROUP BY ge.nome
HAVING COUNT(j.id) >= 3
 ORDER BY zerados DESC, horas_jogadas DESC;


-- 2. Em quais plataformas eu passo mais tempo?
--    Plataformas com mais de 10 horas registradas.
SELECT p.nome                          AS plataforma,
       COUNT(DISTINCT j.id)            AS jogos_jogados,
       COUNT(s.id)                     AS sessoes,
       round(SUM(s.minutos) / 60.0, 1) AS horas
  FROM plataformas p
  JOIN jogos j   ON j.plataforma_id = p.id
  JOIN sessoes s ON s.jogo_id = j.id
 GROUP BY p.nome
HAVING SUM(s.minutos) > 10 * 60
 ORDER BY horas DESC;


-- 3. Quais jogos zerados levaram mais tempo do que eu estimava?
SELECT j.nome,
       j.horas_estimadas,
       round(SUM(s.minutos) / 60.0, 1)                        AS horas_jogadas,
       round((SUM(s.minutos) / 60.0 - j.horas_estimadas)::numeric, 1) AS horas_a_mais
  FROM jogos j
  JOIN sessoes s ON s.jogo_id = j.id
 WHERE j.status = 'zerado'
 GROUP BY j.id, j.nome, j.horas_estimadas
HAVING SUM(s.minutos) / 60.0 > j.horas_estimadas
 ORDER BY horas_a_mais DESC;


-- 4. Quais foram os meses em que eu mais joguei?
--    Meses com mais de 10 horas, quantos jogos diferentes e o mais jogado.
SELECT to_char(date_trunc('month', s.data), 'MM/YYYY') AS mes,
       COUNT(DISTINCT j.id)                            AS jogos_diferentes,
       COUNT(s.id)                                     AS sessoes,
       round(SUM(s.minutos) / 60.0, 1)                 AS horas
  FROM sessoes s
  JOIN jogos j ON j.id = s.jogo_id
 GROUP BY date_trunc('month', s.data)
HAVING SUM(s.minutos) > 10 * 60
 ORDER BY date_trunc('month', s.data);


-- 5. Quais jogos tiveram mais sessões, e de quanto tempo em média?
--    Jogos com 5 sessões ou mais.
SELECT j.nome,
       st.rotulo                    AS status,
       COUNT(s.id)                  AS sessoes,
       round(AVG(s.minutos))        AS minutos_por_sessao,
       MIN(s.data)::date            AS primeira,
       MAX(s.data)::date            AS ultima
  FROM jogos j
  JOIN status_jogo st ON st.codigo = j.status
  JOIN sessoes s      ON s.jogo_id = j.id
 GROUP BY j.id, j.nome, st.rotulo
HAVING COUNT(s.id) >= 5
 ORDER BY sessoes DESC;


-- 6. Quanto tempo um jogo fica parado antes de eu começar a jogar, por gênero?
--    Só gêneros com pelo menos 2 jogos começados.
--    Usa a entidade fraca historico_status: primeira vez em "jogando".
SELECT ge.nome                                              AS genero,
       COUNT(*)                                             AS jogos_comecados,
       round(AVG(EXTRACT(EPOCH FROM (h.inicio - j.adicionado_em)) / 86400)) AS dias_ate_comecar
  FROM (SELECT jogo_id, MIN(alterado_em) AS inicio
          FROM historico_status
         WHERE status = 'jogando'
         GROUP BY jogo_id) h
  JOIN jogos j         ON j.id = h.jogo_id
  JOIN jogo_generos jg ON jg.jogo_id = j.id AND jg.ordem = 1
  JOIN generos ge      ON ge.id = jg.genero_id
 GROUP BY ge.nome
HAVING COUNT(*) >= 2
 ORDER BY dias_ate_comecar;


-- 7. Quais transições de status mais acontecem?
--    Junta cada registro do histórico com o seguinte do mesmo jogo
--    (autojunção) e com a ação cadastrada em transicoes_status.
SELECT o.rotulo     AS de,
       d.rotulo     AS para,
       t.acao,
       COUNT(*)     AS vezes
  FROM historico_status h1
  JOIN historico_status h2   ON h2.jogo_id = h1.jogo_id
                            AND h2.sequencia = h1.sequencia + 1
  JOIN transicoes_status t   ON t.origem = h1.status AND t.destino = h2.status
  JOIN status_jogo o         ON o.codigo = t.origem
  JOIN status_jogo d         ON d.codigo = t.destino
 GROUP BY o.rotulo, d.rotulo, t.acao, o.ordem, d.ordem
HAVING COUNT(*) >= 2
 ORDER BY vezes DESC;


-- 8. Quanto falta jogar em cada status do backlog?
--    Status com mais de 5 jogos, somando as horas restantes com a
--    function fn_horas_restantes.
SELECT st.rotulo                               AS status,
       COUNT(j.id)                             AS jogos,
       round(AVG(j.horas_estimadas)::numeric, 1) AS horas_estimadas_media,
       SUM(fn_horas_restantes(j.id))           AS horas_restantes
  FROM status_jogo st
  JOIN jogos j ON j.status = st.codigo
 GROUP BY st.rotulo, st.ordem
HAVING COUNT(j.id) > 5
 ORDER BY st.ordem;


-- 9. Em que gêneros eu dou nota maior do que a crítica?
--    Compara a nota pessoal (0 a 10) com o Metacritic (0 a 100, dividido
--    por 10) nos jogos zerados. Só gêneros com 2 ou mais jogos avaliados.
SELECT ge.nome                                          AS genero,
       COUNT(j.id)                                      AS avaliados,
       round(AVG(j.nota_pessoal)::numeric, 1)           AS minha_nota,
       round(AVG(j.metacritic) / 10.0, 1)               AS critica,
       round((AVG(j.nota_pessoal) - AVG(j.metacritic) / 10.0)::numeric, 1) AS diferenca
  FROM generos ge
  JOIN jogo_generos jg ON jg.genero_id = ge.id
  JOIN jogos j         ON j.id = jg.jogo_id
 WHERE j.status = 'zerado'
   AND j.nota_pessoal IS NOT NULL
   AND j.metacritic IS NOT NULL
 GROUP BY ge.nome
HAVING COUNT(j.id) >= 2
   AND AVG(j.nota_pessoal) > AVG(j.metacritic) / 10.0
 ORDER BY diferenca DESC;


-- 10. Em que dia da semana e em qual plataforma eu costumo jogar?
--     Combinações com pelo menos 3 sessões.
SELECT CASE EXTRACT(ISODOW FROM s.data)
         WHEN 1 THEN 'Segunda' WHEN 2 THEN 'Terça'  WHEN 3 THEN 'Quarta'
         WHEN 4 THEN 'Quinta'  WHEN 5 THEN 'Sexta'  WHEN 6 THEN 'Sábado'
         ELSE 'Domingo'
       END                              AS dia_da_semana,
       p.nome                           AS plataforma,
       COUNT(s.id)                      AS sessoes,
       round(SUM(s.minutos) / 60.0, 1)  AS horas
  FROM sessoes s
  JOIN jogos j       ON j.id = s.jogo_id
  JOIN plataformas p ON p.id = j.plataforma_id
 GROUP BY EXTRACT(ISODOW FROM s.data), p.nome
HAVING COUNT(s.id) >= 3
 ORDER BY EXTRACT(ISODOW FROM s.data), horas DESC;
