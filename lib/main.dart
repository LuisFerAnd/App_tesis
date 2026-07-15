import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

import 'platform_files.dart';
import 'recording/recording_service.dart';
import 'recording/local_segment_store.dart';
import 'recording/progressive_upload_service.dart';

part 'soap_evaluation.dart';

void main() {
  runApp(const SanareMobileApp());
}

class SanareMobileApp extends StatelessWidget {
  const SanareMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0A7F78);
    const ink = Color(0xFF17212B);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sanare IA',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: const Color(0xFFE7793F),
          tertiary: const Color(0xFF4E6EAB),
          surface: const Color(0xFFF6F8F7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8F7),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF6F8F7),
          foregroundColor: ink,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE2E8E6)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD8E1DF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD8E1DF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primary, width: 1.6),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<_RestoredAuth?> restoredAuthFuture;

  @override
  void initState() {
    super.initState();
    restoredAuthFuture = _restoreAuth();
  }

  Future<_RestoredAuth?> _restoreAuth() async {
    final apiClient = ApiClient();
    final session = await apiClient.restoreSession();
    if (session == null) return null;

    return _RestoredAuth(apiClient: apiClient, session: session);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RestoredAuth?>(
      future: restoredAuthFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final restoredAuth = snapshot.data;
        if (restoredAuth == null) {
          return const LoginScreen();
        }

        return MobileShell(
          apiClient: restoredAuth.apiClient,
          session: restoredAuth.session,
        );
      },
    );
  }
}

class _RestoredAuth {
  const _RestoredAuth({required this.apiClient, required this.session});

  final ApiClient apiClient;
  final ApiSession session;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool passwordVisible = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!formKey.currentState!.validate()) return;

    final apiClient = ApiClient();

    setState(() => isLoading = true);
    try {
      final session = await apiClient.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MobileShell(apiClient: apiClient, session: session),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar sesion: $error')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _openRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DoctorRegisterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0A7F78);
    const deepInk = Color(0xFF17212B);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 460,
                    minHeight: constraints.maxHeight - 42,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: deepInk,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const SanareMark(),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: .12,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: .18,
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'IA clinica',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              const Text(
                                'Sanare IA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Consulta, resumen SOAP y PDF en un flujo medico simple.',
                                style: TextStyle(
                                  color: Color(0xFFDFF7F4),
                                  height: 1.35,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Row(
                                children: [
                                  Expanded(
                                    child: LoginSignal(
                                      icon: Icons.mic_none,
                                      text: 'Audio',
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: LoginSignal(
                                      icon: Icons.auto_awesome_outlined,
                                      text: 'SOAP',
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: LoginSignal(
                                      icon: Icons.picture_as_pdf_outlined,
                                      text: 'PDF',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Acceso medico',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ingresa con tu correo y contrasena para continuar con pacientes, consultas y reportes.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE0E7E5)),
                          ),
                          child: Form(
                            key: formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: const InputDecoration(
                                    labelText: 'Correo medico',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isEmpty) {
                                      return 'Ingresa tu correo medico.';
                                    }
                                    if (!email.contains('@')) {
                                      return 'Usa un correo valido.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: !passwordVisible,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  onFieldSubmitted: (_) => _login(),
                                  decoration: InputDecoration(
                                    labelText: 'Contrasena',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: passwordVisible
                                          ? 'Ocultar contrasena'
                                          : 'Mostrar contrasena',
                                      onPressed: () {
                                        setState(() {
                                          passwordVisible = !passwordVisible;
                                        });
                                      },
                                      icon: Icon(
                                        passwordVisible
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').isEmpty) {
                                      return 'Ingresa tu contrasena.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.verified_user_outlined,
                                      color: primary,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Conexion directa al API de Sanare.',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: FilledButton.icon(
                                    onPressed: isLoading ? null : _login,
                                    icon: isLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.login),
                                    label: Text(
                                      isLoading ? 'Verificando...' : 'Ingresar',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: TextButton.icon(
                                    onPressed: isLoading ? null : _openRegister,
                                    icon: const Icon(
                                      Icons.person_add_alt_outlined,
                                      size: 20,
                                    ),
                                    label: const Text('Crear cuenta medica'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            'Sanare IA para equipos clinicos',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class DoctorRegisterScreen extends StatefulWidget {
  const DoctorRegisterScreen({super.key});

  @override
  State<DoctorRegisterScreen> createState() => _DoctorRegisterScreenState();
}

class _DoctorRegisterScreenState extends State<DoctorRegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final specializationController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmationController = TextEditingController();
  bool isLoading = false;
  bool passwordVisible = false;

  @override
  void dispose() {
    nameController.dispose();
    specializationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!formKey.currentState!.validate()) return;

    final apiClient = ApiClient();

    setState(() => isLoading = true);
    try {
      final session = await apiClient.registerDoctor(
        name: nameController.text.trim(),
        specialization: specializationController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        passwordConfirmation: passwordConfirmationController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MobileShell(apiClient: apiClient, session: session),
        ),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear la cuenta: $error')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo doctor')),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Crear cuenta medica',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cada doctor tendra pacientes, consultas y PDFs separados por su usuario.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE0E7E5)),
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: nameController,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: const InputDecoration(
                              labelText: 'Nombre del doctor',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Ingresa el nombre.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: specializationController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Especializacion',
                              prefixIcon: Icon(Icons.medical_services_outlined),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Ingresa la especializacion.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Correo medico',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return 'Ingresa el correo.';
                              if (!email.contains('@')) {
                                return 'Usa un correo valido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: passwordController,
                            obscureText: !passwordVisible,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Contrasena',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: passwordVisible
                                    ? 'Ocultar contrasena'
                                    : 'Mostrar contrasena',
                                onPressed: () {
                                  setState(() {
                                    passwordVisible = !passwordVisible;
                                  });
                                },
                                icon: Icon(
                                  passwordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              if (password.length < 8) {
                                return 'Minimo 8 caracteres.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: passwordConfirmationController,
                            obscureText: !passwordVisible,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            onFieldSubmitted: (_) => _register(),
                            decoration: const InputDecoration(
                              labelText: 'Confirmar contrasena',
                              prefixIcon: Icon(Icons.lock_reset_outlined),
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Confirma la contrasena.';
                              }
                              if (value != passwordController.text) {
                                return 'Las contrasenas no coinciden.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Icon(
                                Icons.lock_person_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'La informacion clinica queda vinculada a esta cuenta.',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: isLoading ? null : _register,
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_alt_outlined),
                              label: Text(
                                isLoading ? 'Creando...' : 'Crear cuenta',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SanareMark extends StatelessWidget {
  const SanareMark({super.key});

  @override
  Widget build(BuildContext context) {
    const heights = [18.0, 30.0, 44.0, 30.0, 18.0];

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: heights
            .map(
              (height) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 4,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class LoginSignal extends StatelessWidget {
  const LoginSignal({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF7DDDD1), size: 20),
          const SizedBox(height: 5),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class MobileShell extends StatefulWidget {
  const MobileShell({super.key, required this.apiClient, this.session});

  final ApiClient apiClient;
  final ApiSession? session;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      AiConsultationScreen(apiClient: widget.apiClient),
      PatientsScreen(apiClient: widget.apiClient),
      HistoryScreen(apiClient: widget.apiClient),
      AccountScreen(apiClient: widget.apiClient, session: widget.session),
      if (widget.apiClient.isAdmin)
        SoapEvaluationAdminScreen(apiClient: widget.apiClient),
    ];

    return Scaffold(
      body: screens[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Consulta',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Pacientes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.picture_as_pdf_outlined),
            selectedIcon: Icon(Icons.picture_as_pdf),
            label: 'PDF',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
          if (widget.apiClient.isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check),
              label: 'Evaluaciones',
            ),
        ],
      ),
    );
  }
}

class SoapNote {
  const SoapNote({
    required this.reason,
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    required this.aiSummary,
    this.vitalSigns = const {},
    this.aiUsage = const {},
  });

  final String reason;
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;
  final String aiSummary;
  final Map<String, String> vitalSigns;
  final Map<String, dynamic> aiUsage;

  factory SoapNote.fromDraftJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> aiUsage = const {},
  }) {
    final reason = _textOrUnspecified(json['reason']);
    final subjective = _textOrUnspecified(json['subjective']);
    final objective = _textOrUnspecified(json['objective']);
    final assessment = _textOrUnspecified(json['assessment']);
    final plan = _textOrUnspecified(json['plan']);

    return SoapNote(
      reason: reason,
      subjective: subjective,
      objective: objective,
      assessment: assessment,
      plan: plan,
      aiSummary: 'Motivo: $reason\nEvaluacion: $assessment\nPlan: $plan',
      vitalSigns: _vitalSignsFromJson(json['vital_signs']),
      aiUsage: aiUsage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reason': reason,
      'subjective': subjective,
      'objective': objective,
      'assessment': assessment,
      'plan': plan,
      'ai_summary': aiSummary,
      'vital_signs': vitalSigns,
      'ai_usage': aiUsage,
    };
  }
}

class SoapDraftResult {
  const SoapDraftResult({required this.transcript, required this.soapNote});

  final String transcript;
  final SoapNote soapNote;

  factory SoapDraftResult.fromJson(Map<String, dynamic> json) {
    final draft = json['draft'];
    if (draft is! Map<String, dynamic>) {
      throw Exception('Respuesta sin borrador SOAP.');
    }

    return SoapDraftResult(
      transcript: json['transcript']?.toString() ?? '',
      soapNote: SoapNote.fromDraftJson(
        draft,
        aiUsage: _aiUsageFromDraftResponse(json),
      ),
    );
  }
}

class AiConsultationScreen extends StatefulWidget {
  const AiConsultationScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<AiConsultationScreen> createState() => _AiConsultationScreenState();
}

class _AiConsultationScreenState extends State<AiConsultationScreen>
    with WidgetsBindingObserver {
  static const String _draftKey = 'sanare.consultation.autosave';

  late final RecordingService recordingService;
  late final ProgressiveUploadService uploadService;
  Timer? processingPollTimer;
  Timer? processingElapsedTimer;
  final Stopwatch processingStopwatch = Stopwatch();
  late final ValueNotifier<ProcessingSnapshot?> processingSnapshotNotifier;
  String? processingSessionUuid;
  DateTime? consultationStartedAt;
  DateTime? recordingSavedAt;
  Patient? selectedPatient;
  bool isGeneratingSummary = false;
  bool isSaving = false;
  bool isGeneratingPdf = false;
  bool isConsultationSaved = false;
  Duration recordingDuration = Duration.zero;
  Duration? pdfGenerationDuration;
  String? recordingPath;
  List<String> recordingPaths = <String>[];
  String? generatedPdfPath;
  String? generatedTranscript;
  SoapNote? generatedSoapNote;
  int? savedConsultationId;
  RecordingStatus? _lastRecordingStatus;
  bool? _lastRecordingControlsLocked;
  int _lastRecordingSegmentCount = -1;
  String? _lastRecordingPath;

  bool get hasGeneratedSummary => generatedSoapNote != null;
  bool get isRecording =>
      recordingService.status.hasActiveSession ||
      (recordingService.status == RecordingStatus.error &&
          recordingService.hasRecoverableSession);
  bool get isRecordingPaused =>
      recordingService.status == RecordingStatus.paused;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    recordingService = RecordingService.instance;
    uploadService = ProgressiveUploadService.instance;
    processingSnapshotNotifier = ValueNotifier<ProcessingSnapshot?>(null);
    uploadService.configure(widget.apiClient);
    recordingService.onSegmentFinalized = (segment) =>
        uploadService.registerSegment(
          sessionUuid: segment.sessionUuid,
          segmentNumber: segment.segmentNumber,
          localPath: segment.path,
          duration: segment.duration,
          isFinal: segment.isFinal,
        );
    recordingService.addListener(_onRecordingStateChanged);
    if (!widget.apiClient.isAuthenticated) {
      selectedPatient = mockPatients.first;
    }
    unawaited(_initializeScreen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    recordingService.removeListener(_onRecordingStateChanged);
    processingPollTimer?.cancel();
    processingElapsedTimer?.cancel();
    processingSnapshotNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(recordingService.syncRecordingState());
      unawaited(uploadService.processPending());
      final sessionUuid = recordingService.sessionId;
      if (sessionUuid != null && isGeneratingSummary) {
        unawaited(_pollProcessingStatus(sessionUuid));
      }
    }
  }

  Future<void> _initializeScreen() async {
    await uploadService.initialize();
    final recovered = await recordingService.initialize();
    await _restoreDraft();
    _onRecordingStateChanged();
    if (recovered && mounted) {
      await _showRecoveredRecordingDialog();
    } else {
      await _resumePendingProcessing();
    }
  }

  Future<void> _resumePendingProcessing() async {
    final sessions = await uploadService.recoverableSessions();
    if (!mounted || sessions.isEmpty) return;
    final pending = sessions.firstWhere(
      (session) => session.recordingStatus == 'finished',
      orElse: () => sessions.first,
    );
    if (pending.recordingStatus != 'finished') return;
    setState(() => isGeneratingSummary = true);
    _startProcessingPolling(pending.sessionUuid);
  }

  void _onRecordingStateChanged() {
    if (!mounted) return;
    final status = recordingService.status;
    final controlsLocked = recordingService.controlsLocked;
    final segments = recordingService.segments;
    final primaryPath = recordingService.primaryPath;
    final hasStructuralChange =
        status != _lastRecordingStatus ||
        controlsLocked != _lastRecordingControlsLocked ||
        segments.length != _lastRecordingSegmentCount ||
        primaryPath != _lastRecordingPath;
    if (!hasStructuralChange) return;

    _lastRecordingStatus = status;
    _lastRecordingControlsLocked = controlsLocked;
    _lastRecordingSegmentCount = segments.length;
    _lastRecordingPath = primaryPath;
    setState(() {
      if (segments.isNotEmpty) {
        recordingPaths = segments;
        recordingPath = recordingPaths.first;
      }
      if (status != RecordingStatus.recording) {
        recordingDuration = recordingService.duration;
      }
    });
  }

  Future<void> _showRecoveredRecordingDialog() async {
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Grabación incompleta recuperada'),
        content: const Text(
          'Se conservaron los fragmentos de una consulta anterior. '
          'Puedes continuar en un nuevo fragmento, finalizarla o descartarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Descartar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'finish'),
            child: const Text('Finalizar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'continue') {
      final recovered = await recordingService.recoverRecording();
      if (!recovered && mounted) _showRecordingError();
    } else if (action == 'finish') {
      await _stopRecording();
    } else if (action == 'discard') {
      await recordingService.discardRecoveredSession();
    }
  }

  Future<void> _restoreDraft() async {
    final raw = await widget.apiClient.secureStorage.read(key: _draftKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;

      final patientJson = data['selected_patient'];
      final soapJson = data['soap_note'];

      if (!mounted) return;
      setState(() {
        selectedPatient = patientJson is Map<String, dynamic>
            ? Patient.fromJson(patientJson)
            : selectedPatient;
        recordingDuration = Duration(
          seconds: _intOrZero(data['audio_duration_seconds']),
        );
        recordingPath = _nullableText(data['audio_path']);
        recordingPaths = (data['audio_segments'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .where((path) => path.isNotEmpty)
            .toList();
        if (recordingPaths.isEmpty && recordingPath != null) {
          recordingPaths = <String>[recordingPath!];
        }
        consultationStartedAt = DateTime.tryParse(
          data['consultation_started_at']?.toString() ?? '',
        )?.toLocal();
        recordingSavedAt = DateTime.tryParse(
          data['recording_saved_at']?.toString() ?? '',
        )?.toLocal();
        generatedPdfPath = _nullableText(data['pdf_path']);
        generatedTranscript = _nullableText(data['transcript']);
        generatedSoapNote = soapJson is Map<String, dynamic>
            ? SoapNote.fromDraftJson(
                soapJson,
                aiUsage: _mapFromJson(soapJson['ai_usage']),
              )
            : null;
        pdfGenerationDuration = data['pdf_generation_ms'] is num
            ? Duration(milliseconds: (data['pdf_generation_ms'] as num).toInt())
            : null;
        savedConsultationId = (data['saved_consultation_id'] as num?)?.toInt();
        isConsultationSaved = data['is_saved'] == true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consulta recuperada automaticamente.')),
      );
    } catch (_) {
      await _clearDraft();
    }
  }

  Future<void> _persistDraft() async {
    final hasDraft =
        selectedPatient != null ||
        recordingPath != null ||
        generatedSoapNote != null ||
        generatedTranscript != null ||
        generatedPdfPath != null;
    if (!hasDraft) {
      await _clearDraft();
      return;
    }

    final data = <String, dynamic>{
      'selected_patient': selectedPatient?.toJson(),
      'audio_path': recordingPath,
      'audio_segments': recordingPaths,
      'audio_duration_seconds': recordingDuration.inSeconds,
      'consultation_started_at': consultationStartedAt?.toIso8601String(),
      'recording_saved_at': recordingSavedAt?.toIso8601String(),
      'transcript': generatedTranscript,
      'soap_note': generatedSoapNote?.toJson(),
      'pdf_path': generatedPdfPath,
      'pdf_generation_ms': pdfGenerationDuration?.inMilliseconds,
      'saved_consultation_id': savedConsultationId,
      'is_saved': isConsultationSaved,
    };

    await widget.apiClient.secureStorage.write(
      key: _draftKey,
      value: jsonEncode(data),
    );
  }

  Future<void> _clearDraft() {
    return widget.apiClient.secureStorage.delete(key: _draftKey);
  }

  Future<void> _startRecording() async {
    final patient = selectedPatient;
    if (patient == null || recordingService.controlsLocked) return;
    final startedAt = DateTime.now();
    final professionalId = await widget.apiClient.professionalIdentifier();
    final sessionUuid = const Uuid().v4();
    await uploadService.beginSession(
      sessionUuid: sessionUuid,
      patientId: patient.id,
      startedAt: startedAt,
    );
    final registeredSession = await uploadService.session(sessionUuid);
    final started = await recordingService.startRecording(
      patientId: patient.id,
      professionalId: professionalId,
      sessionUuid: sessionUuid,
      consultationCode:
          registeredSession?.consultationCode ??
          registeredSession?.localConsultationCode,
    );
    if (!mounted) return;
    if (!started) {
      await uploadService.recordFailure(
        sessionUuid: sessionUuid,
        stage: 'recording',
        code: 'MICROPHONE_START_FAILED',
        message: 'No se pudo iniciar la grabación.',
      );
      _showRecordingError();
      return;
    }
    setState(() {
      isGeneratingSummary = false;
      isConsultationSaved = false;
      savedConsultationId = null;
      consultationStartedAt = startedAt;
      recordingSavedAt = null;
      recordingDuration = Duration.zero;
      recordingPaths = recordingService.segments;
      recordingPath = recordingService.primaryPath;
      generatedPdfPath = null;
      pdfGenerationDuration = null;
      generatedTranscript = null;
      generatedSoapNote = null;
    });
    unawaited(_persistDraft());
    if (!await recordingService.notificationsEnabled() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Las notificaciones están desactivadas. La grabación continúa, '
            'pero conviene habilitarlas para ver el indicador persistente.',
          ),
        ),
      );
    }
  }

  Future<void> _stopRecording({
    bool autoGenerateSoap = true,
    bool showSavedMessage = true,
  }) async {
    if (recordingService.controlsLocked) return;
    final result = await recordingService.stopRecording();
    if (!mounted || result == null) return;
    setState(() {
      recordingDuration = result.duration;
      recordingPaths = result.paths;
      recordingPath = result.paths.isEmpty ? null : result.paths.first;
      recordingSavedAt = DateTime.now();
    });
    unawaited(_persistDraft());

    if (showSavedMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Grabación guardada localmente '
            '(${_formatDuration(result.duration)}, ${result.paths.length} fragmento(s)).',
          ),
        ),
      );
    }

    if (result.paths.isNotEmpty) {
      final sessionUuid = recordingService.sessionId;
      if (sessionUuid != null) {
        if (autoGenerateSoap) {
          processingStopwatch
            ..reset()
            ..start();
          setState(() => isGeneratingSummary = true);
        }
        await uploadService.finishSession(
          sessionUuid: sessionUuid,
          expectedSegments: result.paths.length,
        );
        if (autoGenerateSoap) _startProcessingPolling(sessionUuid);
      }
    }
  }

  void _startProcessingPolling(String sessionUuid) {
    if (!processingStopwatch.isRunning) processingStopwatch.start();
    processingSessionUuid = sessionUuid;
    processingPollTimer?.cancel();
    processingElapsedTimer?.cancel();
    processingElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && isGeneratingSummary) setState(() {});
    });
    unawaited(_pollProcessingStatus(sessionUuid));
    processingPollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_pollProcessingStatus(sessionUuid)),
    );
  }

  Future<void> _pollProcessingStatus(String sessionUuid) async {
    final snapshot = await uploadService.pollStatus(sessionUuid);
    if (!mounted || snapshot == null) return;
    processingSnapshotNotifier.value = snapshot;
    if (!snapshot.isTerminal) return;

    processingPollTimer?.cancel();
    processingElapsedTimer?.cancel();
    processingStopwatch.stop();
    if (snapshot.status == 'completed' && snapshot.soap != null) {
      final vitalSigns = snapshot.soap!['vital_signs'];
      final durationSeconds = await uploadService.totalDurationSeconds(
        sessionUuid,
      );
      if (!mounted) return;
      setState(() {
        recordingDuration = Duration(seconds: durationSeconds);
        generatedSoapNote = SoapNote.fromDraftJson(
          snapshot.soap!,
          aiUsage: vitalSigns is Map<String, dynamic>
              ? _mapFromJson(vitalSigns['ai_usage'])
              : const {},
        );
        generatedTranscript = null;
        savedConsultationId = snapshot.consultationId;
        isConsultationSaved = true;
        isGeneratingSummary = false;
      });
      unawaited(_persistDraft());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registro SOAP generado. Tiempo: ${snapshot.processingTimeSeconds?.toStringAsFixed(1) ?? '--'} s · ${snapshot.processingTimeLabel ?? 'Sin clasificación'}',
          ),
        ),
      );
    } else {
      setState(() => isGeneratingSummary = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(snapshot.message)));
    }
  }

  Future<void> _retryPendingProcessing() async {
    await uploadService.retryNow();
    final sessionUuid = processingSessionUuid ?? recordingService.sessionId;
    if (!mounted || sessionUuid == null) return;
    processingSnapshotNotifier.value = null;
    processingStopwatch
      ..reset()
      ..start();
    setState(() => isGeneratingSummary = true);
    _startProcessingPolling(sessionUuid);
  }

  Future<void> _cancelPendingProcessing() async {
    final sessionUuid = processingSessionUuid ?? recordingService.sessionId;
    processingPollTimer?.cancel();
    processingElapsedTimer?.cancel();
    processingStopwatch.stop();
    if (sessionUuid != null) {
      await uploadService.cancelSession(sessionUuid);
    }
    if (!mounted) return;
    processingSnapshotNotifier.value = null;
    setState(() => isGeneratingSummary = false);
    processingSessionUuid = null;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Envío cancelado. El audio continúa guardado en el dispositivo.',
        ),
      ),
    );
  }

  Future<void> _toggleRecording() {
    if (recordingService.controlsLocked) return Future.value();
    if (recordingService.status == RecordingStatus.error &&
        recordingService.hasRecoverableSession) {
      return _stopRecording();
    }
    if (isRecordingPaused) return _resumeRecording();
    return isRecording ? _stopRecording() : _startRecording();
  }

  Future<void> _pauseRecording({bool showMessage = true}) async {
    if (recordingService.controlsLocked) return;
    final paused = await recordingService.pauseRecording();
    if (!mounted) return;
    if (!paused) {
      _showRecordingError();
      return;
    }
    unawaited(_persistDraft());
    if (showMessage) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Grabación pausada.')));
    }
  }

  Future<void> _resumeRecording() async {
    if (recordingService.controlsLocked) return;
    final resumed = await recordingService.resumeRecording();
    if (!mounted) return;
    if (!resumed) {
      _showRecordingError();
      return;
    }
    unawaited(_persistDraft());
  }

  void _showRecordingError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          recordingService.errorMessage ?? 'No se pudo operar el micrófono.',
        ),
      ),
    );
  }

  Future<void> _newConsultation() async {
    if (isRecording) {
      await _stopRecording(autoGenerateSoap: false);
    }

    if (!mounted) return;
    setState(() {
      isGeneratingSummary = false;
      recordingDuration = Duration.zero;
      recordingPath = null;
      recordingPaths = <String>[];
      consultationStartedAt = null;
      recordingSavedAt = null;
      generatedPdfPath = null;
      pdfGenerationDuration = null;
      generatedTranscript = null;
      generatedSoapNote = null;
      isConsultationSaved = false;
      savedConsultationId = null;
    });
    processingStopwatch.reset();
    processingSnapshotNotifier.value = null;
    await _clearDraft();
  }

  Future<void> _generateSoapFromAudioSegments(List<String> audioPaths) async {
    final patient = selectedPatient;
    if (patient == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega o selecciona un paciente antes de continuar.'),
        ),
      );
      return;
    }

    if (!widget.apiClient.isAuthenticated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesion para generar el SOAP con IA.'),
        ),
      );
      return;
    }

    setState(() {
      isGeneratingSummary = true;
      generatedPdfPath = null;
      pdfGenerationDuration = null;
      generatedTranscript = null;
      generatedSoapNote = null;
    });

    final generationWatch = Stopwatch()..start();
    try {
      final result = await widget.apiClient
          .generateConsultationDraftFromSegments(
            pacienteId: patient.id,
            audioPaths: audioPaths,
            audioDuration: recordingDuration,
          );

      if (!mounted) return;
      generationWatch.stop();
      final timedSoap = SoapNote(
        reason: result.soapNote.reason,
        subjective: result.soapNote.subjective,
        objective: result.soapNote.objective,
        assessment: result.soapNote.assessment,
        plan: result.soapNote.plan,
        aiSummary: result.soapNote.aiSummary,
        vitalSigns: {
          ...result.soapNote.vitalSigns,
          'ai_generation_seconds': '${generationWatch.elapsed.inSeconds}',
        },
        aiUsage: result.soapNote.aiUsage,
      );
      setState(() {
        generatedTranscript = result.transcript;
        generatedSoapNote = timedSoap;
      });
      unawaited(_persistDraft());
      unawaited(_saveConsultation(showMessage: false, autoTriggered: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOAP generado desde el audio.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el SOAP: $error')),
      );
    } finally {
      if (mounted) setState(() => isGeneratingSummary = false);
    }
  }

  Future<void> _generatePdf() async {
    if (isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deten la grabacion antes de generar el PDF.'),
        ),
      );
      return;
    }

    final soapNote = generatedSoapNote;
    final patient = selectedPatient;
    if (soapNote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Genera el SOAP antes de crear el PDF.')),
      );
      return;
    }
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega o selecciona un paciente antes de continuar.'),
        ),
      );
      return;
    }

    setState(() => isGeneratingPdf = true);
    final stopwatch = Stopwatch()..start();

    try {
      final bytes = await SoapPdfGenerator.generate(
        patient: patient,
        soapNote: soapNote,
        audioDuration: recordingDuration,
        audioPath: recordingPath,
        recordedAt: consultationStartedAt ?? recordingSavedAt ?? DateTime.now(),
      );
      final fileName =
          'sanare_soap_${_safeFilePart(patient.name)}_${_timestampForFile(DateTime.now())}.pdf';
      final path = await savePdfBytes(fileName, bytes);

      stopwatch.stop();
      final generationDuration = stopwatch.elapsed;

      if (!mounted) return;
      setState(() {
        generatedPdfPath = path;
        pdfGenerationDuration = generationDuration;
      });
      unawaited(_persistDraft());
      if (savedConsultationId != null) {
        unawaited(_saveConsultation(showMessage: false, autoTriggered: true));
      }

      if (path.isNotEmpty) {
        unawaited(OpenFilex.open(path));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF SOAP generado en ${_formatGenerationTime(generationDuration)}.',
          ),
        ),
      );
    } catch (error) {
      final sessionUuid = recordingService.sessionId;
      if (sessionUuid != null) {
        await uploadService.recordFailure(
          sessionUuid: sessionUuid,
          stage: 'pdf_generation',
          code: 'PDF_GENERATION_FAILED',
          message: 'No se pudo generar el archivo PDF.',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => isGeneratingPdf = false);
    }
  }

  Future<void> _saveConsultation({
    bool showMessage = true,
    bool autoTriggered = false,
  }) async {
    if (!widget.apiClient.isAuthenticated) {
      if (autoTriggered) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicia sesion para guardar la consulta en Sanare.'),
        ),
      );
      return;
    }

    final soapNote = generatedSoapNote;
    final patient = selectedPatient;
    if (soapNote == null) {
      if (autoTriggered) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Genera el SOAP antes de guardar.')),
      );
      return;
    }
    if (patient == null) {
      if (autoTriggered) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega o selecciona un paciente antes de continuar.'),
        ),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      final consultationId = savedConsultationId;
      final savedId = consultationId == null
          ? await widget.apiClient.createConsultation(
              pacienteId: patient.id,
              soapNote: soapNote,
              audioDuration: recordingPath == null ? null : recordingDuration,
              audioPath: recordingPath,
              consultedAt: consultationStartedAt,
              pdfPath: generatedPdfPath,
              pdfGenerationDuration: pdfGenerationDuration,
            )
          : await widget.apiClient.updateConsultation(
              consultationId: consultationId,
              pacienteId: patient.id,
              soapNote: soapNote,
              audioDuration: recordingPath == null ? null : recordingDuration,
              audioPath: recordingPath,
              consultedAt: consultationStartedAt,
              pdfPath: generatedPdfPath,
              pdfGenerationDuration: pdfGenerationDuration,
            );

      if (!mounted) return;
      setState(() {
        savedConsultationId = savedId;
        isConsultationSaved = true;
      });
      unawaited(_persistDraft());
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consulta guardada en Sanare.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (!autoTriggered) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = selectedPatient;

    return AppScaffold(
      title: 'Consulta IA',
      subtitle: 'Grabar, resumir y generar PDF',
      actions: [
        IconButton(
          tooltip: 'Nueva consulta',
          onPressed: _newConsultation,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          PatientSelector(
            selectedPatient: patient,
            apiClient: widget.apiClient,
            onSelected: (patient) {
              setState(() {
                selectedPatient = patient;
                generatedPdfPath = null;
                pdfGenerationDuration = null;
                generatedTranscript = null;
                generatedSoapNote = null;
                isConsultationSaved = false;
                savedConsultationId = null;
              });
              unawaited(_persistDraft());
            },
          ),
          if (patient != null) ...[
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: recordingService,
              builder: (context, _) {
                final status = recordingService.status;
                final liveDuration = status.hasActiveSession
                    ? recordingService.duration
                    : recordingDuration;
                return RecordingPanel(
                  status: status,
                  counterDuration: liveDuration,
                  audioDuration: liveDuration,
                  audioPath: recordingPath,
                  segmentCount: recordingPaths.length,
                  onToggle: recordingService.controlsLocked
                      ? null
                      : _toggleRecording,
                  onPause:
                      status == RecordingStatus.recording &&
                          !recordingService.controlsLocked
                      ? () => _pauseRecording()
                      : null,
                );
              },
            ),
            const SizedBox(height: 16),
            WorkflowStatus(
              hasAudio: recordingPath != null,
              isGeneratingSummary: isGeneratingSummary,
              hasSummary: hasGeneratedSummary,
              hasPdf: generatedPdfPath != null,
            ),
            const SizedBox(height: 16),
            if (!isGeneratingSummary &&
                recordingPath != null &&
                !hasGeneratedSummary &&
                recordingService.sessionId == null)
              OutlinedButton.icon(
                onPressed: () => _generateSoapFromAudioSegments(
                  recordingPaths.isEmpty
                      ? <String>[recordingPath!]
                      : recordingPaths,
                ),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Generar SOAP'),
              ),
            if (!isGeneratingSummary &&
                recordingPath != null &&
                !hasGeneratedSummary &&
                recordingService.sessionId == null)
              const SizedBox(height: 16),
            if (isGeneratingSummary || processingSnapshotNotifier.value != null)
              ValueListenableBuilder<ProcessingSnapshot?>(
                valueListenable: processingSnapshotNotifier,
                builder: (context, snapshot, _) => AnimatedBuilder(
                  animation: uploadService,
                  builder: (context, _) => AiGenerationCard(
                    message:
                        snapshot?.message ??
                        uploadService.message ??
                        'Guardando y enviando segmentos',
                    progress: snapshot?.progress,
                    isProcessing:
                        isGeneratingSummary && snapshot?.status != 'failed',
                    pendingSegments: uploadService.pendingCount,
                    status: snapshot?.status,
                    localElapsed: processingStopwatch.elapsed,
                    officialSeconds: snapshot?.processingTimeSeconds,
                    classification: snapshot?.processingTimeLabel,
                    onRetry:
                        snapshot?.status == 'failed' ||
                            snapshot?.status == 'timeout'
                        ? _retryPendingProcessing
                        : null,
                    onCancel: isGeneratingSummary
                        ? _cancelPendingProcessing
                        : null,
                  ),
                ),
              ),
            if (isGeneratingSummary) const SizedBox(height: 16),
            if (hasGeneratedSummary)
              AiSummaryCard(
                soapNote: generatedSoapNote!,
                transcript: generatedTranscript,
                showAiUsage: widget.apiClient.isAdmin,
              ),
            if (hasGeneratedSummary) const SizedBox(height: 16),
            if (hasGeneratedSummary)
              ConsultationOutputStatus(
                audioPath: recordingPath,
                audioDuration: recordingDuration,
                pdfPath: generatedPdfPath,
                pdfGenerationDuration: pdfGenerationDuration,
              ),
            if (hasGeneratedSummary) const SizedBox(height: 16),
            if (hasGeneratedSummary)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isSaving ? null : _saveConsultation,
                      icon: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        isSaving
                            ? 'Guardando...'
                            : isConsultationSaved
                            ? 'Guardado'
                            : 'Guardar consulta',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isGeneratingPdf ? null : _generatePdf,
                      icon: isGeneratingPdf
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        isGeneratingPdf ? 'Generando...' : 'Generar PDF',
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  late Future<List<Patient>> patientsFuture;

  @override
  void initState() {
    super.initState();
    patientsFuture = _loadPatients();
  }

  Future<List<Patient>> _loadPatients() {
    return widget.apiClient.isAuthenticated
        ? widget.apiClient.fetchPatients()
        : Future.value(mockPatients);
  }

  void _refreshPatients() {
    setState(() {
      patientsFuture = _loadPatients();
    });
  }

  Future<void> _showCreatePatientDialog() async {
    if (!widget.apiClient.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesion para crear pacientes.')),
      );
      return;
    }

    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final dniController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo paciente'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'Nombres'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Requerido'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Apellidos'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Requerido'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dniController,
                  decoration: const InputDecoration(labelText: 'DNI'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Requerido'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                Navigator.of(context).pop({
                  'first_name': firstNameController.text.trim(),
                  'last_name': lastNameController.text.trim(),
                  'dni': dniController.text.trim(),
                });
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    firstNameController.dispose();
    lastNameController.dispose();
    dniController.dispose();

    if (values == null) return;

    try {
      await widget.apiClient.createPatient(
        firstName: values['first_name']!,
        lastName: values['last_name']!,
        dni: values['dni']!,
      );
      _refreshPatients();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente creado correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear el paciente: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Pacientes',
      subtitle: 'Seleccion para consulta IA',
      actions: [
        IconButton(
          tooltip: 'Nuevo paciente',
          onPressed: _showCreatePatientDialog,
          icon: const Icon(Icons.person_add_alt_outlined),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          const SearchBox(label: 'Buscar por nombre o DNI'),
          const SizedBox(height: 16),
          FutureBuilder<List<Patient>>(
            future: patientsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return ErrorCard(message: snapshot.error.toString());
              }

              final patients = snapshot.data ?? const <Patient>[];
              if (patients.isEmpty) {
                return const EmptyState(
                  icon: Icons.people_outline,
                  title: 'Sin pacientes',
                  body: 'Crea el primer paciente con nombres, apellidos y DNI.',
                );
              }

              return Column(
                children: patients
                    .map(
                      (patient) => PatientTile(
                        patient: patient,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PatientDetailScreen(
                                patient: patient,
                                apiClient: widget.apiClient,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool isExportingCosts = false;

  Future<void> _exportCostsCsv() async {
    if (!widget.apiClient.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesion para exportar costos.')),
      );
      return;
    }

    setState(() => isExportingCosts = true);

    try {
      final path = await widget.apiClient.exportConsultationCostsCsv();

      if (path.isNotEmpty) {
        unawaited(OpenFilex.open(path));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV exportado: $path')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar el CSV: $error')),
      );
    } finally {
      if (mounted) setState(() => isExportingCosts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Consultas y PDF',
      subtitle: 'Resumenes generados por IA',
      actions: widget.apiClient.isAdmin
          ? [
              IconButton(
                tooltip: 'Exportar costos CSV',
                onPressed: isExportingCosts ? null : _exportCostsCsv,
                icon: isExportingCosts
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.table_view_outlined),
              ),
            ]
          : null,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          const SearchBox(label: 'Buscar consulta o paciente'),
          const SizedBox(height: 16),
          FutureBuilder<List<ConsultationSummary>>(
            future: widget.apiClient.isAuthenticated
                ? widget.apiClient.fetchConsultations()
                : Future.value(const <ConsultationSummary>[]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return ErrorCard(message: snapshot.error.toString());
              }

              final consultations =
                  snapshot.data ?? const <ConsultationSummary>[];
              if (consultations.isEmpty) {
                return const EmptyState(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Sin consultas',
                  body: 'Cuando guardes una consulta SOAP real aparecera aqui.',
                );
              }

              return Column(
                children: consultations
                    .map(
                      (consultation) => ConsultationPdfCard(
                        patient: consultation.patient,
                        title: consultation.title,
                        date: consultation.date,
                        status: consultation.status,
                        pdfUrl: consultation.pdfUrl,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.apiClient, this.session});

  final ApiClient apiClient;
  final ApiSession? session;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Perfil medico',
      subtitle: 'Datos consumidos desde Sanare',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Text(
                      'MH',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session?.doctorName ?? 'Dra. Maria Hernandez',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(session?.doctorEmail ?? 'Medicina general'),
                        Text(
                          session?.doctorSpecialization ?? 'Medicina general',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const SettingsTile(
            icon: Icons.api_outlined,
            title: 'APIs del prototipo',
            value: 'Auth, medico, paciente, consulta',
          ),
          const SettingsTile(
            icon: Icons.graphic_eq,
            title: 'Motor IA',
            value: 'Transcripcion + resumen clinico',
          ),
          const SettingsTile(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Salida',
            value: 'PDF de resumen de consulta',
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () async {
              await apiClient.logout();
              if (!context.mounted) return;

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
  }
}

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({
    super.key,
    required this.patient,
    required this.apiClient,
  });

  final Patient patient;
  final ApiClient apiClient;

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  late Future<List<ConsultationRecord>> consultationsFuture;
  int? generatingPdfConsultationId;

  @override
  void initState() {
    super.initState();
    consultationsFuture = _loadConsultations();
  }

  Future<List<ConsultationRecord>> _loadConsultations() {
    return widget.apiClient.isAuthenticated
        ? widget.apiClient.fetchPatientConsultations(widget.patient.id)
        : Future.value(const <ConsultationRecord>[]);
  }

  void _refreshConsultations() {
    setState(() {
      consultationsFuture = _loadConsultations();
    });
  }

  Future<void> _downloadPdf(ConsultationRecord consultation) async {
    setState(() => generatingPdfConsultationId = consultation.id);

    try {
      final bytes = await SoapPdfGenerator.generate(
        patient: consultation.patient,
        soapNote: consultation.soapNote,
        audioDuration: consultation.audioDuration,
        audioPath: consultation.audioPath,
        recordedAt: consultation.consultedAt,
      );
      final fileName =
          'sanare_soap_${_safeFilePart(consultation.patient.name)}_${_timestampForFile(consultation.consultedAt)}.pdf';
      final path = await savePdfBytes(fileName, bytes);

      if (path.isNotEmpty) {
        unawaited(OpenFilex.open(path));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF descargado: ${consultation.title}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar el PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => generatingPdfConsultationId = null);
    }
  }

  Future<void> _retryProcessing(ConsultationRecord consultation) async {
    try {
      await widget.apiClient.retryProcessing(consultation.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El procesamiento se volverá a intentar.'),
        ),
      );
      _refreshConsultations();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar el reintento: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.patient.name,
      subtitle: 'Consultas y documentos',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: _refreshConsultations,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          PatientSummary(patient: widget.patient),
          const SizedBox(height: 18),
          const SectionTitle(title: 'Consultas realizadas'),
          const SizedBox(height: 10),
          FutureBuilder<List<ConsultationRecord>>(
            future: consultationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return ErrorCard(message: snapshot.error.toString());
              }

              final consultations =
                  snapshot.data ?? const <ConsultationRecord>[];
              if (consultations.isEmpty) {
                return const EmptyState(
                  icon: Icons.description_outlined,
                  title: 'Sin consultas',
                  body:
                      'Las consultas guardadas de este paciente apareceran aqui.',
                );
              }

              return Column(
                children: consultations
                    .map(
                      (consultation) => PatientConsultationCard(
                        consultation: consultation,
                        isDownloading:
                            generatingPdfConsultationId == consultation.id,
                        onDownloadPdf: () => _downloadPdf(consultation),
                        onRetry: () => _retryProcessing(consultation),
                        onEvaluate: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute<void>(
                                builder: (_) => SoapEvaluationScreen(
                                  apiClient: widget.apiClient,
                                  consultation: consultation,
                                ),
                              ),
                            )
                            .then((_) => _refreshConsultations()),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class PatientSelector extends StatelessWidget {
  const PatientSelector({
    super.key,
    required this.selectedPatient,
    required this.apiClient,
    required this.onSelected,
  });

  final Patient? selectedPatient;
  final ApiClient apiClient;
  final ValueChanged<Patient> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paciente de la consulta',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Patient>>(
              future: apiClient.isAuthenticated
                  ? apiClient.fetchPatients()
                  : Future.value(mockPatients),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return ErrorCard(message: snapshot.error.toString());
                }

                final patients = snapshot.data ?? const <Patient>[];
                if (patients.isEmpty) {
                  return Text(
                    'Agrega un paciente para iniciar una consulta.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }

                final selected = selectedPatient;
                final value =
                    selected != null &&
                        patients.any((item) => item.id == selected.id)
                    ? patients.firstWhere((item) => item.id == selected.id)
                    : patients.first;
                if (selected == null || !_samePatient(value, selected)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onSelected(value);
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<Patient>(
                      initialValue: value,
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar paciente',
                        prefixIcon: Icon(Icons.person_search_outlined),
                      ),
                      items: patients
                          .map(
                            (patient) => DropdownMenuItem(
                              value: patient,
                              child: Text(patient.name),
                            ),
                          )
                          .toList(),
                      onChanged: (patient) {
                        if (patient != null) onSelected(patient);
                      },
                    ),
                    const SizedBox(height: 12),
                    InfoPill(icon: Icons.badge_outlined, text: value.dni),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RecordingPanel extends StatelessWidget {
  const RecordingPanel({
    super.key,
    required this.status,
    required this.counterDuration,
    required this.audioDuration,
    required this.audioPath,
    required this.segmentCount,
    required this.onToggle,
    this.onPause,
  });

  final RecordingStatus status;
  final Duration counterDuration;
  final Duration audioDuration;
  final String? audioPath;
  final int segmentCount;
  final VoidCallback? onToggle;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final hasAudio = audioPath != null;
    final isRecording =
        status.hasActiveSession ||
        (status == RecordingStatus.error && hasAudio);
    final isPaused = status == RecordingStatus.paused;
    final color = status == RecordingStatus.recording
        ? const Color(0xFFD94A38)
        : Theme.of(context).colorScheme.primary;
    final label = switch (status) {
      RecordingStatus.paused => 'Continuar grabación',
      RecordingStatus.starting => 'Preparando micrófono…',
      RecordingStatus.pausing => 'Pausando…',
      RecordingStatus.resuming => 'Reanudando…',
      RecordingStatus.recovering => 'Recuperando…',
      RecordingStatus.stopping => 'Finalizando…',
      _ when isRecording => 'Detener grabación',
      _ => 'Iniciar grabación',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mic, color: color, size: 62),
            ),
            const SizedBox(height: 16),
            Text(
              isRecording || hasAudio
                  ? _formatDuration(counterDuration)
                  : 'Listo para grabar',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              status == RecordingStatus.recording
                  ? 'Grabando · micrófono confirmado'
                  : status == RecordingStatus.idle && !hasAudio
                  ? 'El audio se usará para construir el resumen SOAP'
                  : status.label,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (hasAudio) const SizedBox(height: 12),
            if (hasAudio)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  InfoPill(
                    icon: Icons.timer_outlined,
                    text: _formatDuration(audioDuration),
                  ),
                  const InfoPill(
                    icon: Icons.save_outlined,
                    text: 'Grabación local',
                  ),
                  if (segmentCount > 1)
                    InfoPill(
                      icon: Icons.library_music_outlined,
                      text: '$segmentCount fragmentos',
                    ),
                ],
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: color),
                onPressed: onToggle,
                icon: Icon(
                  isPaused
                      ? Icons.play_arrow
                      : status.hasActiveSession
                      ? Icons.stop
                      : Icons.mic_none,
                ),
                label: Text(label),
              ),
            ),
            if (onPause != null) const SizedBox(height: 10),
            if (onPause != null)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onPause,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pausar grabacion'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WorkflowStatus extends StatelessWidget {
  const WorkflowStatus({
    super.key,
    required this.hasAudio,
    required this.isGeneratingSummary,
    required this.hasSummary,
    required this.hasPdf,
  });

  final bool hasAudio;
  final bool isGeneratingSummary;
  final bool hasSummary;
  final bool hasPdf;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flujo del prototipo',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            FlowStep(
              icon: Icons.mic_none,
              title: '1. Grabar audio',
              body: hasAudio
                  ? 'Grabacion disponible en almacenamiento local'
                  : 'Consulta capturada desde el telefono',
            ),
            FlowStep(
              icon: Icons.text_snippet_outlined,
              title: '2. Transcribir',
              body: hasSummary
                  ? 'Transcripcion recibida desde IA'
                  : isGeneratingSummary
                  ? 'Transcribiendo audio'
                  : 'Pendiente de audio',
            ),
            FlowStep(
              icon: Icons.auto_awesome_outlined,
              title: '3. Resumir con IA',
              body: hasSummary
                  ? 'SOAP generado con el audio'
                  : isGeneratingSummary
                  ? 'Construyendo documento SOAP'
                  : 'Pendiente de transcripcion',
            ),
            FlowStep(
              icon: Icons.picture_as_pdf_outlined,
              title: '4. Generar PDF',
              body: hasPdf
                  ? 'PDF SOAP generado y guardado localmente'
                  : 'Documento final para expediente',
            ),
          ],
        ),
      ),
    );
  }
}

class FlowStep extends StatelessWidget {
  const FlowStep({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AiGenerationCard extends StatelessWidget {
  const AiGenerationCard({
    super.key,
    required this.message,
    this.progress,
    this.isProcessing = true,
    this.pendingSegments = 0,
    this.status,
    this.localElapsed = Duration.zero,
    this.officialSeconds,
    this.classification,
    this.onRetry,
    this.onCancel,
  });

  final String message;
  final int? progress;
  final bool isProcessing;
  final int pendingSegments;
  final String? status;
  final Duration localElapsed;
  final double? officialSeconds;
  final String? classification;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: isProcessing
                      ? const CircularProgressIndicator(strokeWidth: 2.4)
                      : Icon(
                          status == 'completed'
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (progress != null) const SizedBox(height: 12),
            if (progress != null)
              LinearProgressIndicator(value: progress!.clamp(0, 100) / 100),
            const SizedBox(height: 8),
            Text(
              officialSeconds != null
                  ? 'Tiempo de generación: ${officialSeconds!.toStringAsFixed(1)} segundos'
                  : 'Tiempo transcurrido (referencia local): ${(localElapsed.inMilliseconds / 1000).toStringAsFixed(1)} segundos',
            ),
            if (classification != null) Text('Clasificación: $classification'),
            if (pendingSegments > 0) const SizedBox(height: 8),
            if (pendingSegments > 0)
              Text('$pendingSegments fragmento(s) pendiente(s) de envío'),
            if (onRetry != null || onCancel != null) const SizedBox(height: 8),
            if (onRetry != null || onCancel != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onCancel != null)
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                    ),
                  if (onRetry != null) const SizedBox(width: 8),
                  if (onRetry != null)
                    FilledButton.tonalIcon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class AiSummaryCard extends StatelessWidget {
  const AiSummaryCard({
    super.key,
    required this.soapNote,
    required this.showAiUsage,
    this.transcript,
  });

  final SoapNote soapNote;
  final bool showAiUsage;
  final String? transcript;

  @override
  Widget build(BuildContext context) {
    final cleanTranscript = transcript?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Resumen generado por IA',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                const StatusBadge(text: 'Borrador'),
              ],
            ),
            const SizedBox(height: 14),
            if (cleanTranscript != null && cleanTranscript.isNotEmpty)
              SummaryBlock(title: 'Transcripcion', body: cleanTranscript),
            if (cleanTranscript != null && cleanTranscript.isNotEmpty)
              const SizedBox(height: 8),
            SummaryBlock(title: 'Motivo', body: soapNote.reason),
            const SizedBox(height: 8),
            if (showAiUsage && soapNote.aiUsage.isNotEmpty)
              AiUsagePills(aiUsage: soapNote.aiUsage),
            if (showAiUsage && soapNote.aiUsage.isNotEmpty)
              const SizedBox(height: 12),
            if (soapNote.vitalSigns.isNotEmpty)
              SummaryBlock(
                title: 'Signos vitales',
                body: _formatVitalSigns(soapNote.vitalSigns),
              ),
            if (soapNote.vitalSigns.isNotEmpty) const SizedBox(height: 8),
            SummaryBlock(title: 'S - Subjetivo', body: soapNote.subjective),
            const SizedBox(height: 8),
            SummaryBlock(title: 'O - Objetivo', body: soapNote.objective),
            const SizedBox(height: 8),
            SummaryBlock(title: 'A - Evaluacion', body: soapNote.assessment),
            const SizedBox(height: 8),
            SummaryBlock(title: 'P - Plan', body: soapNote.plan),
          ],
        ),
      ),
    );
  }
}

class AiUsagePills extends StatelessWidget {
  const AiUsagePills({super.key, required this.aiUsage});

  final Map<String, dynamic> aiUsage;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        InfoPill(
          icon: Icons.token_outlined,
          text: '${_intOrZero(aiUsage['soap_total_tokens'])} tokens',
        ),
        InfoPill(
          icon: Icons.attach_money_outlined,
          text: _formatUsd(_doubleOrZero(aiUsage['estimated_total_cost_usd'])),
        ),
      ],
    );
  }
}

class ConsultationOutputStatus extends StatelessWidget {
  const ConsultationOutputStatus({
    super.key,
    required this.audioPath,
    required this.audioDuration,
    required this.pdfPath,
    required this.pdfGenerationDuration,
  });

  final String? audioPath;
  final Duration audioDuration;
  final String? pdfPath;
  final Duration? pdfGenerationDuration;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Archivos de la consulta',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoPill(
                  icon: audioPath == null
                      ? Icons.mic_none
                      : Icons.check_circle_outline,
                  text: audioPath == null
                      ? 'Audio pendiente'
                      : 'Audio ${_formatDuration(audioDuration)}',
                ),
                InfoPill(
                  icon: pdfPath == null
                      ? Icons.picture_as_pdf_outlined
                      : Icons.check_circle_outline,
                  text: pdfGenerationDuration == null
                      ? 'PDF pendiente'
                      : 'PDF ${_formatGenerationTime(pdfGenerationDuration!)}',
                ),
              ],
            ),
            if (audioPath != null) const SizedBox(height: 10),
            if (audioPath != null)
              Text(
                'La grabacion se guarda en almacenamiento privado de la app.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            if (pdfPath != null) const SizedBox(height: 8),
            if (pdfPath != null)
              Text(
                'PDF local: $pdfPath',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class SummaryBlock extends StatelessWidget {
  const SummaryBlock({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}

class SoapPdfGenerator {
  static Future<List<int>> generate({
    required Patient patient,
    required SoapNote soapNote,
    required Duration audioDuration,
    required String? audioPath,
    required DateTime recordedAt,
  }) async {
    final document = pw.Document();
    final generatedAt = DateTime.now();
    final sections = _buildSections(soapNote);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 34, 34, 42),
        build: (context) {
          return [
            _header(generatedAt),
            pw.SizedBox(height: 16),
            _patientBox(patient, recordedAt, audioDuration, audioPath),
            pw.SizedBox(height: 18),
            ...sections.expand(_section),
          ];
        },
        footer: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColor.fromHex('#E2E8E6')),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Sanare IA',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromHex('#6B7280'),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Pagina ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromHex('#6B7280'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return document.save();
  }

  static pw.Widget _header(DateTime generatedAt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#17212B'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Sanare IA',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 23,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Resumen clinico en formato SOAP',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
              ),
            ],
          ),
          pw.Text(
            'Generado: ${_formatDateTime(generatedAt)}',
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _patientBox(
    Patient patient,
    DateTime recordedAt,
    Duration audioDuration,
    String? audioPath,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFFFFF'),
        border: pw.Border.all(color: PdfColor.fromHex('#D8E1DF')),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Datos del paciente',
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#17212B'),
            ),
          ),
          pw.SizedBox(height: 8),
          _metadataRow('Nombre', patient.name),
          _metadataRow('DNI', patient.dni),
          _metadataRow('Fecha de consulta', _formatDateTime(recordedAt)),
          _metadataRow('Duracion de audio', _formatDuration(audioDuration)),
          _metadataRow(
            'Grabacion',
            audioPath == null
                ? 'No adjunta en esta consulta'
                : 'Guardada localmente en el dispositivo',
          ),
        ],
      ),
    );
  }

  static pw.Widget _metadataRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#17212B'),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(color: PdfColor.fromHex('#1F2937')),
            ),
          ),
        ],
      ),
    );
  }

  static List<_PdfSection> _buildSections(SoapNote soapNote) {
    return [
          _PdfSection('01', 'Motivo de consulta', soapNote.reason),
          if (soapNote.vitalSigns.isNotEmpty)
            _PdfSection(
              '02',
              'Signos vitales',
              _formatVitalSigns(soapNote.vitalSigns),
            ),
          _PdfSection('S', 'Subjetivo', soapNote.subjective),
          _PdfSection('O', 'Objetivo', soapNote.objective),
          _PdfSection('A', 'Evaluacion', soapNote.assessment),
          _PdfSection('P', 'Plan', soapNote.plan),
          _PdfSection('IA', 'Resumen IA', soapNote.aiSummary),
        ]
        .where((section) => _isSpecifiedText(section.body))
        .toList(growable: false);
  }

  static List<pw.Widget> _section(_PdfSection section) {
    return [
      pw.NewPage(freeSpace: 120),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#EAF7F5'),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 28,
              height: 22,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#0A7F78'),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                section.marker,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 9),
            pw.Text(
              section.title,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#17212B'),
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 8),
      ..._body(section.body),
      pw.SizedBox(height: 14),
    ];
  }

  static List<pw.Widget> _body(String body) {
    final lines = body
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .toList(growable: false);

    return lines
        .expand((line) {
          if (line.isEmpty) {
            return <pw.Widget>[pw.SizedBox(height: 5)];
          }

          if (line.startsWith('- ')) {
            return <pw.Widget>[
              pw.Bullet(
                text: line.substring(2).trim(),
                bulletColor: PdfColor.fromHex('#0A7F78'),
                style: _bodyTextStyle(),
                margin: const pw.EdgeInsets.only(bottom: 4),
              ),
            ];
          }

          final separator = line.indexOf(':');
          if (separator > 0 && separator < 35) {
            final label = line.substring(0, separator + 1);
            final value = line.substring(separator + 1).trimLeft();

            return <pw.Widget>[
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '$label ',
                      style: _bodyTextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(text: value, style: _bodyTextStyle()),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
            ];
          }

          return <pw.Widget>[
            pw.Text(line, style: _bodyTextStyle()),
            pw.SizedBox(height: 4),
          ];
        })
        .toList(growable: false);
  }

  static pw.TextStyle _bodyTextStyle({pw.FontWeight? fontWeight}) {
    return pw.TextStyle(
      fontSize: 10.8,
      height: 1.32,
      color: PdfColor.fromHex('#111827'),
      fontWeight: fontWeight,
    );
  }
}

class _PdfSection {
  const _PdfSection(this.marker, this.title, this.body);

  final String marker;
  final String title;
  final String body;
}

class ConsultationPdfCard extends StatelessWidget {
  const ConsultationPdfCard({
    super.key,
    required this.patient,
    required this.title,
    required this.date,
    required this.status,
    this.pdfUrl,
  });

  final String patient;
  final String title;
  final String date;
  final String status;
  final String? pdfUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFE9F1FF),
            child: Icon(
              Icons.picture_as_pdf_outlined,
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text('$patient\n$date'),
          isThreeLine: true,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download_outlined),
              const SizedBox(height: 2),
              Text(
                pdfUrl == null ? status : 'Abrir PDF',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade700,
                ),
              ),
          ],
        ),
        actions: actions,
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: label,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Filtros',
          onPressed: () {},
          icon: const Icon(Icons.tune),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class PatientConsultationCard extends StatelessWidget {
  const PatientConsultationCard({
    super.key,
    required this.consultation,
    required this.isDownloading,
    required this.onDownloadPdf,
    required this.onEvaluate,
    required this.onRetry,
  });

  final ConsultationRecord consultation;
  final bool isDownloading;
  final VoidCallback onDownloadPdf;
  final VoidCallback onEvaluate;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFE9F1FF),
                    child: Icon(
                      Icons.description_outlined,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          consultation.consultationCode ??
                              consultation.evaluationCode ??
                              'Consulta #${consultation.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          consultation.date,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  StatusBadge(text: consultation.status),
                  StatusBadge(
                    text:
                        {
                          'pending': 'Evaluación pendiente',
                          'draft': 'Evaluación en borrador',
                          'completed': 'Evaluación completada',
                        }[consultation.evaluationStatus] ??
                        consultation.evaluationStatus,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (consultation.failureStage != null) ...[
                Text(
                  'Fallo en: ${consultation.failureStage}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (consultation.failureMessage != null)
                  Text(consultation.failureMessage!),
                Text(
                  '${consultation.receivedSegments}/${consultation.expectedSegments} segmentos enviados · '
                  '${consultation.transcribedSegments} transcritos · '
                  'SOAP: ${consultation.soapGenerated ? 'Sí' : 'No'}',
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onEvaluate,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Evaluar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isDownloading || !consultation.soapGenerated
                          ? null
                          : onDownloadPdf,
                      icon: isDownloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(isDownloading ? 'Preparando...' : 'PDF'),
                    ),
                  ),
                ],
              ),
              if (consultation.overallStatus == 'failed') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar procesamiento'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PatientTile extends StatelessWidget {
  const PatientTile({super.key, required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFDAF4F1),
            child: Text(
              patient.initials,
              style: const TextStyle(
                color: Color(0xFF087F7A),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          title: Text(
            patient.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(patient.dni),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class PatientSummary extends StatelessWidget {
  const PatientSummary({super.key, required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 31,
                  backgroundColor: const Color(0xFFDAF4F1),
                  child: Text(
                    patient.initials,
                    style: const TextStyle(
                      color: Color(0xFF087F7A),
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(patient.dni),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE7793F),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(body, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(time, style: TextStyle(color: Colors.grey.shade700)),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(value),
        ),
      ),
    );
  }
}

class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.dni,
    required this.age,
  });

  final int id;
  final String name;
  final String dni;
  final int age;

  factory Patient.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name']?.toString() ?? '';
    final lastName = json['last_name']?.toString() ?? '';
    final fullName = json['full_name']?.toString();
    final legacyName = json['nombre']?.toString();
    final name = fullName != null && fullName.trim().isNotEmpty
        ? fullName
        : '$firstName $lastName'.trim();

    return Patient(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: name.isNotEmpty ? name : legacyName ?? 'Paciente sin nombre',
      dni: json['dni']?.toString() ?? 'Sin DNI',
      age:
          (json['age'] as num?)?.toInt() ??
          _ageFromDate(json['fecha_nacimiento']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    final parts = name.split(' ');
    return {
      'id': id,
      'full_name': name,
      'first_name': parts.isEmpty ? name : parts.first,
      'last_name': parts.length > 1 ? parts.sublist(1).join(' ') : '',
      'dni': dni,
      'age': age,
    };
  }

  String get initials {
    final parts = name
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return 'P';

    return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}';
  }
}

const mockPatients = [
  Patient(id: 1, name: 'Ana Lopez', dni: '0801-1994-02341', age: 31),
  Patient(id: 2, name: 'Carlos Mejia', dni: '0801-1982-11245', age: 44),
  Patient(id: 3, name: 'Rosa Martinez', dni: '0501-1976-88412', age: 49),
  Patient(id: 4, name: 'Luis Fernandez', dni: '1101-2001-77122', age: 25),
];

class ConsultationRecord {
  const ConsultationRecord({
    required this.id,
    required this.patient,
    required this.title,
    required this.date,
    required this.status,
    required this.consultedAt,
    required this.soapNote,
    required this.audioDuration,
    this.audioPath,
    this.localPdfPath,
    this.pdfUrl,
    this.evaluationStatus = 'pending',
    this.evaluationCode,
    this.consultationCode,
    this.overallStatus = 'completed',
    this.failureStage,
    this.failureMessage,
    this.soapGenerated = true,
    this.expectedSegments = 0,
    this.receivedSegments = 0,
    this.transcribedSegments = 0,
  });

  final int id;
  final Patient patient;
  final String title;
  final String date;
  final String status;
  final DateTime consultedAt;
  final SoapNote soapNote;
  final Duration audioDuration;
  final String? audioPath;
  final String? localPdfPath;
  final String? pdfUrl;
  final String evaluationStatus;
  final String? evaluationCode;
  final String? consultationCode;
  final String overallStatus;
  final String? failureStage;
  final String? failureMessage;
  final bool soapGenerated;
  final int expectedSegments;
  final int receivedSegments;
  final int transcribedSegments;

  factory ConsultationRecord.fromJson(
    Map<String, dynamic> json, {
    Patient? fallbackPatient,
  }) {
    final patientJson = json['patient'] is Map<String, dynamic>
        ? json['patient'] as Map<String, dynamic>
        : json['paciente'] is Map<String, dynamic>
        ? json['paciente'] as Map<String, dynamic>
        : null;
    final patient = patientJson == null
        ? fallbackPatient ?? mockPatients.first
        : Patient.fromJson(patientJson);
    final vitalSigns = json['vital_signs'] is Map<String, dynamic>
        ? json['vital_signs'] as Map<String, dynamic>
        : <String, dynamic>{};
    final reason = _textOrUnspecified(json['reason']);
    final assessment = _textOrUnspecified(json['assessment']);
    final rawDate =
        json['consulted_at']?.toString() ?? json['created_at']?.toString();
    final consultedAt =
        DateTime.tryParse(rawDate ?? '')?.toLocal() ?? DateTime.now();
    final localPdfPath = _nullableText(vitalSigns['local_pdf_path']);
    final pdfUrl = _nullableText(json['pdf_url']);
    final audioSeconds = _intOrZero(vitalSigns['audio_duration_seconds']);

    return ConsultationRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      patient: patient,
      title: reason == 'no especificado' ? assessment : reason,
      date: _formatDateTime(consultedAt),
      status: _consultationStatusLabel(json['overall_status']?.toString()),
      consultedAt: consultedAt,
      soapNote: SoapNote(
        reason: reason,
        subjective: _textOrUnspecified(json['subjective']),
        objective: _textOrUnspecified(json['objective']),
        assessment: assessment,
        plan: _textOrUnspecified(json['plan']),
        aiSummary:
            _nullableText(vitalSigns['ai_summary']) ??
            'Motivo: $reason\nEvaluacion: $assessment\nPlan: ${_textOrUnspecified(json['plan'])}',
        vitalSigns: _vitalSignsFromJson(vitalSigns),
        aiUsage: _mapFromJson(vitalSigns['ai_usage']),
      ),
      audioDuration: Duration(seconds: audioSeconds),
      audioPath: _nullableText(vitalSigns['local_audio_path']),
      localPdfPath: localPdfPath,
      pdfUrl: pdfUrl,
      evaluationStatus:
          (json['soap_evaluation'] as Map<String, dynamic>?)?['status']
              ?.toString() ??
          'pending',
      evaluationCode:
          (json['soap_evaluation'] as Map<String, dynamic>?)?['test_code']
              ?.toString(),
      consultationCode: json['consultation_code']?.toString(),
      overallStatus: json['overall_status']?.toString() ?? 'completed',
      failureStage: json['failure_stage']?.toString(),
      failureMessage: json['user_friendly_error_message']?.toString(),
      soapGenerated: json['soap_status']?.toString() == 'completed',
      expectedSegments: (json['expected_segments'] as num?)?.toInt() ?? 0,
      receivedSegments: (json['received_segments'] as num?)?.toInt() ?? 0,
      transcribedSegments: (json['transcribed_segments'] as num?)?.toInt() ?? 0,
    );
  }
}

String _consultationStatusLabel(String? status) => switch (status) {
  'failed' => 'No completada',
  'timeout' => 'Tiempo agotado',
  'completed_with_warnings' => 'Completada con advertencias',
  'cancelled' => 'Cancelada',
  'pending_sync' => 'Pendiente de sincronizar',
  'recording' => 'Grabando',
  'transcribing' || 'generating_soap' || 'uploading' => 'Procesando',
  _ => 'Completada',
};

class ConsultationSummary {
  const ConsultationSummary({
    required this.patient,
    required this.title,
    required this.date,
    required this.status,
    this.pdfUrl,
  });

  final String patient;
  final String title;
  final String date;
  final String status;
  final String? pdfUrl;

  factory ConsultationSummary.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] is Map<String, dynamic>
        ? json['patient'] as Map<String, dynamic>
        : json['paciente'] is Map<String, dynamic>
        ? json['paciente'] as Map<String, dynamic>
        : <String, dynamic>{};
    final parsedPatient = Patient.fromJson(patient);
    final assessment =
        json['assessment']?.toString() ?? json['diagnostico']?.toString();
    final reason = json['reason']?.toString();
    final title = reason != null && reason.trim().isNotEmpty
        ? reason
        : assessment;

    return ConsultationSummary(
      patient: parsedPatient.name == 'Paciente sin nombre'
          ? 'Paciente'
          : parsedPatient.name,
      title: title == null || title.isEmpty
          ? 'Consulta generada por IA'
          : title,
      date:
          json['consulted_at']?.toString() ??
          json['created_at']?.toString() ??
          'Sin fecha',
      status: json['resumen_ia'] == null ? 'SOAP guardado' : 'PDF listo',
      pdfUrl: json['pdf_url']?.toString(),
    );
  }
}

class ApiSession {
  const ApiSession({
    required this.token,
    required this.doctorName,
    required this.doctorEmail,
    required this.doctorSpecialization,
    required this.roles,
  });

  final String token;
  final String doctorName;
  final String doctorEmail;
  final String doctorSpecialization;
  final List<String> roles;

  bool get isAdmin => roles.contains('admin');
}

class ApiClient implements SegmentBackendClient {
  ApiClient({FlutterSecureStorage? secureStorage})
    : secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String baseUrl = String.fromEnvironment(
    'SANARE_API_URL',
    defaultValue: 'https://api.sanaresys.com/api',
  );
  static const String _sessionTokenKey = 'sanare.session.token';
  static const String _sessionNameKey = 'sanare.session.doctor_name';
  static const String _sessionEmailKey = 'sanare.session.doctor_email';
  static const String _sessionSpecializationKey =
      'sanare.session.doctor_specialization';
  static const String _sessionRolesKey = 'sanare.session.roles';

  final FlutterSecureStorage secureStorage;
  String? _token;
  bool _isAdmin = false;

  bool get isAuthenticated => _token != null;
  bool get isAdmin => _isAdmin;

  Future<String?> professionalIdentifier() =>
      secureStorage.read(key: _sessionEmailKey);

  @override
  Future<BackendRecordingSession> startRecordingSession({
    required String sessionUuid,
    required int patientId,
    required DateTime startedAt,
    required String localConsultationCode,
    required bool createdOffline,
  }) async {
    final data = await _post('/consultations/start', {
      'session_uuid': sessionUuid,
      'patient_id': patientId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'local_consultation_code': localConsultationCode,
      'created_offline': createdOffline,
    }).timeout(const Duration(seconds: 30));
    return BackendRecordingSession(
      consultationId: (data['consultation_id'] as num).toInt(),
      sessionUuid: data['session_uuid'].toString(),
      consultationCode: data['consultation_code']?.toString(),
    );
  }

  @override
  Future<void> reportConsultationFailure({
    required int consultationId,
    required String stage,
    required String code,
    required String message,
  }) async {
    await _post('/consultations/$consultationId/failure', {
      'failure_stage': stage,
      'failure_code': code,
      'failure_message': message,
    });
  }

  @override
  Future<String> uploadAudioSegment({
    required int consultationId,
    required LocalAudioSegment segment,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/consultations/$consultationId/segments'),
          )
          ..headers.addAll(_multipartHeaders)
          ..fields['session_uuid'] = segment.sessionUuid
          ..fields['segment_number'] = segment.segmentNumber.toString()
          ..fields['duration_seconds'] = segment.durationSeconds.toString()
          ..fields['is_final'] = segment.isFinal ? '1' : '0'
          ..fields['checksum'] = segment.checksum
          ..files.add(
            await http.MultipartFile.fromPath(
              'audio',
              segment.localPath,
              contentType: MediaType('audio', 'mp4'),
            ),
          );
    final response = await request.send().timeout(const Duration(seconds: 30));
    final body = await response.stream.bytesToString().timeout(
      const Duration(minutes: 2),
    );
    final data = _decodeBody(response.statusCode, body);
    return data['checksum']?.toString() ?? '';
  }

  @override
  Future<void> finalizeRecordingSession({
    required int consultationId,
    required String sessionUuid,
    required int expectedSegments,
  }) async {
    await _post('/consultations/$consultationId/finalize', {
      'session_uuid': sessionUuid,
      'expected_segments': expectedSegments,
    }).timeout(const Duration(seconds: 30));
  }

  @override
  Future<ProcessingSnapshot> processingStatus(int consultationId) async {
    final data = await _get(
      '/consultations/$consultationId/processing-status',
    ).timeout(const Duration(seconds: 30));
    return ProcessingSnapshot(
      consultationId: (data['consultation_id'] as num).toInt(),
      sessionUuid: data['session_uuid'].toString(),
      status: data['processing_status'].toString(),
      soapStatus: data['soap_status'].toString(),
      progress: (data['progress_percentage'] as num?)?.toInt() ?? 0,
      message: data['message']?.toString() ?? 'Procesando consulta',
      expectedSegments: (data['expected_segments'] as num?)?.toInt() ?? 0,
      receivedSegments: (data['received_segments'] as num?)?.toInt() ?? 0,
      transcribedSegments: (data['transcribed_segments'] as num?)?.toInt() ?? 0,
      failedSegments: (data['failed_segments'] as num?)?.toInt() ?? 0,
      consultationCode: data['consultation_code']?.toString(),
      processingTimeMs: (data['processing_time_ms'] as num?)?.toInt(),
      processingTimeSeconds: (data['processing_time_seconds'] as num?)
          ?.toDouble(),
      processingTimeRange: (data['processing_time_range'] as num?)?.toInt(),
      processingTimeLabel: data['processing_time_label']?.toString(),
      errorCode: data['error_code']?.toString(),
      errorStage: data['error_stage']?.toString(),
      retryCount: (data['retry_count'] as num?)?.toInt() ?? 0,
      soapGenerated: data['soap_generated'] == true,
      soap: data['soap'] is Map<String, dynamic>
          ? data['soap'] as Map<String, dynamic>
          : null,
    );
  }

  @override
  Future<void> retryProcessing(int consultationId) async {
    await _post(
      '/consultations/$consultationId/retry-processing',
      const {},
    ).timeout(const Duration(seconds: 30));
  }

  @override
  Future<void> cancelProcessing(int consultationId) async {
    await _post(
      '/consultations/$consultationId/cancel-processing',
      const {},
    ).timeout(const Duration(seconds: 30));
  }

  Map<String, String> get _headers {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Map<String, String> get _multipartHeaders {
    return {
      'Accept': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Future<ApiSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _post('/doctors/login', {
      'email': email,
      'password': password,
      'device_name': 'sanare_mobile',
    });

    final session = _sessionFromAuthData(data, fallbackEmail: email);
    await _persistSession(session);
    return session;
  }

  Future<ApiSession> registerDoctor({
    required String name,
    required String specialization,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final data = await _post('/doctors/register', {
      'name': name,
      'specialization': specialization,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'device_name': 'sanare_mobile',
    });

    final session = _sessionFromAuthData(data, fallbackEmail: email);
    await _persistSession(session);
    return session;
  }

  Future<ApiSession?> restoreSession() async {
    final token = await secureStorage.read(key: _sessionTokenKey);
    if (token == null || token.isEmpty) return null;

    _token = token;

    try {
      final data = await _get('/me');
      final session = _sessionFromProfileData(data, token: token);
      await _persistSession(session);
      return session;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await http.post(
          Uri.parse('$baseUrl/doctors/logout'),
          headers: _headers,
        );
      }
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    _token = null;
    _isAdmin = false;

    await Future.wait([
      secureStorage.delete(key: _sessionTokenKey),
      secureStorage.delete(key: _sessionNameKey),
      secureStorage.delete(key: _sessionEmailKey),
      secureStorage.delete(key: _sessionSpecializationKey),
      secureStorage.delete(key: _sessionRolesKey),
    ]);
  }

  ApiSession _sessionFromAuthData(
    Map<String, dynamic> data, {
    required String fallbackEmail,
  }) {
    _token = data['token']?.toString() ?? data['access_token']?.toString();
    if (_token == null || _token!.isEmpty) {
      throw Exception('Respuesta sin token.');
    }

    final user = data['doctor'] is Map<String, dynamic>
        ? data['doctor'] as Map<String, dynamic>
        : data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final medico = data['medico'] is Map<String, dynamic>
        ? data['medico'] as Map<String, dynamic>
        : <String, dynamic>{};
    final roles = data['roles'] is List
        ? (data['roles'] as List).map((role) => role.toString()).toList()
        : <String>[];
    _isAdmin = roles.contains('admin');

    return ApiSession(
      token: _token!,
      doctorName:
          medico['nombre']?.toString() ?? user['name']?.toString() ?? 'Medico',
      doctorEmail: user['email']?.toString() ?? fallbackEmail,
      doctorSpecialization:
          user['specialization']?.toString() ??
          medico['especializacion']?.toString() ??
          'Medicina general',
      roles: roles,
    );
  }

  ApiSession _sessionFromProfileData(
    Map<String, dynamic> data, {
    required String token,
  }) {
    final user = data['doctor'] is Map<String, dynamic>
        ? data['doctor'] as Map<String, dynamic>
        : data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    final roles = data['roles'] is List
        ? (data['roles'] as List).map((role) => role.toString()).toList()
        : <String>[];

    _token = token;
    _isAdmin = roles.contains('admin');

    return ApiSession(
      token: token,
      doctorName: user['name']?.toString() ?? 'Medico',
      doctorEmail: user['email']?.toString() ?? '',
      doctorSpecialization:
          user['specialization']?.toString() ?? 'Medicina general',
      roles: roles,
    );
  }

  Future<void> _persistSession(ApiSession session) async {
    await Future.wait([
      secureStorage.write(key: _sessionTokenKey, value: session.token),
      secureStorage.write(key: _sessionNameKey, value: session.doctorName),
      secureStorage.write(key: _sessionEmailKey, value: session.doctorEmail),
      secureStorage.write(
        key: _sessionSpecializationKey,
        value: session.doctorSpecialization,
      ),
      secureStorage.write(
        key: _sessionRolesKey,
        value: jsonEncode(session.roles),
      ),
    ]);
  }

  Future<List<Patient>> fetchPatients() async {
    final data = await _get(_isAdmin ? '/admin/patients' : '/patients');
    final items = _itemsFrom(data, 'patients');

    return items
        .whereType<Map<String, dynamic>>()
        .map(Patient.fromJson)
        .toList();
  }

  Future<List<ConsultationSummary>> fetchConsultations() async {
    final data = await _get(
      _isAdmin ? '/admin/consultations' : '/consultations',
    );
    final items = _itemsFrom(data, 'consultations');

    return items
        .whereType<Map<String, dynamic>>()
        .map(ConsultationSummary.fromJson)
        .toList();
  }

  Future<List<ConsultationRecord>> fetchPatientConsultations(
    int patientId,
  ) async {
    final data = _isAdmin
        ? await _get('/admin/consultations?per_page=100')
        : await _get('/consultations?patient_id=$patientId');
    final items = _itemsFrom(data, 'consultations');

    return items
        .whereType<Map<String, dynamic>>()
        .where((item) {
          if (!_isAdmin) return true;

          final patient = item['patient'];
          return patient is Map<String, dynamic> &&
              (patient['id'] as num?)?.toInt() == patientId;
        })
        .map((item) => ConsultationRecord.fromJson(item))
        .toList();
  }

  Future<String> exportConsultationCostsCsv() async {
    if (!_isAdmin) {
      throw Exception('Solo el administrador puede exportar costos.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/consultations/costs/export'),
      headers: {
        'Accept': 'text/csv',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }

    return saveCsvBytes(
      'sanare_costos_consultas_${_timestampForFile(DateTime.now())}.csv',
      response.bodyBytes,
    );
  }

  Future<SoapEvaluation> fetchSoapEvaluation(int consultationId) async {
    final data = await _get('/consultations/$consultationId/soap-evaluation');
    return SoapEvaluation.fromJson(data['evaluation'] as Map<String, dynamic>);
  }

  Future<SoapEvaluation> fetchSoapEvaluationById(int evaluationId) async {
    final data = await _get('/soap-evaluations/$evaluationId');
    return SoapEvaluation.fromJson(data['evaluation'] as Map<String, dynamic>);
  }

  Future<SoapEvaluation> saveSoapEvaluation(
    SoapEvaluation evaluation, {
    bool complete = false,
  }) async {
    final path =
        '/soap-evaluations/${evaluation.id}${complete ? '/complete' : ''}';
    final data = complete
        ? await _post(path, evaluation.toPayload())
        : await _put(path, evaluation.toPayload());
    return SoapEvaluation.fromJson(data['evaluation'] as Map<String, dynamic>);
  }

  Future<List<SoapEvaluation>> fetchSoapEvaluations({
    String query = '',
    String? status,
  }) async {
    final params = <String, String>{
      'per_page': '100',
      if (query.trim().isNotEmpty) 'search': query.trim(),
      'status': ?status,
    };
    final suffix = '?${Uri(queryParameters: params).query}';
    final data = await _get('/admin/soap-evaluations$suffix');
    return _itemsFrom(
      data,
      'evaluations',
    ).whereType<Map<String, dynamic>>().map(SoapEvaluation.fromJson).toList();
  }

  Future<String> exportSoapEvaluations(
    String format, {
    String query = '',
    String? status,
    int? evaluationId,
  }) async {
    if (!_isAdmin) {
      throw Exception('No tienes permiso para exportar evaluaciones.');
    }
    final params = <String, String>{
      if (query.trim().isNotEmpty) 'search': query.trim(),
      'status': ?status,
      if (evaluationId != null) 'evaluation_id': '$evaluationId',
    };
    final response = await http.get(
      Uri.parse(
        '$baseUrl/admin/soap-evaluations/export/$format',
      ).replace(queryParameters: params.isEmpty ? null : params),
      headers: {
        'Accept': 'application/octet-stream',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }
    return saveExportBytes(
      'evaluaciones_soap_${_timestampForFile(DateTime.now())}.$format',
      response.bodyBytes,
    );
  }

  Future<Patient> createPatient({
    required String firstName,
    required String lastName,
    required String dni,
  }) async {
    final data = await _post('/patients', {
      'first_name': firstName,
      'last_name': lastName,
      'dni': dni,
    });

    final patient = data['patient'];
    if (patient is! Map<String, dynamic>) {
      throw Exception('Respuesta sin paciente.');
    }

    return Patient.fromJson(patient);
  }

  Future<int> createConsultation({
    required int pacienteId,
    required SoapNote soapNote,
    Duration? audioDuration,
    String? audioPath,
    DateTime? consultedAt,
    String? pdfPath,
    Duration? pdfGenerationDuration,
  }) async {
    final vitalSigns = <String, dynamic>{
      ...soapNote.vitalSigns,
      'ai_summary': soapNote.aiSummary,
    };
    if (soapNote.aiUsage.isNotEmpty) {
      vitalSigns['ai_usage'] = soapNote.aiUsage;
    }
    if (audioDuration != null) {
      vitalSigns['audio_duration_seconds'] = audioDuration.inSeconds;
    }
    if (audioPath != null) {
      vitalSigns['local_audio_path'] = audioPath;
    }
    if (pdfPath != null) {
      vitalSigns['local_pdf_path'] = pdfPath;
    }
    if (pdfGenerationDuration != null) {
      vitalSigns['pdf_generation_ms'] = pdfGenerationDuration.inMilliseconds;
    }

    final data = await _post('/consultations', {
      'patient_id': pacienteId,
      'reason': soapNote.reason,
      'subjective': soapNote.subjective,
      'objective': soapNote.objective,
      'assessment': soapNote.assessment,
      'plan': soapNote.plan,
      if (consultedAt != null) 'consulted_at': consultedAt.toIso8601String(),
      'vital_signs': vitalSigns,
    });

    final consultation = data['consultation'];
    if (consultation is Map<String, dynamic>) {
      return (consultation['id'] as num?)?.toInt() ?? 0;
    }

    return 0;
  }

  Future<int> updateConsultation({
    required int consultationId,
    required int pacienteId,
    required SoapNote soapNote,
    Duration? audioDuration,
    String? audioPath,
    DateTime? consultedAt,
    String? pdfPath,
    Duration? pdfGenerationDuration,
  }) async {
    final vitalSigns = <String, dynamic>{
      ...soapNote.vitalSigns,
      'ai_summary': soapNote.aiSummary,
    };
    if (soapNote.aiUsage.isNotEmpty) {
      vitalSigns['ai_usage'] = soapNote.aiUsage;
    }
    if (audioDuration != null) {
      vitalSigns['audio_duration_seconds'] = audioDuration.inSeconds;
    }
    if (audioPath != null) {
      vitalSigns['local_audio_path'] = audioPath;
    }
    if (pdfPath != null) {
      vitalSigns['local_pdf_path'] = pdfPath;
    }
    if (pdfGenerationDuration != null) {
      vitalSigns['pdf_generation_ms'] = pdfGenerationDuration.inMilliseconds;
    }

    final data = await _put('/consultations/$consultationId', {
      'patient_id': pacienteId,
      'reason': soapNote.reason,
      'subjective': soapNote.subjective,
      'objective': soapNote.objective,
      'assessment': soapNote.assessment,
      'plan': soapNote.plan,
      if (consultedAt != null) 'consulted_at': consultedAt.toIso8601String(),
      'vital_signs': vitalSigns,
    });

    final consultation = data['consultation'];
    if (consultation is Map<String, dynamic>) {
      return (consultation['id'] as num?)?.toInt() ?? consultationId;
    }

    return consultationId;
  }

  Future<SoapDraftResult> generateConsultationDraftFromAudio({
    required int pacienteId,
    required String audioPath,
    required Duration audioDuration,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/ai/consultation-draft'),
          )
          ..headers.addAll(_multipartHeaders)
          ..fields['patient_id'] = pacienteId.toString()
          ..fields['audio_duration_seconds'] = audioDuration.inSeconds
              .toString()
          ..files.add(
            await http.MultipartFile.fromPath(
              'audio',
              audioPath,
              contentType: MediaType('audio', 'mp4'),
            ),
          );

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = _decodeBody(response.statusCode, body);

    return SoapDraftResult.fromJson(data);
  }

  Future<SoapDraftResult> generateConsultationDraftFromSegments({
    required int pacienteId,
    required List<String> audioPaths,
    required Duration audioDuration,
  }) async {
    if (audioPaths.isEmpty) {
      throw ArgumentError('No hay fragmentos de audio para procesar.');
    }
    if (audioPaths.length == 1) {
      return generateConsultationDraftFromAudio(
        pacienteId: pacienteId,
        audioPath: audioPaths.single,
        audioDuration: audioDuration,
      );
    }

    final transcripts = <String>[];
    for (final audioPath in audioPaths) {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/ai/transcriptions'),
      )..headers.addAll(_multipartHeaders);
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioPath,
          contentType: MediaType('audio', 'mp4'),
        ),
      );
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final data = _decodeBody(response.statusCode, body);
      final transcript = data['transcript']?.toString().trim() ?? '';
      if (transcript.isNotEmpty) transcripts.add(transcript);
    }
    if (transcripts.isEmpty) {
      throw Exception('No se detectó voz en los fragmentos conservados.');
    }

    final data = await _post('/ai/consultation-draft', {
      'patient_id': pacienteId,
      'transcript': transcripts.join('\n\n'),
      'audio_duration_seconds': audioDuration.inSeconds,
    });
    return SoapDraftResult.fromJson(data);
  }

  List<dynamic> _itemsFrom(Map<String, dynamic> data, String key) {
    final keyed = data[key];

    if (keyed is List<dynamic>) return keyed;
    if (keyed is Map<String, dynamic> && keyed['data'] is List<dynamic>) {
      return keyed['data'] as List<dynamic>;
    }
    if (data['data'] is List<dynamic>) return data['data'] as List<dynamic>;

    return const [];
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    return _decodeBody(response.statusCode, response.body);
  }

  Map<String, dynamic> _decodeBody(int statusCode, String responseBody) {
    final body = responseBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(responseBody) as Map<String, dynamic>;

    if (statusCode < 200 || statusCode >= 300) {
      throw Exception(body['message']?.toString() ?? 'HTTP $statusCode');
    }

    return body;
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }

  return '$minutes:$seconds';
}

String _textOrUnspecified(Object? value) {
  final text = value?.toString().trim() ?? '';

  return _isSpecifiedText(text) ? text : 'no especificado';
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';

  return _isSpecifiedText(text) ? text : null;
}

int _intOrZero(Object? value) {
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _doubleOrZero(Object? value) {
  if (value is num) return value.toDouble();

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatUsd(double value) {
  return 'USD ${value.toStringAsFixed(value < 0.01 ? 6 : 2)}';
}

Map<String, String> _vitalSignsFromJson(Object? value) {
  if (value is! Map<String, dynamic>) return const {};

  final signs = <String, String>{};
  for (final entry in value.entries) {
    if (_metadataVitalSignKeys.contains(entry.key)) continue;

    if (entry.value is List) {
      final items = (entry.value as List)
          .map((item) => item.toString().trim())
          .where(_isSpecifiedText)
          .toList(growable: false);
      if (items.isNotEmpty) signs[entry.key] = items.join(', ');
      continue;
    }

    final text = entry.value?.toString().trim() ?? '';
    if (_isSpecifiedText(text)) signs[entry.key] = text;
  }

  return signs;
}

Map<String, dynamic> _aiUsageFromDraftResponse(Map<String, dynamic> json) {
  final usage = _mapFromJson(json['usage']);
  final cost = _mapFromJson(json['cost']);
  final models = _mapFromJson(json['models']);

  return {
    ...cost,
    if (models['transcription'] != null)
      'transcription_model': models['transcription'],
    if (models['soap_formatter'] != null)
      'soap_model': models['soap_formatter'],
    if (usage['input_tokens'] != null)
      'soap_input_tokens': usage['input_tokens'],
    if (usage['output_tokens'] != null)
      'soap_output_tokens': usage['output_tokens'],
    if (usage['total_tokens'] != null)
      'soap_total_tokens': usage['total_tokens'],
  };
}

Map<String, dynamic> _mapFromJson(Object? value) {
  return value is Map<String, dynamic> ? value : const {};
}

String _formatVitalSigns(Map<String, String> vitalSigns) {
  return vitalSigns.entries
      .map((entry) => '${_vitalSignLabel(entry.key)}: ${entry.value}')
      .join('\n');
}

String _vitalSignLabel(String key) {
  return switch (key) {
    'temperature' => 'Temperatura',
    'blood_pressure' => 'Presion arterial',
    'heart_rate' => 'Frecuencia cardiaca',
    'respiratory_rate' => 'Frecuencia respiratoria',
    'oxygen_saturation' => 'Saturacion de oxigeno',
    'weight' => 'Peso',
    'height' => 'Talla',
    'other' => 'Otros',
    _ => key,
  };
}

bool _isSpecifiedText(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('.', '')
      .replaceAll(':', '');

  return normalized.isNotEmpty &&
      normalized != 'null' &&
      normalized != 'no especificado' &&
      normalized != 'no especificada';
}

bool _samePatient(Patient first, Patient second) {
  return first.id == second.id &&
      first.name == second.name &&
      first.dni == second.dni;
}

const _metadataVitalSignKeys = {
  'ai_summary',
  'audio_duration_seconds',
  'local_audio_path',
  'local_pdf_path',
  'pdf_generation_ms',
  'ai_usage',
};

String _formatGenerationTime(Duration duration) {
  if (duration.inSeconds >= 1) {
    final seconds = duration.inMilliseconds / 1000;
    return '${seconds.toStringAsFixed(1)} s';
  }

  return '${duration.inMilliseconds} ms';
}

String _formatDateTime(DateTime value) {
  final localValue = value.toLocal();
  final day = localValue.day.toString().padLeft(2, '0');
  final month = localValue.month.toString().padLeft(2, '0');
  final year = localValue.year.toString();
  final hour = localValue.hour.toString().padLeft(2, '0');
  final minute = localValue.minute.toString().padLeft(2, '0');

  return '$day/$month/$year $hour:$minute';
}

String _timestampForFile(DateTime value) {
  final localValue = value.toLocal();
  final year = localValue.year.toString();
  final month = localValue.month.toString().padLeft(2, '0');
  final day = localValue.day.toString().padLeft(2, '0');
  final hour = localValue.hour.toString().padLeft(2, '0');
  final minute = localValue.minute.toString().padLeft(2, '0');
  final second = localValue.second.toString().padLeft(2, '0');

  return '$year$month${day}_$hour$minute$second';
}

String _safeFilePart(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  return normalized.isEmpty ? 'paciente' : normalized;
}

int _ageFromDate(String? date) {
  if (date == null || date.isEmpty) return 0;
  final birthDate = DateTime.tryParse(date);
  if (birthDate == null) return 0;

  final today = DateTime.now();
  var age = today.year - birthDate.year;
  final hadBirthday =
      today.month > birthDate.month ||
      (today.month == birthDate.month && today.day >= birthDate.day);
  if (!hadBirthday) age--;
  return age;
}
