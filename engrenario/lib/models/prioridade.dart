import 'dart:math' as math;

import '../core/formatos.dart';
import 'jogo.dart';

/// Dados de que as estratégias precisam para decidir.
class ContextoPrioridade {
  const ContextoPrioridade({
    required this.horasLivres,
    required this.generosFavoritos,
    required this.agora,
  });

  /// Horas que o usuário tem para jogar nesta semana.
  final double horasLivres;

  /// Gênero -> quantos jogos zerados dele.
  final Map<String, int> generosFavoritos;
  final DateTime agora;
}

class Recomendacao {
  const Recomendacao(this.jogo, this.pontos, this.motivo);
  final JogoAcervo jogo;

  /// De 0 a 100.
  final double pontos;
  final String motivo;
}

/// Contrato de uma estratégia de priorização da fila (padrão Strategy).
///
/// Cada subclasse pontua os jogos de um jeito; o método [recomendar] é
/// igual para todas e chama o [pontuar] da estratégia escolhida
/// (polimorfismo).
abstract class EstrategiaPrioridade {
  const EstrategiaPrioridade();

  static const List<EstrategiaPrioridade> todas = [
    Equilibrada(),
    VitoriaRapida(),
    ObraPrima(),
    PoeiraNaEstante(),
  ];

  String get nome;
  String get descricao;

  /// Pontuação de 0 a 100 para o jogo neste contexto.
  double pontuar(JogoAcervo jogo, ContextoPrioridade contexto);

  /// Frase curta que explica a pontuação ao usuário.
  String justificar(JogoAcervo jogo, ContextoPrioridade contexto);

  List<Recomendacao> recomendar(
    Iterable<JogoAcervo> jogos,
    ContextoPrioridade contexto,
  ) {
    final lista = [
      for (final jogo in jogos)
        if (jogo.pendente)
          Recomendacao(
            jogo,
            pontuar(jogo, contexto).clamp(0.0, 100.0),
            justificar(jogo, contexto),
          ),
    ];
    lista.sort((a, b) {
      final porPontos = b.pontos.compareTo(a.pontos);
      return porPontos != 0 ? porPontos : a.jogo.nome.compareTo(b.jogo.nome);
    });
    return lista;
  }
}

/// Prefere o que dá para terminar logo.
class VitoriaRapida extends EstrategiaPrioridade {
  const VitoriaRapida();

  @override
  String get nome => 'Vitória rápida';

  @override
  String get descricao => 'O que dá para terminar com o tempo que você tem.';

  @override
  double pontuar(JogoAcervo jogo, ContextoPrioridade contexto) {
    final faltam = jogo.horasParaTerminar;
    final livres = math.max(contexto.horasLivres, 0.5);
    if (faltam <= livres) return 100 - (faltam / livres) * 30;
    return 60 * (livres / faltam);
  }

  @override
  String justificar(JogoAcervo jogo, ContextoPrioridade contexto) {
    final faltam = jogo.horasParaTerminar;
    final livres = math.max(contexto.horasLivres, 0.5);
    if (faltam <= livres) {
      return 'Faltam ${Formatos.horas(faltam)}: cabe nesta semana.';
    }
    return 'Faltam ${Formatos.horas(faltam)}, cerca de '
        '${Formatos.semanas(faltam / livres)} nesse ritmo.';
  }
}

/// Prefere o que a crítica mais elogiou.
class ObraPrima extends EstrategiaPrioridade {
  const ObraPrima();

  @override
  String get nome => 'Obra-prima';

  @override
  String get descricao => 'Os mais bem avaliados pela crítica primeiro.';

  @override
  double pontuar(JogoAcervo jogo, ContextoPrioridade contexto) =>
      (jogo.metacritic ?? 50).toDouble();

  @override
  String justificar(JogoAcervo jogo, ContextoPrioridade contexto) =>
      jogo.metacritic == null
          ? 'Sem nota da crítica, fica no meio da fila.'
          : 'Nota ${jogo.metacritic} no Metacritic.';
}

/// Prefere o que espera há mais tempo.
class PoeiraNaEstante extends EstrategiaPrioridade {
  const PoeiraNaEstante();

  @override
  String get nome => 'Poeira na estante';

  @override
  String get descricao => 'O que está esperando há mais tempo.';

  int _dias(JogoAcervo jogo, ContextoPrioridade contexto) =>
      math.max(0, contexto.agora.difference(jogo.adicionadoEm).inDays);

  @override
  double pontuar(JogoAcervo jogo, ContextoPrioridade contexto) =>
      math.min(100, _dias(jogo, contexto) / 3.65); // um ano = 100 pontos

  @override
  String justificar(JogoAcervo jogo, ContextoPrioridade contexto) {
    final dias = _dias(jogo, contexto);
    if (dias == 0) return 'Chegou hoje ao acervo.';
    return 'No acervo ${Formatos.haQuanto(jogo.adicionadoEm, agora: contexto.agora)}.';
  }
}

/// Combina as outras três e dá bônus ao que já foi começado e aos
/// gêneros que o usuário mais zera.
class Equilibrada extends EstrategiaPrioridade {
  const Equilibrada();

  static const _rapida = VitoriaRapida();
  static const _obra = ObraPrima();
  static const _poeira = PoeiraNaEstante();

  @override
  String get nome => 'Equilibrada';

  @override
  String get descricao => 'Pesa duração, nota, espera e o seu gosto.';

  bool _generoFavorito(JogoAcervo jogo, ContextoPrioridade contexto) {
    if (contexto.generosFavoritos.isEmpty) return false;
    final maior = contexto.generosFavoritos.values.reduce(math.max);
    return jogo.generos.any((g) => contexto.generosFavoritos[g] == maior);
  }

  @override
  double pontuar(JogoAcervo jogo, ContextoPrioridade contexto) {
    var pontos = _rapida.pontuar(jogo, contexto) * 0.40 +
        _obra.pontuar(jogo, contexto) * 0.35 +
        _poeira.pontuar(jogo, contexto) * 0.25;
    if (jogo.status == StatusJogo.jogando) pontos += 15;
    if (_generoFavorito(jogo, contexto)) pontos += 8;
    return pontos;
  }

  @override
  String justificar(JogoAcervo jogo, ContextoPrioridade contexto) {
    if (jogo.status == StatusJogo.jogando) {
      return 'Você já começou: faltam ${Formatos.horas(jogo.horasParaTerminar)}.';
    }
    if (_generoFavorito(jogo, contexto)) {
      return '${jogo.generoPrincipal} é o gênero que você mais zera.';
    }
    // Explica pelo critério que mais pesou.
    final candidatos = <EstrategiaPrioridade>[_rapida, _obra, _poeira];
    candidatos.sort(
      (a, b) => b.pontuar(jogo, contexto).compareTo(a.pontuar(jogo, contexto)),
    );
    return candidatos.first.justificar(jogo, contexto);
  }
}
