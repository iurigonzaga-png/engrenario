import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/acervo_controller.dart';
import '../core/formatos.dart';
import '../core/rotas.dart';
import '../core/tema.dart';
import '../models/jogo.dart';
import '../models/prioridade.dart';
import '../models/resumo.dart';
import '../widgets/capa.dart';
import '../widgets/cartao_jogo.dart';
import '../widgets/engrenagem.dart';
import '../widgets/letreiro.dart';
import '../widgets/manometro.dart';
import '../widgets/placa.dart';
import '../widgets/raios.dart';
import '../widgets/revelar.dart';
import 'detalhe_screen.dart';

/// Tela inicial: a "oficina". As engrenagens do topo giram conforme a
/// rolagem e cada seção se monta quando entra na tela.
class InicioScreen extends StatefulWidget {
  const InicioScreen({
    super.key,
    required this.aoProcurar,
    required this.aoVerFila,
    required this.aoVerAcervo,
  });

  final VoidCallback aoProcurar;
  final VoidCallback aoVerFila;
  final VoidCallback aoVerAcervo;

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen>
    with SingleTickerProviderStateMixin {
  final _rolagem = ScrollController();

  // Sequência de abertura: as engrenagens dão um giro e o título sobe.
  late final AnimationController _abertura = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  static const double _alturaTopo = 350;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_abertura.status == AnimationStatus.dismissed) {
      if (MediaQuery.of(context).disableAnimations) {
        _abertura.value = 1;
      } else {
        _abertura.forward();
      }
    }
  }

  @override
  void dispose() {
    _rolagem.dispose();
    _abertura.dispose();
    super.dispose();
  }

  /// Quanto já foi rolado, em pixels (0 antes do primeiro layout).
  double get _deslocamento {
    if (!_rolagem.hasClients || !_rolagem.position.hasPixels) return 0;
    return math.max(0, _rolagem.position.pixels);
  }

  /// Fração da página já rolada, de 0 a 1.
  double get _fracaoRolada {
    if (!_rolagem.hasClients) return 0;
    final posicao = _rolagem.position;
    if (!posicao.hasPixels || !posicao.hasContentDimensions) return 0;
    final maximo = posicao.maxScrollExtent;
    return maximo <= 0 ? 0 : (posicao.pixels / maximo).clamp(0.0, 1.0);
  }

  void _abrir(JogoAcervo jogo) => Navigator.of(context).push(
        rotaSuave(
            DetalheScreen(jogoId: jogo.id!, heroTag: 'inicio-${jogo.id}')),
      );

  @override
  Widget build(BuildContext context) {
    final acervo = Acervo.of(context);
    final resumo = acervo.resumo;
    final naBancada = acervo.porStatus(StatusJogo.jogando);
    final zerados = acervo.porStatus(StatusJogo.zerado)
      ..sort((a, b) => (b.concluidoEm ?? b.adicionadoEm)
          .compareTo(a.concluidoEm ?? a.adicionadoEm));
    Recomendacao? proximo;
    for (final r in acervo.recomendar(const Equilibrada())) {
      if (r.jogo.status == StatusJogo.fila) {
        proximo = r;
        break;
      }
    }

    return Stack(
      children: [
        ListView(
          controller: _rolagem,
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            _topo(context),
            Letreiro(itens: _frasesDoLetreiro(resumo)),
            if (resumo.total == 0)
              Padding(
                padding: const EdgeInsets.only(top: 36),
                child: EstadoVazio(
                  icone: Icons.inventory_2_outlined,
                  titulo: 'A oficina está parada',
                  mensagem: 'Procure o primeiro jogo no catálogo e ponha na '
                      'fila. O manômetro começa a medir a partir daí.',
                  acao: 'Procurar jogo',
                  aoTocar: widget.aoProcurar,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 30, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Revelar(child: TituloSecao('Pressão do backlog')),
                    const SizedBox(height: 14),
                    _pressao(resumo),
                    const SizedBox(height: 34),
                    Revelar(
                      child: TituloSecao(
                        'Na bancada',
                        acao: '${naBancada.length} de '
                            '${acervo.limiteSimultaneos}',
                        aoTocar: widget.aoVerAcervo,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            if (resumo.total > 0) ...[
              _bancada(acervo, naBancada),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 34, 18, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Revelar(
                      child: TituloSecao(
                        'Próximo da fila',
                        acao: 'Ver a ordem',
                        aoTocar: widget.aoVerFila,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Revelar(
                      atraso: const Duration(milliseconds: 90),
                      child: proximo == null
                          ? Placa(
                              child: Text(
                                'Não há jogos esperando na fila. Procure um '
                                'no catálogo ou tire algum da lista de desejos.',
                                style: Letras.texto(17.5, cor: Paleta.nevoa),
                              ),
                            )
                          : CartaoJogo(
                              jogo: proximo.jogo,
                              heroTag: 'inicio-${proximo.jogo.id}',
                              onTap: () => _abrir(proximo!.jogo),
                              rodape: Text(
                                proximo.motivo,
                                style: Letras.texto(
                                  15.5,
                                  cor: Paleta.lataoClaro,
                                  estilo: FontStyle.italic,
                                ),
                              ),
                            ),
                    ),
                    if (zerados.isNotEmpty) ...[
                      const SizedBox(height: 34),
                      const Revelar(child: TituloSecao('Últimos zerados')),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
              if (zerados.isNotEmpty) _zerados(zerados.take(8).toList()),
            ],
          ],
        ),
        // Cano lateral: enche conforme a tela é rolada.
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          bottom: 120,
          right: 5,
          width: 5,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _rolagem,
                builder: (context, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: Paleta.marinho.op(0.8),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Paleta.aco.op(0.6)),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.topCenter,
                    heightFactor: math.max(0.04, _fracaoRolada),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Paleta.latao,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<String> _frasesDoLetreiro(ResumoAcervo resumo) {
    if (resumo.total == 0) {
      return const ['Acervo vazio', 'Procure um jogo para começar'];
    }
    String plural(int n, String um, String varios) =>
        n == 1 ? '1 $um' : '$n $varios';
    return [
      '${resumo.quantos(StatusJogo.fila)} na fila',
      '${resumo.quantos(StatusJogo.jogando)} na bancada',
      plural(resumo.zerados, 'zerado', 'zerados'),
      '${Formatos.numero(resumo.horasTotais, casas: 0)} h registradas',
      plural(resumo.quantos(StatusJogo.desejo), 'desejado', 'desejados'),
    ];
  }

  // ------------------------------------------------------------------ topo

  Widget _topo(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final topoSeguro = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: _alturaTopo + topoSeguro,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: Listenable.merge([_rolagem, _abertura]),
          builder: (context, _) {
            final rolado = _deslocamento;
            final entrada = Curves.easeOutCubic.transform(_abertura.value);
            // Giro = rolagem + um impulso que se dissipa na abertura.
            final giro = rolado * 0.006 + (1 - entrada) * 2.6;
            final sumindo = (1 - rolado / 240).clamp(0.0, 1.0);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Leque de raios art déco atrás das engrenagens.
                Positioned.fill(
                  child: CustomPaint(
                    painter: RaiosPainter(
                      centro: Offset(
                        largura - 40,
                        topoSeguro + 50 + rolado * 0.35,
                      ),
                      giro: giro * 0.15,
                      intensidade: entrada,
                    ),
                  ),
                ),
                // Engrenagem grande (16 dentes).
                Positioned(
                  left: largura - 40 - 130,
                  top: topoSeguro + 50 - 130 + rolado * 0.35,
                  child: Opacity(
                    opacity: entrada,
                    child: Engrenagem(tamanho: 260, dentes: 16, angulo: giro),
                  ),
                ),
                // Engrenagem menor (8 dentes), encaixada: gira ao contrário
                // e duas vezes mais rápido.
                Positioned(
                  left: largura - 199 - 65,
                  top: topoSeguro + 142 - 65 + rolado * 0.35,
                  child: Opacity(
                    opacity: entrada,
                    child: Engrenagem(
                      tamanho: 130,
                      dentes: 8,
                      cor: Paleta.cobalto,
                      angulo: -giro * 2 + math.pi / 8,
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 26,
                  child: Opacity(
                    opacity: sumindo * entrada,
                    child: Transform.translate(
                      offset: Offset(0, (1 - entrada) * 30 + rolado * 0.22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child:
                                Text('Engrenário', style: Letras.gravacao(54)),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Text(
                              'Todo backlog é uma caldeira. Aqui você '
                              'controla a pressão.',
                              style: Letras.texto(19),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ pressão

  Widget _pressao(ResumoAcervo resumo) {
    final cor = switch (resumo.nivel) {
      NivelPressao.estavel => Paleta.celeste,
      NivelPressao.aquecendo => Paleta.latao,
      NivelPressao.critica => Paleta.brasa,
    };
    final String explicacao;
    if (resumo.pendentes == 0) {
      explicacao = 'Nada pendente. A caldeira está fria.';
    } else {
      explicacao = 'Faltam ${Formatos.horas(resumo.horasPendentes)} de jogo em '
          '${resumo.pendentes == 1 ? '1 jogo' : '${resumo.pendentes} jogos'}. '
          'Jogando ${Formatos.numero(resumo.horasSemanais)} h por semana, a '
          'fila acaba em ${Formatos.semanas(resumo.semanasParaLimpar)}.';
    }
    return RevelarBuilder(
      duracao: const Duration(milliseconds: 1500),
      curva: Curves.easeOutCubic,
      builder: (context, animacao) => AnimatedBuilder(
        animation: animacao,
        builder: (context, filho) => Opacity(
          opacity: (animacao.value * 2.5).clamp(0.0, 1.0),
          child: filho,
        ),
        child: Placa(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
          child: Column(
            children: [
              Semantics(
                label: 'Manômetro do backlog: pressão '
                    '${resumo.nivel.rotulo.toLowerCase()}',
                child: ExcludeSemantics(
                  child: Manometro(
                    valor: resumo.pressao,
                    // O ponteiro varre o mostrador ao entrar na tela.
                    entrada: animacao,
                    tamanho: 228,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(resumo.nivel.rotulo, style: Letras.gravacao(30, cor: cor)),
              const SizedBox(height: 6),
              Text(
                explicacao,
                textAlign: TextAlign.center,
                style: Letras.texto(17.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ bancada

  Widget _bancada(AcervoController acervo, List<JogoAcervo> jogos) {
    if (jogos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Revelar(
          child: Placa(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bancada vazia. Escolha um jogo da fila e comece: é aqui '
                  'que você registra as sessões.',
                  style: Letras.texto(17.5, cor: Paleta.nevoa),
                ),
                const SizedBox(height: 14),
                BotaoLatao(
                  rotulo: 'Escolher o que jogar',
                  icone: Icons.auto_awesome_outlined,
                  onPressed: widget.aoVerFila,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 268,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: jogos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final jogo = jogos[i];
          final previsao = acervo.previsaoDeTermino(jogo);
          return Revelar(
            key: ValueKey(jogo.id),
            atraso: Duration(milliseconds: i * 110),
            deslocamento: const Offset(40, 0),
            child: SizedBox(
              width: 244,
              child: Placa(
                padding: EdgeInsets.zero,
                rebites: false,
                onTap: () => _abrir(jogo),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Hero(
                      tag: 'inicio-${jogo.id}',
                      child: CapaJogo(
                        url: jogo.capaUrl,
                        altura: 128,
                        moldura: false,
                        raio: 0,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jogo.nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Letras.texto(19, peso: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            CanoProgresso(
                              valor: jogo.progresso,
                              cor: Paleta.celeste,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              jogo.legenda,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Letras.texto(15.5),
                            ),
                            Text(
                              previsao == null
                                  ? 'Sem previsão de término'
                                  : 'Termina por volta de '
                                      '${Formatos.dataCurta(previsao)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Letras.texto(15, cor: Paleta.nevoa),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------ zerados

  Widget _zerados(List<JogoAcervo> jogos) => SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          itemCount: jogos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final jogo = jogos[i];
            return Revelar(
              key: ValueKey(jogo.id),
              atraso: Duration(milliseconds: i * 80),
              deslocamento: const Offset(30, 0),
              child: Semantics(
                button: true,
                label: '${jogo.nome}, ${jogo.legenda}',
                child: GestureDetector(
                  onTap: () => _abrir(jogo),
                  child: SizedBox(
                    width: 142,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'inicio-${jogo.id}',
                          child: CapaJogo(
                            url: jogo.capaUrl,
                            largura: 142,
                            altura: 92,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          jogo.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Letras.texto(16),
                        ),
                        if (jogo.notaPessoal != null)
                          Text(
                            'Nota ${Formatos.numero(jogo.notaPessoal!)}',
                            style: Letras.maquina(13, cor: Paleta.latao),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}
