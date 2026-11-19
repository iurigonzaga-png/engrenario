/// Funções de formatação usadas em todo o app (sem dependências externas).
class Formatos {
  Formatos._();

  static const _meses = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  /// 90 minutos -> "1 h 30 min"
  static String minutos(int total) {
    if (total <= 0) return '0 min';
    final h = total ~/ 60;
    final m = total % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h h';
    return '$h h $m min';
  }

  /// 12.5 -> "12 h 30 min"
  static String horas(double h) => minutos((h * 60).round());

  /// 12.5 -> "12,5" ; 12.0 -> "12"
  static String numero(double v, {int casas = 1}) {
    final texto = v.toStringAsFixed(casas).replaceAll('.', ',');
    if (texto.contains(',')) {
      return texto.replaceFirst(RegExp(r',?0+$'), '');
    }
    return texto;
  }

  static String data(DateTime d) => '${d.day} ${_meses[d.month - 1]} ${d.year}';

  static String dataCurta(DateTime d) => '${d.day} ${_meses[d.month - 1]}';

  /// Texto relativo: "hoje", "ontem", "há 5 dias".
  static String haQuanto(DateTime d, {DateTime? agora}) {
    final a = agora ?? DateTime.now();
    final dias = DateTime(a.year, a.month, a.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (dias <= 0) return 'hoje';
    if (dias == 1) return 'ontem';
    if (dias < 30) return 'há $dias dias';
    if (dias < 365) {
      final meses = dias ~/ 30;
      return meses == 1 ? 'há 1 mês' : 'há $meses meses';
    }
    final anos = dias ~/ 365;
    return anos == 1 ? 'há 1 ano' : 'há $anos anos';
  }

  static String semanas(double s) {
    if (s < 1) return 'menos de uma semana';
    final n = s.ceil();
    if (n < 9) return n == 1 ? '1 semana' : '$n semanas';
    final meses = (s / 4.345).round();
    if (meses < 24) return '$meses meses';
    return '${numero(s / 52)} anos';
  }
}
