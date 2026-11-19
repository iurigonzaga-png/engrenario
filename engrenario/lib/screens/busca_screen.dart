import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/acervo_controller.dart';
import '../core/config.dart';
import '../core/erros.dart';
import '../core/rotas.dart';
import '../core/tema.dart';
import '../models/jogo.dart';
import '../services/catalogo_service.dart';
import '../widgets/capa.dart';
import '../widgets/engrenagem.dart';
import '../widgets/placa.dart';
import '../widgets/revelar.dart';
import 'detalhe_screen.dart';
import 'formularios.dart';

/// Busca jogos na API da RAWG e leva os escolhidos para o acervo.
class BuscaScreen extends StatefulWidget {
  const BuscaScreen({super.key, this.servico});

  /// Permite injetar outro catálogo (ex.: em testes).
  final CatalogoService? servico;

  @override
  State<BuscaScreen> createState() => _BuscaScreenState();
}

class _BuscaScreenState extends State<BuscaScreen> {
  late final CatalogoService _servico = widget.servico ?? RawgService();
  final _campo = TextEditingController();
  Timer? _espera;

  List<JogoCatalogo> _resultados = const [];
  bool _carregando = true;
  String? _erro;
  String _termo = '';
  int _pedido = 0;

  @override
  void initState() {
    super.initState();
    _consultar('');
  }

  @override
  void dispose() {
    _espera?.cancel();
    _campo.dispose();
    super.dispose();
  }

  /// Espera o usuário parar de digitar antes de chamar a API.
  void _aoDigitar(String texto) {
    _espera?.cancel();
    _espera = Timer(
      const Duration(milliseconds: 500),
      () => _consultar(texto.trim()),
    );
    setState(() {});
  }

  Future<void> _consultar(String termo) async {
    final pedido = ++_pedido;
    setState(() {
      _carregando = true;
      _erro = null;
      _termo = termo;
    });
    try {
      final lista = termo.length < 2
          ? await _servico.populares()
          : await _servico.buscar(termo);
      // Ignora respostas de buscas antigas que chegaram atrasadas.
      if (!mounted || pedido != _pedido) return;
      setState(() {
        _resultados = lista;
        _carregando = false;
      });
    } on ErroDeCatalogo catch (e) {
      if (!mounted || pedido != _pedido) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    }
  }

  Future<void> _escolher(JogoCatalogo jogo) async {
    final acervo = Acervo.ler(context);
    final existente = acervo.porRawgId(jogo.rawgId);
    if (existente != null) {
      Navigator.of(context).push(rotaSuave(
        DetalheScreen(jogoId: existente.id!, heroTag: 'busca-${jogo.rawgId}'),
      ));
      return;
    }
    FocusScope.of(context).unfocus();
    final novo =
        await abrirFolha<JogoAcervo>(context, FolhaAdicionar(jogo: jogo));
    if (novo != null && mounted) {
      avisar(context, '${novo.nome} entrou no acervo.');
    }
  }

  Widget _corpo() {
    if (_carregando) {
      return const Carregando(mensagem: 'Consultando o catálogo');
    }
    if (_erro != null) {
      return EstadoVazio(
        icone: ConfigApi.chaveConfigurada ? Icons.cloud_off : Icons.vpn_key,
        titulo: ConfigApi.chaveConfigurada
            ? 'Catálogo fora de alcance'
            : 'Falta a chave da API',
        mensagem: _erro!,
        acao: 'Tentar de novo',
        aoTocar: () => _consultar(_termo),
      );
    }
    if (_resultados.isEmpty) {
      return EstadoVazio(
        icone: Icons.search_off,
        titulo: 'Nada encontrado',
        mensagem: 'O catálogo não tem jogos para "$_termo". '
            'Tente o nome em inglês ou só uma parte dele.',
      );
    }
    final acervo = Acervo.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _resultados.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              _termo.length < 2
                  ? 'Os mais adicionados da RAWG'
                  : 'Resultados para "$_termo"',
              style: Letras.texto(16.5, cor: Paleta.nevoa),
            ),
          );
        }
        final jogo = _resultados[i - 1];
        return Revelar(
          key: ValueKey('${_pedido}_${jogo.rawgId}'),
          deslocamento: const Offset(0, 18),
          child: _ResultadoCatalogo(
            jogo: jogo,
            noAcervo: acervo.porRawgId(jogo.rawgId),
            aoTocar: () => _escolher(jogo),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Voltar',
                      icon: const Icon(Icons.arrow_back),
                      color: Paleta.lataoClaro,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _campo,
                        autofocus: false,
                        textInputAction: TextInputAction.search,
                        onChanged: _aoDigitar,
                        onSubmitted: (t) {
                          _espera?.cancel();
                          _consultar(t.trim());
                        },
                        style: Letras.texto(19),
                        cursorColor: Paleta.latao,
                        decoration:
                            campoDecorado('Procurar jogo no catálogo').copyWith(
                          prefixIcon:
                              const Icon(Icons.search, color: Paleta.latao),
                          suffixIcon: _campo.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpar busca',
                                  icon: const Icon(Icons.close,
                                      color: Paleta.nevoa),
                                  onPressed: () {
                                    _campo.clear();
                                    _espera?.cancel();
                                    _consultar('');
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey('$_pedido-$_carregando'),
                    child: _corpo(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ResultadoCatalogo extends StatelessWidget {
  const _ResultadoCatalogo({
    required this.jogo,
    required this.noAcervo,
    required this.aoTocar,
  });

  final JogoCatalogo jogo;
  final JogoAcervo? noAcervo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Placa(
        rebites: false,
        padding: const EdgeInsets.all(10),
        onTap: aoTocar,
        child: Row(
          children: [
            Hero(
              tag: 'busca-${jogo.rawgId}',
              child: CapaJogo(url: jogo.capaUrl, largura: 104, altura: 70),
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
                    style: Letras.texto(18.5, peso: FontWeight.w600)
                        .copyWith(height: 1.15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    jogo.legenda,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Letras.texto(15.5, cor: Paleta.nevoa),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (noAcervo != null)
                        Selo.status(noAcervo!.status)
                      else ...[
                        if (jogo.metacritic != null)
                          Selo('Crítica ${jogo.metacritic}',
                              cor: Paleta.lataoClaro),
                        if (jogo.horasApi > 0)
                          Selo('${jogo.horasApi} h', cor: Paleta.nevoa),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              noAcervo != null ? Icons.chevron_right : Icons.add_circle_outline,
              color: noAcervo != null ? Paleta.nevoa : Paleta.latao,
              semanticLabel:
                  noAcervo != null ? 'Abrir no acervo' : 'Adicionar ao acervo',
            ),
          ],
        ),
      );
}
