import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/acervo_controller.dart';
import '../core/erros.dart';
import '../core/formatos.dart';
import '../core/tema.dart';
import '../models/jogo.dart';
import '../models/sessao.dart';
import '../widgets/capa.dart';
import '../widgets/placa.dart';

/// Lê "12,5" ou "12.5".
double? _decimal(String? texto) =>
    double.tryParse((texto ?? '').trim().replaceAll(',', '.'));

/// Caixa de erro das regras de negócio, mostrada dentro do formulário.
class _ErroDoFormulario extends StatelessWidget {
  const _ErroDoFormulario(this.mensagem);
  final String? mensagem;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: mensagem == null
            ? const SizedBox(width: double.infinity)
            : Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Paleta.brasa.op(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Paleta.brasa),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.report_gmailerrorred,
                        color: Paleta.brasa, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(mensagem!, style: Letras.texto(16)),
                      ),
                    ),
                  ],
                ),
              ),
      );
}

// ------------------------------------------------------------------ adicionar

/// Pergunta para onde vai o jogo escolhido no catálogo.
class FolhaAdicionar extends StatefulWidget {
  const FolhaAdicionar({super.key, required this.jogo});
  final JogoCatalogo jogo;

  @override
  State<FolhaAdicionar> createState() => _FolhaAdicionarState();
}

class _FolhaAdicionarState extends State<FolhaAdicionar> {
  String? _erro;
  bool _salvando = false;

  Future<void> _adicionar(StatusJogo status) async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final novo = await Acervo.ler(context).adicionar(widget.jogo, status);
      if (mounted) Navigator.of(context).pop(novo);
    } on RegraDeNegocio catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final jogo = widget.jogo;
    final horas = jogo.horasApi > 0
        ? 'Duração média de ${jogo.horasApi} h, segundo a RAWG.'
        : 'A RAWG não informa a duração: o app assume '
            '${Formatos.numero(Jogo.horasPadrao)} h, e você pode ajustar depois.';
    return FolhaInferior(
      titulo: 'Adicionar ao acervo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CapaJogo(url: jogo.capaUrl, largura: 96, altura: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(jogo.nome,
                        style: Letras.texto(19, peso: FontWeight.w600)),
                    Text(jogo.legenda,
                        style: Letras.texto(15.5, cor: Paleta.nevoa)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(horas, style: Letras.texto(16, cor: Paleta.nevoa)),
          const SizedBox(height: 16),
          _ErroDoFormulario(_erro),
          BotaoLatao(
            rotulo: 'Pôr na fila',
            icone: Icons.hourglass_empty,
            expandir: true,
            onPressed: _salvando ? null : () => _adicionar(StatusJogo.fila),
          ),
          const SizedBox(height: 10),
          BotaoLatao(
            rotulo: 'Guardar como desejado',
            icone: Icons.bookmark_border,
            secundario: true,
            expandir: true,
            onPressed: _salvando ? null : () => _adicionar(StatusJogo.desejo),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ sessão

/// Formulário para registrar tempo jogado.
class FolhaSessao extends StatefulWidget {
  const FolhaSessao({super.key, required this.jogo});
  final JogoAcervo jogo;

  @override
  State<FolhaSessao> createState() => _FolhaSessaoState();
}

class _FolhaSessaoState extends State<FolhaSessao> {
  final _form = GlobalKey<FormState>();
  final _horas = TextEditingController(text: '1');
  final _minutos = TextEditingController(text: '0');
  final _comentario = TextEditingController();
  late DateTime _dia = _hoje;
  String? _erro;
  bool _salvando = false;

  DateTime get _hoje {
    final a = DateTime.now();
    return DateTime(a.year, a.month, a.day);
  }

  int get _total =>
      (int.tryParse(_horas.text.trim()) ?? 0) * 60 +
      (int.tryParse(_minutos.text.trim()) ?? 0);

  @override
  void dispose() {
    _horas.dispose();
    _minutos.dispose();
    _comentario.dispose();
    super.dispose();
  }

  /// Dias disponíveis: de hoje para trás, até 30 dias ou até a data em
  /// que o jogo entrou no acervo.
  List<DateTime> get _dias {
    final e = widget.jogo.adicionadoEm;
    final entrada = DateTime(e.year, e.month, e.day);
    final dias = <DateTime>[];
    for (var i = 0; i < 30; i++) {
      final dia = DateTime(_hoje.year, _hoje.month, _hoje.day - i);
      if (dia.isBefore(entrada)) break;
      dias.add(dia);
    }
    return dias;
  }

  String _nomeDoDia(DateTime dia) {
    final distancia = _hoje.difference(dia).inHours;
    if (distancia < 12) return 'Hoje';
    if (distancia < 36) return 'Ontem';
    return Formatos.dataCurta(dia);
  }

  String? _validarDuracao(String? _) {
    final total = _total;
    if (total < Sessao.minimoMinutos) return 'Mínimo de 5 minutos.';
    if (total > Sessao.maximoMinutos) return 'Máximo de 16 horas por sessão.';
    return null;
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    // Sessão de hoje leva a hora atual; de outro dia, fica ao meio-dia.
    final ehHoje = _dia == _hoje;
    final data = ehHoje ? DateTime.now() : _dia.add(const Duration(hours: 12));
    try {
      await Acervo.ler(context).registrarSessao(
        widget.jogo,
        minutos: _total,
        data: data,
        comentario: _comentario.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on RegraDeNegocio catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dias = _dias;
    return FolhaInferior(
      titulo: 'Registrar sessão',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.jogo.nome, style: Letras.texto(18, cor: Paleta.nevoa)),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _horas,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    style: Letras.maquina(20),
                    decoration: campoDecorado('Horas', sufixo: 'h'),
                    validator: _validarDuracao,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minutos,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    style: Letras.maquina(20),
                    decoration: campoDecorado('Minutos', sufixo: 'min'),
                    validator: (v) {
                      final m = int.tryParse((v ?? '').trim());
                      if (m == null) return 'Informe os minutos.';
                      if (m > 59) return 'De 0 a 59.';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Quando foi?', style: Letras.texto(17, cor: Paleta.nevoa)),
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: dias.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Escolha(
                  rotulo: _nomeDoDia(dias[i]),
                  marcada: dias[i] == _dia,
                  aoTocar: () => setState(() => _dia = dias[i]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _comentario,
              maxLength: 140,
              textCapitalization: TextCapitalization.sentences,
              style: Letras.texto(18),
              decoration: campoDecorado(
                'Comentário (opcional)',
                ajuda: 'Onde você parou, o que achou.',
              ),
            ),
            const SizedBox(height: 8),
            _ErroDoFormulario(_erro),
            BotaoLatao(
              rotulo: 'Registrar sessão',
              icone: Icons.check,
              expandir: true,
              onPressed: _salvando ? null : _salvar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Opção selecionável (substitui chips e rádios com o visual do app).
class Escolha extends StatelessWidget {
  const Escolha({
    super.key,
    required this.rotulo,
    required this.marcada,
    required this.aoTocar,
    this.icone,
  });

  final String rotulo;
  final bool marcada;
  final VoidCallback aoTocar;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final cor = marcada ? Paleta.abismo : Paleta.creme;
    return Semantics(
      button: true,
      selected: marcada,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: marcada ? Paleta.latao : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: marcada ? Paleta.lataoClaro : Paleta.aco,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: aoTocar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icone != null) ...[
                    Icon(icone, size: 18, color: cor),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    rotulo,
                    style: Letras.texto(
                      17,
                      cor: cor,
                      peso: marcada ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ nota

/// Seletor de nota de 0 a 10, de meio em meio ponto.
class SeletorDeNota extends StatelessWidget {
  const SeletorDeNota({super.key, required this.nota, required this.aoMudar});

  final double nota;
  final ValueChanged<double> aoMudar;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              Formatos.numero(nota),
              style: Letras.maquina(30, cor: Paleta.lataoClaro),
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
                value: nota,
                min: 0,
                max: 10,
                divisions: 20,
                label: Formatos.numero(nota),
                semanticFormatterCallback: (v) => 'Nota ${Formatos.numero(v)}',
                onChanged: aoMudar,
              ),
            ),
          ),
        ],
      );
}

/// Pede a nota final antes de marcar um jogo como zerado.
class FolhaZerar extends StatefulWidget {
  const FolhaZerar({super.key, required this.jogo});
  final JogoAcervo jogo;

  @override
  State<FolhaZerar> createState() => _FolhaZerarState();
}

class _FolhaZerarState extends State<FolhaZerar> {
  late double _nota = widget.jogo.notaPessoal ?? 8;
  String? _erro;
  bool _salvando = false;

  Future<void> _zerar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await Acervo.ler(context)
          .mudarStatus(widget.jogo, StatusJogo.zerado, nota: _nota);
      if (mounted) Navigator.of(context).pop(true);
    } on RegraDeNegocio catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FolhaInferior(
        titulo: 'Marcar como zerado',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Você jogou ${Formatos.horas(widget.jogo.horasJogadas)} de '
              '${widget.jogo.nome}. Que nota ele merece?',
              style: Letras.texto(18),
            ),
            const SizedBox(height: 10),
            SeletorDeNota(
              nota: _nota,
              aoMudar: (v) => setState(() => _nota = v),
            ),
            const SizedBox(height: 12),
            _ErroDoFormulario(_erro),
            BotaoLatao(
              rotulo: 'Marcar como zerado',
              icone: Icons.emoji_events_outlined,
              expandir: true,
              onPressed: _salvando ? null : _zerar,
            ),
          ],
        ),
      );
}

// ------------------------------------------------------------------ detalhes

/// Edição dos dados que o usuário controla em um jogo do acervo.
class FolhaDetalhes extends StatefulWidget {
  const FolhaDetalhes({super.key, required this.jogo});
  final JogoAcervo jogo;

  @override
  State<FolhaDetalhes> createState() => _FolhaDetalhesState();
}

class _FolhaDetalhesState extends State<FolhaDetalhes> {
  final _form = GlobalKey<FormState>();
  late final _horas = TextEditingController(
    text: Formatos.numero(widget.jogo.horasEstimadas),
  );
  late final _plataforma =
      TextEditingController(text: widget.jogo.plataforma ?? '');
  late final _anotacoes =
      TextEditingController(text: widget.jogo.anotacoes ?? '');
  late double _nota = widget.jogo.notaPessoal ?? 8;
  String? _erro;
  bool _salvando = false;

  bool get _zerado => widget.jogo.status == StatusJogo.zerado;

  @override
  void dispose() {
    _horas.dispose();
    _plataforma.dispose();
    _anotacoes.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await Acervo.ler(context).salvarDetalhes(
        widget.jogo,
        horasEstimadas: _decimal(_horas.text)!,
        plataforma: _plataforma.text,
        anotacoes: _anotacoes.text,
        nota: _zerado ? _nota : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on RegraDeNegocio catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FolhaInferior(
        titulo: 'Editar jogo',
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _horas,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(6),
                ],
                style: Letras.maquina(20),
                decoration: campoDecorado(
                  'Duração estimada',
                  sufixo: 'horas',
                  ajuda: widget.jogo.horasApi > 0
                      ? 'A RAWG sugere ${widget.jogo.horasApi} h. '
                          'Ajuste para o seu jeito de jogar.'
                      : 'Quanto você acha que leva para terminar.',
                ),
                validator: (v) {
                  final h = _decimal(v);
                  if (h == null) return 'Informe um número, como 12 ou 7,5.';
                  if (h < JogoAcervo.horasMinimas) {
                    return 'O mínimo é meia hora.';
                  }
                  if (h > JogoAcervo.horasMaximas) {
                    return 'O máximo é 2000 horas.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _plataforma,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                style: Letras.texto(18),
                decoration: campoDecorado('Plataforma (opcional)'),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _anotacoes,
                maxLength: 400,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: Letras.texto(18),
                decoration: campoDecorado('Anotações (opcional)'),
              ),
              if (_zerado) ...[
                const SizedBox(height: 6),
                Text('Sua nota', style: Letras.texto(17, cor: Paleta.nevoa)),
                SeletorDeNota(
                  nota: _nota,
                  aoMudar: (v) => setState(() => _nota = v),
                ),
              ],
              const SizedBox(height: 10),
              _ErroDoFormulario(_erro),
              BotaoLatao(
                rotulo: 'Salvar alterações',
                icone: Icons.check,
                expandir: true,
                onPressed: _salvando ? null : _salvar,
              ),
            ],
          ),
        ),
      );
}

// ------------------------------------------------------------------ ajustes

/// Preferências que alimentam as regras: tamanho da bancada e ritmo.
class FolhaPreferencias extends StatefulWidget {
  const FolhaPreferencias({super.key});

  @override
  State<FolhaPreferencias> createState() => _FolhaPreferenciasState();
}

class _FolhaPreferenciasState extends State<FolhaPreferencias> {
  final _form = GlobalKey<FormState>();
  late final AcervoController _acervo = Acervo.ler(context);
  late int _limite = _acervo.limiteSimultaneos;
  late final _horas = TextEditingController(
    text: Formatos.numero(_acervo.horasSemanais),
  );
  String? _erro;
  bool _salvando = false;

  @override
  void dispose() {
    _horas.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      await _acervo.salvarPreferencias(
        limiteSimultaneos: _limite,
        horasSemanais: _decimal(_horas.text)!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on RegraDeNegocio catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _salvando = false;
        });
      }
    }
  }

  Widget _passo(IconData icone, String rotulo, VoidCallback? aoTocar) =>
      IconButton(
        onPressed: aoTocar,
        tooltip: rotulo,
        icon: Icon(icone),
        color: Paleta.lataoClaro,
        disabledColor: Paleta.aco,
        iconSize: 26,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      );

  @override
  Widget build(BuildContext context) => FolhaInferior(
        titulo: 'Ajustes da oficina',
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Jogos ao mesmo tempo na bancada', style: Letras.texto(18)),
              Text(
                'O app não deixa começar um jogo novo acima desse limite.',
                style: Letras.texto(15.5, cor: Paleta.nevoa),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _passo(
                    Icons.remove_circle_outline,
                    'Diminuir',
                    _limite > AcervoController.limiteMinimo
                        ? () => setState(() => _limite--)
                        : null,
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '$_limite',
                      textAlign: TextAlign.center,
                      style: Letras.maquina(34, cor: Paleta.lataoClaro),
                    ),
                  ),
                  _passo(
                    Icons.add_circle_outline,
                    'Aumentar',
                    _limite < AcervoController.limiteMaximo
                        ? () => setState(() => _limite++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _horas,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  LengthLimitingTextInputFormatter(5),
                ],
                style: Letras.maquina(20),
                decoration: campoDecorado(
                  'Horas de jogo por semana',
                  sufixo: 'h',
                  ajuda: 'Define a pressão do backlog e as previsões.',
                ),
                validator: (v) {
                  final h = _decimal(v);
                  if (h == null) return 'Informe um número, como 8 ou 10,5.';
                  if (h < AcervoController.horasSemanaisMinimas ||
                      h > AcervoController.horasSemanaisMaximas) {
                    return 'Use um valor entre 1 e 100.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _ErroDoFormulario(_erro),
              BotaoLatao(
                rotulo: 'Salvar ajustes',
                icone: Icons.check,
                expandir: true,
                onPressed: _salvando ? null : _salvar,
              ),
            ],
          ),
        ),
      );
}

/// Confirmação para ações que não têm volta.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String acao,
}) async {
  final resposta = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      backgroundColor: Paleta.painel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Paleta.latao),
      ),
      title: Text(titulo, style: Letras.gravacao(24)),
      content: Text(mensagem, style: Letras.texto(18)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        BotaoLatao(
          rotulo: 'Cancelar',
          secundario: true,
          onPressed: () => Navigator.of(dialogo).pop(false),
        ),
        BotaoLatao(
          rotulo: acao,
          secundario: true,
          perigo: true,
          onPressed: () => Navigator.of(dialogo).pop(true),
        ),
      ],
    ),
  );
  return resposta ?? false;
}
