import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const List<DisplayColorOption> _displayColorOptions = [
  DisplayColorOption('white', 'Putih', Color(0xFFFFFFFF)),
  DisplayColorOption('red', 'Merah', Color(0xFFFF4B4B)),
  DisplayColorOption('green', 'Hijau', Color(0xFF65E572)),
  DisplayColorOption('blue', 'Biru', Color(0xFF5C8DFF)),
  DisplayColorOption('yellow', 'Kuning', Color(0xFFFFD95C)),
  DisplayColorOption('cyan', 'Cyan', Color(0xFF4FE8FF)),
];

const Color _accentGreen = Color(0xFF00D66B);
const Color _actionBlue = Color(0xFF2F9DED);
const Color _dangerRed = Color(0xFFDD2D32);

void main() {
  runApp(const Esp32ClockApp());
}

class Esp32ClockApp extends StatelessWidget {
  const Esp32ClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JamDigital',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF111111),
          onSurface: Colors.white,
          primary: Colors.white,
          onPrimary: Colors.black,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF141414),
          hintStyle: const TextStyle(color: Color(0xFF666666)),
          labelStyle: const TextStyle(color: Color(0xFFAAAAAA)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF777777)),
          ),
        ),
      ),
      home: const ClockControlScreen(),
    );
  }
}

class ClockControlScreen extends StatefulWidget {
  const ClockControlScreen({super.key});

  @override
  State<ClockControlScreen> createState() => _ClockControlScreenState();
}

class _ClockControlScreenState extends State<ClockControlScreen> {
  final TextEditingController _ipController =
      TextEditingController(text: '192.168.4.1');
  final TextEditingController _messageController =
      TextEditingController(text: 'Selamat Datang');
  final TextEditingController _volumeController =
      TextEditingController(text: '15');
  final TextEditingController _testHourController =
      TextEditingController(text: '7');
  final TextEditingController _durationOneController =
      TextEditingController(text: '10');
  final TextEditingController _durationTwoController =
      TextEditingController(text: '5');
  final TextEditingController _durationThreeController =
      TextEditingController(text: '8');
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final List<AlarmSlotControllers> _alarmSlots;

  Timer? _clockTimer;
  Timer? _scrollTimer;
  DateTime _now = DateTime.now();
  double _scrollOffset = 0;

  int _fontType = 0;
  String _clockColorId = 'white';
  String _runningTextColorId = 'yellow';
  String _frameColorId = 'white';
  double _brightness = 128;
  double _scrollSpeed = 50;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _hasPendingDisplayChanges = false;

  @override
  void initState() {
    super.initState();
    _alarmSlots = List.generate(
      5,
      (index) => AlarmSlotControllers(
        index: index,
        hour: index == 0 ? '5' : '12',
        minute: '0',
        day: '0',
        month: '0',
        track: '${30 + index}',
        message: 'ALARM SHOLAT ${index + 1}',
      ),
    );
    _messageController.addListener(_markDisplayDirty);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted) return;
      final speedStep = 0.08 + (_scrollSpeed / 100) * 0.42;
      setState(() => _scrollOffset += speedStep);
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _scrollTimer?.cancel();
    _ipController.dispose();
    _messageController.dispose();
    _volumeController.dispose();
    _testHourController.dispose();
    _durationOneController.dispose();
    _durationTwoController.dispose();
    _durationThreeController.dispose();
    for (final slot in _alarmSlots) {
      slot.dispose();
    }
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _sendRequest({
    required String path,
    Map<String, String>? parameters,
    required String successTitle,
    String? successDetail,
    required String errorMessage,
  }) async {
    setState(() => _isLoading = true);

    try {
      final uri = Uri.http(_ipController.text.trim(), path, parameters);
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (!mounted) return false;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showAppSnackBar(
          successTitle,
          detail: successDetail,
          isError: false,
        );
        return true;
      }

      _showAppSnackBar('$errorMessage (${response.statusCode})', isError: true);
      return false;
    } on TimeoutException {
      if (!mounted) return false;
      _showAppSnackBar('ESP32 tidak merespons dalam 5 detik.', isError: true);
      return false;
    } catch (e) {
      debugPrint('HTTP error: $e');
      if (!mounted) return false;
      _showAppSnackBar(errorMessage, isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _applyDisplay() async {
    final durationOne =
        _readIntController(_durationOneController, min: 1, max: 255);
    final durationTwo =
        _readIntController(_durationTwoController, min: 1, max: 255);
    final durationThree =
        _readIntController(_durationThreeController, min: 1, max: 255);
    _durationOneController.text = durationOne.toString();
    _durationTwoController.text = durationTwo.toString();
    _durationThreeController.text = durationThree.toString();

    final success = await _sendRequest(
      path: '/savedisplay',
      parameters: {
        'pesan': _messageController.text.trim(),
        'bright': _brightness.round().toString(),
        'speed': _scrollSpeed.round().toString(),
        'fontType': _fontType.toString(),
        'cJam': _colorHex(_selectedColor(_clockColorId)),
        'cTeks': _colorHex(_selectedColor(_runningTextColorId)),
        'cFrame': _colorHex(_selectedColor(_frameColorId)),
        'dur1': durationOne.toString(),
        'dur2': durationTwo.toString(),
        'dur3': durationThree.toString(),
      },
      successTitle: 'Tampilan diterapkan',
      successDetail: 'Pengaturan berhasil dikirim ke ESP32.',
      errorMessage: 'Gagal menerapkan pengaturan tampilan.',
    );

    if (success && mounted) {
      setState(() => _hasPendingDisplayChanges = false);
    }
  }

  Future<void> _syncTime() async {
    final epochSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _sendRequest(
      path: '/settime',
      parameters: {'epoch': epochSeconds.toString()},
      successTitle: 'Waktu HP dikirim',
      successDetail: 'Jam ESP32 berhasil disinkronkan.',
      errorMessage: 'Gagal menyinkronkan waktu.',
    );
  }

  Future<void> _saveAlarm(AlarmSlotControllers slot) async {
    final hour = _readIntController(slot.hourController, min: 0, max: 23);
    final minute = _readIntController(slot.minuteController, min: 0, max: 59);
    final day = _readIntController(slot.dayController, min: 0, max: 31);
    final month = _readIntController(slot.monthController, min: 0, max: 12);
    final track = _readIntController(slot.trackController, min: 1, max: 255);
    slot.hourController.text = hour.toString();
    slot.minuteController.text = minute.toString();
    slot.dayController.text = day.toString();
    slot.monthController.text = month.toString();
    slot.trackController.text = track.toString();

    await _sendRequest(
      path: '/save_alarm',
      parameters: {
        'id': slot.index.toString(),
        'h': hour.toString(),
        'm': minute.toString(),
        'd': day.toString(),
        'mo': month.toString(),
        'en': slot.enabled ? '1' : '0',
        'tr': track.toString(),
        'msg': slot.messageController.text.trim(),
      },
      successTitle: 'Alarm ${slot.index + 1} disimpan',
      successDetail: 'Pengaturan alarm berhasil dikirim ke ESP32.',
      errorMessage: 'Gagal menyimpan alarm ${slot.index + 1}.',
    );
  }

  Future<void> _saveVolume() async {
    final volume = _readIntController(_volumeController, min: 0, max: 30);
    _volumeController.text = volume.toString();

    await _sendRequest(
      path: '/setmp3',
      parameters: {'vol': volume.toString()},
      successTitle: 'Volume disimpan',
      errorMessage: 'Gagal menyimpan volume.',
    );
  }

  Future<void> _testHourlyChime() async {
    final volume = _readIntController(_volumeController, min: 0, max: 30);
    final hour = _readIntController(_testHourController, min: 1, max: 24);
    _volumeController.text = volume.toString();
    _testHourController.text = hour.toString();

    await _sendRequest(
      path: '/setmp3',
      parameters: {
        'vol': volume.toString(),
        'action': 'testChime',
        'hour': hour.toString(),
      },
      successTitle: 'Tes bel jam dikirim',
      successDetail: 'ESP32 memutar suara bel jam ke-$hour.',
      errorMessage: 'Gagal mengetes suara bel jam.',
    );
  }

  Future<void> _saveWifi() async {
    final ssid = _ssidController.text.trim();
    if (ssid.isEmpty) {
      _showAppSnackBar('SSID tidak boleh kosong.', isError: true);
      return;
    }

    await _sendRequest(
      path: '/savewifi',
      parameters: {
        'ssid': ssid,
        'pass': _passwordController.text,
      },
      successTitle: 'WiFi disimpan',
      successDetail: 'ESP32 akan melakukan restart.',
      errorMessage: 'Gagal menyimpan konfigurasi WiFi.',
    );
  }

  Future<void> _resetWifi() async {
    await _sendRequest(
      path: '/resetwifi',
      successTitle: 'Reset WiFi dikirim',
      successDetail: 'ESP32 akan kembali ke mode Access Point.',
      errorMessage: 'Gagal reset WiFi ESP32.',
    );
  }

  int _readIntController(
    TextEditingController controller, {
    required int min,
    required int max,
  }) {
    final value = int.tryParse(controller.text.trim()) ?? min;
    return value.clamp(min, max);
  }

  void _markDisplayDirty() {
    if (_hasPendingDisplayChanges) return;
    setState(() => _hasPendingDisplayChanges = true);
  }

  void _showAppSnackBar(
    String message, {
    String? detail,
    required bool isError,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: Color(0xFFD0D0D0),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF202020),
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF333333)),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jam Digital',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Monitor',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF777777),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVirtualDeviceCard(),
                const SizedBox(height: 10),
                _buildDisplayStatus(),
                const SizedBox(height: 18),
                _buildConnectionInfo(),
                const SizedBox(height: 24),
                _buildSectionHeader('01', 'Waktu', 'Sinkronisasi waktu ESP32'),
                const SizedBox(height: 12),
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Waktu HP'),
                      const SizedBox(height: 8),
                      Text(
                        _formatClock(_now),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPrimaryButton(
                        text: 'Sinkronkan Waktu HP',
                        icon: Icons.sync_rounded,
                        onPressed: _isLoading ? null : _syncTime,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  '02',
                  'Tampilan Layar',
                  'Atur preview sebelum dikirim ke ESP32',
                ),
                const SizedBox(height: 12),
                _buildDisplaySettingsCard(),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  '03',
                  'Audio / MP3 DFPlayer',
                  'Kontrol volume dan tes bel jam',
                ),
                const SizedBox(height: 12),
                _buildAudioCard(),
                const SizedBox(height: 28),
                _buildSectionHeader('04', 'Jaringan', 'Konfigurasi WiFi ESP32'),
                const SizedBox(height: 12),
                _buildNetworkCard(),
                const SizedBox(height: 30),
                Center(
                  child: Text(
                    'ESP32 P10 LED MATRIX',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVirtualDeviceCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Virtual Device',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Tampilan Sementara LED',
                      style: TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1D1D),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: const Text(
                  'LIVE PREVIEW',
                  style: TextStyle(
                    color: Color(0xFFDADADA),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 3.2,
            child: CustomPaint(
              painter: P10PreviewPainter(
                message: _messageController.text,
                now: _now,
                brightness: _brightness,
                fontType: _fontType,
                scrollOffset: _scrollOffset,
                clockColor: _selectedColor(_clockColorId),
                runningTextColor: _selectedColor(_runningTextColorId),
                frameColor: _selectedColor(_frameColorId),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayStatus() {
    final color = _hasPendingDisplayChanges
        ? const Color(0xFFE0C36A)
        : const Color(0xFF8BCB9B);
    final text = _hasPendingDisplayChanges
        ? 'Ada perubahan yang belum diterapkan'
        : 'Sinkron dengan ESP32';

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text('●', style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFFAAAAAA),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionInfo() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('IP ESP32'),
          const SizedBox(height: 8),
          TextField(
            controller: _ipController,
            keyboardType: TextInputType.url,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
            decoration: const InputDecoration(
              hintText: '192.168.4.1',
              prefixIcon: Icon(
                Icons.router_outlined,
                color: Color(0xFF777777),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplaySettingsCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Font'),
          const SizedBox(height: 8),
          _buildFontDropdown(),
          const SizedBox(height: 20),
          _buildLabel('Warna Jam Digital (Atas)'),
          const SizedBox(height: 8),
          _buildColorDropdown(
            value: _clockColorId,
            onChanged: (value) {
              setState(() => _clockColorId = value);
              _markDisplayDirty();
            },
          ),
          const SizedBox(height: 18),
          _buildLabel('Warna Running Text (Bawah)'),
          const SizedBox(height: 8),
          _buildColorDropdown(
            value: _runningTextColorId,
            onChanged: (value) {
              setState(() => _runningTextColorId = value);
              _markDisplayDirty();
            },
          ),
          const SizedBox(height: 18),
          _buildLabel('Warna Frame'),
          const SizedBox(height: 8),
          _buildColorDropdown(
            value: _frameColorId,
            onChanged: (value) {
              setState(() => _frameColorId = value);
              _markDisplayDirty();
            },
          ),
          const SizedBox(height: 20),
          _buildLabel('Running Text'),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Masukkan teks...',
              prefixIcon: Icon(
                Icons.text_fields_rounded,
                color: Color(0xFF777777),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 22),
          _buildSlider(
            title: 'Brightness',
            value: _brightness,
            min: 10,
            max: 255,
            valueLabel: _brightness.round().toString(),
            onChanged: (value) {
              setState(() => _brightness = value);
              _markDisplayDirty();
            },
          ),
          const SizedBox(height: 18),
          _buildSlider(
            title: 'Scroll Speed',
            value: _scrollSpeed,
            min: 10,
            max: 100,
            valueLabel: _scrollSpeed.round().toString(),
            onChanged: (value) {
              setState(() => _scrollSpeed = value);
              _markDisplayDirty();
            },
          ),
          const SizedBox(height: 22),
          _buildPrimaryButton(
            text: 'Terapkan Tampilan',
            icon: Icons.check_rounded,
            onPressed: _isLoading ? null : _applyDisplay,
          ),
        ],
      ),
    );
  }

  Widget _buildAudioCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('Volume (0 - 30):'),
          const SizedBox(height: 8),
          _buildNumberField(
            controller: _volumeController,
            hintText: '20',
          ),
          const SizedBox(height: 18),
          _buildSolidButton(
            text: 'SET VOLUME',
            icon: Icons.volume_up_rounded,
            color: _accentGreen,
            onPressed: _isLoading ? null : _saveVolume,
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF444444), height: 1),
          const SizedBox(height: 24),
          _buildLabel('Tes Suara Bel Jam:'),
          const SizedBox(height: 8),
          _buildNumberField(
            controller: _testHourController,
            hintText: '7',
          ),
          const SizedBox(height: 18),
          _buildSolidButton(
            text: 'TES BEL JAM',
            icon: Icons.campaign_rounded,
            color: _actionBlue,
            onPressed: _isLoading ? null : _testHourlyChime,
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('SSID'),
          const SizedBox(height: 8),
          TextField(
            controller: _ssidController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Nama WiFi',
              prefixIcon: Icon(
                Icons.wifi_rounded,
                color: Color(0xFF777777),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _buildLabel('Password'),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Password WiFi',
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF777777),
                size: 20,
              ),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF777777),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _buildSolidButton(
            text: 'SIMPAN & KONEKSIKAN WIFI',
            icon: Icons.restart_alt_rounded,
            color: _accentGreen,
            onPressed: _isLoading ? null : _saveWifi,
          ),
          const SizedBox(height: 14),
          _buildSolidButton(
            text: 'RESET KE MODE AP',
            icon: Icons.wifi_tethering_rounded,
            color: _dangerRed,
            onPressed: _isLoading ? null : _resetWifi,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String number, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Color(0xFF555555),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _accentGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: child,
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFBDBDBD),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(
          Icons.numbers_rounded,
          color: Color(0xFF777777),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildFontDropdown() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _fontType,
          isExpanded: true,
          dropdownColor: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(8),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF777777),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Normal')),
            DropdownMenuItem(value: 1, child: Text('Kotak 3x5')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _fontType = value);
            _markDisplayDirty();
          },
        ),
      ),
    );
  }

  Widget _buildColorDropdown({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(8),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF777777),
          ),
          items: _displayColorOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option.id,
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: option.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF555555)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    option.label,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (selected) {
            if (selected == null) return;
            onChanged(selected);
          },
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required String valueLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 11),
            ),
            const Spacer(),
            Text(
              valueLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            activeTrackColor: Colors.white,
            inactiveTrackColor: const Color(0xFF444444),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withValues(alpha: 0.08),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return _buildSolidButton(
      text: text.toUpperCase(),
      icon: icon,
      color: _accentGreen,
      onPressed: onPressed,
    );
  }

  Widget _buildSolidButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF444444),
          disabledForegroundColor: const Color(0xFF888888),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

}

class DisplayColorOption {
  const DisplayColorOption(this.id, this.label, this.color);

  final String id;
  final String label;
  final Color color;
}

Color _selectedColor(String id) {
  return _displayColorOptions
      .firstWhere(
        (option) => option.id == id,
        orElse: () => _displayColorOptions.first,
      )
      .color;
}

String _colorHex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return value.toRadixString(16).padLeft(6, '0').toUpperCase();
}

class P10PreviewPainter extends CustomPainter {
  P10PreviewPainter({
    required this.message,
    required this.now,
    required this.brightness,
    required this.fontType,
    required this.scrollOffset,
    required this.clockColor,
    required this.runningTextColor,
    required this.frameColor,
  });

  static const int columns = 64;
  static const int rows = 16;

  final String message;
  final DateTime now;
  final double brightness;
  final int fontType;
  final double scrollOffset;
  final Color clockColor;
  final Color runningTextColor;
  final Color frameColor;

  @override
  void paint(Canvas canvas, Size size) {
    final panelRect = Offset.zero & size;
    final borderPaint = Paint()
      ..color = _brightnessColor(frameColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect, const Radius.circular(8)),
      Paint()..color = Colors.black,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panelRect.deflate(0.5), const Radius.circular(8)),
      borderPaint,
    );

    final margin = math.max(10.0, size.width * 0.035);
    final matrixRect = Rect.fromLTWH(
      margin,
      margin,
      size.width - margin * 2,
      size.height - margin * 2,
    );
    final cellW = matrixRect.width / columns;
    final cellH = matrixRect.height / rows;
    final dotSize = math.min(cellW, cellH) * 0.56;
    final inactivePaint = Paint()..color = const Color(0xFF1F1F1F);
    final clockPaint = Paint()..color = _brightnessColor(clockColor);
    final runningTextPaint = Paint()
      ..color = _brightnessColor(runningTextColor);

    final previewMessage = message.trim();
    final clockPixels = _clockPixels().toSet();
    final runningTextPixels =
        _runningTextPixels(previewMessage.toUpperCase()).toSet();

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        final center = Offset(
          matrixRect.left + x * cellW + cellW / 2,
          matrixRect.top + y * cellH + cellH / 2,
        );
        final point = Point(x, y);
        final paint = clockPixels.contains(point)
            ? clockPaint
            : runningTextPixels.contains(point)
            ? runningTextPaint
            : inactivePaint;
        canvas.drawCircle(center, dotSize / 2, paint);
      }
    }
  }

  Iterable<Point<int>> _clockPixels() {
    final clock = _formatClock(now);
    final result = <Point<int>>{};
    final primary = _renderText(clock, 1);
    result.addAll(_place(primary, ((columns - primary.width) / 2).floor(), 1));
    return result;
  }

  Iterable<Point<int>> _runningTextPixels(String text) {
    final runningText = text.trim().isEmpty ? 'RUNNING TEXT' : text;
    final rendered = _renderText(runningText, fontType);
    final y = fontType == 0 ? 8 : 10;
    final travel = columns + rendered.width + 8;
    final left = columns - (scrollOffset.round() % travel);
    return _place(rendered, left, y);
  }

  RenderedText _renderText(String text, int type) {
    final glyphs = type == 1 ? _font3x5 : _font5x7;
    final fallback = glyphs[' ']!;
    final spacing = type == 1 ? 1 : 1;
    final width = text.runes.fold<int>(0, (total, rune) {
      final char = String.fromCharCode(rune).toUpperCase();
      return total + (glyphs[char] ?? fallback).first.length + spacing;
    });
    final height = type == 1 ? 5 : 7;
    final points = <Point<int>>{};
    var cursor = 0;

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune).toUpperCase();
      final glyph = glyphs[char] ?? fallback;
      for (var y = 0; y < glyph.length; y++) {
        for (var x = 0; x < glyph[y].length; x++) {
          if (glyph[y][x] == '1') points.add(Point(cursor + x, y));
        }
      }
      cursor += glyph.first.length + spacing;
    }

    return RenderedText(
      points: points,
      width: math.max(0, width - spacing),
      height: height,
    );
  }

  Color _brightnessColor(Color color) {
    final factor = (0.25 + ((brightness - 10) / 245) * 0.75).clamp(0.25, 1.0);
    final argb = color.toARGB32();
    return Color.fromARGB(
      (argb >> 24) & 0xFF,
      (((argb >> 16) & 0xFF) * factor).round().clamp(0, 255),
      (((argb >> 8) & 0xFF) * factor).round().clamp(0, 255),
      ((argb & 0xFF) * factor).round().clamp(0, 255),
    );
  }

  Iterable<Point<int>> _place(RenderedText text, int left, int top) sync* {
    for (final point in text.points) {
      final x = point.x + left;
      final y = point.y + top;
      if (x >= 0 && x < columns && y >= 0 && y < rows) {
        yield Point(x, y);
      }
    }
  }

  @override
  bool shouldRepaint(covariant P10PreviewPainter oldDelegate) {
    return oldDelegate.message != message ||
        oldDelegate.now.second != now.second ||
        oldDelegate.brightness != brightness ||
        oldDelegate.fontType != fontType ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.clockColor != clockColor ||
        oldDelegate.runningTextColor != runningTextColor ||
        oldDelegate.frameColor != frameColor;
  }
}

class RenderedText {
  const RenderedText({
    required this.points,
    required this.width,
    required this.height,
  });

  final Set<Point<int>> points;
  final int width;
  final int height;
}

class Point<T extends num> {
  const Point(this.x, this.y);

  final T x;
  final T y;

  @override
  bool operator ==(Object other) {
    return other is Point<T> && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

String _formatClock(DateTime time) {
  return '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

const Map<String, List<String>> _font5x7 = {
  ' ': ['000', '000', '000', '000', '000', '000', '000'],
  'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  'B': ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
  'C': ['01111', '10000', '10000', '10000', '10000', '10000', '01111'],
  'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  'G': ['01111', '10000', '10000', '10111', '10001', '10001', '01111'],
  'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
  'I': ['111', '010', '010', '010', '010', '010', '111'],
  'J': ['00111', '00010', '00010', '00010', '10010', '10010', '01100'],
  'K': ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
  'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
  'M': ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
  'N': ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
  'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
  'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
  'Q': ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
  'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
  'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
  'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
  'V': ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
  'W': ['10001', '10001', '10001', '10101', '10101', '10101', '01010'],
  'X': ['10001', '10001', '01010', '00100', '01010', '10001', '10001'],
  'Y': ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
  'Z': ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
  '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
  '1': ['010', '110', '010', '010', '010', '010', '111'],
  '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
  '3': ['11110', '00001', '00001', '01110', '00001', '00001', '11110'],
  '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
  '5': ['11111', '10000', '10000', '11110', '00001', '00001', '11110'],
  '6': ['01110', '10000', '10000', '11110', '10001', '10001', '01110'],
  '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
  '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
  '9': ['01110', '10001', '10001', '01111', '00001', '00001', '01110'],
  ':': ['0', '1', '1', '0', '1', '1', '0'],
  ',': ['0', '0', '0', '0', '0', '1', '1'],
  '.': ['0', '0', '0', '0', '0', '1', '1'],
  '-': ['000', '000', '000', '111', '000', '000', '000'],
};

const Map<String, List<String>> _font3x5 = {
  ' ': ['000', '000', '000', '000', '000'],
  'A': ['111', '101', '111', '101', '101'],
  'B': ['110', '101', '110', '101', '110'],
  'C': ['111', '100', '100', '100', '111'],
  'D': ['110', '101', '101', '101', '110'],
  'E': ['111', '100', '110', '100', '111'],
  'F': ['111', '100', '110', '100', '100'],
  'G': ['111', '100', '101', '101', '111'],
  'H': ['101', '101', '111', '101', '101'],
  'I': ['111', '010', '010', '010', '111'],
  'J': ['001', '001', '001', '101', '111'],
  'K': ['101', '101', '110', '101', '101'],
  'L': ['100', '100', '100', '100', '111'],
  'M': ['101', '111', '111', '101', '101'],
  'N': ['101', '111', '111', '111', '101'],
  'O': ['111', '101', '101', '101', '111'],
  'P': ['111', '101', '111', '100', '100'],
  'Q': ['111', '101', '101', '111', '001'],
  'R': ['110', '101', '110', '101', '101'],
  'S': ['111', '100', '111', '001', '111'],
  'T': ['111', '010', '010', '010', '010'],
  'U': ['101', '101', '101', '101', '111'],
  'V': ['101', '101', '101', '101', '010'],
  'W': ['101', '101', '111', '111', '101'],
  'X': ['101', '101', '010', '101', '101'],
  'Y': ['101', '101', '111', '010', '010'],
  'Z': ['111', '001', '010', '100', '111'],
  '0': ['111', '101', '101', '101', '111'],
  '1': ['010', '110', '010', '010', '111'],
  '2': ['111', '001', '111', '100', '111'],
  '3': ['111', '001', '111', '001', '111'],
  '4': ['101', '101', '111', '001', '001'],
  '5': ['111', '100', '111', '001', '111'],
  '6': ['111', '100', '111', '101', '111'],
  '7': ['111', '001', '010', '010', '010'],
  '8': ['111', '101', '111', '101', '111'],
  '9': ['111', '101', '111', '001', '111'],
  ':': ['0', '1', '0', '1', '0'],
  ',': ['0', '0', '0', '1', '1'],
  '.': ['0', '0', '0', '1', '1'],
  '-': ['000', '000', '111', '000', '000'],
};
