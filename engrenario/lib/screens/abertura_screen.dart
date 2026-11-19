import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/acervo_controller.dart';
import '../core/tema.dart';
import '../widgets/engrenagem.dart';
import '../widgets/placa.dart';
import '../widgets/raios.dart';
import 'principal_screen.dart';

/// Tela de abertura: as engrenagens engatam enquanto o acervo é carregado.
class AberturaScreen extends StatefulWidget {
  const AberturaScreen({super.key});

  @override
  State<AberturaScreen> createState() => _AberturaScreenState();
}

class _AberturaScreenState extends State<AberturaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacao = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  bool _iniciou = false;
  String? _falha;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iniciou) {
      _iniciou = true;
      _preparar();
    }
  }

  Future<void> _preparar() async {
    final acervo = Acervo.ler(context);
    final semMovimento = MediaQuery.of(context).disableAnimations;
    if (_falha != null) setState(() => _falha = null);
    if (semMovimento) {
      _animacao.value = 1;
    } else {
      _animacao.forward(from: 0);
    }
    // Carrega o banco e, em paralelo, deixa a animação terminar.
    await Future.wait([
      acervo.carregar(),
      Future<void>.delayed(
        semMovimento ? Duration.zero : const Duration(milliseconds: 1900),
      ),
    ]);
    if (!mounted) return;
    if (acervo.falha != null) {
      setState(() => _falha = acervo.falha);
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const PrincipalScreen(),
        transitionsBuilder: (_, animacao, __, filho) =>
            FadeTransition(opacity: animacao, child: filho),
      ),
    );
  }

  @override
  void dispose() {
    _animacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_falha != null) {
      return Scaffold(
        body: EstadoVazio(
          icone: Icons.error_outline,
          titulo: 'A oficina não abriu',
          mensagem: '$_falha Confira a API e tente de novo.',
          acao: 'Tentar de novo',
          aoTocar: _preparar,
        ),
      );
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _animacao,
            builder: (context, _) => LayoutBuilder(
              builder: (context, limites) => CustomPaint(
                painter: RaiosPainter(
                  centro: Offset(
                    limites.maxWidth / 2 - 40,
                    limites.maxHeight / 2 - 61,
                  ),
                  giro: Curves.easeInOutCubic.transform(_animacao.value) * 0.3,
                  intensidade: Curves.easeOut.transform(_animacao.value),
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _animacao,
              builder: (context, _) {
                final t = _animacao.value;
                final giro = Curves.easeInOutCubic.transform(t) * math.pi * 1.5;
                final chegada =
                    Curves.easeOutBack.transform((t / 0.45).clamp(0.0, 1.0));
                final titulo = Curves.easeOut
                    .transform(((t - 0.35) / 0.5).clamp(0.0, 1.0));
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 210,
                      height: 150,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Transform.scale(
                              scale: chegada,
                              child: Engrenagem(
                                tamanho: 130,
                                dentes: 16,
                                angulo: giro,
                              ),
                            ),
                          ),
                          // 16 e 8 dentes: a menor gira ao contrário, em dobro.
                          Positioned(
                            left: 65 + 79.4 - 32.5,
                            top: 65 + 45.8 - 32.5,
                            child: Transform.scale(
                              scale: chegada,
                              child: Engrenagem(
                                tamanho: 65,
                                dentes: 8,
                                cor: Paleta.cobalto,
                                angulo: -giro * 2 + math.pi / 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    Opacity(
                      opacity: titulo,
                      child: Transform.translate(
                        offset: Offset(0, (1 - titulo) * 16),
                        child: Column(
                          children: [
                            Text('Engrenário', style: Letras.gravacao(46)),
                            const SizedBox(height: 6),
                            Text(
                              'Acendendo a caldeira',
                              style: Letras.texto(17, cor: Paleta.nevoa),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
