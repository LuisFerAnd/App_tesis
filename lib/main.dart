import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:record/record.dart';

import 'platform_files.dart';

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
      home: const LoginScreen(),
    );
  }
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

  void _openDemo() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MobileShell(apiClient: ApiClient())),
    );
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
                                  child: OutlinedButton.icon(
                                    onPressed: isLoading ? null : _openDemo,
                                    icon: const Icon(
                                      Icons.explore_outlined,
                                      size: 20,
                                    ),
                                    label: const Text('Continuar en modo demo'),
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
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmationController = TextEditingController();
  bool isLoading = false;
  bool passwordVisible = false;

  @override
  void dispose() {
    nameController.dispose();
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
      AccountScreen(session: widget.session),
    ];

    return Scaffold(
      body: screens[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Consulta',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Pacientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.picture_as_pdf_outlined),
            selectedIcon: Icon(Icons.picture_as_pdf),
            label: 'PDF',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
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

class _AiConsultationScreenState extends State<AiConsultationScreen> {
  late final AudioRecorder audioRecorder;
  Timer? recordingTimer;
  DateTime? recordingStartedAt;
  DateTime? recordingSavedAt;
  Patient selectedPatient = mockPatients.first;
  bool isRecording = false;
  bool isGeneratingSummary = false;
  bool isSaving = false;
  bool isGeneratingPdf = false;
  Duration recordingDuration = Duration.zero;
  Duration? pdfGenerationDuration;
  String? recordingPath;
  String? generatedPdfPath;
  String? generatedTranscript;
  SoapNote? generatedSoapNote;

  bool get hasGeneratedSummary => generatedSoapNote != null;

  @override
  void initState() {
    super.initState();
    audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    recordingTimer?.cancel();
    unawaited(audioRecorder.dispose());
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permite el microfono para grabar la consulta.'),
          ),
        );
        return;
      }

      final startedAt = DateTime.now();
      final path = await createRecordingPath(
        'sanare_audio_${_timestampForFile(startedAt)}.m4a',
      );

      await audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      if (!mounted) return;
      setState(() {
        isRecording = true;
        isGeneratingSummary = false;
        recordingStartedAt = startedAt;
        recordingSavedAt = null;
        recordingDuration = Duration.zero;
        recordingPath = null;
        generatedPdfPath = null;
        pdfGenerationDuration = null;
        generatedTranscript = null;
        generatedSoapNote = null;
      });
      _startRecordingTimer();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar la grabacion: $error')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final stoppedPath = await audioRecorder.stop();
      recordingTimer?.cancel();

      final duration = recordingStartedAt == null
          ? recordingDuration
          : DateTime.now().difference(recordingStartedAt!);

      final savedPath = stoppedPath == null || stoppedPath.isEmpty
          ? null
          : stoppedPath;

      if (!mounted) return;
      setState(() {
        isRecording = false;
        recordingDuration = duration;
        recordingPath = savedPath;
        recordingSavedAt = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Grabacion guardada localmente (${_formatDuration(duration)}).',
          ),
        ),
      );

      if (savedPath != null) {
        unawaited(_generateSoapFromAudio(savedPath));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo detener la grabacion: $error')),
      );
    }
  }

  Future<void> _toggleRecording() {
    return isRecording ? _stopRecording() : _startRecording();
  }

  void _startRecordingTimer() {
    recordingTimer?.cancel();
    recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = recordingStartedAt;
      if (!mounted || startedAt == null) return;

      setState(() {
        recordingDuration = DateTime.now().difference(startedAt);
      });
    });
  }

  Future<void> _newConsultation() async {
    if (isRecording) {
      await _stopRecording();
    }

    if (!mounted) return;
    setState(() {
      isGeneratingSummary = false;
      recordingDuration = Duration.zero;
      recordingPath = null;
      recordingSavedAt = null;
      generatedPdfPath = null;
      pdfGenerationDuration = null;
      generatedTranscript = null;
      generatedSoapNote = null;
    });
  }

  Future<void> _generateSoapFromAudio(String audioPath) async {
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

    try {
      final result = await widget.apiClient.generateConsultationDraftFromAudio(
        pacienteId: selectedPatient.id,
        audioPath: audioPath,
        audioDuration: recordingDuration,
      );

      if (!mounted) return;
      setState(() {
        generatedTranscript = result.transcript;
        generatedSoapNote = result.soapNote;
      });

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
    if (soapNote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Genera el SOAP antes de crear el PDF.')),
      );
      return;
    }

    setState(() => isGeneratingPdf = true);
    final stopwatch = Stopwatch()..start();

    try {
      final bytes = await SoapPdfGenerator.generate(
        patient: selectedPatient,
        soapNote: soapNote,
        audioDuration: recordingDuration,
        audioPath: recordingPath,
        recordedAt: recordingSavedAt ?? DateTime.now(),
      );
      final fileName =
          'sanare_soap_${_safeFilePart(selectedPatient.name)}_${_timestampForFile(DateTime.now())}.pdf';
      final path = await savePdfBytes(fileName, bytes);

      stopwatch.stop();
      final generationDuration = stopwatch.elapsed;

      if (!mounted) return;
      setState(() {
        generatedPdfPath = path;
        pdfGenerationDuration = generationDuration;
      });

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => isGeneratingPdf = false);
    }
  }

  Future<void> _saveConsultation() async {
    if (!widget.apiClient.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modo demo: inicia sesion para guardar en Sanare.'),
        ),
      );
      return;
    }

    final soapNote = generatedSoapNote;
    if (soapNote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Genera el SOAP antes de guardar.')),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      await widget.apiClient.createConsultation(
        pacienteId: selectedPatient.id,
        soapNote: soapNote,
        audioDuration: recordingPath == null ? null : recordingDuration,
        audioPath: recordingPath,
        pdfPath: generatedPdfPath,
        pdfGenerationDuration: pdfGenerationDuration,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consulta guardada en Sanare.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $error')));
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            selectedPatient: selectedPatient,
            apiClient: widget.apiClient,
            onSelected: (patient) {
              setState(() {
                selectedPatient = patient;
                generatedPdfPath = null;
                pdfGenerationDuration = null;
                generatedTranscript = null;
                generatedSoapNote = null;
              });
            },
          ),
          const SizedBox(height: 16),
          RecordingPanel(
            isRecording: isRecording,
            duration: recordingDuration,
            audioPath: recordingPath,
            onToggle: _toggleRecording,
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
              !hasGeneratedSummary)
            OutlinedButton.icon(
              onPressed: () => _generateSoapFromAudio(recordingPath!),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Generar SOAP'),
            ),
          if (!isGeneratingSummary &&
              recordingPath != null &&
              !hasGeneratedSummary)
            const SizedBox(height: 16),
          if (isGeneratingSummary) const AiGenerationCard(),
          if (isGeneratingSummary) const SizedBox(height: 16),
          if (hasGeneratedSummary)
            AiSummaryCard(
              soapNote: generatedSoapNote!,
              transcript: generatedTranscript,
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
                    label: Text(isSaving ? 'Guardando...' : 'Guardar consulta'),
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
          const SearchBox(label: 'Buscar por nombre, DNI o telefono'),
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
      actions: [
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
      ],
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
  const AccountScreen({super.key, this.session});

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
                        const Text('Colegiacion: 28473'),
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
            onPressed: () {
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

  final Patient selectedPatient;
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
                final patients = snapshot.data ?? mockPatients;
                final value =
                    patients.any((item) => item.id == selectedPatient.id)
                    ? patients.firstWhere(
                        (item) => item.id == selectedPatient.id,
                      )
                    : patients.first;
                if (!_samePatient(value, selectedPatient)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onSelected(value);
                  });
                }

                return DropdownButtonFormField<Patient>(
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
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InfoPill(
                    icon: Icons.badge_outlined,
                    text: selectedPatient.dni,
                  ),
                ),
                const SizedBox(width: 8),
                InfoPill(
                  icon: Icons.bloodtype_outlined,
                  text: selectedPatient.bloodType,
                ),
              ],
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
    required this.isRecording,
    required this.duration,
    required this.audioPath,
    required this.onToggle,
  });

  final bool isRecording;
  final Duration duration;
  final String? audioPath;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = isRecording
        ? const Color(0xFFD94A38)
        : Theme.of(context).colorScheme.primary;
    final label = isRecording ? 'Detener grabacion' : 'Iniciar grabacion';
    final hasAudio = audioPath != null;

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
                  ? _formatDuration(duration)
                  : 'Listo para grabar',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              isRecording
                  ? 'Escuchando la consulta medico-paciente'
                  : hasAudio
                  ? 'Audio guardado localmente en el dispositivo'
                  : 'El audio se usara para construir el resumen SOAP',
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
                    text: _formatDuration(duration),
                  ),
                  const InfoPill(
                    icon: Icons.save_outlined,
                    text: 'Grabacion local',
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
                icon: Icon(isRecording ? Icons.stop : Icons.mic_none),
                label: Text(label),
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
  const AiGenerationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Generando SOAP desde el audio',
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiSummaryCard extends StatelessWidget {
  const AiSummaryCard({super.key, required this.soapNote, this.transcript});

  final SoapNote soapNote;
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
            if (soapNote.aiUsage.isNotEmpty)
              AiUsagePills(aiUsage: soapNote.aiUsage),
            if (soapNote.aiUsage.isNotEmpty) const SizedBox(height: 12),
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

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
        build: (context) {
          return [
            _header(generatedAt),
            pw.SizedBox(height: 18),
            _patientBox(patient, recordedAt, audioDuration, audioPath),
            pw.SizedBox(height: 18),
            _section('Motivo de consulta', soapNote.reason),
            if (soapNote.vitalSigns.isNotEmpty)
              _section(
                'Signos vitales',
                _formatVitalSigns(soapNote.vitalSigns),
              ),
            _section('S - Subjetivo', soapNote.subjective),
            _section('O - Objetivo', soapNote.objective),
            _section('A - Evaluacion', soapNote.assessment),
            _section('P - Plan', soapNote.plan),
            _section('Resumen IA', soapNote.aiSummary),
          ];
        },
        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Pagina ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
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
                  fontSize: 24,
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
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#D8E1DF')),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Paciente',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
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
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  static pw.Widget _section(String title, String body) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F6F8F7'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(body, style: const pw.TextStyle(fontSize: 11, height: 1.35)),
        ],
      ),
    );
  }
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
  });

  final ConsultationRecord consultation;
  final bool isDownloading;
  final VoidCallback onDownloadPdf;

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
                          consultation.title,
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
                  StatusBadge(text: consultation.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                consultation.soapNote.aiSummary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isDownloading ? null : onDownloadPdf,
                      icon: isDownloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(
                        isDownloading ? 'Preparando...' : 'Descargar PDF',
                      ),
                    ),
                  ),
                ],
              ),
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
          subtitle: Text('${patient.dni} - ${patient.phone}'),
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
                      Text(patient.phone),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoPill(
                  icon: Icons.bloodtype_outlined,
                  text: patient.bloodType,
                ),
                InfoPill(
                  icon: Icons.cake_outlined,
                  text: '${patient.age} anos',
                ),
                const InfoPill(
                  icon: Icons.warning_amber_outlined,
                  text: 'Sin alertas',
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
          trailing: const Icon(Icons.chevron_right),
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
    required this.phone,
    required this.age,
    required this.bloodType,
  });

  final int id;
  final String name;
  final String dni;
  final String phone;
  final int age;
  final String bloodType;

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
      phone: json['telefono']?.toString() ?? 'Sin telefono',
      age: _ageFromDate(json['fecha_nacimiento']?.toString()),
      bloodType: json['grupo_sanguineo']?.toString() ?? 'No especificado',
    );
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
  Patient(
    id: 1,
    name: 'Ana Lopez',
    dni: '0801-1994-02341',
    phone: '+504 9876-1234',
    age: 31,
    bloodType: 'O+',
  ),
  Patient(
    id: 2,
    name: 'Carlos Mejia',
    dni: '0801-1982-11245',
    phone: '+504 9456-7788',
    age: 44,
    bloodType: 'A+',
  ),
  Patient(
    id: 3,
    name: 'Rosa Martinez',
    dni: '0501-1976-88412',
    phone: '+504 3321-9087',
    age: 49,
    bloodType: 'B-',
  ),
  Patient(
    id: 4,
    name: 'Luis Fernandez',
    dni: '1101-2001-77122',
    phone: '+504 8899-1020',
    age: 25,
    bloodType: 'AB+',
  ),
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
    final consultedAt = DateTime.tryParse(rawDate ?? '') ?? DateTime.now();
    final localPdfPath = _nullableText(vitalSigns['local_pdf_path']);
    final pdfUrl = _nullableText(json['pdf_url']);
    final audioSeconds = _intOrZero(vitalSigns['audio_duration_seconds']);

    return ConsultationRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      patient: patient,
      title: reason == 'no especificado' ? assessment : reason,
      date: _formatDateTime(consultedAt),
      status: localPdfPath == null && pdfUrl == null
          ? 'SOAP guardado'
          : 'PDF disponible',
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
    );
  }
}

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
    required this.roles,
  });

  final String token;
  final String doctorName;
  final String doctorEmail;
  final List<String> roles;

  bool get isAdmin => roles.contains('admin');
}

class ApiClient {
  ApiClient();

  static const String baseUrl = String.fromEnvironment(
    'SANARE_API_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  String? _token;
  bool _isAdmin = false;

  bool get isAuthenticated => _token != null;
  bool get isAdmin => _isAdmin;

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

    return _sessionFromAuthData(data, fallbackEmail: email);
  }

  Future<ApiSession> registerDoctor({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final data = await _post('/doctors/register', {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'device_name': 'sanare_mobile',
    });

    return _sessionFromAuthData(data, fallbackEmail: email);
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
      roles: roles,
    );
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

  Future<void> createConsultation({
    required int pacienteId,
    required SoapNote soapNote,
    Duration? audioDuration,
    String? audioPath,
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

    await _post('/consultations', {
      'patient_id': pacienteId,
      'reason': soapNote.reason,
      'subjective': soapNote.subjective,
      'objective': soapNote.objective,
      'assessment': soapNote.assessment,
      'plan': soapNote.plan,
      'vital_signs': vitalSigns,
    });
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
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');

  return '$day/$month/$year $hour:$minute';
}

String _timestampForFile(DateTime value) {
  final year = value.year.toString();
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');

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
