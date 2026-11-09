import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors.dart';
import '../../core/countries.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import 'report_repository.dart';

/// What a report is about. From a scan, [scanId] links it to the scan record;
/// [medicineName] is set when the scan matched a registered medicine (the
/// server resolves the name itself), otherwise the user names the product.
class ReportTarget {
  const ReportTarget({this.scanId, this.medicineName});

  final String? scanId;
  final String? medicineName;
}

/// Opens the report form, asking the user to log in first if needed
/// (reports are tied to an account).
Future<void> openReportForm(BuildContext context, WidgetRef ref, [ReportTarget target = const ReportTarget()]) async {
  if (ref.read(authControllerProvider).value == null) {
    final loggedIn = await context.push<bool>('/login');
    if (loggedIn != true || !context.mounted) return;
  }
  await context.push('/report', extra: target);
}

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.target});

  final ReportTarget target;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productName = TextEditingController();
  final _purchaseLocation = TextEditingController();
  final _description = TextEditingController();

  late String? _country = () {
    final accountCountry = ref.read(authControllerProvider).value?.country;
    return reportCountries.contains(accountCountry) ? accountCountry : null;
  }();
  ReportPhoto? _photo;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _productName.dispose();
    _purchaseLocation.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    // Downscaled on pick: plenty for evidence, and quick to upload.
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 70);
    } catch (_) {
      // Typically camera/photo access denied.
      setState(() => _error = "Couldn't open the ${source == ImageSource.camera ? 'camera' : 'photo library'}. "
          'Check that Hakikisha is allowed to use it in Settings.');
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length >= maxReportPhotoBytes) {
      setState(() => _error = 'That photo is too large. Please try another one.');
      return;
    }
    setState(() {
      _photo = ReportPhoto(bytes, contentType: file?.mimeType ?? 'image/jpeg');
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    // A report must name its product: by scan, or by name. Reports opened
    // from a medicine's page have no scan, so they're named after it.
    final typedName = _productName.text.trim();
    final productName = typedName.isNotEmpty
        ? typedName
        : (widget.target.scanId == null ? widget.target.medicineName : null);
    final purchaseLocation = _purchaseLocation.text.trim();
    try {
      await ref.read(reportRepositoryProvider).submit(
            scanId: widget.target.scanId,
            productName: productName,
            medicineName: widget.target.medicineName,
            description: _description.text.trim(),
            country: _country!,
            purchaseLocation: purchaseLocation.isEmpty ? null : purchaseLocation,
            photo: _photo,
          );
      if (!mounted) return;
      setState(() => _submitting = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: HakikishaColors.green, size: 40),
          title: const Text('Report sent'),
          content: Text(
            "Thank you. We've filed your report, and our team will pass it to the medicines regulator in $_country. "
            "Don't use the product in the meantime.",
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))],
        ),
      );
      if (mounted) context.pop();
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final medicineName = widget.target.medicineName;

    return Scaffold(
      appBar: AppBar(title: const Text('Report a suspicious medicine')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Reports go to the national medicines regulator. Tell us what you noticed.',
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              if (medicineName != null)
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Product'),
                  child: Text(medicineName, style: textTheme.bodyLarge),
                )
              else
                TextFormField(
                  controller: _productName,
                  decoration: const InputDecoration(
                    labelText: 'Product name',
                    hintText: 'As printed on the package',
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Please tell us which product this is about.' : null,
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _country,
                decoration: const InputDecoration(labelText: 'Country where you found it'),
                items: [for (final c in reportCountries) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (value) => setState(() => _country = value),
                validator: (v) => v == null ? 'Please select a country.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purchaseLocation,
                decoration: const InputDecoration(
                  labelText: 'Where you bought it (optional)',
                  hintText: 'Pharmacy, market or seller, and area',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'What made you suspicious?',
                  hintText: 'e.g. misspelt label, broken seal, tablets look different',
                  alignLabelWithHint: true,
                ),
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please describe what made you suspicious.' : null,
              ),
              const SizedBox(height: 24),
              Text('Photo (optional)', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              if (_photo != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_photo!.bytes, height: 200, width: double.infinity, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        tooltip: 'Remove photo',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _photo = null),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Take photo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choose photo'),
                      ),
                    ),
                  ],
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Send report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
