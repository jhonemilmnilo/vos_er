// lib/modules/overtime/edit_overtime_sheet.dart
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:vos_er/app_providers.dart";

import "../../data/repositories/overtime_repository.dart";
import "../approvals/overtime/overtime_models.dart";

/// Sheet for editing an existing overtime request
class EditOvertimeSheet extends ConsumerStatefulWidget {
  const EditOvertimeSheet({super.key, required this.overtime});

  final OvertimeApprovalHeader overtime;

  @override
  ConsumerState<EditOvertimeSheet> createState() => _EditOvertimeSheetState();
}

class _EditOvertimeSheetState extends ConsumerState<EditOvertimeSheet> {
  final TextEditingController _purposeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _processing = false;
  String? _error;

  TimeOfDay _otFrom = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _otTo = const TimeOfDay(hour: 21, minute: 0);
  int _durationMinutes = 180;

  @override
  void initState() {
    super.initState();
    _purposeCtrl.text = widget.overtime.purpose;
    _otFrom = widget.overtime.otFrom;
    _otTo = widget.overtime.otTo;
    _durationMinutes = widget.overtime.durationMinutes;
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    super.dispose();
  }

  void _calculateDuration() {
    final fromMinutes = _otFrom.hour * 60 + _otFrom.minute;
    final toMinutes = _otTo.hour * 60 + _otTo.minute;

    // Handle overnight case
    if (toMinutes < fromMinutes) {
      _durationMinutes = (24 * 60 - fromMinutes) + toMinutes;
    } else {
      _durationMinutes = toMinutes - fromMinutes;
    }
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

  Future<void> _selectTime(BuildContext context, bool isFrom) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? _otFrom : _otTo,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              dayPeriodBorderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _otFrom = picked;
        } else {
          _otTo = picked;
        }
        _calculateDuration();
      });
    }
  }

  Future<void> _submitUpdate() async {
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

      await overtimeRepo.updateOvertimeRequest(
        overtimeId: widget.overtime.overtimeId,
        otFrom: _formatTimeOfDay(_otFrom),
        otTo: _formatTimeOfDay(_otTo),
        schedTimeout: _formatTimeOfDay(widget.overtime.schedTimeout),
        durationMinutes: _durationMinutes,
        purpose: _purposeCtrl.text.trim(),
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();

      Navigator.of(context).pop(true); // Return success

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Overtime request updated successfully"),
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
    final durationHours = _durationMinutes ~/ 60;
    final durationMins = _durationMinutes % 60;

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final viewInsets = mediaQuery.viewInsets;

    double getBaseHeight() {
      if (screenHeight < 600) return screenHeight * 0.85;
      if (screenHeight < 800) return screenHeight * 0.75;
      return screenHeight * 0.65;
    }

    // If keyboard is open, take up the full available space above the keyboard
    final double sheetHeight = viewInsets.bottom > 0 ? (screenHeight - viewInsets.bottom) : getBaseHeight();

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        height: sheetHeight,
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
                          "Edit Overtime Request",
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(widget.overtime.requestDate),
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

                      // OT Time Selection
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
                                  "Overtime Hours",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _TimeInput(
                                    label: "From",
                                    time: _otFrom,
                                    onTap: () => _selectTime(context, true),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _TimeInput(
                                    label: "To",
                                    time: _otTo,
                                    onTap: () => _selectTime(context, false),
                                  ),
                                ),
                              ],
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
                          counterStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.5)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Purpose is required";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Submit Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1F2937).withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _processing ? null : _submitUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _processing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            "Update Request",
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class _TimeInput extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeInput({required this.label, required this.time, required this.onTap});

  String _formatTime() {
    final hh = time.hour.toString().padLeft(2, "0");
    final mm = time.minute.toString().padLeft(2, "0");
    return "$hh:$mm";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  _formatTime(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
                ),
              ],
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
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
