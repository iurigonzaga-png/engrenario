import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../models/jogo.dart';
import 'capa.dart';
import 'placa.dart';

/// Linha de um jogo do acervo: capa, nome, situação e progresso.
class CartaoJogo extends StatelessWidget {
  const CartaoJogo({
    super.key,
    required this.jogo,
    required this.heroTag,
    this.onTap,
    this.rodape,
  });

  final JogoAcervo jogo;
  final String heroTag;
  final VoidCallback? onTap;

  /// Linha extra abaixo da legenda (ex.: motivo de uma recomendação).
  final Widget? rodape;

  @override
  Widget build(BuildContext context) {
    final mostraCano = jogo.status == StatusJogo.jogando;
    return Placa(
      rebites: false,
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: heroTag,
            child: CapaJogo(url: jogo.capaUrl, largura: 104, altura: 78),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jogo.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Letras.texto(19, peso: FontWeight.w600)
                      .copyWith(height: 1.15),
                ),
                const SizedBox(height: 4),
                Text(
                  jogo.legenda,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Letras.texto(15.5, cor: Paleta.nevoa),
                ),
                const SizedBox(height: 8),
                if (mostraCano)
                  CanoProgresso(
                    valor: jogo.progresso,
                    altura: 9,
                    cor: Paleta.celeste,
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Selo.status(jogo.status),
                  ),
                if (rodape != null) ...[const SizedBox(height: 8), rodape!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
