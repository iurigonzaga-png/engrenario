import '../core/formatos.dart';
import 'resumo.dart';

/// Uma insígnia que o usuário conquista usando o app.
///
/// A classe base define o contrato; cada subclasse mede o progresso com
/// um critério diferente (herança + polimorfismo).
abstract class Conquista {
  const Conquista(this.titulo, this.descricao);

  final String titulo;
  final String descricao;

  static const List<Conquista> todas = [
    ConquistaZerados('Primeira engrenagem', 'Zere o seu primeiro jogo.', 1),
    ConquistaZerados('Mecânico de bancada', 'Zere 5 jogos.', 5),
    ConquistaZerados('Mestre relojoeiro', 'Zere 20 jogos.', 20),
    ConquistaHoras('Caldeira acesa', 'Registre 10 horas de jogo.', 10),
    ConquistaHoras('Maquinista', 'Registre 100 horas de jogo.', 100),
    ConquistaGeneros(
        'Gabinete de curiosidades', 'Zere jogos de 4 gêneros diferentes.', 4),
    ConquistaFilaSobControle('Pressão sob controle',
        'Tenha jogos pendentes e a pressão do backlog estável.'),
  ];

  /// De 0 a 1.
  double progresso(ResumoAcervo resumo);

  /// Texto do tipo "3 de 5".
  String situacao(ResumoAcervo resumo);

  bool conquistada(ResumoAcervo resumo) => progresso(resumo) >= 1;
}

class ConquistaZerados extends Conquista {
  const ConquistaZerados(super.titulo, super.descricao, this.meta);
  final int meta;

  @override
  double progresso(ResumoAcervo resumo) =>
      (resumo.zerados / meta).clamp(0.0, 1.0);

  @override
  String situacao(ResumoAcervo resumo) =>
      '${resumo.zerados > meta ? meta : resumo.zerados} de $meta';
}

class ConquistaHoras extends Conquista {
  const ConquistaHoras(super.titulo, super.descricao, this.meta);
  final double meta;

  @override
  double progresso(ResumoAcervo resumo) =>
      (resumo.horasTotais / meta).clamp(0.0, 1.0);

  @override
  String situacao(ResumoAcervo resumo) {
    final feitas = resumo.horasTotais > meta ? meta : resumo.horasTotais;
    return '${Formatos.numero(feitas)} de ${Formatos.numero(meta)} h';
  }
}

class ConquistaGeneros extends Conquista {
  const ConquistaGeneros(super.titulo, super.descricao, this.meta);
  final int meta;

  @override
  double progresso(ResumoAcervo resumo) =>
      (resumo.generosZerados / meta).clamp(0.0, 1.0);

  @override
  String situacao(ResumoAcervo resumo) =>
      '${resumo.generosZerados > meta ? meta : resumo.generosZerados} de $meta';
}

class ConquistaFilaSobControle extends Conquista {
  const ConquistaFilaSobControle(super.titulo, super.descricao);

  @override
  double progresso(ResumoAcervo resumo) {
    if (resumo.pendentes == 0) return 0;
    if (resumo.nivel == NivelPressao.estavel) return 1;
    // Quanto mais perto do limite estável (0,35), mais perto de conquistar.
    return (0.35 / resumo.pressao).clamp(0.0, 0.99);
  }

  @override
  String situacao(ResumoAcervo resumo) => resumo.pendentes == 0
      ? 'Sem jogos pendentes'
      : 'Pressão ${resumo.nivel.rotulo.toLowerCase()}';
}
