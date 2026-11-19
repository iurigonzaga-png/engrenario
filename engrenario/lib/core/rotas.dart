import 'package:flutter/material.dart';

/// Transição padrão entre telas: a nova sobe de leve enquanto aparece.
Route<T> rotaSuave<T>(Widget tela) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animacao, secundaria) => tela,
      transitionsBuilder: (context, animacao, secundaria, filho) {
        final curva =
            CurvedAnimation(parent: animacao, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curva,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(curva),
            child: filho,
          ),
        );
      },
    );
