import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Desenha uma engrenagem de linhas limpas: dentes de ponta arredondada,
/// aro gravado, raios vazados e cubo com parafusos.
///
/// O perfil dos dentes (raio externo, raio de base e passo) segue o mesmo
/// das versões anteriores, então pares já posicionados continuam encaixando.
class EngrenagemPainter extends CustomPainter {
  const EngrenagemPainter({
    required this.angulo,
    this.dentes = 12,
    this.cor = Paleta.latao,
    int? raios,
  }) : raios = raios ?? (dentes >= 14 ? 6 : (dentes >= 10 ? 5 : 4));

  final double angulo;
  final int dentes;
  final Color cor;

  /// Quantidade de raios ligando o cubo ao aro.
  final int raios;

  @override
  void paint(Canvas canvas, Size size) {
    final raio = size.shortestSide / 2;
    final interno = raio * 0.82;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angulo);

    Offset polar(double r, double a) =>
        Offset(r * math.cos(a), r * math.sin(a));

    // Contorno dos dentes: flancos retos, topo e fundo em arco.
    final passo = 2 * math.pi / dentes;
    final contorno = Path();
    for (var i = 0; i < dentes; i++) {
      final a = i * passo;
      final p1 = polar(interno, a - passo * 0.27);
      final p2 = polar(raio, a - passo * 0.13);
      final p3 = polar(raio, a + passo * 0.13);
      final p4 = polar(interno, a + passo * 0.27);
      final proximo = polar(interno, a + passo - passo * 0.27);
      if (i == 0) contorno.moveTo(p1.dx, p1.dy);
      contorno
        ..lineTo(p2.dx, p2.dy)
        ..arcToPoint(p3, radius: Radius.circular(raio))
        ..lineTo(p4.dx, p4.dy)
        ..arcToPoint(proximo, radius: Radius.circular(interno));
    }
    contorno.close();

    // Janelas entre os raios e os furos do cubo.
    final aroInterno = raio * 0.60;
    final cubo = raio * 0.27;
    final meiaLargura = raio * 0.075;
    final vazados = Path();
    for (var k = 0; k < raios; k++) {
      final a0 = k * 2 * math.pi / raios;
      final a1 = (k + 1) * 2 * math.pi / raios;
      // Desconta a largura do raio (constante) em cada borda da janela.
      final folgaFora = math.asin(meiaLargura / aroInterno);
      final folgaDentro = math.asin(math.min(1.0, meiaLargura / cubo));
      final f1 = polar(aroInterno, a0 + folgaFora);
      final f2 = polar(aroInterno, a1 - folgaFora);
      final d2 = polar(cubo, a1 - folgaDentro);
      final d1 = polar(cubo, a0 + folgaDentro);
      vazados
        ..moveTo(f1.dx, f1.dy)
        ..arcToPoint(f2, radius: Radius.circular(aroInterno))
        ..lineTo(d2.dx, d2.dy)
        ..arcToPoint(d1, radius: Radius.circular(cubo), clockwise: false)
        ..close();
    }
    vazados.addOval(Rect.fromCircle(center: Offset.zero, radius: raio * 0.085));
    final corpo = Path.combine(PathOperation.difference, contorno, vazados);

    final area = Rect.fromCircle(center: Offset.zero, radius: raio);
    final escuro = Color.lerp(cor, Paleta.abismo, 0.55)!;
    canvas.drawPath(
      corpo,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(cor, Colors.white, 0.28)!,
            cor,
            Color.lerp(cor, Paleta.abismo, 0.35)!,
          ],
          stops: const [0, 0.5, 1],
        ).createShader(area),
    );
    canvas.drawPath(
      corpo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, raio * 0.018)
        ..color = escuro,
    );

    // Aro gravado (dois filetes) e anel do cubo.
    final filete = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, raio * 0.016)
      ..color = escuro.op(0.75);
    canvas
      ..drawCircle(Offset.zero, raio * 0.72, filete)
      ..drawCircle(Offset.zero, raio * 0.17, filete);
    canvas.drawCircle(
      Offset.zero,
      raio * 0.765,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, raio * 0.01)
        ..color = Colors.white.op(0.22),
    );

    // Parafusos do cubo, alinhados entre os raios.
    if (raio > 20) {
      for (var k = 0; k < raios; k++) {
        final a = (k + 0.5) * 2 * math.pi / raios;
        canvas.drawCircle(
          polar(raio * 0.215, a),
          raio * 0.022,
          Paint()..color = escuro,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(EngrenagemPainter antigo) =>
      antigo.angulo != angulo ||
      antigo.dentes != dentes ||
      antigo.cor != cor ||
      antigo.raios != raios;
}

/// Engrenagem parada em um ângulo (use [angulo] para ligá-la ao scroll).
class Engrenagem extends StatelessWidget {
  const Engrenagem({
    super.key,
    required this.tamanho,
    this.angulo = 0,
    this.dentes = 12,
    this.cor = Paleta.latao,
  });

  final double tamanho;
  final double angulo;
  final int dentes;
  final Color cor;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.square(tamanho),
          painter: EngrenagemPainter(angulo: angulo, dentes: dentes, cor: cor),
        ),
      );
}

/// Engrenagem que gira sozinha, sem parar (carregamentos e detalhes).
class EngrenagemGirando extends StatefulWidget {
  const EngrenagemGirando({
    super.key,
    required this.tamanho,
    this.dentes = 12,
    this.cor = Paleta.latao,
    this.periodo = const Duration(seconds: 6),
    this.horario = true,
  });

  final double tamanho;
  final int dentes;
  final Color cor;
  final Duration periodo;
  final bool horario;

  @override
  State<EngrenagemGirando> createState() => _EngrenagemGirandoState();
}

class _EngrenagemGirandoState extends State<EngrenagemGirando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giro =
      AnimationController(vsync: this, duration: widget.periodo);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeita a preferência do sistema por menos movimento.
    if (MediaQuery.of(context).disableAnimations) {
      _giro.stop();
    } else if (!_giro.isAnimating) {
      _giro.repeat();
    }
  }

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _giro,
        builder: (context, _) => Engrenagem(
          tamanho: widget.tamanho,
          dentes: widget.dentes,
          cor: widget.cor,
          angulo: (widget.horario ? 1 : -1) * _giro.value * 2 * math.pi,
        ),
      );
}

/// Indicador de carregamento: duas engrenagens encaixadas.
class Carregando extends StatelessWidget {
  const Carregando({super.key, this.mensagem});
  final String? mensagem;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 92,
              height: 60,
              child: Stack(
                children: const [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: EngrenagemGirando(
                      tamanho: 56,
                      periodo: Duration(seconds: 4),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: EngrenagemGirando(
                      tamanho: 38,
                      dentes: 8,
                      cor: Paleta.cobalto,
                      periodo: Duration(milliseconds: 2667),
                      horario: false,
                    ),
                  ),
                ],
              ),
            ),
            if (mensagem != null) ...[
              const SizedBox(height: 16),
              Text(mensagem!, style: Letras.texto(17, cor: Paleta.nevoa)),
            ],
          ],
        ),
      );
}
