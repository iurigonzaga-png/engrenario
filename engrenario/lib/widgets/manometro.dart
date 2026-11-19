import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Manômetro com aro de latão e mostrador azul. Mostra um valor de 0 a 1 em um mostrador com
/// três faixas (estável, aquecendo e crítica).
///
/// O ponteiro acompanha [entrada] (para a varredura ao aparecer na tela)
/// e treme de leve quando a pressão está alta.
class Manometro extends StatefulWidget {
  const Manometro({
    super.key,
    required this.valor,
    this.entrada,
    this.tamanho = 240,
    this.marcas = const ['0', '13', '26', '39', '52'],
    this.unidade = 'semanas',
  });

  final double valor;
  final Animation<double>? entrada;
  final double tamanho;

  /// Rótulos distribuídos ao longo da escala.
  final List<String> marcas;
  final String unidade;

  @override
  State<Manometro> createState() => _ManometroState();
}

class _ManometroState extends State<Manometro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tremor = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ajustarTremor();
  }

  @override
  void didUpdateWidget(Manometro antigo) {
    super.didUpdateWidget(antigo);
    _ajustarTremor();
  }

  void _ajustarTremor() {
    final parado = MediaQuery.of(context).disableAnimations;
    if (!parado && widget.valor >= 0.35) {
      if (!_tremor.isAnimating) _tremor.repeat();
    } else {
      _tremor.stop();
    }
  }

  @override
  void dispose() {
    _tremor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entrada = widget.entrada ?? const AlwaysStoppedAnimation(1.0);
    return TweenAnimationBuilder<double>(
      // Anima suavemente quando o valor muda (ex.: ao zerar um jogo).
      tween: Tween(end: widget.valor.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, alvo, _) => AnimatedBuilder(
        animation: Listenable.merge([entrada, _tremor]),
        builder: (context, _) {
          final amplitude = alvo < 0.35 ? 0.0 : (alvo - 0.3) * 0.012;
          final tremor = math.sin(_tremor.value * 2 * math.pi * 3) * amplitude;
          final leitura =
              (alvo * entrada.value + tremor * entrada.value).clamp(0.0, 1.03);
          return CustomPaint(
            size: Size.square(widget.tamanho),
            painter: _ManometroPainter(
              leitura: leitura,
              marcas: widget.marcas,
              unidade: widget.unidade,
            ),
          );
        },
      ),
    );
  }
}

class _ManometroPainter extends CustomPainter {
  _ManometroPainter({
    required this.leitura,
    required this.marcas,
    required this.unidade,
  });

  final double leitura;
  final List<String> marcas;
  final String unidade;

  static const _inicio = math.pi * 0.75; // 135 graus
  static const _varredura = math.pi * 1.5; // 270 graus
  static const _mostrador = Color(0xFF072B40);
  static const _tinta = Paleta.creme;

  double _anguloDe(double v) => _inicio + _varredura * v;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final raio = size.shortestSide / 2;
    final area = Rect.fromCircle(center: centro, radius: raio);

    // Sombra e aro de latão.
    canvas.drawCircle(
      centro.translate(0, raio * 0.04),
      raio * 0.98,
      Paint()
        ..color = Colors.black.op(0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, raio * 0.08),
    );
    canvas.drawCircle(
      centro,
      raio * 0.98,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Paleta.lataoClaro,
            Paleta.lataoEscuro,
            Paleta.latao,
            Paleta.lataoClaro,
            Paleta.lataoEscuro,
            Paleta.latao,
            Paleta.lataoClaro,
          ],
        ).createShader(area),
    );
    canvas.drawCircle(
      centro,
      raio * 0.87,
      Paint()..color = Paleta.abismo,
    );

    // Mostrador azul-noite.
    final raioFace = raio * 0.84;
    canvas.drawCircle(
      centro,
      raioFace,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF0F3F5E), _mostrador, Color(0xFF021C2B)],
          stops: [0, 0.7, 1],
        ).createShader(Rect.fromCircle(center: centro, radius: raioFace)),
    );

    // Faixas de pressão.
    final raioFaixa = raioFace * 0.80;
    final faixa = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = raioFace * 0.085;
    void arco(double de, double ate, Color cor) => canvas.drawArc(
          Rect.fromCircle(center: centro, radius: raioFaixa),
          _anguloDe(de),
          _varredura * (ate - de),
          false,
          faixa..color = cor,
        );
    arco(0, 0.35, Paleta.cobalto);
    arco(0.35, 0.70, Paleta.latao);
    arco(0.70, 1, Paleta.brasa);

    // Traços da escala.
    final traco = Paint()
      ..color = _tinta
      ..strokeCap = StrokeCap.butt;
    const divisoes = 40;
    for (var i = 0; i <= divisoes; i++) {
      final a = _anguloDe(i / divisoes);
      final grande = i % 10 == 0;
      final medio = i % 5 == 0;
      final dir = Offset(math.cos(a), math.sin(a));
      final fora = raioFace * 0.93;
      final dentro = raioFace * (grande ? 0.70 : (medio ? 0.80 : 0.86));
      canvas.drawLine(
        centro + dir * dentro,
        centro + dir * fora,
        traco..strokeWidth = grande ? raio * 0.016 : raio * 0.008,
      );
    }

    // Números da escala.
    for (var i = 0; i < marcas.length; i++) {
      final v = marcas.length == 1 ? 0.0 : i / (marcas.length - 1);
      final a = _anguloDe(v);
      final pos = centro + Offset(math.cos(a), math.sin(a)) * (raioFace * 0.57);
      _escrever(canvas, marcas[i], pos, raio * 0.12, _tinta);
    }
    _escrever(
      canvas,
      unidade,
      centro.translate(0, raioFace * 0.52),
      raio * 0.095,
      Paleta.nevoa,
    );

    // Ponteiro.
    final a = _anguloDe(leitura);
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.rotate(a);
    final ponteiro = Path()
      ..moveTo(-raioFace * 0.18, -raio * 0.028)
      ..lineTo(raioFace * 0.78, -raio * 0.006)
      ..lineTo(raioFace * 0.84, 0)
      ..lineTo(raioFace * 0.78, raio * 0.006)
      ..lineTo(-raioFace * 0.18, raio * 0.028)
      ..close();
    canvas.drawPath(
      ponteiro.shift(Offset(raio * 0.012, raio * 0.02)),
      Paint()..color = Colors.black.op(0.45),
    );
    canvas.drawPath(ponteiro, Paint()..color = Paleta.lataoClaro);
    canvas.restore();

    // Eixo do ponteiro.
    canvas.drawCircle(
      centro,
      raio * 0.085,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.4),
          colors: [Paleta.lataoClaro, Paleta.latao, Paleta.lataoEscuro],
        ).createShader(Rect.fromCircle(center: centro, radius: raio * 0.085)),
    );
    canvas.drawCircle(centro, raio * 0.025, Paint()..color = Paleta.abismo);

    // Reflexo do vidro.
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: raioFace * 0.94),
      math.pi * 1.15,
      math.pi * 0.42,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = raio * 0.02
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.op(0.12),
    );
  }

  void _escrever(
    Canvas canvas,
    String texto,
    Offset centro,
    double tamanho,
    Color cor,
  ) {
    final pintor = TextPainter(
      text: TextSpan(text: texto, style: Letras.maquina(tamanho, cor: cor)),
      textDirection: TextDirection.ltr,
    )..layout();
    pintor.paint(
      canvas,
      centro - Offset(pintor.width / 2, pintor.height / 2),
    );
    pintor.dispose();
  }

  @override
  bool shouldRepaint(_ManometroPainter antigo) =>
      antigo.leitura != leitura ||
      antigo.unidade != unidade ||
      antigo.marcas != marcas;
}
