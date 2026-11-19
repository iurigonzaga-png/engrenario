import 'package:flutter/material.dart';

import '../controllers/acervo_controller.dart';
import '../core/rotas.dart';
import '../core/tema.dart';
import '../models/jogo.dart';
import '../widgets/cartao_jogo.dart';
import '../widgets/placa.dart';
import '../widgets/revelar.dart';
import 'detalhe_screen.dart';
import 'formularios.dart';

/// Lista completa do acervo, com filtro por situação e por nome.
class AcervoScreen extends StatefulWidget {
  const AcervoScreen({super.key, required this.aoProcurar});

  /// Abre a busca no catálogo.
  final VoidCallback aoProcurar;

  @override
  State<AcervoScreen> createState() => _AcervoScreenState();
}

class _AcervoScreenState extends State<AcervoScreen> {
  final _campo = TextEditingController();
  StatusJogo? _filtro;
  String _nome = '';

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final acervo = Acervo.of(context);
    final resumo = acervo.resumo;
    final termo = _nome.toLowerCase();
    final visiveis = acervo.jogos.where((j) {
      if (_filtro != null && j.status != _filtro) return false;
      return termo.isEmpty || j.nome.toLowerCase().contains(termo);
    }).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Text('Acervo', style: Letras.gravacao(40)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
            child: Text(
              resumo.total == 0
                  ? 'Nenhum jogo guardado ainda.'
                  : resumo.total == 1
                      ? '1 jogo guardado.'
                      : '${resumo.total} jogos guardados.',
              style: Letras.texto(17, cor: Paleta.nevoa),
            ),
          ),
          if (resumo.total > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: _campo,
                onChanged: (t) => setState(() => _nome = t.trim()),
                style: Letras.texto(18),
                cursorColor: Paleta.latao,
                decoration: campoDecorado('Filtrar pelo nome').copyWith(
                  prefixIcon:
                      const Icon(Icons.filter_list, color: Paleta.latao),
                  suffixIcon: _nome.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar filtro',
                          icon: const Icon(Icons.close, color: Paleta.nevoa),
                          onPressed: () {
                            _campo.clear();
                            setState(() => _nome = '');
                          },
                        ),
                ),
              ),
            ),
            SizedBox(
              height: 68,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                children: [
                  Escolha(
                    rotulo: 'Todos ${resumo.total}',
                    marcada: _filtro == null,
                    aoTocar: () => setState(() => _filtro = null),
                  ),
                  for (final status in const [
                    StatusJogo.jogando,
                    StatusJogo.fila,
                    StatusJogo.zerado,
                    StatusJogo.desejo,
                    StatusJogo.abandonado,
                  ]) ...[
                    const SizedBox(width: 8),
                    Escolha(
                      rotulo: '${status.rotulo} ${resumo.quantos(status)}',
                      marcada: _filtro == status,
                      aoTocar: () => setState(() => _filtro = status),
                    ),
                  ],
                ],
              ),
            ),
          ],
          Expanded(
            child: resumo.total == 0
                ? EstadoVazio(
                    icone: Icons.inventory_2_outlined,
                    titulo: 'Acervo vazio',
                    mensagem: 'Procure um jogo no catálogo e ponha na fila '
                        'ou na lista de desejos.',
                    acao: 'Procurar jogo',
                    aoTocar: widget.aoProcurar,
                  )
                : visiveis.isEmpty
                    ? EstadoVazio(
                        icone: Icons.search_off,
                        titulo: 'Nada por aqui',
                        mensagem: _nome.isEmpty
                            ? 'Nenhum jogo com a situação '
                                '"${_filtro?.rotulo ?? ''}".'
                            : 'Nenhum jogo do acervo combina com "$_nome".',
                        acao: 'Limpar filtros',
                        aoTocar: () {
                          _campo.clear();
                          setState(() {
                            _nome = '';
                            _filtro = null;
                          });
                        },
                      )
                    : ListView.separated(
                        // A chave refaz a lista (e as animações) ao filtrar.
                        key: ValueKey('${_filtro?.codigo}|$termo'),
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: visiveis.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final jogo = visiveis[i];
                          final tag = 'acervo-${jogo.id}';
                          return Revelar(
                            key: ValueKey(jogo.id),
                            // Os primeiros entram em cascata; o resto,
                            // conforme a rolagem os traz para a tela.
                            atraso: Duration(milliseconds: i < 6 ? i * 60 : 0),
                            child: CartaoJogo(
                              jogo: jogo,
                              heroTag: tag,
                              onTap: () => Navigator.of(context).push(
                                rotaSuave(DetalheScreen(
                                  jogoId: jogo.id!,
                                  heroTag: tag,
                                )),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
