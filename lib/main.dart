import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ScanStore.init();
  runApp(const BarcodeReaderApp());
}

class BarcodeReaderApp extends StatelessWidget {
  const BarcodeReaderApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'قارئ باركود',
        theme: ScannerTheme.dark,
        home: const ScannerHome(),
      );
}

// ============================================================
// نموذج السجل
// ============================================================
class ScanRecord {
  ScanRecord({
    required this.value,
    required this.format,
    required this.time,
  });

  final String value;
  final String format;
  final DateTime time;

  Map<String, dynamic> toJson() => {
        'value': value,
        'format': format,
        'time': time.millisecondsSinceEpoch,
      };

  factory ScanRecord.fromJson(Map<String, dynamic> json) => ScanRecord(
        value: json['value'] as String? ?? '',
        format: json['format'] as String? ?? 'unknown',
        time: DateTime.fromMillisecondsSinceEpoch(json['time'] as int? ?? 0),
      );
}

// ============================================================
// مخزن السجل (SharedPreferences)
// ============================================================
class ScanStore {
  static late SharedPreferences _prefs;
  static const _key = 'scan_history';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static List<ScanRecord> load() {
    try {
      final raw = _prefs.getString(_key);
      if (raw == null) return <ScanRecord>[];
      return (jsonDecode(raw) as List)
          .map((e) => ScanRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <ScanRecord>[];
    }
  }

  static Future<void> save(List<ScanRecord> records) async {
    await _prefs.setString(
      _key,
      jsonEncode(records.map((e) => e.toJson()).toList()),
    );
  }
}

// ============================================================
// الشاشة الرئيسية
// ============================================================
class ScannerHome extends StatefulWidget {
  const ScannerHome({Key? key}) : super(key: key);

  @override
  State<ScannerHome> createState() => _ScannerHomeState();
}

class _ScannerHomeState extends State<ScannerHome>
    with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController();
  late TabController tabs;
  List<ScanRecord> history = <ScanRecord>[];
  String? lastValue;
  DateTime? lastScan;

  @override
  void initState() {
    super.initState();
    history = ScanStore.load();
    tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    tabs.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (capture.barcodes.isEmpty) return;

    final barcode = capture.barcodes.first;
    final value = barcode.rawValue;
    if (value == null || value.trim().isEmpty) return;

    final now = DateTime.now();

    // منع التكرار السريع لنفس القيمة
    if (value == lastValue &&
        lastScan != null &&
        now.difference(lastScan!).inMilliseconds < 1800) {
      return;
    }

    lastValue = value;
    lastScan = now;

    final record = ScanRecord(
      value: value,
      format: barcode.format.name,
      time: now,
    );

    setState(() {
      history.removeWhere((item) => item.value == value);
      history.insert(0, record);
      if (history.length > 80) history.removeLast();
    });

    await ScanStore.save(history);

    try {
      await controller.stop();
    } catch (_) {}

    if (!mounted) return;
    await _showResult(record);

    if (mounted) {
      try {
        await controller.start();
      } catch (_) {}
    }
  }

  Future<void> _showResult(ScanRecord record) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151B27),
      showDragHandle: true,
      builder: (context) => ResultSheet(record: record),
    );
  }

  Future<void> clearHistory() async {
    setState(() => history.clear());
    await ScanStore.save(history);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'قارئ باركود',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: <Widget>[
            IconButton(
              onPressed: () => controller.toggleTorch(),
              icon: const Icon(Icons.flash_on_rounded),
            ),
            IconButton(
              onPressed: clearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
          bottom: TabBar(
            controller: tabs,
            tabs: const <Widget>[
              Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'مسح'),
              Tab(icon: Icon(Icons.history_rounded), text: 'السجل'),
            ],
          ),
        ),
        body: TabBarView(
          controller: tabs,
          children: <Widget>[
            _ScannerView(controller: controller, onDetect: _onDetect),
            HistoryView(
              records: history,
              onDelete: (record) async {
                setState(() => history.remove(record));
                await ScanStore.save(history);
              },
            ),
          ],
        ),
      );
}

// ============================================================
// عرض الكاميرا + الإطار
// ============================================================
class _ScannerView extends StatelessWidget {
  const _ScannerView({required this.controller, required this.onDetect});

  final MobileScannerController controller;
  final Function(BarcodeCapture) onDetect;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: controller,
            onDetect: onDetect,
          ),
          Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(.18)),
          ),
          const Center(child: ScanFrame()),
          Positioned(
            top: 38,
            left: 28,
            right: 28,
            child: Column(
              children: <Widget>[
                const Text(
                  'وجّه الكاميرا نحو الرمز',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'سيتم التعرف عليه تلقائيًا',
                  style: TextStyle(color: Colors.white.withOpacity(.72)),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.55),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(
                    Icons.tips_and_updates_outlined,
                    color: ScannerTheme.cyan,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'يدعم QR والروابط والمنتجات والنصوص.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

// ============================================================
// عرض سجل الفحص
// ============================================================
class HistoryView extends StatelessWidget {
  const HistoryView({Key? key, required this.records, required this.onDelete})
      : super(key: key);

  final List<ScanRecord> records;
  final Future<void> Function(ScanRecord) onDelete;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.qr_code_2_rounded, size: 70, color: ScannerTheme.cyan),
            SizedBox(height: 16),
            Text(
              'لا يوجد سجل بعد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text('ابدأ بمسح أول رمز'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return Dismissible(
          key: ValueKey('${record.value}$index'),
          onDismissed: (_) => onDelete(record),
          background: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 22),
            child: const Icon(Icons.delete_outline),
          ),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: ScannerTheme.cyan.withOpacity(.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: ScannerTheme.cyan,
                ),
              ),
              title: Text(
                record.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
              ),
              subtitle: Text(
                '${record.format}  •  ${record.time.day}/${record.time.month}/${record.time.year}',
              ),
              trailing: IconButton(
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: record.value),
                ),
                icon: const Icon(Icons.copy_rounded),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// لوحة النتيجة (Bottom Sheet)
// ============================================================
class ResultSheet extends StatelessWidget {
  const ResultSheet({Key? key, required this.record}) : super(key: key);

  final ScanRecord record;

  bool get isUrl =>
      record.value.startsWith('http://') ||
      record.value.startsWith('https://');

  Future<void> open() async {
    final uri = Uri.tryParse(record.value);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Icon(
                Icons.check_circle_rounded,
                color: ScannerTheme.cyan,
                size: 56,
              ),
              const SizedBox(height: 12),
              const Text(
                'تم التعرف على الرمز',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                record.format,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(.6)),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.22),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SelectableText(
                  record.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: record.value),
                      ),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('نسخ'),
                    ),
                  ),
                  if (isUrl) ...<Widget>[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: open,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('فتح الرابط'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
}