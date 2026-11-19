/// Configuração da API externa (RAWG).
///
/// Gere uma chave gratuita em https://rawg.io/apidocs e cole abaixo,
/// ou rode o app com:  flutter run --dart-define=RAWG_KEY=sua_chave
class ConfigApi {
  ConfigApi._();

  static const String urlBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  static const String _naoConfigurada = 'COLE_SUA_CHAVE_AQUI';

  static const String chaveRawg = String.fromEnvironment(
    'RAWG_KEY',
    defaultValue: '89146fec7ca847f68aa3b90ed3ec73a1',
  );

  static bool get chaveConfigurada =>
      chaveRawg.isNotEmpty && chaveRawg != _naoConfigurada;
}
