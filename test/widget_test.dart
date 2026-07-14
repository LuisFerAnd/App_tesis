import 'package:flutter/material.dart';
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

  testWidgets('patient summary only shows managed patient data', (
    WidgetTester tester,
  ) async {
    final patient = Patient(
      id: 1,
      name: 'Paciente de prueba',
      dni: '0801-1990-00001',
      age: 36,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PatientSummary(patient: patient)),
      ),
    );

    expect(find.text(patient.name), findsOneWidget);
    expect(find.text(patient.dni), findsOneWidget);
    expect(find.text('36 anos'), findsNothing);
    expect(find.text('Sin alertas'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_outlined), findsNothing);
  });

  testWidgets('audio upload problem offers cancel and retry actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiGenerationCard(
            message: 'No se pudo subir el audio',
            isProcessing: false,
            pendingSegments: 1,
            onCancel: () {},
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
