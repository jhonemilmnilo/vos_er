// lib/modules/approvals/overtime/overtime_filing_sheet.dart
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:vos_er/app_providers.dart";

import "../../../data/repositories/overtime_repository.dart";

/// Sheet for filing overtime request from attendance
class OvertimeFilingSheet extends ConsumerStatefulWidget {
  const OvertimeFilingSheet({
    super.key,
    required this.userId,
    required this.departmentId,
    required this.requestDate,
    required this.otFrom,
    required this.otTo,
    required this.schedTimeout,
  });

  final int userId;
  final int departmentId;
  final DateTime requestDate;
  final TimeOfDay otFrom; // When OT starts (scheduled end time)
  final TimeOfDay otTo; // When user actually timed out
  final TimeOfDay schedTimeout; // Scheduled timeout

  @override
  ConsumerState<OvertimeFilingSheet> createState() => _OvertimeFilingSheetState();
}

class _OvertimeFilingSheetState extends ConsumerState<OvertimeFilingSheet> {
  final TextEditingController _purposeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _purposeCtrl.dispose();
    super.dispose();
  }

  int _calculateDurationMinutes() {
    final fromMinutes = widget.otFrom.hour * 60 + widget.otFrom.minute;
    final toMinutes = widget.otTo.hour * 60 + widget.otTo.minute;

    // Handle overnight case
    if (toMinutes < fromMinutes) {
      return (24 * 60 - fromMinutes) + toMinutes;
    }
    return toMinutes - fromMinutes;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, "0");
    final mm = time.minute.toString().padLeft(2, "0");
    return "$hh:$mm:00";
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, "0");
    final m = date.month.toString().padLeft(2, "0");
    final d = date.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  Future<void> _submitOvertimeRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_processing) return;

    HapticFeedback.selectionClick();

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final overtimeRepo = OvertimeRepository(api);

      final durationMinutes = _calculateDurationMinutes();
      final nowIso = DateTime.now().toUtc().toIso8601String();

      await overtimeRepo.fileOvertimeRequest(
        userId: widget.userId,
        departmentId: widget.departmentId,
        requestDate: _formatDate(widget.requestDate),
        filedAt: nowIso,
        otFrom: _formatTimeOfDay(widget.otFrom),
        otTo: _formatTimeOfDay(widget.otTo),
        schedTimeout: _formatTimeOfDay(widget.schedTimeout),
        durationMinutes: durationMinutes,
        purpose: _purposeCtrl.text.trim(),
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();

      Navigator.of(context).pop(true); // Return success

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Overtime request filed successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _processing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final durationMinutes = _calculateDurationMinutes();
    final durationHours = durationMinutes ~/ 60;
    final durationMins = durationMinutes % 60;

    double getSheetHeight() {
      final screenHeight = MediaQuery.of(context).size.height;
      if (screenHeight < 600) return screenHeight * 0.85;
      if (screenHeight < 800) return screenHeight * 0.75;
      return screenHeight * 0.65;
    }

    return SizedBox(
      height: getSheetHeight(),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "File Overtime Request",
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(widget.requestDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.surfaceContainerHighest.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 32, thickness: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: cs.onErrorContainer, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // OT Details Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, color: cs.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Overtime Details",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _InfoRow(
                              label: "OT Start",
                              value: _formatTimeOfDay(widget.otFrom).substring(0, 5),
                              icon: Icons.play_arrow_rounded,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              label: "OT End",
                              value: _formatTimeOfDay(widget.otTo).substring(0, 5),
                              icon: Icons.stop_rounded,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              label: "Duration",
                              value: "${durationHours}h ${durationMins}m",
                              icon: Icons.timer_rounded,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Purpose Input
                      Text(
                        "Purpose",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _purposeCtrl,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: "Enter the reason for overtime...",
                          hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6)),
                          filled: true,
                          fillColor: cs.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outline.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.primary, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.error),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Please enter the purpose of overtime";
                          }
                          if (value.trim().length < 10) {
                            return "Purpose must be at least 10 characters";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Info Note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: cs.secondary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Your overtime request will be submitted for approval. You will be notified once it's reviewed.",
                                style: TextStyle(
                                  color: cs.onSecondaryContainer,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _processing ? null : _submitOvertimeRequest,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: _processing
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _processing ? "Submitting..." : "Submit Overtime Request",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(color: cs.onSurface, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
