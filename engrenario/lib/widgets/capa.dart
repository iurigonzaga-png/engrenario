import 'package:flutter/material.dart';

import '../core/tema.dart';
import 'engrenagem.dart';

/// Capa de um jogo carregada da internet, com moldura de latão.
///
/// Pede à RAWG uma versão reduzida da imagem; se ela falhar, tenta a
/// original e, por último, mostra uma engrenagem no lugar.
class CapaJogo extends StatefulWidget {
  const CapaJogo({
    super.key,
    required this.url,
    this.largura,
    this.altura,
    this.moldura = true,
    this.raio = 4,
  });

  final String? url;
  final double? largura;
  final double? altura;
  final bool moldura;
  final double raio;

  @override
  State<CapaJogo> createState() => _CapaJogoState();
}

class _CapaJogoState extends State<CapaJogo> {
  bool _usarOriginal = false;

  @override
  void didUpdateWidget(CapaJogo antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.url != widget.url) _usarOriginal = false;
  }

  /// media.rawg.io/media/games/x.jpg -> media.rawg.io/media/crop/600/400/games/x.jpg
  String? get _endereco {
    final url = widget.url;
    if (url == null || url.isEmpty) return null;
    const marca = 'media.rawg.io/media/';
    if (_usarOriginal || !url.contains(marca) || url.contains('/crop/')) {
      return url;
    }
    return url.replaceFirst(marca, '${marca}crop/600/400/');
  }

  Widget _reserva() => Container(
        color: Paleta.painelClaro,
        alignment: Alignment.center,
        child: const Opacity(
          opacity: 0.5,
          child: Engrenagem(tamanho: 34, dentes: 10, cor: Paleta.aco),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final endereco = _endereco;
    final imagem = endereco == null
        ? _reserva()
        : Image.network(
            endereco,
            key: ValueKey(endereco),
            fit: BoxFit.cover,
            width: widget.largura,
            height: widget.altura,
            gaplessPlayback: true,
            frameBuilder: (context, filho, quadro, sincrono) {
              if (sincrono) return filho;
              return AnimatedOpacity(
                opacity: quadro == null ? 0 : 1,
                duration: const Duration(milliseconds: 350),
                child: filho,
              );
            },
            errorBuilder: (context, erro, pilha) {
              if (!_usarOriginal && endereco != widget.url) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _usarOriginal = true);
                });
              }
              return _reserva();
            },
          );
    return Container(
      width: widget.largura,
      height: widget.altura,
      decoration: BoxDecoration(
        color: Paleta.painelClaro,
        borderRadius: BorderRadius.circular(widget.raio),
      ),
      foregroundDecoration: widget.moldura
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(widget.raio),
              border: Border.all(color: Paleta.aco, width: 1.2),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: ExcludeSemantics(child: imagem),
    );
  }
}
