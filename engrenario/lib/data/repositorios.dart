import '../models/jogo.dart';
import '../models/sessao.dart';
import 'api_client.dart';

abstract class Repositorio<T> {
  Future<int> inserir(T item);
  Future<void> atualizar(T item);
  Future<void> excluir(int id);
  Future<List<T>> listar();
  Future<T?> buscarPorId(int id);
}

class JogoRepositorio implements Repositorio<JogoAcervo> {
  @override
  Future<int> inserir(JogoAcervo item) async {
    final result = await ApiClient.post('/jogos', item.toMap());
    final id = result['id'];
    if (id is! num) {
      throw const ApiException('A API não retornou o id do jogo criado.');
    }
    item.id = id.toInt();
    return item.id!;
  }

  @override
  Future<void> atualizar(JogoAcervo item) async {
    await ApiClient.put('/jogos/${item.id}', item.toMap());
  }

  @override
  Future<void> excluir(int id) => ApiClient.delete('/jogos/$id');

  @override
  Future<List<JogoAcervo>> listar() async => (await ApiClient.getList('/jogos'))
      .map((row) => JogoAcervo.fromMap(row))
      .toList();

  @override
  Future<JogoAcervo?> buscarPorId(int id) async =>
      JogoAcervo.fromMap(await ApiClient.getObject('/jogos/$id'));

  Future<void> salvarDescricao(int id, String descricao) =>
      ApiClient.put('/jogos/$id/descricao', {'descricao': descricao});

  Future<bool> existeRawgId(int rawgId) async {
    final result = await ApiClient.getObject('/jogos/rawg/$rawgId/exists');
    return result['exists'] == true;
  }
}

class SessaoRepositorio implements Repositorio<Sessao> {
  @override
  Future<int> inserir(Sessao item) async {
    final result = await ApiClient.post('/sessoes', item.toMap());
    final id = result['id'];
    if (id is! num) {
      throw const ApiException('A API não retornou o id da sessão criada.');
    }
    item.id = id.toInt();
    return item.id!;
  }

  @override
  Future<void> atualizar(Sessao item) async {
    throw UnsupportedError('A API não oferece edição de sessões.');
  }

  @override
  Future<void> excluir(int id) => ApiClient.delete('/sessoes/$id');

  @override
  Future<List<Sessao>> listar() async => (await ApiClient.getList('/sessoes'))
      .map((row) => Sessao.fromMap(row))
      .toList();

  @override
  Future<Sessao?> buscarPorId(int id) async =>
      Sessao.fromMap(await ApiClient.getObject('/sessoes/$id'));

  Future<List<Sessao>> listarDoJogo(int jogoId) async =>
      (await ApiClient.getList('/jogos/$jogoId/sessoes'))
          .map((row) => Sessao.fromMap(row))
          .toList();

  Future<int> minutosNoDia(DateTime dia) async {
    final chave = dia.toIso8601String().substring(0, 10);
    final result = await ApiClient.getObject(
      '/sessoes/minutos-no-dia?dia=$chave',
    );
    return (result['total'] as num).toInt();
  }

  Future<Map<int, int>> minutosPorJogoDesde(DateTime inicio) async {
    final desde = Uri.encodeQueryComponent(inicio.toIso8601String());
    final rows = await ApiClient.getList(
      '/sessoes/minutos-por-jogo?desde=$desde',
    );
    return {
      for (final row in rows)
        (row['jogo_id'] as num).toInt(): (row['total'] as num).toInt(),
    };
  }
}

class ConfigRepositorio {
  Future<String?> ler(String chave) async {
    final result = await ApiClient.getObject(
      '/configuracoes/${Uri.encodeComponent(chave)}',
    );
    return result['valor'] as String?;
  }

  Future<void> gravar(String chave, String valor) async {
    await ApiClient.put(
      '/configuracoes/${Uri.encodeComponent(chave)}',
      {'valor': valor},
    );
  }
}
