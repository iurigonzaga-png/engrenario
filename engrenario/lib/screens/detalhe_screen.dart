import 'package:flutter/material.dart';

import '../controllers/acervo_controller.dart';
import '../core/erros.dart';
import '../core/formatos.dart';
import '../core/tema.dart';
import '../models/jogo.dart';
import '../models/sessao.dart';
import '../services/catalogo_service.dart';
import '../widgets/capa.dart';
import '../widgets/placa.dart';
import '../widgets/revelar.dart';
import 'formularios.dart';

/// Tudo sobre um jogo do acervo: situação, progresso, sessões e ações.
class DetalheScreen extends StatefulWidget {
  const DetalheScreen({
    super.key,
    required this.jogoId,
    required this.heroTag,
    this.servico,
  });

  final int jogoId;
  final String heroTag;
  final CatalogoService? servico;

  @override
  State<DetalheScreen> createState() => _DetalheScreenState();
}

class _DetalheScreenState extends State<DetalheScreen> {
  late final CatalogoService _servico = widget.servico ?? RawgService();
  Future<List<Sessao>>? _sessoes;
  Future<String>? _descricao;
  int? _minutosVistos;
  bool _descricaoAberta = false;

  void _carregarSessoes(AcervoController acervo, JogoAcervo jogo) {
    // Recarrega a lista só quando o total jogado mudou.
    if (_sessoes == null || _minutosVistos != jogo.minutosJogados) {
      _minutosVistos = jogo.minutosJogados;
      _sessoes = acervo.sessoesDe(jogo);
    }
  }

  Future<void> _mudarStatus(JogoAcervo jogo, StatusJogo destino) async {
    final acervo = Acervo.ler(context);
    if (destino == StatusJogo.zerado) {
      if (jogo.minutosJogados == 0) {
        avisar(
          context,
          'Registre ao menos uma sessão antes de marcar como zerado.',
          erro: true,
        );
        return;
      }
      final zerou = await abrirFolha<bool>(context, FolhaZerar(jogo: jogo));
      if (zerou == true && mounted) {
        avisar(context, '${jogo.nome} zerado. Mais uma engrenagem no lugar.');
      }
      return;
    }
    if (destino == StatusJogo.abandonado) {
      final sim = await confirmar(
        context,
        titulo: 'Abandonar o jogo?',
        mensagem: 'Ele sai da fila e as sessões registradas ficam guardadas. '
            'Dá para devolver à fila depois.',
        acao: 'Abandonar',
      );
      if (!sim) return;
    }
    try {
      await acervo.mudarStatus(jogo, destino);
      if (mounted) avisar(context, 'Agora está: ${destino.rotulo}.');
    } on RegraDeNegocio catch (e) {
      if (mounted) avisar(context, e.mensagem, erro: true);
    }
  }

  Future<void> _remover(JogoAcervo jogo) async {
    final sim = await confirmar(
      context,
      titulo: 'Remover do acervo?',
      mensagem: '${jogo.nome} e todas as sessões dele serão apagados. '
          'Não dá para desfazer.',
      acao: 'Remover',
    );
    if (!sim || !mounted) return;
    final acervo = Acervo.ler(context);
    final navegador = Navigator.of(context);
    final nome = jogo.nome;
    await acervo.remover(jogo);
    if (!mounted) return;
    avisar(context, '$nome saiu do acervo.');
    navegador.pop();
  }

  Future<void> _excluirSessao(Sessao sessao) async {
    final sim = await confirmar(
      context,
      titulo: 'Apagar a sessão?',
      mensagem: 'Os ${Formatos.minutos(sessao.minutos)} de '
          '${Formatos.data(sessao.data)} saem do total jogado.',
      acao: 'Apagar',
    );
    if (!sim || !mounted) return;
    await Acervo.ler(context).excluirSessao(sessao);
  }

  @override
  Widget build(BuildContext context) {
    final acervo = Acervo.of(context);
    final jogo = acervo.porId(widget.jogoId);
    if (jogo == null) {
      // O jogo foi removido: a tela fecha sozinha.
      return const Scaffold(body: SizedBox.shrink());
    }
    _carregarSessoes(acervo, jogo);
    _descricao ??= acervo.descricaoDe(jogo, _servico.descricao);
    final previsao = acervo.previsaoDeTermino(jogo);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            backgroundColor: Paleta.marinho,
            surfaceTintColor: Colors.transparent,
            foregroundColor: Paleta.lataoClaro,
            leading: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Voltar',
              iconSize: 38,
              padding: EdgeInsets.zero,
              icon: const _BotaoSobreImagem(Icons.arrow_back),
            ),
            actions: [
              IconButton(
                onPressed: () =>
                    abrirFolha<bool>(context, FolhaDetalhes(jogo: jogo)),
                tooltip: 'Editar jogo',
                iconSize: 38,
                padding: EdgeInsets.zero,
                icon: const _BotaoSobreImagem(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: () => _remover(jogo),
                tooltip: 'Remover do acervo',
                iconSize: 38,
                padding: EdgeInsets.zero,
                icon: const _BotaoSobreImagem(Icons.delete_outline),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: widget.heroTag,
                    child: CapaJogo(
                      url: jogo.capaUrl,
                      moldura: false,
                      raio: 0,
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x80001624),
                          Color(0x00001624),
                          Color(0xFF001624),
                        ],
                        stops: [0, 0.45, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(jogo.nome, style: Letras.gravacao(34)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Selo.status(jogo.status),
                    if (jogo.metacritic != null)
                      Selo('Crítica ${jogo.metacritic}',
                          cor: Paleta.lataoClaro),
                    if (jogo.notaPessoal != null)
                      Selo('Sua nota ${Formatos.numero(jogo.notaPessoal!)}',
                          cor: Paleta.celeste),
                    if (jogo.ano != null)
                      Selo('${jogo.ano}', cor: Paleta.nevoa),
                    if (jogo.plataforma != null)
                      Selo(jogo.plataforma!, cor: Paleta.nevoa),
                    for (final genero in jogo.generos.take(3))
                      Selo(genero, cor: Paleta.nevoa),
                  ],
                ),
                const SizedBox(height: 20),
                Revelar(child: _progresso(jogo, previsao)),
                const SizedBox(height: 16),
                Revelar(
                  atraso: const Duration(milliseconds: 80),
                  child: _acoes(jogo),
                ),
                if (jogo.anotacoes != null) ...[
                  const SizedBox(height: 26),
                  const TituloSecao('Anotações'),
                  const SizedBox(height: 8),
                  Text(
                    jogo.anotacoes!,
                    style: Letras.texto(18, estilo: FontStyle.italic),
                  ),
                ],
                const SizedBox(height: 26),
                TituloSecao(
                  'Sessões',
                  acao: jogo.status == StatusJogo.jogando ? 'Registrar' : null,
                  aoTocar: () =>
                      abrirFolha<bool>(context, FolhaSessao(jogo: jogo)),
                ),
                const SizedBox(height: 8),
                _listaDeSessoes(jogo),
                const SizedBox(height: 26),
                const TituloSecao('Sobre o jogo'),
                const SizedBox(height: 8),
                _sobre(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progresso(JogoAcervo jogo, DateTime? previsao) {
    final String linha;
    if (jogo.status == StatusJogo.zerado) {
      linha = jogo.concluidoEm == null
          ? 'Zerado.'
          : 'Zerado em ${Formatos.data(jogo.concluidoEm!)}.';
    } else if (jogo.passouDaEstimativa) {
      linha = 'Você já passou da estimativa. Ajuste a duração em "Editar" '
          'ou marque como zerado.';
    } else if (previsao != null) {
      linha = 'Nesse ritmo, você termina por volta de '
          '${Formatos.data(previsao)}.';
    } else if (jogo.pendente) {
      linha = 'Faltam ${Formatos.horas(jogo.horasParaTerminar)} para terminar.';
    } else {
      linha = jogo.legenda;
    }
    return Placa(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(jogo.progresso * 100).round()}%',
                style: Letras.maquina(38, cor: Paleta.lataoClaro),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${Formatos.horas(jogo.horasJogadas)} de '
                    '${Formatos.horas(jogo.horasEstimadas)}',
                    style: Letras.texto(17, cor: Paleta.nevoa),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CanoProgresso(
            valor: jogo.progresso,
            altura: 14,
            cor: jogo.status == StatusJogo.zerado
                ? Paleta.lataoClaro
                : Paleta.celeste,
          ),
          const SizedBox(height: 12),
          Text(linha, style: Letras.texto(17)),
        ],
      ),
    );
  }

  Widget _acoes(JogoAcervo jogo) {
    final transicoes = jogo.status.transicoes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (jogo.status == StatusJogo.jogando) ...[
          BotaoLatao(
            rotulo: 'Registrar sessão',
            icone: Icons.timer_outlined,
            expandir: true,
            onPressed: () => abrirFolha<bool>(context, FolhaSessao(jogo: jogo)),
          ),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < transicoes.length; i++) ...[
          BotaoLatao(
            rotulo: jogo.status.acaoPara(transicoes[i]),
            icone: iconeDoStatus(transicoes[i]),
            expandir: true,
            // Fora da bancada, a primeira transição é a ação principal.
            secundario: jogo.status == StatusJogo.jogando || i > 0,
            perigo: transicoes[i] == StatusJogo.abandonado,
            onPressed: () => _mudarStatus(jogo, transicoes[i]),
          ),
          if (i < transicoes.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _listaDeSessoes(JogoAcervo jogo) => FutureBuilder<List<Sessao>>(
        future: _sessoes,
        builder: (context, foto) {
          final sessoes = foto.data;
          if (sessoes == null) {
            return Text('Lendo o diário de bordo',
                style: Letras.texto(17, cor: Paleta.nevoa));
          }
          if (sessoes.isEmpty) {
            return Text(
              jogo.status == StatusJogo.jogando
                  ? 'Nenhuma sessão ainda. Registre a primeira depois de jogar.'
                  : 'Nenhuma sessão registrada. Só jogos na bancada recebem sessões.',
              style: Letras.texto(17, cor: Paleta.nevoa),
            );
          }
          return Column(
            children: [
              for (final sessao in sessoes)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(14, 6, 2, 6),
                  decoration: BoxDecoration(
                    color: Paleta.marinho,
                    borderRadius: BorderRadius.circular(4),
                    border: Border(
                      left: BorderSide(color: Paleta.celeste.op(0.8), width: 3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${Formatos.minutos(sessao.minutos)}  em '
                              '${Formatos.data(sessao.data)}',
                              style: Letras.maquina(15),
                            ),
                            if (sessao.comentario != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  sessao.comentario!,
                                  style: Letras.texto(16.5, cor: Paleta.nevoa),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _excluirSessao(sessao),
                        tooltip: 'Apagar sessão',
                        icon: const Icon(Icons.close, size: 20),
                        color: Paleta.nevoa,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );

  Widget _sobre() => FutureBuilder<String>(
        future: _descricao,
        builder: (context, foto) {
          if (foto.hasError) {
            final erro = foto.error;
            return Text(
              erro is ErroDeCatalogo
                  ? erro.mensagem
                  : 'Não foi possível buscar a descrição.',
              style: Letras.texto(17, cor: Paleta.nevoa),
            );
          }
          if (!foto.hasData) {
            return Text('Buscando a descrição na RAWG',
                style: Letras.texto(17, cor: Paleta.nevoa));
          }
          final texto = foto.data!;
          if (texto.isEmpty) {
            return Text('A RAWG não tem descrição para este jogo.',
                style: Letras.texto(17, cor: Paleta.nevoa));
          }
          final longo = texto.length > 320;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.topCenter,
                child: Text(
                  texto,
                  maxLines: _descricaoAberta || !longo ? null : 6,
                  overflow: _descricaoAberta || !longo
                      ? TextOverflow.visible
                      : TextOverflow.fade,
                  style: Letras.texto(17.5),
                ),
              ),
              if (longo)
                TextButton(
                  onPressed: () =>
                      setState(() => _descricaoAberta = !_descricaoAberta),
                  style: TextButton.styleFrom(
                    foregroundColor: Paleta.celeste,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 48),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(
                    _descricaoAberta ? 'Mostrar menos' : 'Ler tudo',
                    style: Letras.texto(17, cor: Paleta.celeste),
                  ),
                ),
              Text(
                'Dados e capa: RAWG (rawg.io)',
                style: Letras.texto(14.5, cor: Paleta.nevoa),
              ),
            ],
          );
        },
      );
}

/// Ícone com fundo escuro, legível sobre qualquer capa.
class _BotaoSobreImagem extends StatelessWidget {
  const _BotaoSobreImagem(this.icone);
  final IconData icone;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Paleta.abismo.op(0.72),
          shape: BoxShape.circle,
          border: Border.all(color: Paleta.aco),
        ),
        child: Icon(icone, size: 20, color: Paleta.lataoClaro),
      );
}
