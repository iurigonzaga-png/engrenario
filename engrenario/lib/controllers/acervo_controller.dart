import 'package:flutter/widgets.dart';

import '../core/erros.dart';
import '../core/formatos.dart';
import '../data/repositorios.dart';
import '../models/jogo.dart';
import '../models/prioridade.dart';
import '../models/resumo.dart';
import '../models/sessao.dart';

/// Camada de regras de negócio do acervo.
///
/// Fica entre as telas e os repositórios: toda mudança passa por aqui,
/// é validada e só então é gravada no banco. As telas escutam este
/// controlador (ChangeNotifier) e se redesenham sozinhas.
class AcervoController extends ChangeNotifier {
  AcervoController({
    JogoRepositorio? jogos,
    SessaoRepositorio? sessoes,
    ConfigRepositorio? config,
  })  : _repoJogos = jogos ?? JogoRepositorio(),
        _repoSessoes = sessoes ?? SessaoRepositorio(),
        _repoConfig = config ?? ConfigRepositorio();

  static const _chaveLimite = 'limite_simultaneos';
  static const _chaveHoras = 'horas_semanais';
  static const int limiteMinimo = 1;
  static const int limiteMaximo = 10;
  static const double horasSemanaisMinimas = 1;
  static const double horasSemanaisMaximas = 100;
  static const int _minutosDoDia = 24 * 60;

  final JogoRepositorio _repoJogos;
  final SessaoRepositorio _repoSessoes;
  final ConfigRepositorio _repoConfig;

  List<JogoAcervo> _jogos = [];
  Map<int, int> _minutosRecentes = {};
  int _limiteSimultaneos = 3;
  double _horasSemanais = 8;
  bool _carregando = true;
  String? _falha;
  ResumoAcervo? _resumo;

  bool get carregando => _carregando;
  String? get falha => _falha;
  List<JogoAcervo> get jogos => List.unmodifiable(_jogos);
  int get limiteSimultaneos => _limiteSimultaneos;
  double get horasSemanais => _horasSemanais;

  ResumoAcervo get resumo =>
      _resumo ??= ResumoAcervo.de(_jogos, _horasSemanais);

  List<JogoAcervo> porStatus(StatusJogo status) =>
      _jogos.where((j) => j.status == status).toList();

  JogoAcervo? porId(int? id) {
    for (final j in _jogos) {
      if (j.id == id) return j;
    }
    return null;
  }

  JogoAcervo? porRawgId(int rawgId) {
    for (final j in _jogos) {
      if (j.rawgId == rawgId) return j;
    }
    return null;
  }

  // ---------------------------------------------------------------- leitura

  Future<void> carregar() async {
    try {
      _limiteSimultaneos =
          int.tryParse(await _repoConfig.ler(_chaveLimite) ?? '') ??
              _limiteSimultaneos;
      _horasSemanais =
          double.tryParse(await _repoConfig.ler(_chaveHoras) ?? '') ??
              _horasSemanais;
      await _recarregar();
      _falha = null;
    } catch (e) {
      _falha = 'Não foi possível carregar o acervo: $e';
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> _recarregar() async {
    _jogos = await _repoJogos.listar();
    _minutosRecentes = await _repoSessoes.minutosPorJogoDesde(
      DateTime.now().subtract(const Duration(days: 14)),
    );
    _resumo = null;
  }

  Future<List<Sessao>> sessoesDe(JogoAcervo jogo) =>
      _repoSessoes.listarDoJogo(jogo.id!);

  // ---------------------------------------------------------------- jogos

  /// Leva um jogo do catálogo para o acervo.
  ///
  /// Regras: não aceita jogo repetido e a entrada é sempre pela fila ou
  /// pela lista de desejos.
  Future<JogoAcervo> adicionar(JogoCatalogo jogo, StatusJogo status) async {
    if (status != StatusJogo.fila && status != StatusJogo.desejo) {
      throw const RegraDeNegocio(
        'Um jogo novo entra pela fila ou pela lista de desejos.',
      );
    }
    if (porRawgId(jogo.rawgId) != null ||
        await _repoJogos.existeRawgId(jogo.rawgId)) {
      throw RegraDeNegocio('"${jogo.nome}" já está no seu acervo.');
    }
    final novo = JogoAcervo.doCatalogo(jogo, status);
    await _repoJogos.inserir(novo);
    await _recarregar();
    notifyListeners();
    return porRawgId(jogo.rawgId) ?? novo;
  }

  /// Muda o status de um jogo aplicando as regras de cada transição.
  Future<void> mudarStatus(
    JogoAcervo jogo,
    StatusJogo destino, {
    double? nota,
  }) async {
    final origem = jogo.status;
    if (!origem.podeIrPara(destino)) {
      throw RegraDeNegocio(
        'Um jogo ${origem.rotulo.toLowerCase()} não pode ir direto para '
        '"${destino.rotulo}".',
      );
    }

    switch (destino) {
      case StatusJogo.jogando:
        final naBancada = porStatus(StatusJogo.jogando).length;
        if (naBancada >= _limiteSimultaneos) {
          throw RegraDeNegocio(
            'A bancada está cheia: você já joga $naBancada de '
            '$_limiteSimultaneos. Zere, pause ou abandone um antes de '
            'começar outro.',
          );
        }
      case StatusJogo.zerado:
        if (jogo.minutosJogados == 0) {
          throw const RegraDeNegocio(
            'Registre ao menos uma sessão antes de marcar como zerado.',
          );
        }
        if (nota == null) {
          throw const RegraDeNegocio('Dê uma nota de 0 a 10 para zerar.');
        }
      case StatusJogo.desejo:
        if (jogo.minutosJogados > 0) {
          throw const RegraDeNegocio(
            'Este jogo já tem horas registradas, então não é mais um desejo.',
          );
        }
      case StatusJogo.fila:
      case StatusJogo.abandonado:
        break;
    }

    if (destino == StatusJogo.zerado) jogo.definirNota(nota);
    jogo.moverPara(destino);
    jogo.concluidoEm = destino == StatusJogo.zerado ? DateTime.now() : null;

    await _repoJogos.atualizar(jogo);
    await _recarregar();
    notifyListeners();
  }

  /// Atualiza os dados que o usuário edita no formulário do jogo.
  Future<void> salvarDetalhes(
    JogoAcervo jogo, {
    required double horasEstimadas,
    String? plataforma,
    String? anotacoes,
    double? nota,
  }) async {
    jogo.definirHorasEstimadas(horasEstimadas);
    if (jogo.status == StatusJogo.zerado) {
      if (nota == null) {
        throw const RegraDeNegocio('Um jogo zerado precisa de nota.');
      }
      jogo.definirNota(nota);
    }
    jogo.plataforma = _limpo(plataforma);
    jogo.anotacoes = _limpo(anotacoes);
    await _repoJogos.atualizar(jogo);
    await _recarregar();
    notifyListeners();
  }

  /// Devolve a descrição do jogo, consultando o catálogo só na primeira
  /// vez: o texto fica guardado no banco para as próximas aberturas.
  Future<String> descricaoDe(
    JogoAcervo jogo,
    Future<String> Function(int rawgId) buscarNoCatalogo,
  ) async {
    final guardada = jogo.descricao;
    if (guardada != null) return guardada;
    final texto = await buscarNoCatalogo(jogo.rawgId);
    jogo.descricao = texto;
    try {
      await _repoJogos.salvarDescricao(jogo.id!, texto);
    } catch (_) {
      // Sem banco agora: o texto já está na tela e na memória; na próxima
      // abertura do app ele é buscado e gravado de novo.
    }
    return texto;
  }

  Future<void> remover(JogoAcervo jogo) async {
    await _repoJogos.excluir(jogo.id!);
    await _recarregar();
    notifyListeners();
  }

  // ---------------------------------------------------------------- sessões

  /// Registra tempo jogado.
  ///
  /// Regras: só para jogos em andamento, nunca no futuro, e a soma do dia
  /// (todos os jogos) não pode passar de 24 horas.
  Future<void> registrarSessao(
    JogoAcervo jogo, {
    required int minutos,
    required DateTime data,
    String? comentario,
  }) async {
    if (jogo.status != StatusJogo.jogando) {
      throw const RegraDeNegocio(
        'Só dá para registrar sessão de um jogo que está na bancada. '
        'Comece a jogar primeiro.',
      );
    }
    final agora = DateTime.now();
    if (data.isAfter(agora)) {
      throw const RegraDeNegocio('A sessão não pode ser no futuro.');
    }
    final dia = DateTime(data.year, data.month, data.day);
    final entrada = jogo.adicionadoEm;
    if (dia.isBefore(DateTime(entrada.year, entrada.month, entrada.day))) {
      throw RegraDeNegocio(
        'O jogo só entrou no acervo em ${Formatos.data(entrada)}.',
      );
    }
    // O construtor de Sessao valida a duração (5 min a 16 h).
    final sessao = Sessao(
      jogoId: jogo.id!,
      data: data,
      minutos: minutos,
      comentario: _limpo(comentario),
    );
    final jaNoDia = await _repoSessoes.minutosNoDia(dia);
    if (jaNoDia + minutos > _minutosDoDia) {
      throw RegraDeNegocio(
        'Esse dia já tem ${Formatos.minutos(jaNoDia)} registrados. '
        'Com mais ${Formatos.minutos(minutos)} passaria de 24 horas.',
      );
    }
    await _repoSessoes.inserir(sessao);
    await _recarregar();
    notifyListeners();
  }

  Future<void> excluirSessao(Sessao sessao) async {
    await _repoSessoes.excluir(sessao.id!);
    await _recarregar();
    notifyListeners();
  }

  // ---------------------------------------------------------------- cálculos

  /// Horas por semana que o usuário vem dedicando a este jogo
  /// (média dos últimos 14 dias).
  double ritmoSemanal(JogoAcervo jogo) =>
      (_minutosRecentes[jogo.id] ?? 0) / 60 / 2;

  /// Data estimada para terminar o jogo, ou null se não der para estimar.
  ///
  /// Usa o ritmo real das últimas duas semanas; sem sessões recentes,
  /// divide as horas semanais configuradas entre os jogos da bancada.
  DateTime? previsaoDeTermino(JogoAcervo jogo) {
    if (jogo.status != StatusJogo.jogando) return null;
    final faltam = jogo.horasParaTerminar;
    if (faltam <= 0) return null;
    var ritmo = ritmoSemanal(jogo);
    if (ritmo <= 0) {
      final naBancada = porStatus(StatusJogo.jogando).length;
      ritmo = _horasSemanais / (naBancada == 0 ? 1 : naBancada);
    }
    if (ritmo <= 0) return null;
    final dias = (faltam / ritmo * 7).ceil();
    return DateTime.now().add(Duration(days: dias));
  }

  /// Ordena os jogos pendentes segundo a estratégia escolhida.
  List<Recomendacao> recomendar(
    EstrategiaPrioridade estrategia, {
    double? horasLivres,
  }) {
    final contexto = ContextoPrioridade(
      horasLivres: horasLivres ?? _horasSemanais,
      generosFavoritos: resumo.zeradosPorGenero,
      agora: DateTime.now(),
    );
    return estrategia.recomendar(_jogos, contexto);
  }

  // ---------------------------------------------------------------- ajustes

  Future<void> salvarPreferencias({
    required int limiteSimultaneos,
    required double horasSemanais,
  }) async {
    if (limiteSimultaneos < limiteMinimo || limiteSimultaneos > limiteMaximo) {
      throw const RegraDeNegocio(
        'A bancada comporta de 1 a 10 jogos ao mesmo tempo.',
      );
    }
    if (horasSemanais < horasSemanaisMinimas ||
        horasSemanais > horasSemanaisMaximas) {
      throw const RegraDeNegocio(
        'As horas por semana ficam entre 1 e 100.',
      );
    }
    final naBancada = porStatus(StatusJogo.jogando).length;
    if (limiteSimultaneos < naBancada) {
      throw RegraDeNegocio(
        'Você está jogando $naBancada agora. Pause algum antes de reduzir '
        'a bancada para $limiteSimultaneos.',
      );
    }
    _limiteSimultaneos = limiteSimultaneos;
    _horasSemanais = horasSemanais;
    await _repoConfig.gravar(_chaveLimite, '$limiteSimultaneos');
    await _repoConfig.gravar(_chaveHoras, '$horasSemanais');
    _resumo = null;
    notifyListeners();
  }

  String? _limpo(String? texto) {
    final t = texto?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}

/// Disponibiliza o [AcervoController] para toda a árvore de widgets.
class Acervo extends InheritedNotifier<AcervoController> {
  const Acervo({
    super.key,
    required AcervoController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Lê o controlador e passa a escutar suas mudanças.
  static AcervoController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Acervo>()!.notifier!;

  /// Lê o controlador sem escutar (para usar em callbacks).
  static AcervoController ler(BuildContext context) =>
      context.getInheritedWidgetOfExactType<Acervo>()!.notifier!;
}
