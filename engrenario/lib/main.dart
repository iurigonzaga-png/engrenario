import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/acervo_controller.dart';
import 'core/tema.dart';
import 'screens/abertura_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Paleta.marinho,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const EngrenarioApp());
}

class EngrenarioApp extends StatefulWidget {
  const EngrenarioApp({super.key});

  @override
  State<EngrenarioApp> createState() => _EngrenarioAppState();
}

class _EngrenarioAppState extends State<EngrenarioApp> {
  // Um único controlador para o app inteiro (interface, regras e banco
  // conversam por ele).
  final _acervo = AcervoController();

  @override
  void dispose() {
    _acervo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Acervo(
        controller: _acervo,
        child: MaterialApp(
          title: 'Engrenário',
          debugShowCheckedModeBanner: false,
          theme: temaEngrenario(),
          home: const AberturaScreen(),
        ),
      );
}
