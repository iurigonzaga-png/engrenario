import '../core/erros.dart';

/// Uma sessão de jogo: quanto tempo foi jogado em um dia.
class Sessao {
  Sessao({
    this.id,
    required this.jogoId,
    required this.data,
    required int minutos,
    this.comentario,
  }) : _minutos = _validar(minutos);

  factory Sessao.fromMap(Map<String, Object?> m) => Sessao(
        id: m['id'] as int?,
        jogoId: m['jogo_id'] as int,
        data: DateTime.parse(m['data'] as String),
        minutos: m['minutos'] as int,
        comentario: m['comentario'] as String?,
      );

  static const int minimoMinutos = 5;
  static const int maximoMinutos = 16 * 60;

  int? id;
  final int jogoId;
  final DateTime data;
  final String? comentario;
  final int _minutos;

  int get minutos => _minutos;

  static int _validar(int minutos) {
    if (minutos < minimoMinutos || minutos > maximoMinutos) {
      throw const RegraDeNegocio(
        'Uma sessão dura de 5 minutos a 16 horas.',
      );
    }
    return minutos;
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'jogo_id': jogoId,
        'data': data.toIso8601String(),
        'minutos': _minutos,
        'comentario': comentario,
      };
}
