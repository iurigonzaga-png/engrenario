// Testes das regras de negócio que não dependem de banco nem de rede.
// Rode com: flutter test
import 'package:engrenario/core/erros.dart';
import 'package:engrenario/models/conquista.dart';
import 'package:engrenario/models/jogo.dart';
import 'package:engrenario/models/prioridade.dart';
import 'package:engrenario/models/resumo.dart';
import 'package:engrenario/models/sessao.dart';
import 'package:flutter_test/flutter_test.dart';

JogoAcervo jogo(
  int id,
  StatusJogo status, {
  double estimadas = 10,
  int minutos = 0,
  int? metacritic,
  int diasNoAcervo = 0,
  double? nota,
}) =>
    JogoAcervo(
      id: id,
      rawgId: id,
      nome: 'Jogo $id',
      generos: const ['RPG'],
      metacritic: metacritic,
      status: status,
      horasEstimadas: estimadas,
      minutosJogados: minutos,
      notaPessoal: nota,
      adicionadoEm: DateTime.now().subtract(Duration(days: diasNoAcervo)),
    );

void main() {
  group('Máquina de estados', () {
    test('jogo na fila não pode ser zerado direto', () {
      final j = jogo(1, StatusJogo.fila);
      expect(
        () => j.moverPara(StatusJogo.zerado),
        throwsA(isA<RegraDeNegocio>()),
      );
    });

    test('jogo na fila pode começar a ser jogado', () {
      final j = jogo(1, StatusJogo.fila)..moverPara(StatusJogo.jogando);
      expect(j.status, StatusJogo.jogando);
    });
  });

  group('Validações', () {
    test('duração estimada fora da faixa é recusada', () {
      final j = jogo(1, StatusJogo.fila);
      expect(() => j.definirHorasEstimadas(0), throwsA(isA<RegraDeNegocio>()));
      expect(
        () => j.definirHorasEstimadas(5000),
        throwsA(isA<RegraDeNegocio>()),
      );
    });

    test('nota precisa ficar entre 0 e 10', () {
      final j = jogo(1, StatusJogo.zerado);
      expect(() => j.definirNota(11), throwsA(isA<RegraDeNegocio>()));
      j.definirNota(9.5);
      expect(j.notaPessoal, 9.5);
    });

    test('sessão curta demais é recusada', () {
      expect(
        () => Sessao(jogoId: 1, data: DateTime.now(), minutos: 2),
        throwsA(isA<RegraDeNegocio>()),
      );
    });
  });

  group('Cálculos', () {
    test('progresso e horas restantes', () {
      final j = jogo(1, StatusJogo.jogando, estimadas: 10, minutos: 150);
      expect(j.progresso, closeTo(0.25, 0.001));
      expect(j.horasParaTerminar, closeTo(7.5, 0.001));
    });

    test('pressão do backlog considera só jogos pendentes', () {
      final resumo = ResumoAcervo.de([
        jogo(1, StatusJogo.fila, estimadas: 40),
        jogo(2, StatusJogo.jogando, estimadas: 20, minutos: 600),
        jogo(3, StatusJogo.zerado, estimadas: 30, minutos: 1800, nota: 8),
        jogo(4, StatusJogo.desejo, estimadas: 100),
      ], 10);
      expect(resumo.horasPendentes, closeTo(50, 0.001));
      expect(resumo.semanasParaLimpar, closeTo(5, 0.001));
      expect(resumo.nivel, NivelPressao.estavel);
    });
  });

  group('Polimorfismo', () {
    final jogos = [
      jogo(1, StatusJogo.fila, estimadas: 5, metacritic: 70),
      jogo(2, StatusJogo.fila,
          estimadas: 90, metacritic: 96, diasNoAcervo: 500),
    ];
    final contexto = ContextoPrioridade(
      horasLivres: 8,
      generosFavoritos: const {},
      agora: DateTime.now(),
    );

    test('cada estratégia ordena a fila do seu jeito', () {
      expect(
        const VitoriaRapida().recomendar(jogos, contexto).first.jogo.id,
        1,
      );
      expect(const ObraPrima().recomendar(jogos, contexto).first.jogo.id, 2);
      expect(
        const PoeiraNaEstante().recomendar(jogos, contexto).first.jogo.id,
        2,
      );
    });

    test('conquistas medem o progresso com critérios diferentes', () {
      final resumo = ResumoAcervo.de([
        jogo(1, StatusJogo.zerado, minutos: 600, nota: 9),
      ], 8);
      const zerados = ConquistaZerados('t', 'd', 1);
      const horas = ConquistaHoras('t', 'd', 100);
      expect(zerados.conquistada(resumo), isTrue);
      expect(horas.conquistada(resumo), isFalse);
      expect(horas.progresso(resumo), closeTo(0.1, 0.001));
    });
  });
}
