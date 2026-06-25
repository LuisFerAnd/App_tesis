import 'package:flutter_test/flutter_test.dart';

import 'package:sanare_mobile/main.dart';

void main() {
  testWidgets('shows the Sanare login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SanareMobileApp());

    expect(find.text('Sanare IA'), findsOneWidget);
    expect(find.text('Acceso medico'), findsOneWidget);
    expect(find.text('Correo medico'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('navigates to the mobile shell', (WidgetTester tester) async {
    await tester.pumpWidget(const SanareMobileApp());

    await tester.ensureVisible(find.text('Continuar en modo demo'));
    await tester.tap(find.text('Continuar en modo demo'));
    await tester.pumpAndSettle();

    expect(find.text('Consulta IA'), findsOneWidget);
    expect(find.text('Iniciar grabacion'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Resumen generado por IA'), 300);
    expect(find.text('Resumen generado por IA'), findsOneWidget);
  });
}
