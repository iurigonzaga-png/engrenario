import 'jogo.dart';

/// Nível de pressão do backlog, lido no manômetro da tela inicial.
enum NivelPressao {
  estavel('Estável'),
  aquecendo('Aquecendo'),
  critica('Crítica');

  const NivelPressao(this.rotulo);
  final String rotulo;
}

/// Números consolidados do acervo. Imutável: é recalculado a cada mudança.
class ResumoAcervo {
  ResumoAcervo._({
    required this.total,
    required this.porStatus,
    required this.minutosTotais,
    required this.horasPendentes,
    required this.horasSemanais,
    required this.minutosPorGenero,
    required this.zeradosPorGenero,
    required this.mediaDasNotas,
  });

  factory ResumoAcervo.de(List<JogoAcervo> jogos, double horasSemanais) {
    final porStatus = {for (final s in StatusJogo.values) s: 0};
    final minutosPorGenero = <String, int>{};
    final zeradosPorGenero = <String, int>{};
    var minutos = 0;
    var pendentes = 0.0;
    var somaNotas = 0.0;
    var notas = 0;

    for (final jogo in jogos) {
      porStatus[jogo.status] = porStatus[jogo.status]! + 1;
      minutos += jogo.minutosJogados;
      pendentes += jogo.horasParaTerminar;
      if (jogo.minutosJogados > 0) {
        minutosPorGenero.update(
          jogo.generoPrincipal,
          (v) => v + jogo.minutosJogados,
          ifAbsent: () => jogo.minutosJogados,
        );
      }
      if (jogo.status == StatusJogo.zerado) {
        for (final genero in jogo.generos) {
          zeradosPorGenero.update(genero, (v) => v + 1, ifAbsent: () => 1);
        }
        if (jogo.notaPessoal != null) {
          somaNotas += jogo.notaPessoal!;
          notas++;
        }
      }
    }

    return ResumoAcervo._(
      total: jogos.length,
      porStatus: porStatus,
      minutosTotais: minutos,
      horasPendentes: pendentes,
      horasSemanais: horasSemanais,
      minutosPorGenero: minutosPorGenero,
      zeradosPorGenero: zeradosPorGenero,
      mediaDasNotas: notas == 0 ? null : somaNotas / notas,
    );
  }

  final int total;
  final Map<StatusJogo, int> porStatus;
  final int minutosTotais;

  /// Horas que faltam somando fila e jogos em andamento.
  final double horasPendentes;
  final double horasSemanais;
  final Map<String, int> minutosPorGenero;
  final Map<String, int> zeradosPorGenero;
  final double? mediaDasNotas;

  int quantos(StatusJogo status) => porStatus[status] ?? 0;
  int get zerados => quantos(StatusJogo.zerado);
  int get pendentes => quantos(StatusJogo.fila) + quantos(StatusJogo.jogando);
  double get horasTotais => minutosTotais / 60;
  int get generosZerados => zeradosPorGenero.length;

  /// Em quantas semanas a fila acaba no ritmo configurado.
  double get semanasParaLimpar =>
      horasSemanais <= 0 ? 0 : horasPendentes / horasSemanais;

  /// Pressão de 0 a 1: um ano de fila já enche o manômetro.
  double get pressao => (semanasParaLimpar / 52).clamp(0.0, 1.0);

  NivelPressao get nivel {
    if (pressao < 0.35) return NivelPressao.estavel;
    if (pressao < 0.70) return NivelPressao.aquecendo;
    return NivelPressao.critica;
  }

  /// Gêneros ordenados por tempo jogado, do maior para o menor.
  List<MapEntry<String, int>> get generosMaisJogados =>
      minutosPorGenero.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
}
