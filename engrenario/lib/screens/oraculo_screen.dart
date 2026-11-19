import 'package:flutter/material.dart';

import '../controllers/acervo_controller.dart';
import '../core/formatos.dart';
import '../core/rotas.dart';
import '../core/tema.dart';
import '../models/prioridade.dart';
import '../widgets/capa.dart';
import '../widgets/cartao_jogo.dart';
import '../widgets/placa.dart';
import '../widgets/revelar.dart';
import 'detalhe_screen.dart';
import 'formularios.dart';

/// "O que jogar": ordena a fila conforme a estratégia e o tempo livre.
class OraculoScreen extends StatefulWidget {
  const OraculoScreen({super.key, required this.aoProcurar});
  final VoidCallback aoProcurar;

  @override
  State<OraculoScreen> createState() => _OraculoScreenState();
}

class _OraculoScreenState extends State<OraculoScreen> {
  EstrategiaPrioridade _estrategia = EstrategiaPrioridade.todas.first;
  double? _horasLivres;

  void _abrir(Recomendacao r, String tag) => Navigator.of(context).push(
        rotaSuave(DetalheScreen(jogoId: r.jogo.id!, heroTag: tag)),
      );

  @override
  Widget build(BuildContext context) {
    final acervo = Acervo.of(context);
    final horas = (_horasLivres ?? acervo.horasSemanais).clamp(1.0, 40.0);
    final ranking = acervo.recomendar(_estrategia, horasLivres: horas);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          Text('O que jogar', style: Letras.gravacao(40)),
          const SizedBox(height: 2),
          Text(
            'Diga quanto tempo você tem e como quer decidir. '
            'A fila se reorganiza sozinha.',
            style: Letras.texto(17, cor: Paleta.nevoa),
          ),
          const SizedBox(height: 18),
          Placa(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tempo livre nesta semana', style: Letras.texto(18)),
                Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        '${horas.round()} h',
                        style: Letras.maquina(28, cor: Paleta.lataoClaro),
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Paleta.latao,
                          inactiveTrackColor: Paleta.aco.op(0.5),
                          thumbColor: Paleta.lataoClaro,
                          overlayColor: Paleta.latao.op(0.15),
                          trackHeight: 5,
                        ),
                        child: Slider(
                          value: horas,
                          min: 1,
                          max: 40,
                          divisions: 39,
                          label: '${horas.round()} h',
                          semanticFormatterCallback: (v) =>
                              '${v.round()} horas livres',
                          onChanged: (v) => setState(() => _horasLivres = v),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Como decidir', style: Letras.texto(18)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in EstrategiaPrioridade.todas)
                      Escolha(
                        rotulo: e.nome,
                        marcada: e.nome == _estrategia.nome,
                        aoTocar: () => setState(() => _estrategia = e),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _estrategia.descricao,
                    key: ValueKey(_estrategia.nome),
                    style: Letras.texto(16.5,
                        cor: Paleta.nevoa, estilo: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (ranking.isEmpty)
            EstadoVazio(
              icone: Icons.hourglass_disabled,
              titulo: 'Fila vazia',
              mensagem: 'Não há jogos na fila nem na bancada. '
                  'Adicione um para receber sugestões.',
              acao: 'Procurar jogo',
              aoTocar: widget.aoProcurar,
            )
          else ...[
            const TituloSecao('Comece por este'),
            const SizedBox(height: 10),
            // A chave reinicia a animação quando a escolha muda.
            Revelar(
              key:
                  ValueKey('topo-${_estrategia.nome}-${ranking.first.jogo.id}'),
              child: _Destaque(
                recomendacao: ranking.first,
                aoTocar: () =>
                    _abrir(ranking.first, 'oraculo-${ranking.first.jogo.id}'),
              ),
            ),
            if (ranking.length > 1) ...[
              const SizedBox(height: 24),
              const TituloSecao('Depois, nesta ordem'),
              const SizedBox(height: 10),
              for (var i = 1; i < ranking.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Revelar(
                    key: ValueKey(
                        'pos-${_estrategia.nome}-${ranking[i].jogo.id}'),
                    atraso: Duration(milliseconds: i < 6 ? i * 50 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 34,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '${i + 1}',
                              style: Letras.maquina(20, cor: Paleta.latao),
                            ),
                          ),
                        ),
                        Expanded(
                          child: CartaoJogo(
                            jogo: ranking[i].jogo,
                            heroTag: 'oraculo-${ranking[i].jogo.id}',
                            onTap: () => _abrir(
                              ranking[i],
                              'oraculo-${ranking[i].jogo.id}',
                            ),
                            rodape: Text(
                              ranking[i].motivo,
                              style: Letras.texto(15.5,
                                  cor: Paleta.lataoClaro,
                                  estilo: FontStyle.italic),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Destaque extends StatelessWidget {
  const _Destaque({required this.recomendacao, required this.aoTocar});

  final Recomendacao recomendacao;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final jogo = recomendacao.jogo;
    return Placa(
      padding: EdgeInsets.zero,
      onTap: aoTocar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Hero(
            tag: 'oraculo-${jogo.id}',
            child: CapaJogo(
              url: jogo.capaUrl,
              altura: 170,
              moldura: false,
              raio: 0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(jogo.nome, style: Letras.gravacao(28)),
                const SizedBox(height: 6),
                Text(recomendacao.motivo, style: Letras.texto(18)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CanoProgresso(
                        valor: recomendacao.pontos / 100,
                        altura: 10,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${Formatos.numero(recomendacao.pontos, casas: 0)} pontos',
                      style: Letras.maquina(14, cor: Paleta.nevoa),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
