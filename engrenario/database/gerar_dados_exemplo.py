"""Gera database/dados_exemplo.sql com jogos reais da RAWG e um ano de uso
simulado (sessões, mudanças de status, notas).

O que vem da API: nome, capa, gêneros, plataformas, nota do Metacritic,
lançamento e duração média de cada jogo.
O que é simulado: o uso do acervo (quando cada jogo entrou, quando foi
jogado, por quanto tempo, a nota pessoal). A simulação respeita as mesmas
regras que o banco impõe por trigger, então o arquivo gerado roda sem erro.

Uso (só precisa rodar de novo para trocar os dados; o .sql já está pronto):
    RAWG_KEY=sua_chave python3 database/gerar_dados_exemplo.py

Gasta PAGINAS requisições da cota da RAWG.
"""

from __future__ import annotations

import json
import os
import random
import sys
import urllib.request
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

PAGINAS = 3          # 40 jogos por página
MAX_NOVOS = 70       # jogos de exemplo a inserir
SEMENTE = 2026       # mesma semente = mesma simulação
API_LOCAL = 'http://localhost:3000/api/jogos'
SAIDA = Path(__file__).with_name('dados_exemplo.sql')
FUSO = timezone(timedelta(hours=-3))

# Limites usados na simulação (mais conservadores que os do banco).
MAX_MINUTOS_DIA = 6 * 60

COMENTARIOS = [
    'Chefe final derrotado depois de várias tentativas.',
    'Explorando o mapa e fazendo missões secundárias.',
    'Sessão curta antes de dormir.',
    'Joguei com amigos online.',
    'Finalmente entendi o sistema de combate.',
    'Muito grind hoje.',
    'História ficou ótima nesse capítulo.',
    'Travei num puzzle por meia hora.',
    'Completei a área inicial.',
    'Fim de semana livre: maratona.',
]

PLATAFORMAS_PREFERIDAS = [
    'PC', 'PlayStation 5', 'Nintendo Switch', 'PlayStation 4',
    'Xbox Series S/X', 'Xbox One',
]


def baixar_catalogo(chave: str) -> list[dict]:
    jogos: list[dict] = []
    for pagina in range(1, PAGINAS + 1):
        url = ('https://api.rawg.io/api/games?ordering=-added&page_size=40'
               f'&page={pagina}&key={chave}')
        with urllib.request.urlopen(url, timeout=20) as resposta:
            jogos.extend(json.load(resposta)['results'])
    return jogos


def rawg_ids_existentes() -> set[int]:
    """Jogos que já estão no acervo (não serão tocados pelo script)."""
    try:
        with urllib.request.urlopen(API_LOCAL, timeout=5) as resposta:
            return {j['rawg_id'] for j in json.load(resposta)}
    except OSError:
        print('Backend fora do ar: nenhum jogo existente será excluído.',
              file=sys.stderr)
        return set()


def texto(valor: str | None) -> str:
    if valor is None:
        return 'NULL'
    return "'" + valor.replace("'", "''") + "'"


def quando(momento: datetime) -> str:
    return "'" + momento.isoformat(timespec='minutes') + "'"


class Agenda:
    """Controla os minutos já usados em cada dia (máx. MAX_MINUTOS_DIA)."""

    def __init__(self) -> None:
        self.usado: dict[date, int] = {}

    def cabe(self, dia: date, minutos: int) -> bool:
        return self.usado.get(dia, 0) + minutos <= MAX_MINUTOS_DIA

    def reservar(self, dia: date, minutos: int) -> None:
        self.usado[dia] = self.usado.get(dia, 0) + minutos


def main() -> None:
    chave = os.environ.get('RAWG_KEY', '').strip()
    if not chave:
        sys.exit('Defina RAWG_KEY com a sua chave da RAWG.')

    sorteio = random.Random(SEMENTE)
    agora = datetime.now(FUSO).replace(second=0, microsecond=0)
    inicio = agora - timedelta(days=365)
    existentes = rawg_ids_existentes()

    candidatos = [
        j for j in baixar_catalogo(chave)
        if j['id'] not in existentes and j.get('genres') and j.get('platforms')
    ][:MAX_NOVOS]
    sorteio.shuffle(candidatos)

    # Distribuição final dos status: cerca de 1/3 zerados, sorteados entre
    # os jogos com ao menos 3 h; só 1 fica "jogando" (limite da bancada).
    quantos_zerados = round(len(candidatos) * 0.32)
    elegiveis = [j for j in candidatos if (j.get('playtime') or 0) >= 3]
    zerados = {j['id'] for j in elegiveis[:quantos_zerados]}
    restantes = [j for j in candidatos if j['id'] not in zerados]
    destino: dict[int, str] = {j: 'zerado' for j in zerados}
    destino[restantes[0]['id']] = 'jogando'
    for j in restantes[1:7]:
        destino[j['id']] = 'abandonado'
    for j in restantes[7:19]:
        destino[j['id']] = 'desejo'
    for j in restantes[19:]:
        destino[j['id']] = 'fila'

    agenda = Agenda()
    linhas: list[str] = []
    resumo: dict[str, int] = {}
    total_sessoes = 0

    def jogar(rawg_id: int, de: datetime, ate: datetime, horas: float) -> datetime:
        """Distribui [horas] em sessões entre [de] e [ate]. Devolve o fim."""
        nonlocal total_sessoes
        restante = max(30, int(horas * 60))
        dia = de
        ultimo = de
        while restante > 0 and dia < ate:
            minutos = min(restante, sorteio.choice([45, 60, 75, 90, 120, 150, 180, 240]))
            minutos = max(minutos, 30)
            if agenda.cabe(dia.date(), minutos):
                hora = dia.replace(hour=sorteio.choice([12, 14, 19, 20, 21, 22]),
                                   minute=sorteio.choice([0, 15, 30, 45]))
                hora = max(hora, de)
                if hora > ate:
                    break
                agenda.reservar(dia.date(), minutos)
                comentario = (sorteio.choice(COMENTARIOS)
                              if sorteio.random() < 0.25 else None)
                linhas.append(
                    f'SELECT pg_temp.sessao({rawg_id}, {quando(hora)}, '
                    f'{minutos}, {texto(comentario)});')
                total_sessoes += 1
                restante -= minutos
                ultimo = hora + timedelta(minutes=minutos)
            dia += timedelta(days=sorteio.choice([1, 1, 2, 2, 3, 4, 6]))
        return ultimo

    def mudar(rawg_id: int, status: str, momento: datetime,
              nota: float | None = None) -> None:
        nota_sql = 'NULL' if nota is None else f'{nota:.1f}'
        linhas.append(
            f"SELECT pg_temp.mudar_status({rawg_id}, '{status}', "
            f'{quando(momento)}, {nota_sql});')

    for jogo in candidatos:
        rid = jogo['id']
        final = destino[rid]
        resumo[final] = resumo.get(final, 0) + 1
        generos = [g['name'] for g in jogo['genres']][:4]
        plataformas = [p['platform']['name'] for p in jogo['platforms']]
        preferidas = [p for p in PLATAFORMAS_PREFERIDAS if p in plataformas]
        plataforma = sorteio.choice(preferidas or plataformas)
        horas_api = int(jogo.get('playtime') or 0)
        estimadas = float(min(max(horas_api or 12, 2), 120))
        metacritic = jogo.get('metacritic')
        lancamento = jogo.get('released')

        adicionado = inicio + timedelta(
            days=sorteio.uniform(0, 330 if final != 'desejo' else 355),
            hours=sorteio.uniform(8, 14))
        if lancamento and adicionado.date() < date.fromisoformat(lancamento):
            adicionado = datetime.combine(
                date.fromisoformat(lancamento), adicionado.timetz())
        comeca_como = 'desejo' if final == 'desejo' or sorteio.random() < 0.2 else 'fila'

        linhas.append('')
        linhas.append(f'-- {jogo["name"]} ({final})')
        linhas.append(
            'INSERT INTO jogos (rawg_id, nome, capa_url, metacritic, lancamento, '
            'horas_api, horas_estimadas, status, plataforma_id, adicionado_em) '
            f'VALUES ({rid}, {texto(jogo["name"])}, '
            f'{texto(jogo.get("background_image"))}, '
            f'{metacritic if metacritic is not None else "NULL"}, '
            f'{texto(lancamento)}, {horas_api}, {estimadas}, '
            f"'{comeca_como}', "
            f'(SELECT id FROM plataformas WHERE nome = {texto(plataforma)}), '
            f'{quando(adicionado)});')
        valores = ', '.join(
            f'({texto(g)}, {i})' for i, g in enumerate(generos, start=1))
        linhas.append(
            'INSERT INTO jogo_generos (jogo_id, genero_id, ordem) '
            'SELECT j.id, g.id, x.ordem FROM jogos j '
            f'CROSS JOIN (VALUES {valores}) AS x (nome, ordem) '
            f'JOIN generos g ON g.nome = x.nome WHERE j.rawg_id = {rid};')

        momento = adicionado
        if comeca_como == 'desejo' and final != 'desejo':
            momento += timedelta(days=sorteio.uniform(5, 40))
            mudar(rid, 'fila', momento)

        if final in ('zerado', 'abandonado', 'jogando'):
            if final == 'jogando':
                momento = max(momento, agora - timedelta(days=25))
            else:
                momento += timedelta(days=sorteio.uniform(1, 45))
            momento = min(momento, agora - timedelta(days=3))
            mudar(rid, 'jogando', momento)
            if final == 'zerado':
                horas = estimadas * sorteio.uniform(0.75, 1.3)
            elif final == 'abandonado':
                horas = estimadas * sorteio.uniform(0.1, 0.4)
            else:
                horas = estimadas * sorteio.uniform(0.3, 0.6)
            fim = jogar(rid, momento + timedelta(hours=2),
                        agora - timedelta(hours=6), horas)
            if final == 'zerado':
                base = (metacritic or 75) / 10
                nota = round(min(10, max(4, base + sorteio.uniform(-1.5, 1.2))) * 2) / 2
                mudar(rid, 'zerado', fim + timedelta(minutes=5), nota)
            elif final == 'abandonado':
                mudar(rid, 'abandonado',
                      min(fim + timedelta(days=sorteio.uniform(3, 20)),
                          agora - timedelta(hours=1)))
        elif final == 'fila' and sorteio.random() < 0.15:
            # Começou, jogou um pouco e devolveu à fila.
            momento += timedelta(days=sorteio.uniform(2, 30))
            momento = min(momento, agora - timedelta(days=20))
            mudar(rid, 'jogando', momento)
            fim = jogar(rid, momento + timedelta(hours=2),
                        agora - timedelta(days=10), estimadas * 0.15)
            mudar(rid, 'fila', fim + timedelta(days=2))

    generos_todos = sorted({g['name'] for j in candidatos for g in j['genres']})
    plataformas_todas = sorted({p['platform']['name']
                                for j in candidatos for p in j['platforms']})

    cabecalho = f"""-- =====================================================================
-- Engrenário: dados de exemplo
-- =====================================================================
-- Gerado por database/gerar_dados_exemplo.py em {agora:%d/%m/%Y %H:%M}.
-- Jogos, gêneros, plataformas, notas e durações: reais, da API RAWG
-- ({len(candidatos)} jogos). Sessões, status e notas pessoais: simulados
-- (um ano de uso), seguindo as regras dos triggers.
-- Resultado: {', '.join(f'{v} {k}' for k, v in sorted(resumo.items()))};
-- {total_sessoes} sessões.
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
  {(','+chr(10)+'  ').join(f'({texto(g)})' for g in generos_todos)}
ON CONFLICT (nome) DO NOTHING;

INSERT INTO plataformas (nome) VALUES
  {(','+chr(10)+'  ').join(f'({texto(p)})' for p in plataformas_todas)}
ON CONFLICT (nome) DO NOTHING;
"""
    SAIDA.write_text(cabecalho + '\n'.join(linhas) + '\n\nCOMMIT;\n',
                     encoding='utf-8')
    print(f'{SAIDA}: {len(candidatos)} jogos, {total_sessoes} sessões, '
          f'{resumo}')


if __name__ == '__main__':
    main()
