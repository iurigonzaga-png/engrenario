import 'package:flutter/material.dart';

import '../core/rotas.dart';
import '../core/tema.dart';
import '../widgets/engrenagem.dart';
import 'acervo_screen.dart';
import 'busca_screen.dart';
import 'inicio_screen.dart';
import 'oraculo_screen.dart';
import 'registros_screen.dart';

/// Casca do app: quatro abas e o botão central de adicionar jogo.
class PrincipalScreen extends StatefulWidget {
  const PrincipalScreen({super.key});

  @override
  State<PrincipalScreen> createState() => _PrincipalScreenState();
}

class _PrincipalScreenState extends State<PrincipalScreen> {
  int _aba = 0;

  void _irPara(int aba) => setState(() => _aba = aba);

  void _procurar() =>
      Navigator.of(context).push(rotaSuave(const BuscaScreen()));

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        // Só a aba atual fica montada: ao voltar para ela, as animações
        // de entrada tocam de novo.
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          child: KeyedSubtree(
            key: ValueKey(_aba),
            child: switch (_aba) {
              0 => InicioScreen(
                  aoProcurar: _procurar,
                  aoVerFila: () => _irPara(2),
                  aoVerAcervo: () => _irPara(1),
                ),
              1 => AcervoScreen(aoProcurar: _procurar),
              2 => OraculoScreen(aoProcurar: _procurar),
              _ => const RegistrosScreen(),
            },
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _BotaoAdicionar(aoTocar: _procurar),
        bottomNavigationBar: _BarraInferior(aba: _aba, aoMudar: _irPara),
      );
}

class _BotaoAdicionar extends StatelessWidget {
  const _BotaoAdicionar({required this.aoTocar});
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Procurar jogo para adicionar',
        child: GestureDetector(
          onTap: aoTocar,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const EngrenagemGirando(
                  tamanho: 74,
                  dentes: 12,
                  periodo: Duration(seconds: 14),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Paleta.abismo,
                    shape: BoxShape.circle,
                    border: Border.all(color: Paleta.lataoClaro, width: 1.5),
                  ),
                  child: const Icon(Icons.add, color: Paleta.lataoClaro),
                ),
              ],
            ),
          ),
        ),
      );
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({required this.aba, required this.aoMudar});

  final int aba;
  final ValueChanged<int> aoMudar;

  static const _itens = [
    (Icons.home_outlined, 'Início'),
    (Icons.inventory_2_outlined, 'Acervo'),
    (Icons.auto_awesome_outlined, 'O que jogar'),
    (Icons.insights_outlined, 'Registros'),
  ];

  Widget _item(int i) {
    final ativo = i == aba;
    final cor = ativo ? Paleta.lataoClaro : Paleta.nevoa;
    return Expanded(
      child: Semantics(
        button: true,
        selected: ativo,
        child: InkWell(
          onTap: () => aoMudar(i),
          child: SizedBox(
            height: 62,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  height: 2,
                  width: ativo ? 26 : 0,
                  margin: const EdgeInsets.only(bottom: 6),
                  color: Paleta.latao,
                ),
                Icon(_itens[i].$1, color: cor, size: 23),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _itens[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Letras.texto(
                        13.5,
                        cor: cor,
                        peso: ativo ? FontWeight.w600 : FontWeight.w400,
                      ).copyWith(height: 1.1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Paleta.marinho.op(0.97),
          border: const Border(
            top: BorderSide(color: Paleta.aco, width: 1.2),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.op(0.5), blurRadius: 14),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Material(
            type: MaterialType.transparency,
            child: Row(
              children: [
                _item(0),
                _item(1),
                const SizedBox(width: 78), // espaço do botão central
                _item(2),
                _item(3),
              ],
            ),
          ),
        ),
      );
}
