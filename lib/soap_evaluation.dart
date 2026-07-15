part of 'main.dart';

class SoapEvaluation {
  SoapEvaluation({
    required this.id,
    required this.consultationId,
    required this.evaluatorId,
    required this.code,
    required this.date,
    required this.evaluatorName,
    required this.specialization,
    required this.status,
    required this.version,
    required this.values,
    this.audioSeconds,
    this.aiSeconds,
    this.consultationSeconds,
    this.lastSavedAt,
    this.consultationCode,
    this.overallStatus = 'completed',
    this.soapStatus = 'completed',
    this.failureStage,
    this.failureMessage,
    this.expectedSegments = 0,
    this.receivedSegments = 0,
    this.transcribedSegments = 0,
  });

  final int id;
  final int consultationId;
  final int evaluatorId;
  final String code;
  final String date;
  final String evaluatorName;
  final String specialization;
  String status;
  int version;
  int? audioSeconds;
  int? aiSeconds;
  int? consultationSeconds;
  DateTime? lastSavedAt;
  final String? consultationCode;
  final String overallStatus;
  final String soapStatus;
  final String? failureStage;
  final String? failureMessage;
  final int expectedSegments;
  final int receivedSegments;
  final int transcribedSegments;
  final Map<String, dynamic> values;

  factory SoapEvaluation.fromJson(Map<String, dynamic> json) {
    const editable = <String>[
      'consultation_duration_seconds',
      'consultation_duration_source',
      'manual_time_seconds',
      'use_prototype',
      'audio_transcription',
      'clinical_processing',
      'soap_generation',
      'soap_subjective',
      'soap_objective',
      'soap_assessment',
      'soap_plan',
      'soap_placement',
      'soap_clarity',
      'error_transcription',
      'error_omission',
      'error_added',
      'error_confusion',
      'error_placement',
      'error_wording',
      'utility_1',
      'utility_2',
      'utility_3',
      'utility_4',
      'utility_5',
      'utility_6',
      'ease_1',
      'ease_2',
      'ease_3',
      'ease_4',
      'ease_5',
      'ease_6',
    ];
    final consultation = json['consultation'] is Map<String, dynamic>
        ? json['consultation'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final legacyErrorScale = json['error_scale_version'] != 2;
    final legacySoapScale = json['soap_scale_version'] != 2;
    const soapScaleFields = {
      'soap_subjective',
      'soap_objective',
      'soap_assessment',
      'soap_plan',
      'soap_placement',
      'soap_clarity',
    };
    dynamic editableValue(String key) {
      final value = json[key];
      if (legacySoapScale && soapScaleFields.contains(key) && value is num) {
        return const {0: 1, 1: 2, 2: 3}[value.toInt()] ?? value;
      }
      if (!legacyErrorScale || !key.startsWith('error_') || value is! num) {
        return value;
      }
      return const {0: 5, 1: 4, 2: 3, 3: 2}[value.toInt()] ?? value;
    }

    return SoapEvaluation(
      id: (json['id'] as num).toInt(),
      consultationId: (json['consultation_id'] as num).toInt(),
      evaluatorId: (json['evaluator_id'] as num).toInt(),
      code: json['test_code']?.toString() ?? '',
      date: json['test_date']?.toString() ?? '',
      evaluatorName: json['evaluator_name']?.toString() ?? 'Dato no disponible',
      specialization:
          json['evaluator_specialization']?.toString() ?? 'Dato no disponible',
      status: json['status']?.toString() ?? 'pending',
      version: (json['version'] as num?)?.toInt() ?? 1,
      audioSeconds: (json['audio_duration_seconds'] as num?)?.toInt(),
      aiSeconds: (json['ai_time_seconds'] as num?)?.toInt(),
      consultationSeconds: (json['consultation_duration_seconds'] as num?)
          ?.toInt(),
      lastSavedAt: DateTime.tryParse(json['last_saved_at']?.toString() ?? ''),
      consultationCode: consultation['consultation_code']?.toString(),
      overallStatus: consultation['overall_status']?.toString() ?? 'completed',
      soapStatus: consultation['soap_status']?.toString() ?? 'completed',
      failureStage: consultation['failure_stage']?.toString(),
      failureMessage: consultation['user_friendly_error_message']?.toString(),
      expectedSegments:
          (consultation['expected_segments'] as num?)?.toInt() ?? 0,
      receivedSegments:
          (consultation['received_segments'] as num?)?.toInt() ?? 0,
      transcribedSegments:
          (consultation['transcribed_segments'] as num?)?.toInt() ?? 0,
      values: {for (final key in editable) key: editableValue(key)},
    );
  }

  Map<String, dynamic> toPayload() => {'version': version, ...values};
  Map<String, dynamic> toLocalJson() => {
    'id': id,
    'consultation_id': consultationId,
    'evaluator_id': evaluatorId,
    'test_code': code,
    'test_date': date,
    'evaluator_name': evaluatorName,
    'evaluator_specialization': specialization,
    'status': status,
    'version': version,
    'audio_duration_seconds': audioSeconds,
    'ai_time_seconds': aiSeconds,
    'last_saved_at': lastSavedAt?.toIso8601String(),
    'error_scale_version': 2,
    'soap_scale_version': 2,
    ...values,
  };

  bool get hasSoap => soapStatus == 'completed';
  List<String> get requiredFields => hasSoap
      ? _requiredEvaluationFields
      : _requiredEvaluationFieldsWithoutSoap;
  int get answered => requiredFields.where((key) => values[key] != null).length;
  double get progress => answered / requiredFields.length;
}

const _requiredEvaluationFieldsWithoutSoap = <String>[
  'use_prototype',
  'audio_transcription',
  'clinical_processing',
  'soap_generation',
  'manual_time_seconds',
  'utility_1',
  'utility_2',
  'utility_3',
  'utility_4',
  'utility_5',
  'utility_6',
  'ease_1',
  'ease_2',
  'ease_3',
  'ease_4',
  'ease_5',
  'ease_6',
];

const _requiredEvaluationFields = <String>[
  'use_prototype',
  'audio_transcription',
  'clinical_processing',
  'soap_generation',
  'manual_time_seconds',
  'soap_subjective',
  'soap_objective',
  'soap_assessment',
  'soap_plan',
  'soap_placement',
  'soap_clarity',
  'error_transcription',
  'error_omission',
  'error_added',
  'error_confusion',
  'error_placement',
  'error_wording',
  'utility_1',
  'utility_2',
  'utility_3',
  'utility_4',
  'utility_5',
  'utility_6',
  'ease_1',
  'ease_2',
  'ease_3',
  'ease_4',
  'ease_5',
  'ease_6',
];

class SoapEvaluationScreen extends StatefulWidget {
  const SoapEvaluationScreen({
    super.key,
    required this.apiClient,
    this.consultation,
    this.initialEvaluation,
  }) : assert(consultation != null || initialEvaluation != null);
  final ApiClient apiClient;
  final ConsultationRecord? consultation;
  final SoapEvaluation? initialEvaluation;
  @override
  State<SoapEvaluationScreen> createState() => _SoapEvaluationScreenState();
}

class _SoapEvaluationScreenState extends State<SoapEvaluationScreen>
    with WidgetsBindingObserver {
  SoapEvaluation? evaluation;
  int section = 0;
  bool loading = true;
  bool saving = false;
  bool completing = false;
  String saveState = 'Guardado';
  Timer? debounce;
  int editRevision = 0;
  final scrollController = ScrollController();
  final manualMinutes = TextEditingController();
  final manualSeconds = TextEditingController();
  final consultationMinutes = TextEditingController();
  final consultationSeconds = TextEditingController();

  String get draftKey => evaluation == null
      ? ''
      : 'sanare.soap_evaluation.${evaluation!.evaluatorId}.${evaluation!.consultationId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    scrollController.dispose();
    manualMinutes.dispose();
    manualSeconds.dispose();
    consultationMinutes.dispose();
    consultationSeconds.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.apiClient.isAdmin) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_persistLocal());
    }
  }

  Future<void> _load() async {
    try {
      var server = widget.initialEvaluation == null
          ? await widget.apiClient.fetchSoapEvaluation(widget.consultation!.id)
          : await widget.apiClient.fetchSoapEvaluationById(
              widget.initialEvaluation!.id,
            );
      final key =
          'sanare.soap_evaluation.${server.evaluatorId}.${server.consultationId}';
      final raw = widget.apiClient.isAdmin
          ? null
          : await widget.apiClient.secureStorage.read(key: key);
      if (raw != null) {
        final local = SoapEvaluation.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (local.version >= server.version && local.lastSavedAt != null) {
          server = local;
        }
      }
      _setEvaluation(server);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la evaluación: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _setEvaluation(SoapEvaluation value) {
    evaluation = value;
    final manual = (value.values['manual_time_seconds'] as num?)?.toInt();
    if (manual != null) {
      manualMinutes.text = '${manual ~/ 60}';
      manualSeconds.text = '${manual % 60}';
    }
    final consultation = value.consultationSeconds;
    if (consultation != null) {
      consultationMinutes.text = '${consultation ~/ 60}';
      consultationSeconds.text = '${consultation % 60}';
    }
  }

  void _change(String key, dynamic value) {
    if (widget.apiClient.isAdmin || evaluation?.status == 'completed') return;
    setState(() {
      editRevision++;
      evaluation!.values[key] = value;
      saveState = 'Guardando…';
    });
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(_save()),
    );
    unawaited(_persistLocal());
  }

  void _timeChanged(
    String key,
    TextEditingController minutes,
    TextEditingController seconds, {
    String? sourceKey,
  }) {
    if (minutes.text.isEmpty && seconds.text.isEmpty) {
      _change(key, null);
      if (sourceKey != null) _change(sourceKey, 'manual');
      return;
    }
    final min = int.tryParse(minutes.text) ?? 0;
    final sec = int.tryParse(seconds.text) ?? 0;
    if (min < 0 || sec < 0 || sec > 59) return;
    _change(key, min * 60 + sec);
    if (sourceKey != null) _change(sourceKey, 'manual');
  }

  Future<void> _persistLocal() async {
    if (widget.apiClient.isAdmin) return;
    final item = evaluation;
    if (item == null) return;
    item.lastSavedAt = DateTime.now();
    await widget.apiClient.secureStorage.write(
      key: draftKey,
      value: jsonEncode(item.toLocalJson()),
    );
  }

  Future<bool> _save({bool showMessage = false}) async {
    final item = evaluation;
    if (item == null ||
        widget.apiClient.isAdmin ||
        saving ||
        item.status == 'completed') {
      return true;
    }
    debounce?.cancel();
    final revisionBeingSaved = editRevision;
    setState(() {
      saving = true;
      saveState = 'Guardando…';
    });
    try {
      final saved = await widget.apiClient.saveSoapEvaluation(item);
      if (revisionBeingSaved == editRevision) {
        _setEvaluation(saved);
        await widget.apiClient.secureStorage.delete(key: draftKey);
        if (mounted) setState(() => saveState = 'Guardado');
      } else {
        item.version = saved.version;
        item.status = saved.status;
        item.lastSavedAt = saved.lastSavedAt;
      }
      if (showMessage && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Borrador guardado.')));
      }
      return true;
    } catch (_) {
      await _persistLocal();
      if (mounted) {
        setState(() => saveState = 'Sin conexión: cambios pendientes');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => saving = false);
        if (revisionBeingSaved != editRevision) {
          debounce = Timer(
            const Duration(milliseconds: 300),
            () => unawaited(_save()),
          );
        }
      }
    }
  }

  Future<void> _complete() async {
    if (widget.apiClient.isAdmin) return;
    final item = evaluation!;
    final missing = item.requiredFields
        .where((key) => item.values[key] == null)
        .toList();
    if (missing.isNotEmpty) {
      final first = _sectionFor(missing.first);
      setState(() => section = first);
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Faltan ${missing.length} respuestas obligatorias.'),
        ),
      );
      return;
    }
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Finalizar evaluación'),
            content: const Text(
              'Una vez finalizada, la evaluación quedará registrada como completada.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Finalizar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => completing = true);
    try {
      final saved = await widget.apiClient.saveSoapEvaluation(
        item,
        complete: true,
      );
      _setEvaluation(saved);
      await widget.apiClient.secureStorage.delete(key: draftKey);
      if (mounted) {
        setState(() => saveState = 'Guardado');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evaluación completada correctamente.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo finalizar: $error')));
      }
    } finally {
      if (mounted) setState(() => completing = false);
    }
  }

  int _sectionFor(String key) {
    if ([
      'use_prototype',
      'audio_transcription',
      'clinical_processing',
      'soap_generation',
    ].contains(key)) {
      return 0;
    }
    if (key == 'manual_time_seconds') return 1;
    if (key.startsWith('soap_')) return 2;
    if (key.startsWith('error_')) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (evaluation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Evaluación SOAP')),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'No disponible',
          body: 'No se pudo cargar la ficha.',
        ),
      );
    }
    final item = evaluation!;
    final readOnly = widget.apiClient.isAdmin || item.status == 'completed';
    return PopScope(
      canPop: !saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_save());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(item.code),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  widget.apiClient.isAdmin ? 'Solo lectura' : saveState,
                  style: TextStyle(
                    fontSize: 12,
                    color: saveState.startsWith('Sin')
                        ? Colors.orange.shade800
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            LinearProgressIndicator(value: item.progress),
            if (widget.apiClient.isAdmin)
              const MaterialBanner(
                content: Text(
                  'Vista administrativa: esta evaluación pertenece al doctor y no puede modificarse.',
                ),
                actions: [SizedBox.shrink()],
              ),
            _sectionTabs(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: AbsorbPointer(
                  absorbing: readOnly,
                  child: _sectionBody(),
                ),
              ),
            ),
            if (!widget.apiClient.isAdmin)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving || readOnly
                              ? null
                              : () => _save(showMessage: true),
                          child: const Text('Guardar borrador'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: completing || readOnly ? null : _complete,
                          child: Text(
                            readOnly
                                ? 'Completada'
                                : completing
                                ? 'Finalizando…'
                                : 'Finalizar evaluación',
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
    );
  }

  Widget _sectionTabs() => SizedBox(
    height: 58,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (_, i) => ChoiceChip(
        selected: section == i,
        label: Text(
          '${i + 1}. ${['IA', 'Tiempo', 'SOAP', 'Errores', 'Aceptación'][i]}',
        ),
        onSelected: (_) => setState(() => section = i),
      ),
    ),
  );

  Widget _sectionBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (section == 0) ..._identification(),
      Text(
        [
          'Sección I. Uso de inteligencia artificial',
          'Sección II. Tiempo de generación',
          'Sección III. Organización SOAP',
          'Sección IV. Errores identificados',
          'Sección V. Aceptación tecnológica',
        ][section],
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      ...switch (section) {
        0 => _binarySection(),
        1 => _timeSection(),
        2 => _soapSection(),
        3 => _errorSection(),
        _ => _acceptanceSection(),
      },
    ],
  );

  List<Widget> _identification() => [
    Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este formulario tiene como finalidad recolectar información para evaluar reportes automatizados de consultas médicas generados mediante agentes de inteligencia artificial. La información será utilizada únicamente con fines académicos.',
            ),
            const Divider(height: 28),
            _info('Código', evaluation!.code),
            _info(
              'Código de consulta',
              evaluation!.consultationCode ?? 'Pendiente de sincronización',
            ),
            _info('Fecha', evaluation!.date),
            _info('Evaluador', evaluation!.evaluatorName),
            _info('Especialidad', evaluation!.specialization),
            _info('Duración del audio', _readable(evaluation!.audioSeconds)),
            _info('Tiempo de generación', _readable(evaluation!.aiSeconds)),
            _info('Estado técnico', evaluation!.overallStatus),
            if (evaluation!.failureStage != null)
              _info('Etapa del fallo', evaluation!.failureStage!),
            if (evaluation!.failureMessage != null)
              _info('Mensaje', evaluation!.failureMessage!),
            _info(
              'Segmentos',
              '${evaluation!.receivedSegments}/${evaluation!.expectedSegments} enviados · ${evaluation!.transcribedSegments} transcritos',
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 18),
  ];
  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
  List<Widget> _binarySection() => _questions(
    {
      'use_prototype':
          'El prototipo fue utilizado para generar el registro clínico.',
      'audio_transcription':
          'El prototipo realizó la transcripción del audio a texto.',
      'clinical_processing':
          'El prototipo procesó la información clínica de la consulta.',
      'soap_generation':
          'El prototipo generó el registro clínico en formato SOAP.',
    },
    const {0: 'No', 1: 'Sí'},
  );
  List<Widget> _soapSection() => _questions(
    {
      'soap_subjective': 'El registro presenta la sección subjetiva.',
      'soap_objective': 'El registro presenta la sección objetiva.',
      'soap_assessment': 'El registro presenta la sección de evaluación.',
      'soap_plan': 'El registro presenta la sección de plan.',
      'soap_placement': 'La información está ubicada adecuadamente.',
      'soap_clarity': 'La información se presenta clara y ordenada.',
    },
    evaluation!.hasSoap
        ? const {1: 'No cumple', 2: 'Cumple parcialmente', 3: 'Cumple'}
        : const {98: 'No aplica: no se generó SOAP'},
  );
  List<Widget> _errorSection() => [
    ..._questions(
      {
        'error_transcription': 'Errores de transcripción de palabras.',
        'error_omission': 'Omisión de información importante.',
        'error_added': 'Información agregada que no fue mencionada.',
        'error_confusion':
            'Confusión entre síntomas, diagnóstico, evaluación o indicación.',
        'error_placement': 'Ubicación incorrecta en las secciones SOAP.',
        'error_wording': 'Redacción ambigua o poco clara.',
      },
      evaluation!.hasSoap
          ? const {
              1: 'Totalmente erróneo',
              2: 'Grave',
              3: 'Moderado',
              4: 'Leve',
              5: 'No presenta',
            }
          : const {98: 'No aplica: no se generó SOAP'},
    ),
  ];
  List<Widget> _acceptanceSection() => [
    ..._likert('Utilidad percibida', 'utility', [
      'El prototipo me permite generar registros con mayor rapidez.',
      'El uso del prototipo mejora mi desempeño.',
      'El uso del prototipo aumenta mi productividad.',
      'El uso del prototipo mejora mi eficacia.',
      'El prototipo facilita mi trabajo.',
      'En general, el prototipo es útil para generar registros SOAP.',
    ]),
    const SizedBox(height: 18),
    ..._likert('Facilidad de uso percibida', 'ease', [
      'Aprender a utilizar el prototipo fue fácil.',
      'La interacción es clara y comprensible.',
      'Me resulta fácil operar el prototipo.',
      'Considero que tengo control sobre su uso.',
      'Me resulta fácil adquirir habilidad para utilizarlo.',
      'En general, el prototipo es fácil de utilizar.',
    ]),
  ];
  List<Widget> _likert(String title, String prefix, List<String> labels) => [
    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
    const Text('1 = Totalmente en desacuerdo · 5 = Totalmente de acuerdo'),
    const SizedBox(height: 8),
    ...List.generate(
      6,
      (i) => _question('${prefix}_${i + 1}', labels[i], const {
        1: '1',
        2: '2',
        3: '3',
        4: '4',
        5: '5',
      }),
    ),
  ];
  List<Widget> _questions(
    Map<String, String> questions,
    Map<int, String> options,
  ) => [
    const Text('Seleccione una sola opción para cada criterio.'),
    const SizedBox(height: 8),
    ...questions.entries.map(
      (entry) => _question(entry.key, entry.value, options),
    ),
  ];
  Widget _question(String key, String label, Map<int, String> options) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.entries
                .map(
                  (option) => ChoiceChip(
                    label: Text(option.value),
                    selected: evaluation!.values[key] == option.key,
                    onSelected: (_) => _change(key, option.key),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
  );
  List<Widget> _timeSection() {
    final ai = evaluation!.aiSeconds;
    final manual = (evaluation!.values['manual_time_seconds'] as num?)?.toInt();
    final difference = ai == null || manual == null ? null : manual - ai;
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _info('Tiempo del prototipo', _readable(ai)),
              const SizedBox(height: 12),
              const Text(
                'Tiempo manual estimado',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              _durationInputs(
                manualMinutes,
                manualSeconds,
                () => _timeChanged(
                  'manual_time_seconds',
                  manualMinutes,
                  manualSeconds,
                ),
              ),
              const Divider(),
              _info('Diferencia', _signedReadable(difference)),
              if (difference != null)
                Text(
                  difference > 0
                      ? 'El prototipo requirió menos tiempo.'
                      : difference < 0
                      ? 'El prototipo requirió más tiempo.'
                      : 'Ambos métodos requirieron el mismo tiempo.',
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Duración aproximada de la consulta',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              _durationInputs(
                consultationMinutes,
                consultationSeconds,
                () => _timeChanged(
                  'consultation_duration_seconds',
                  consultationMinutes,
                  consultationSeconds,
                  sourceKey: 'consultation_duration_source',
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _durationInputs(
    TextEditingController minutes,
    TextEditingController seconds,
    VoidCallback changed,
  ) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: minutes,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          onChanged: (_) => changed(),
          decoration: const InputDecoration(labelText: 'Minutos'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: seconds,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
            TextInputFormatter.withFunction((oldValue, newValue) {
              final value = int.tryParse(newValue.text);
              return value == null || value <= 59 ? newValue : oldValue;
            }),
          ],
          onChanged: (_) => changed(),
          decoration: const InputDecoration(labelText: 'Segundos (0–59)'),
        ),
      ),
    ],
  );
}

String _readable(int? seconds) {
  if (seconds == null) return 'Dato no disponible';
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return minutes > 0
      ? '$minutes min ${remainder.toString().padLeft(2, '0')} s'
      : '$remainder s';
}

String _signedReadable(int? seconds) {
  if (seconds == null) return 'Dato no disponible';
  return '${seconds < 0 ? '−' : ''}${_readable(seconds.abs())}';
}

class SoapEvaluationAdminScreen extends StatefulWidget {
  const SoapEvaluationAdminScreen({super.key, required this.apiClient});
  final ApiClient apiClient;
  @override
  State<SoapEvaluationAdminScreen> createState() =>
      _SoapEvaluationAdminScreenState();
}

class _SoapEvaluationAdminScreenState extends State<SoapEvaluationAdminScreen> {
  final search = TextEditingController();
  late Future<List<SoapEvaluation>> future;
  String? exporting;
  String? status;
  @override
  void initState() {
    super.initState();
    future = widget.apiClient.fetchSoapEvaluations();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void reload() => setState(
    () => future = widget.apiClient.fetchSoapEvaluations(
      query: search.text,
      status: status,
    ),
  );
  Future<void> export(String format, {int? evaluationId}) async {
    setState(() => exporting = format);
    try {
      final path = await widget.apiClient.exportSoapEvaluations(
        format,
        query: search.text,
        status: status,
        evaluationId: evaluationId,
      );
      if (!mounted) return;
      if (path.isNotEmpty) {
        if (format == 'sav') {
          final box = context.findRenderObject() as RenderBox?;
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(path, mimeType: 'application/x-spss-sav')],
              title: 'Compartir evaluación SPSS',
              subject: 'Evaluaciones SOAP en formato SPSS',
              sharePositionOrigin: box == null
                  ? null
                  : box.localToGlobal(Offset.zero) & box.size,
            ),
          );
        } else {
          unawaited(OpenFilex.open(path));
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportación $format generada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar: $error')));
      }
    } finally {
      if (mounted) setState(() => exporting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Evaluaciones SOAP',
      subtitle: 'Administración y exportación',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  onSubmitted: (_) => reload(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Código, evaluador o especialidad',
                  ),
                ),
              ),
              IconButton(onPressed: reload, icon: const Icon(Icons.search)),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: status,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Todos')),
              DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
              DropdownMenuItem(value: 'draft', child: Text('Borrador')),
              DropdownMenuItem(value: 'completed', child: Text('Completada')),
            ],
            onChanged: (value) {
              status = value;
              reload();
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: ['xlsx', 'csv', 'sav']
                .map(
                  (format) => OutlinedButton.icon(
                    onPressed: exporting == null ? () => export(format) : null,
                    icon: exporting == format
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(format.toUpperCase()),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<SoapEvaluation>>(
            future: future,
            builder: (_, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ErrorCard(message: snapshot.error.toString());
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'Sin evaluaciones',
                  body: 'No hay resultados para los filtros actuales.',
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SoapEvaluationScreen(
                                  apiClient: widget.apiClient,
                                  initialEvaluation: item,
                                ),
                              ),
                            ),
                            title: Text(
                              item.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${item.evaluatorName} · ${item.specialization}\nÚltimo guardado: ${item.lastSavedAt == null ? 'Dato no disponible' : _formatDateTime(item.lastSavedAt!)}',
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Exportar evaluación individual',
                              onSelected: (format) =>
                                  export(format, evaluationId: item.id),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'xlsx',
                                  child: Text('Exportar XLSX'),
                                ),
                                PopupMenuItem(
                                  value: 'csv',
                                  child: Text('Exportar CSV'),
                                ),
                                PopupMenuItem(
                                  value: 'sav',
                                  child: Text('Exportar SAV'),
                                ),
                              ],
                            ),
                          ),
                        ),
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
