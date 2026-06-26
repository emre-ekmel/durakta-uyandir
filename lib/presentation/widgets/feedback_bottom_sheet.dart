import 'dart:convert';
import 'dart:io';

import 'package:durakta_uyandir/core/services/feedback_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void showFeedbackBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _FeedbackSheetContent(),
  );
}

class _FeedbackSheetContent extends StatefulWidget {
  const _FeedbackSheetContent();

  @override
  State<_FeedbackSheetContent> createState() => _FeedbackSheetContentState();
}

class _FeedbackSheetContentState extends State<_FeedbackSheetContent> {
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  bool _isSending = false;
  final List<XFile> _selectedImages = [];
  final List<String> _imagesBase64 = [];

  static const int _maxChars = 500;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _selectedCategory != null &&
      _descriptionController.text.trim().isNotEmpty;

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 3) {
      _showSnackBar("settings.feedback_image_limit_error".tr());
      return;
    }

    try {
      // Firestore 1MB limiti için çözünürlük ve kaliteyi oldukça düşürüyoruz
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 40,
        maxWidth: 600,
      );

      if (image != null) {
        // Diskteki dosya boyutunu RAM'e almadan önce kontrol et (OOM Zafiyetini önler)
        final length = await image.length();
        if (length > 200 * 1024) {
             _showSnackBar("settings.feedback_image_size_error".tr());
             return;
        }

        final bytes = await image.readAsBytes();

        setState(() {
          _selectedImages.add(image);
          _imagesBase64.add(base64Encode(bytes));
        });
      }
    } catch (e) {
      _showSnackBar("settings.feedback_image_error".tr());
    }
  }

  Future<void> _sendDirect() async {
    if (!_validate()) return;

    setState(() => _isSending = true);

    try {
      final success = await FeedbackService.sendFeedback(
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        imagesBase64: _imagesBase64.isEmpty ? null : _imagesBase64,
      );

      if (!mounted) return;
      setState(() => _isSending = false);

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("settings.feedback_success".tr()),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showSnackBar("settings.feedback_send_failed".tr());
      }
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      
      if (e.message == 'RATE_LIMIT') {
        _showSnackBar("settings.feedback_rate_limit".tr());
      } else {
         _showSnackBar("settings.feedback_send_failed".tr());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      _showSnackBar("settings.feedback_send_failed".tr());
    }
  }

  Future<void> _openGitHub() async {
    if (!_validate()) return;

    final success = await FeedbackService.openGitHubIssue(
      category: _selectedCategory!,
      description: _descriptionController.text.trim(),
    );

    if (mounted && !success) {
      _showSnackBar("settings.feedback_open_failed".tr());
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  bool _validate() {
    if (_selectedCategory == null) {
      _showSnackBar("settings.feedback_no_category".tr());
      return false;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar("settings.feedback_empty_desc".tr());
      return false;
    }
    return true;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              "settings.feedback_title".tr(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "settings.feedback_category".tr(),
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildCategoryChip(
                  label: "settings.feedback_bug".tr(),
                  value: 'bug',
                  icon: Icons.bug_report_outlined,
                ),
                _buildCategoryChip(
                  label: "settings.feedback_suggestion".tr(),
                  value: 'suggestion',
                  icon: Icons.lightbulb_outline,
                ),
                _buildCategoryChip(
                  label: "settings.feedback_general".tr(),
                  value: 'general',
                  icon: Icons.chat_bubble_outline,
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: _maxChars,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: "settings.feedback_description".tr(),
                hintText: "settings.feedback_description_hint".tr(),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Screenshot Seçici
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedImages.length < 3)
                  OutlinedButton.icon(
                    onPressed: _isSending ? null : _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: Text("settings.feedback_image_add".tr()),
                  ),
                if (_selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_selectedImages.length, (index) {
                      final image = _selectedImages[index];
                      return Container(
                        width: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(image.path),
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _isSending
                                      ? null
                                      : () {
                                          setState(() {
                                            _selectedImages.removeAt(index);
                                            _imagesBase64.removeAt(index);
                                          });
                                        },
                                  child: Container(
                                    margin: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${(File(image.path).lengthSync() / 1024).toStringAsFixed(0)} KB",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSending || !_isValid ? null : _sendDirect,
                icon: _isSending
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
                label: Text(
                  _isSending
                      ? "settings.feedback_sending".tr()
                      : "settings.feedback_send".tr(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton.icon(
                onPressed: _isSending || !_isValid ? null : _openGitHub,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  "settings.feedback_github".tr(),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            if (!FeedbackService.isWebhookAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "settings.feedback_webhook_unavailable".tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _selectedCategory == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? value : null;
        });
      },
    );
  }
}
