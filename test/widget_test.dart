import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:servired_app/main.dart';

void main() {
  setUpAll(() async {
    // Cargar variables de entorno para tests
    await dotenv.load(fileName: '.env.dev');
  });

  testWidgets('ServiredApp arranca sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const ServiredApp());
    // pump() en lugar de pumpAndSettle(): la app contiene Timer.periodic
    // (countdown de AcumuladoCardWidget) que nunca se asienta. Un pump
    // único es suficiente para verificar que el árbol inicial renderiza
    // sin excepciones.
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
