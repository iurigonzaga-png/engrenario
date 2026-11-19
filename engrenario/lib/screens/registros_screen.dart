import 'package:flutter/material.dart';

import '../controllers/acervo_controller.dart';
import '../core/formatos.dart';
import '../core/tema.dart';
import '../models/conquista.dart';
import '../models/jogo.dart';
import '../models/resumo.dart';
import '../widgets/placa.dart';
import '../widgets/revelar.dart';
import 'formularios.dart';

/// Números do acervo, tempo por gênero, conquistas e ajustes.
class RegistrosScreen extends StatelessWidget {
  const RegistrosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final acervo = Acervo.of(context);
    final resumo = acervo.resumo;
    final generos = resumo.generosMaisJogados.take(6).toList();
    final maiorGenero = generos.isEmpty ? 1 : generos.first.value;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          Text('Registros', style: Letras.gravacao(40)),
          const SizedBox(height: 2),
          Text(
            'O que a oficina produziu até agora.',
            style: Letras.texto(17, cor: Paleta.nevoa),
          ),
          const SizedBox(height: 18),
          RevelarBuilder(
            duracao: const Duration(milliseconds: 1100),
            builder: (context, animacao) => Row(
              children: [
                Expanded(
                  child: _Contador(
                    valor: resumo.zerados.toDouble(),
                    rotulo: 'zerados',
                    animacao: animacao,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Contador(
                    valor: resumo.horasTotais,
                    rotulo: 'horas jogadas',
                    animacao: animacao,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Contador(
                    valor: resumo.mediaDasNotas ?? 0,
                    casas: 1,
                    vazio: resumo.mediaDasNotas == null,
                    rotulo: 'nota média',
                    animacao: animacao,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const TituloSecao('Tempo por gênero'),
          const SizedBox(height: 12),
          if (generos.isEmpty)
            Text(
              'Aparece aqui depois da primeira sessão registrada.',
              style: Letras.texto(17, cor: Paleta.nevoa),
            )
          else
            RevelarBuilder(
              duracao: const Duration(milliseconds: 1000),
              builder: (context, animacao) => Column(
                children: [
                  for (final g in generos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(g.key, style: Letras.texto(17.5)),
                              ),
                              Text(
                                Formatos.minutos(g.value),
                                style: Letras.maquina(14, cor: Paleta.nevoa),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          CanoProgresso(
                            valor: g.value / maiorGenero,
                            entrada: animacao,
                            cor: Paleta.cobalto,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          const TituloSecao('Conquistas'),
          const SizedBox(height: 12),
          for (var i = 0; i < Conquista.todas.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Revelar(
                atraso: Duration(milliseconds: i * 40),
                child: _Insignia(conquista: Conquista.todas[i], resumo: resumo),
              ),
            ),
          const SizedBox(height: 20),
          const TituloSecao('Ajustes'),
          const SizedBox(height: 12),
          Revelar(
            child: Placa(
              onTap: () => abrirFolha<bool>(context, const FolhaPreferencias()),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: Paleta.latao),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bancada para ${acervo.limiteSimultaneos} '
                          '${acervo.limiteSimultaneos == 1 ? 'jogo' : 'jogos'}',
                          style: Letras.texto(18),
                        ),
                        Text(
                          '${Formatos.numero(acervo.horasSemanais)} h de jogo '
                          'por semana',
                          style: Letras.texto(16, cor: Paleta.nevoa),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Paleta.nevoa),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'Capas e dados dos jogos fornecidos pela RAWG (rawg.io).\n'
            '${resumo.quantos(StatusJogo.desejo)} desejados e '
            '${resumo.quantos(StatusJogo.abandonado)} abandonados no acervo.',
            textAlign: TextAlign.center,
            style: Letras.texto(15, cor: Paleta.nevoa),
          ),
        ],
      ),
    );
  }
}

/// Número que conta de zero até o valor enquanto aparece.
class _Contador extends StatelessWidget {
  const _Contador({
    required this.valor,
    required this.rotulo,
    required this.animacao,
    this.casas = 0,
    this.vazio = false,
  });

  final double valor;
  final String rotulo;
  final Animation<double> animacao;
  final int casas;
  final bool vazio;

  @override
  Widget build(BuildContext context) => Placa(
        rebites: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Semantics(
          label: vazio
              ? '$rotulo: sem dados'
              : '${Formatos.numero(valor, casas: casas)} $rotulo',
          excludeSemantics: true,
          child: Column(
            children: [
              AnimatedBuilder(
                animation: animacao,
                builder: (context, _) => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    vazio
                        ? '--'
                        : Formatos.numero(valor * animacao.value, casas: casas),
                    style: Letras.maquina(30, cor: Paleta.lataoClaro),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                rotulo,
                textAlign: TextAlign.center,
                style: Letras.texto(15, cor: Paleta.nevoa),
              ),
            ],
          ),
        ),
      );
}

class _Insignia extends StatelessWidget {
  const _Insignia({required this.conquista, required this.resumo});

  final Conquista conquista;
  final ResumoAcervo resumo;

  @override
  Widget build(BuildContext context) {
    final feita = conquista.conquistada(resumo);
    final cor = feita ? Paleta.lataoClaro : Paleta.nevoa;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: feita ? Paleta.painelClaro : Paleta.marinho,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: feita ? Paleta.latao : Paleta.aco.op(0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(
            feita ? Icons.military_tech : Icons.lock_outline,
            color: feita ? Paleta.latao : Paleta.aco,
            size: 30,
            semanticLabel: feita ? 'Conquistada' : 'Bloqueada',
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conquista.titulo, style: Letras.gravacao(20, cor: cor)),
                Text(
                  conquista.descricao,
                  style: Letras.texto(16, cor: Paleta.nevoa),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: CanoProgresso(
                        valor: conquista.progresso(resumo),
                        altura: 8,
                        cor: feita ? Paleta.latao : Paleta.cobalto,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      conquista.situacao(resumo),
                      style: Letras.maquina(13, cor: cor),
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
