import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Faixa de texto que corre sem parar na horizontal.
class Letreiro extends StatefulWidget {
  const Letreiro({
    super.key,
    required this.itens,
    this.altura = 44,
    this.velocidade = 36,
    this.estilo,
  });

  final List<String> itens;
  final double altura;

  /// Pixels por segundo.
  final double velocidade;
  final TextStyle? estilo;

  @override
  State<Letreiro> createState() => _LetreiroState();
}

class _LetreiroState extends State<Letreiro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controle = AnimationController(vsync: this);
  double _larguraDoBloco = 0;

  TextStyle get _estilo => widget.estilo ?? Letras.gravacao(20);

  String get _texto => widget.itens.map((i) => '$i   •   ').join();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _medir();
  }

  @override
  void didUpdateWidget(Letreiro antigo) {
    super.didUpdateWidget(antigo);
    _medir();
  }

  void _medir() {
    final pintor = TextPainter(
      text: TextSpan(text: _texto, style: _estilo),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final largura = pintor.width;
    pintor.dispose();
    if (largura <= 0) return;
    if (largura != _larguraDoBloco) {
      _larguraDoBloco = largura;
      _controle.stop();
      _controle.duration = Duration(
        milliseconds: (largura / widget.velocidade * 1000).round(),
      );
    }
    if (MediaQuery.of(context).disableAnimations) {
      _controle.stop();
    } else if (!_controle.isAnimating) {
      _controle.repeat();
    }
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;
    final copias =
        _larguraDoBloco <= 0 ? 2 : (larguraTela / _larguraDoBloco).ceil() + 1;
    return Container(
      height: widget.altura,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E4A73), Color(0xFF093A5C)],
        ),
        border: Border.symmetric(
          horizontal: BorderSide(color: Paleta.latao.op(0.7)),
        ),
      ),
      child: ClipRect(
        child: ExcludeSemantics(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 0,
            maxWidth: double.infinity,
            child: AnimatedBuilder(
              animation: _controle,
              builder: (context, filho) => Transform.translate(
                offset: Offset(-_controle.value * _larguraDoBloco, 0),
                child: filho,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < copias; i++)
                    Text(_texto, style: _estilo, maxLines: 1, softWrap: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
