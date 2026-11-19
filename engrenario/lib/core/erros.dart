/// Erro levantado quando uma regra de negócio é violada.
/// A mensagem já vem pronta para ser mostrada ao usuário.
class RegraDeNegocio implements Exception {
  const RegraDeNegocio(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}

/// Erro de comunicação com o catálogo externo (API).
class ErroDeCatalogo implements Exception {
  const ErroDeCatalogo(this.mensagem);
  final String mensagem;

  @override
  String toString() => mensagem;
}
