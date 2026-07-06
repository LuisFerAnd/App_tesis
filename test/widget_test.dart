import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:sanare_mobile/main.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('shows the Sanare login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SanareMobileApp());
    await tester.pumpAndSettle();

    expect(find.text('Sanare IA'), findsOneWidget);
    expect(find.text('Acceso medico'), findsOneWidget);
    expect(find.text('Correo medico'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Crear cuenta medica'), findsOneWidget);
  });

  testWidgets('opens the doctor registration screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SanareMobileApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Crear cuenta medica'));
    await tester.tap(find.text('Crear cuenta medica'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo doctor'), findsOneWidget);
    expect(find.text('Nombre del doctor'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  testWidgets('does not expose demo access on login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SanareMobileApp());
    await tester.pumpAndSettle();

    expect(find.text('Continuar en modo demo'), findsNothing);
  });
}
