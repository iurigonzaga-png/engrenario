import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Leque de raios art déco saindo de [centro], com anéis concêntricos
/// finos. Fica atrás das engrenagens, bem discreto.
class RaiosPainter extends CustomPainter {
  const RaiosPainter({
    required this.centro,
    this.giro = 0,
    this.intensidade = 1,
    this.quantidade = 36,
  });

  final Offset centro;

  /// Rotação lenta do leque (radianos).
  final double giro;

  /// De 0 a 1: multiplica a opacidade de tudo.
  final double intensidade;
  final int quantidade;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensidade <= 0) return;
    final alcance = size.longestSide * 1.6;
    final passo = 2 * math.pi / quantidade;

    // Brilho cobalto no centro do leque.
    canvas.drawCircle(
      centro,
      alcance * 0.35,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Paleta.cobalto.op(0.22 * intensidade),
            Paleta.cobalto.op(0),
          ],
        ).createShader(Rect.fromCircle(center: centro, radius: alcance * 0.35)),
    );

    // Raios: fatias alternadas, que somem com a distância.
    final fatia = Paint()
      ..shader = RadialGradient(
        colors: [
          Paleta.celeste.op(0.10 * intensidade),
          Paleta.celeste.op(0.03 * intensidade),
          Paleta.celeste.op(0),
        ],
        stops: const [0, 0.3, 0.7],
      ).createShader(Rect.fromCircle(center: centro, radius: alcance));
    final raios = Path();
    for (var i = 0; i < quantidade; i += 2) {
      final a = giro + i * passo;
      raios
        ..moveTo(centro.dx, centro.dy)
        ..lineTo(
          centro.dx + alcance * math.cos(a),
          centro.dy + alcance * math.sin(a),
        )
        ..lineTo(
          centro.dx + alcance * math.cos(a + passo * 0.55),
          centro.dy + alcance * math.sin(a + passo * 0.55),
        )
        ..close();
    }
    canvas.drawPath(raios, fatia);

    // Anéis concêntricos, cada vez mais apagados.
    for (var k = 1; k <= 4; k++) {
      canvas.drawCircle(
        centro,
        150.0 + k * 62,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Paleta.latao.op((0.16 - k * 0.03) * intensidade),
      );
    }
  }

  @override
  bool shouldRepaint(RaiosPainter antigo) =>
      antigo.centro != centro ||
      antigo.giro != giro ||
      antigo.intensidade != intensidade ||
      antigo.quantidade != quantidade;
}
