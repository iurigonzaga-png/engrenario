import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/erros.dart';
import '../models/jogo.dart';

/// Contrato de um catálogo de jogos. O app conversa com esta abstração;
/// trocar a RAWG por outra fonte exige só uma nova implementação.
abstract class CatalogoService {
  Future<List<JogoCatalogo>> buscar(String termo);
  Future<List<JogoCatalogo>> populares();

  /// Texto de apresentação do jogo (em inglês, como vem da API).
  Future<String> descricao(int rawgId);
}

/// Implementação que consome a API pública da RAWG (https://rawg.io/apidocs).
class RawgService implements CatalogoService {
  RawgService({http.Client? cliente}) : _cliente = cliente ?? http.Client();

  static const _host = 'api.rawg.io';
  static const _espera = Duration(seconds: 12);

  /// Máximo que a RAWG devolve numa chamada (pedir mais não traz mais).
  static const _porPagina = 40;

  /// Quanto tempo uma lista já consultada vale antes de ir à RAWG de novo.
  static const _validade = Duration(hours: 6);
  static const _maximoGuardado = 60;

  /// Cache das listas, compartilhado por todas as telas enquanto o app
  /// está aberto. Poupa a cota mensal da RAWG: reabrir a busca ou repetir
  /// um termo não gasta requisição.
  static final _guardadas =
      <String, ({DateTime em, List<JogoCatalogo> jogos})>{};

  final http.Client _cliente;

  @override
  Future<List<JogoCatalogo>> buscar(String termo) =>
      _listarGuardando('busca:${termo.trim().toLowerCase()}', {
        'search': termo.trim(),
        'search_precise': 'true',
        'page_size': '$_porPagina',
      });

  @override
  Future<List<JogoCatalogo>> populares() => _listarGuardando('populares', {
        'ordering': '-added',
        'page_size': '$_porPagina',
      });

  Future<List<JogoCatalogo>> _listarGuardando(
    String chave,
    Map<String, String> parametros,
  ) async {
    final guardada = _guardadas[chave];
    if (guardada != null &&
        DateTime.now().difference(guardada.em) < _validade) {
      return guardada.jogos;
    }
    final jogos = await _listar(parametros);
    if (_guardadas.length >= _maximoGuardado) {
      // Descarta a consulta mais antiga.
      _guardadas.remove(_guardadas.keys.first);
    }
    _guardadas
      ..remove(chave)
      ..[chave] = (em: DateTime.now(), jogos: List.unmodifiable(jogos));
    return jogos;
  }

  @override
  Future<String> descricao(int rawgId) async {
    final json = await _get('/api/games/$rawgId', const {});
    final texto = (json['description_raw'] as String?)?.trim() ?? '';
    return texto;
  }

  Future<List<JogoCatalogo>> _listar(Map<String, String> parametros) async {
    final json = await _get('/api/games', parametros);
    final resultados = json['results'];
    if (resultados is! List) return const [];
    final vistos = <int>{};
    final jogos = <JogoCatalogo>[];
    for (final item in resultados) {
      if (item is Map<String, dynamic> && item['id'] is num) {
        final jogo = JogoCatalogo.fromJson(item);
        // A API às vezes repete um jogo entre páginas.
        if (vistos.add(jogo.rawgId)) jogos.add(jogo);
      }
    }
    return jogos;
  }

  Future<Map<String, dynamic>> _get(
    String caminho,
    Map<String, String> parametros,
  ) async {
    if (!ConfigApi.chaveConfigurada) {
      throw const ErroDeCatalogo(
        'Falta a chave da RAWG. Cole a sua em lib/core/config.dart '
        '(é gratuita em rawg.io/apidocs).',
      );
    }
    final uri = Uri.https(_host, caminho, {
      ...parametros,
      'key': ConfigApi.chaveRawg,
    });

    final http.Response resposta;
    try {
      resposta = await _cliente.get(uri).timeout(_espera);
    } on TimeoutException {
      throw const ErroDeCatalogo(
        'O catálogo demorou demais para responder. Tente de novo.',
      );
    } catch (_) {
      throw const ErroDeCatalogo(
        'Sem conexão com o catálogo. Confira a internet e tente de novo.',
      );
    }

    switch (resposta.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw const ErroDeCatalogo(
          'A RAWG recusou a chave. Confira o valor em lib/core/config.dart.',
        );
      case 404:
        throw const ErroDeCatalogo('O catálogo não conhece este jogo.');
      case 429:
        throw const ErroDeCatalogo(
          'O limite mensal de consultas da RAWG foi atingido.',
        );
      default:
        throw ErroDeCatalogo(
          'O catálogo respondeu com erro ${resposta.statusCode}.',
        );
    }

    try {
      final corpo = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (corpo is Map<String, dynamic>) return corpo;
    } on FormatException {
      // cai no erro abaixo
    }
    throw const ErroDeCatalogo('O catálogo enviou uma resposta inesperada.');
  }
}
