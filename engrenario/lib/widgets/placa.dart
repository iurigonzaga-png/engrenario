import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../models/jogo.dart';

/// Painel azul com moldura de aço e cantoneiras de latão nos cantos.
class Placa extends StatelessWidget {
  const Placa({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.rebites = true,
    this.cor = Paleta.painel,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Mostra as cantoneiras de latão (o nome vem da versão com rebites).
  final bool rebites;
  final Color cor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final conteudo = CustomPaint(
      foregroundPainter: rebites ? const _CantoneirasPainter() : null,
      child: Padding(padding: padding, child: child),
    );
    return Container(
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Paleta.aco, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.op(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? conteudo
          : Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap, child: conteudo),
            ),
    );
  }
}

/// Cantoneiras em L, de latão, com um ponto de fixação na dobra.
class _CantoneirasPainter extends CustomPainter {
  const _CantoneirasPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const margem = 7.0;
    const braco = 14.0;
    final traco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.square
      ..color = Paleta.latao.op(0.85);
    final ponto = Paint()..color = Paleta.latao;
    for (final (x, y, dx, dy) in [
      (margem, margem, 1.0, 1.0),
      (size.width - margem, margem, -1.0, 1.0),
      (margem, size.height - margem, 1.0, -1.0),
      (size.width - margem, size.height - margem, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x + dx * braco, y)
          ..lineTo(x, y)
          ..lineTo(x, y + dy * braco),
        traco,
      );
      canvas.drawCircle(Offset(x + dx * 4.5, y + dy * 4.5), 1.6, ponto);
    }
  }

  @override
  bool shouldRepaint(_CantoneirasPainter antigo) => false;
}

/// Título de seção com filete de latão.
class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {super.key, this.acao, this.aoTocar});

  final String texto;
  final String? acao;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(texto, style: Letras.gravacao(24)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Paleta.latao, Paleta.latao.op(0)],
                ),
              ),
            ),
          ),
          if (acao != null)
            TextButton(
              onPressed: aoTocar,
              style: TextButton.styleFrom(
                foregroundColor: Paleta.celeste,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(48, 48),
              ),
              child: Text(
                acao!,
                style: Letras.texto(17, cor: Paleta.celeste),
              ),
            ),
        ],
      );
}

/// Botão de cantos retos: principal (latão chapado, texto escuro) ou
/// secundário (fundo escuro, contorno de latão e texto claro).
class BotaoLatao extends StatelessWidget {
  const BotaoLatao({
    super.key,
    required this.rotulo,
    required this.onPressed,
    this.icone,
    this.secundario = false,
    this.perigo = false,
    this.expandir = false,
  });

  final String rotulo;
  final VoidCallback? onPressed;
  final IconData? icone;
  final bool secundario;
  final bool perigo;
  final bool expandir;

  static const _preenchimento = Paleta.latao;

  @override
  Widget build(BuildContext context) {
    final ativo = onPressed != null;
    final contorno = perigo ? Paleta.brasa : _preenchimento;
    final corTexto =
        secundario ? (perigo ? Paleta.brasa : Paleta.creme) : Paleta.abismo;
    final conteudo = Row(
      mainAxisSize: expandir ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icone != null) ...[
          Icon(icone, size: 18, color: corTexto),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            rotulo,
            textAlign: TextAlign.center,
            style: Letras.maquina(16, cor: corTexto).copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              // A Josefin assenta alto na linha: equilibra o respiro.
              height: 1.35,
            ),
          ),
        ),
      ],
    );
    return Opacity(
      opacity: ativo ? 1 : 0.4,
      child: Material(
        color: secundario ? Paleta.abismo : _preenchimento,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: secundario
              ? BorderSide(color: contorno, width: 1.2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashColor: (secundario ? contorno : Paleta.abismo).op(0.12),
          highlightColor: (secundario ? contorno : Paleta.abismo).op(0.06),
          hoverColor: (secundario ? contorno : Colors.white).op(0.10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: conteudo,
            ),
          ),
        ),
      ),
    );
  }
}

Color corDoStatus(StatusJogo status) => switch (status) {
      StatusJogo.desejo => Paleta.nevoa,
      StatusJogo.fila => Paleta.latao,
      StatusJogo.jogando => Paleta.celeste,
      StatusJogo.zerado => Paleta.lataoClaro,
      StatusJogo.abandonado => Paleta.cobre,
    };

IconData iconeDoStatus(StatusJogo status) => switch (status) {
      StatusJogo.desejo => Icons.bookmark_border,
      StatusJogo.fila => Icons.hourglass_empty,
      StatusJogo.jogando => Icons.sports_esports_outlined,
      StatusJogo.zerado => Icons.emoji_events_outlined,
      StatusJogo.abandonado => Icons.do_not_disturb_alt_outlined,
    };

/// Etiqueta carimbada com o status do jogo.
class Selo extends StatelessWidget {
  const Selo(this.texto, {super.key, this.cor = Paleta.latao, this.icone});

  factory Selo.status(StatusJogo status) => Selo(
        status.rotulo,
        cor: corDoStatus(status),
        icone: iconeDoStatus(status),
      );

  final String texto;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cor.op(0.12),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: cor.op(0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(icone, size: 14, color: cor),
              const SizedBox(width: 5),
            ],
            Text(texto, style: Letras.maquina(12.5, cor: cor)),
          ],
        ),
      );
}

/// Barra de progresso em forma de cano: o vapor (latão) avança por dentro.
class CanoProgresso extends StatelessWidget {
  const CanoProgresso({
    super.key,
    required this.valor,
    this.altura = 12,
    this.cor = Paleta.latao,
    this.entrada,
  });

  final double valor;
  final double altura;
  final Color cor;

  /// Se informado, o preenchimento acompanha esta animação (0 a 1).
  final Animation<double>? entrada;

  @override
  Widget build(BuildContext context) {
    final entrada = this.entrada ?? const AlwaysStoppedAnimation(1.0);
    return Semantics(
      label: 'Progresso',
      value: '${(valor * 100).round()}%',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: valor.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, alvo, _) => AnimatedBuilder(
          animation: entrada,
          builder: (context, _) => Container(
            height: altura,
            decoration: BoxDecoration(
              color: Paleta.aco.op(0.45),
              borderRadius: BorderRadius.circular(altura / 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (alvo * entrada.value).clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cor,
                    borderRadius: BorderRadius.circular(altura / 2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso para telas sem conteúdo ou com erro, sempre com um próximo passo.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.titulo,
    required this.mensagem,
    this.icone = Icons.settings_outlined,
    this.acao,
    this.aoTocar,
  });

  final String titulo;
  final String mensagem;
  final IconData icone;
  final String? acao;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 44, color: Paleta.acoClaro),
              const SizedBox(height: 14),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: Letras.gravacao(24),
              ),
              const SizedBox(height: 8),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: Letras.texto(17, cor: Paleta.nevoa),
              ),
              if (acao != null) ...[
                const SizedBox(height: 18),
                BotaoLatao(rotulo: acao!, onPressed: aoTocar),
              ],
            ],
          ),
        ),
      );
}

/// Fundo padrão das folhas que sobem do rodapé (formulários).
class FolhaInferior extends StatelessWidget {
  const FolhaInferior({super.key, required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        // Sobe junto com o teclado.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Paleta.painel,
            border: Border(top: BorderSide(color: Paleta.latao, width: 2)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(titulo, style: Letras.gravacao(26)),
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          ),
        ),
      );
}

Future<T?> abrirFolha<T>(BuildContext context, Widget folha) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => folha,
    );
