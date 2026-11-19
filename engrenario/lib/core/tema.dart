import 'package:flutter/material.dart';

/// Paleta do Engrenário: steampunk moderno, com um quê de pavilhão de
/// exposição dos anos 60. Azul-marinho profundo como base, latão amarelo
/// como destaque e aço azulado nas molduras.
class Paleta {
  Paleta._();

  // Azuis de fundo, do mais fundo ao mais elevado.
  static const abismo = Color(0xFF001624);
  static const marinho = Color(0xFF032536);
  static const painel = Color(0xFF0A2F43);
  static const painelClaro = Color(0xFF143D55);

  /// Aço azulado: molduras, filetes e trilhos inativos.
  static const aco = Color(0xFF2D5068);
  static const acoClaro = Color(0xFF4D7896);

  // Latão (o amarelo da casa): o mesmo tom dos botões. O claro só sobe um
  // pouco a luz, sem chegar no amarelo pálido.
  static const latao = Color(0xFFD3AB4E);
  static const lataoClaro = Color(0xFFDDB75A);
  static const lataoEscuro = Color(0xFF8F6A22);

  // Acentos.
  static const cobalto = Color(0xFF3E9FE0);
  static const celeste = Color(0xFF86CDFF);
  static const cobre = Color(0xFFDE8F57);
  static const brasa = Color(0xFFE8594D);

  // Texto.
  static const creme = Color(0xFFF3E6CE);
  static const nevoa = Color(0xFF9DB5C5);
}

extension CorOpacidade on Color {
  /// Mesma cor com opacidade de 0 a 1.
  Color op(double opacidade) =>
      withAlpha((opacidade.clamp(0.0, 1.0) * 255).round());
}

/// Três vozes tipográficas: letreiro (títulos art déco), texto e
/// placa (rótulos, selos e leituras de instrumento).
class Letras {
  Letras._();

  static TextStyle gravacao(double tamanho, {Color cor = Paleta.latao}) =>
      TextStyle(
        fontFamily: 'Limelight',
        // A Limelight é mais larga que um texto comum: compensa um pouco.
        fontSize: tamanho * 0.9,
        height: 1.1,
        letterSpacing: 0.4,
        color: cor,
      );

  static TextStyle texto(
    double tamanho, {
    Color cor = Paleta.creme,
    FontWeight peso = FontWeight.w400,
    FontStyle estilo = FontStyle.normal,
  }) =>
      TextStyle(
        fontFamily: 'SourceSerif4',
        // Olho maior que o da fonte antiga: mesmo corpo visual, menos pontos.
        fontSize: tamanho * 0.92,
        height: 1.4,
        color: cor,
        fontWeight: peso,
        fontStyle: estilo,
      );

  static TextStyle maquina(double tamanho, {Color cor = Paleta.creme}) =>
      TextStyle(
        fontFamily: 'JosefinSans',
        fontSize: tamanho,
        height: 1.2,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
        color: cor,
      );
}

ThemeData temaEngrenario() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Paleta.abismo,
    fontFamily: 'SourceSerif4',
    colorScheme: const ColorScheme.dark(
      primary: Paleta.latao,
      onPrimary: Paleta.abismo,
      secondary: Paleta.cobalto,
      onSecondary: Paleta.abismo,
      surface: Paleta.marinho,
      onSurface: Paleta.creme,
      error: Paleta.brasa,
      onError: Paleta.creme,
    ),
    splashColor: Paleta.celeste.op(0.10),
    highlightColor: Paleta.celeste.op(0.05),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Paleta.creme,
      displayColor: Paleta.creme,
      fontFamily: 'SourceSerif4',
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Paleta.latao,
      selectionColor: Paleta.cobalto.op(0.4),
      selectionHandleColor: Paleta.latao,
    ),
  );
}

/// Decoração padrão dos campos de formulário.
InputDecoration campoDecorado(String rotulo, {String? ajuda, String? sufixo}) {
  OutlineInputBorder borda(Color c, [double l = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: c, width: l),
      );
  return InputDecoration(
    labelText: rotulo,
    helperText: ajuda,
    helperMaxLines: 2,
    suffixText: sufixo,
    filled: true,
    fillColor: Paleta.abismo.op(0.7),
    labelStyle: Letras.texto(17, cor: Paleta.nevoa),
    floatingLabelStyle: Letras.texto(17, cor: Paleta.latao),
    helperStyle: Letras.texto(14, cor: Paleta.nevoa),
    suffixStyle: Letras.maquina(14, cor: Paleta.nevoa),
    errorStyle: Letras.texto(14, cor: Paleta.brasa),
    errorMaxLines: 3,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: borda(Paleta.aco),
    focusedBorder: borda(Paleta.latao, 1.6),
    errorBorder: borda(Paleta.brasa),
    focusedErrorBorder: borda(Paleta.brasa, 1.6),
  );
}

/// Mostra um aviso curto no rodapé.
void avisar(BuildContext context, String mensagem, {bool erro = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: erro ? const Color(0xFF3A1620) : Paleta.painelClaro,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: erro ? Paleta.brasa : Paleta.latao),
        ),
        content: Text(mensagem, style: Letras.texto(16)),
      ),
    );
}
