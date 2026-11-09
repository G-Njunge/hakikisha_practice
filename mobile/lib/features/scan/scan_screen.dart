import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/errors.dart';
import '../shell/home_shell.dart';
import '../verify/medicine_repository.dart';

/// The API accepts 8–13 digit EAN/UPC barcodes.
final _barcodePattern = RegExp(r'^\d{8,13}$');

const _retailFormats = [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE];

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with WidgetsBindingObserver {
  // Started and stopped by hand (rather than autoStart) because the tab shell
  // keeps this screen alive in the background: the camera should only run
  // while this tab is visible, nothing is pushed over it, and the app is in
  // the foreground.
  final _controller = MobileScannerController(autoStart: false, formats: _retailFormats);

  bool _tabVisible = true;
  bool _appInForeground = true;
  bool _busy = false;
  Future<void> _cameraOps = Future.value();

  bool get _cameraShouldRun => _tabVisible && _appInForeground && !_busy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabVisible = ActiveTab.of(context) == Tabs.scan;
    _syncCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    _syncCamera();
  }

  /// Start/stop calls are queued so a quick tab switch can't overlap a start
  /// that's still in flight (the controller throws on that).
  void _syncCamera() {
    _cameraOps = _cameraOps.then((_) async {
      if (!mounted) return;
      try {
        if (_cameraShouldRun) {
          await _controller.start();
        } else {
          await _controller.stop();
        }
      } on MobileScannerException {
        // Shown by the scanner's errorBuilder (e.g. permission denied).
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && _barcodePattern.hasMatch(v), orElse: () => null);
    if (barcode != null) _lookUp(barcode);
  }

  Future<void> _lookUp(String barcode) async {
    if (_busy) return;
    setState(() => _busy = true);
    _syncCamera();
    HapticFeedback.mediumImpact();

    try {
      final result = await ref.read(medicineRepositoryProvider).scanBarcode(barcode);
      if (!mounted) return;
      await context.push('/verify', extra: result);
    } on AppException catch (e) {
      _showMessage(e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _syncCamera();
      }
    }
  }

  Future<void> _scanFromPhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (photo == null) return;

    BarcodeCapture? capture;
    try {
      capture = await _controller.analyzeImage(photo.path, formats: _retailFormats);
    } catch (_) {
      capture = null;
    }
    final barcode = capture?.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && _barcodePattern.hasMatch(v), orElse: () => null);

    if (barcode == null) {
      _showMessage("We couldn't find a barcode in that photo. Try a closer, sharper shot without glare.");
      return;
    }
    await _lookUp(barcode);
  }

  Future<void> _enterManually() async {
    final barcode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ManualEntrySheet(),
    );
    if (barcode != null) await _lookUp(barcode);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan a medicine'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (state.torchState == TorchState.unavailable) return const SizedBox.shrink();
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'Turn off flashlight' : 'Turn on flashlight',
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                onPressed: _controller.toggleTorch,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _CameraError(error: error),
                ),
                const _ViewfinderOverlay(),
                if (_busy)
                  const ColoredBox(
                    color: Colors.black54,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Point the camera at the barcode on the pack.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _scanFromPhoto,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('From photo'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _enterManually,
                          icon: const Icon(Icons.keyboard_outlined),
                          label: const Text('Type number'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.8,
          child: AspectRatio(
            aspectRatio: 1.8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'Camera access is off for Hakikisha. Allow it in Settings, or use a photo or type the number below.'
                    : "The camera couldn't start. You can still use a photo or type the number below.",
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              if (denied) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: Geolocator.openAppSettings,
                  child: const Text('Open Settings'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet();

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_field.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enter the barcode number', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('The 8–13 digits printed under the barcode.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _field,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)],
              decoration: const InputDecoration(labelText: 'Barcode number'),
              validator: (value) => _barcodePattern.hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Barcodes are 8 to 13 digits long.',
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Check medicine')),
          ],
        ),
      ),
    );
  }
}
