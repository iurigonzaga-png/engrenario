import 'dart:math' as math;

import '../core/erros.dart';
import '../core/formatos.dart';

/// Situação de um jogo dentro do acervo.
///
/// Cada status conhece para quais outros pode ir: é a máquina de estados
/// que sustenta as regras de negócio do app.
enum StatusJogo {
  desejo('Desejado', 'desejo'),
  fila('Na fila', 'fila'),
  jogando('Jogando', 'jogando'),
  zerado('Zerado', 'zerado'),
  abandonado('Abandonado', 'abandonado');

  const StatusJogo(this.rotulo, this.codigo);

  final String rotulo;

  /// Valor gravado no banco de dados.
  final String codigo;

  static StatusJogo deCodigo(String? codigo) => values.firstWhere(
        (s) => s.codigo == codigo,
        orElse: () => StatusJogo.fila,
      );

  List<StatusJogo> get transicoes => switch (this) {
        StatusJogo.desejo => const [StatusJogo.fila],
        StatusJogo.fila => const [
            StatusJogo.jogando,
            StatusJogo.abandonado,
            StatusJogo.desejo,
          ],
        StatusJogo.jogando => const [
            StatusJogo.zerado,
            StatusJogo.fila,
            StatusJogo.abandonado,
          ],
        StatusJogo.zerado => const [StatusJogo.jogando],
        StatusJogo.abandonado => const [StatusJogo.fila],
      };

  bool podeIrPara(StatusJogo destino) => transicoes.contains(destino);

  /// Nome da ação que leva deste status ao [destino].
  String acaoPara(StatusJogo destino) => switch (destino) {
        StatusJogo.jogando =>
          this == StatusJogo.zerado ? 'Jogar de novo' : 'Começar a jogar',
        StatusJogo.zerado => 'Marcar como zerado',
        StatusJogo.abandonado => 'Abandonar',
        StatusJogo.desejo => 'Mover para desejados',
        StatusJogo.fila => switch (this) {
            StatusJogo.jogando => 'Pausar e devolver à fila',
            StatusJogo.desejo => 'Já tenho: pôr na fila',
            _ => 'Devolver à fila',
          },
      };
}

/// Abstração de um jogo. Não pode ser instanciada: quem existe de verdade
/// são os jogos do catálogo ([JogoCatalogo]) e os do acervo ([JogoAcervo]).
abstract class Jogo {
  Jogo({
    required this.rawgId,
    required this.nome,
    this.capaUrl,
    List<String> generos = const [],
    this.metacritic,
    this.lancamento,
    this.horasApi = 0,
  }) : _generos = List.unmodifiable(generos);

  /// Estimativa usada quando a API não informa a duração do jogo.
  static const double horasPadrao = 12;

  final int rawgId;
  final String nome;
  final String? capaUrl;
  final int? metacritic;
  final DateTime? lancamento;

  /// Tempo médio de jogo informado pela API, em horas (0 = desconhecido).
  final int horasApi;

  final List<String> _generos;

  List<String> get generos => _generos;
  int? get ano => lancamento?.year;
  String get generoPrincipal =>
      _generos.isEmpty ? 'Sem gênero' : _generos.first;

  /// Linha de apoio mostrada abaixo do nome. Cada tipo de jogo descreve
  /// a si mesmo de um jeito (polimorfismo).
  String get legenda;

  /// Quantas horas ainda faltam para terminar este jogo.
  double get horasParaTerminar;
}

/// Jogo vindo da API externa, ainda fora do acervo.
class JogoCatalogo extends Jogo {
  JogoCatalogo({
    required super.rawgId,
    required super.nome,
    super.capaUrl,
    super.generos,
    super.metacritic,
    super.lancamento,
    super.horasApi,
    List<String> plataformas = const [],
    this.notaComunidade = 0,
  }) : plataformas = List.unmodifiable(plataformas);

  /// Constrói a partir de um item JSON da RAWG.
  factory JogoCatalogo.fromJson(Map<String, dynamic> json) {
    List<String> nomes(dynamic lista, [String? aninhado]) {
      if (lista is! List) return const [];
      final saida = <String>[];
      for (final item in lista) {
        dynamic alvo = item;
        if (aninhado != null && item is Map) alvo = item[aninhado];
        if (alvo is Map && alvo['name'] is String)
          saida.add(alvo['name'] as String);
      }
      return saida;
    }

    return JogoCatalogo(
      rawgId: (json['id'] as num).toInt(),
      nome: (json['name'] as String?)?.trim() ?? 'Sem nome',
      capaUrl: json['background_image'] as String?,
      generos: nomes(json['genres']),
      metacritic: (json['metacritic'] as num?)?.toInt(),
      lancamento: DateTime.tryParse(json['released'] as String? ?? ''),
      horasApi: (json['playtime'] as num?)?.toInt() ?? 0,
      plataformas: nomes(json['platforms'], 'platform'),
      notaComunidade: (json['rating'] as num?)?.toDouble() ?? 0,
    );
  }

  final List<String> plataformas;

  /// Nota média dos usuários da RAWG, de 0 a 5.
  final double notaComunidade;

  @override
  String get legenda {
    final partes = <String>[generoPrincipal, if (ano != null) '$ano'];
    return partes.join(', ');
  }

  @override
  double get horasParaTerminar =>
      horasApi > 0 ? horasApi.toDouble() : Jogo.horasPadrao;
}

/// Jogo guardado no acervo do usuário (persistido no banco).
///
/// Os campos sensíveis são privados e só mudam por métodos que validam
/// o valor (encapsulamento).
class JogoAcervo extends Jogo {
  JogoAcervo({
    this.id,
    required super.rawgId,
    required super.nome,
    super.capaUrl,
    super.generos,
    super.metacritic,
    super.lancamento,
    super.horasApi,
    required StatusJogo status,
    required double horasEstimadas,
    double? notaPessoal,
    this.plataforma,
    this.anotacoes,
    required this.adicionadoEm,
    this.concluidoEm,
    this.minutosJogados = 0,
    this.ultimaSessao,
    this.descricao,
  })  : _status = status,
        _horasEstimadas = horasEstimadas,
        _notaPessoal = notaPessoal;

  /// Leva um jogo do catálogo para o acervo.
  factory JogoAcervo.doCatalogo(JogoCatalogo jogo, StatusJogo status) =>
      JogoAcervo(
        rawgId: jogo.rawgId,
        nome: jogo.nome,
        capaUrl: jogo.capaUrl,
        generos: jogo.generos,
        metacritic: jogo.metacritic,
        lancamento: jogo.lancamento,
        horasApi: jogo.horasApi,
        status: status,
        horasEstimadas: jogo.horasParaTerminar,
        plataforma: jogo.plataformas.isEmpty ? null : jogo.plataformas.first,
        adicionadoEm: DateTime.now(),
      );

  factory JogoAcervo.fromMap(Map<String, Object?> m) => JogoAcervo(
        id: m['id'] as int?,
        rawgId: m['rawg_id'] as int,
        nome: m['nome'] as String,
        capaUrl: m['capa_url'] as String?,
        generos: ((m['generos'] as String?) ?? '')
            .split('|')
            .where((g) => g.isNotEmpty)
            .toList(),
        metacritic: m['metacritic'] as int?,
        lancamento: DateTime.tryParse((m['lancamento'] as String?) ?? ''),
        horasApi: (m['horas_api'] as int?) ?? 0,
        status: StatusJogo.deCodigo(m['status'] as String?),
        horasEstimadas: (m['horas_estimadas'] as num).toDouble(),
        notaPessoal: (m['nota_pessoal'] as num?)?.toDouble(),
        plataforma: m['plataforma'] as String?,
        anotacoes: m['anotacoes'] as String?,
        adicionadoEm: DateTime.parse(m['adicionado_em'] as String),
        concluidoEm: DateTime.tryParse((m['concluido_em'] as String?) ?? ''),
        minutosJogados: ((m['minutos_jogados'] as num?) ?? 0).toInt(),
        ultimaSessao: DateTime.tryParse((m['ultima_sessao'] as String?) ?? ''),
        descricao: m['descricao'] as String?,
      );

  static const double horasMinimas = 0.5;
  static const double horasMaximas = 2000;

  int? id;
  String? plataforma;
  String? anotacoes;
  final DateTime adicionadoEm;
  DateTime? concluidoEm;

  /// Soma das sessões registradas (calculada pelo banco).
  int minutosJogados;
  DateTime? ultimaSessao;

  /// Descrição da RAWG guardada no banco: `null` se ainda não foi buscada,
  /// vazia se a RAWG não tem texto para o jogo. Grava-se por rota própria,
  /// por isso não entra em [toMap].
  String? descricao;

  StatusJogo _status;
  double _horasEstimadas;
  double? _notaPessoal;

  StatusJogo get status => _status;
  double get horasEstimadas => _horasEstimadas;
  double? get notaPessoal => _notaPessoal;

  /// Troca o status respeitando a máquina de estados.
  void moverPara(StatusJogo destino) {
    if (!_status.podeIrPara(destino)) {
      throw RegraDeNegocio(
        'Um jogo ${_status.rotulo.toLowerCase()} não pode ir direto para '
        '"${destino.rotulo}".',
      );
    }
    _status = destino;
  }

  void definirHorasEstimadas(double horas) {
    if (horas.isNaN || horas < horasMinimas || horas > horasMaximas) {
      throw const RegraDeNegocio(
        'A duração estimada precisa ficar entre meia hora e 2000 horas.',
      );
    }
    _horasEstimadas = horas;
  }

  void definirNota(double? nota) {
    if (nota != null && (nota.isNaN || nota < 0 || nota > 10)) {
      throw const RegraDeNegocio('A nota vai de 0 a 10.');
    }
    _notaPessoal = nota;
  }

  double get horasJogadas => minutosJogados / 60;

  /// Avanço de 0 a 1. Um jogo zerado está sempre completo.
  double get progresso {
    if (_status == StatusJogo.zerado) return 1;
    if (_horasEstimadas <= 0) return 0;
    return (horasJogadas / _horasEstimadas).clamp(0.0, 1.0);
  }

  bool get passouDaEstimativa =>
      _status == StatusJogo.jogando && horasJogadas > _horasEstimadas;

  /// Só conta como pendência o que está na fila ou em andamento.
  bool get pendente =>
      _status == StatusJogo.fila || _status == StatusJogo.jogando;

  @override
  double get horasParaTerminar =>
      pendente ? math.max(0, _horasEstimadas - horasJogadas) : 0;

  @override
  String get legenda => switch (_status) {
        StatusJogo.desejo => 'Desejado, $generoPrincipal',
        StatusJogo.fila =>
          'Na fila ${Formatos.haQuanto(adicionadoEm)}, ${Formatos.horas(_horasEstimadas)}',
        StatusJogo.jogando =>
          '${(progresso * 100).round()}% feito, faltam ${Formatos.horas(horasParaTerminar)}',
        StatusJogo.zerado => _notaPessoal == null
            ? 'Zerado em ${Formatos.horas(horasJogadas)}'
            : 'Zerado, nota ${Formatos.numero(_notaPessoal!)}',
        StatusJogo.abandonado =>
          'Abandonado com ${Formatos.horas(horasJogadas)} jogadas',
      };

  /// Colunas persistidas na tabela `jogos`.
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'rawg_id': rawgId,
        'nome': nome,
        'capa_url': capaUrl,
        'generos': generos.join('|'),
        'metacritic': metacritic,
        'lancamento': lancamento?.toIso8601String(),
        'horas_api': horasApi,
        'horas_estimadas': _horasEstimadas,
        'status': _status.codigo,
        'nota_pessoal': _notaPessoal,
        'plataforma': plataforma,
        'anotacoes': anotacoes,
        'adicionado_em': adicionadoEm.toIso8601String(),
        'concluido_em': concluidoEm?.toIso8601String(),
      };
}
