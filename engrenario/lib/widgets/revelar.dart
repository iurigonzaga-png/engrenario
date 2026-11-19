import 'package:flutter/material.dart';

/// Constrói o filho com uma animação que só começa quando o widget
/// entra na área visível durante a rolagem.
///
/// Funciona dentro de qualquer lista rolável: escuta a posição do scroll
/// e compara com a própria posição na tela.
class RevelarBuilder extends StatefulWidget {
  const RevelarBuilder({
    super.key,
    required this.builder,
    this.duracao = const Duration(milliseconds: 700),
    this.atraso = Duration.zero,
    this.curva = Curves.easeOutCubic,
  });

  final Widget Function(BuildContext context, Animation<double> animacao)
      builder;
  final Duration duracao;
  final Duration atraso;
  final Curve curva;

  @override
  State<RevelarBuilder> createState() => _RevelarBuilderState();
}

class _RevelarBuilderState extends State<RevelarBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle =
      AnimationController(vsync: this, duration: widget.duracao);
  late final Animation<double> _animacao =
      CurvedAnimation(parent: _controle, curve: widget.curva);

  // Todas as áreas roláveis acima deste widget (vertical e horizontal).
  List<ScrollPosition> _posicoes = const [];
  bool _disparou = false;
  Size _tela = const Size(400, 800);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final midia = MediaQuery.of(context);
    _tela = midia.size;

    if (midia.disableAnimations) {
      // Menos movimento: mostra tudo de uma vez.
      _disparou = true;
      _controle.value = 1;
      _soltar();
      return;
    }

    final novas = <ScrollPosition>[];
    var rolavel = Scrollable.maybeOf(context);
    while (rolavel != null) {
      novas.add(rolavel.position);
      rolavel = Scrollable.maybeOf(rolavel.context);
    }
    _soltar();
    _posicoes = novas;
    if (!_disparou) {
      for (final p in _posicoes) {
        p.addListener(_verificar);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificar());
  }

  void _soltar() {
    for (final p in _posicoes) {
      p.removeListener(_verificar);
    }
    _posicoes = const [];
  }

  void _verificar() {
    if (_disparou || !mounted) return;
    final caixa = context.findRenderObject();
    if (caixa is! RenderBox || !caixa.attached || !caixa.hasSize) return;
    final canto = caixa.localToGlobal(Offset.zero);
    // Dispara quando o topo do widget passa de 92% da altura da tela
    // (e, em listas horizontais, quando ele entra pela lateral).
    if (canto.dy < _tela.height * 0.92 && canto.dx < _tela.width) {
      _disparou = true;
      _soltar();
      Future.delayed(widget.atraso, () {
        if (mounted) _controle.forward();
      });
    }
  }

  @override
  void dispose() {
    _soltar();
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _animacao);
}

/// Revela o filho subindo e ganhando opacidade ao entrar na tela.
class Revelar extends StatelessWidget {
  const Revelar({
    super.key,
    required this.child,
    this.atraso = Duration.zero,
    this.deslocamento = const Offset(0, 28),
  });

  final Widget child;
  final Duration atraso;
  final Offset deslocamento;

  @override
  Widget build(BuildContext context) => RevelarBuilder(
        atraso: atraso,
        builder: (context, animacao) => AnimatedBuilder(
          animation: animacao,
          child: child,
          builder: (context, filho) => Opacity(
            opacity: animacao.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: deslocamento * (1 - animacao.value),
              child: filho,
            ),
          ),
        ),
      );
}
