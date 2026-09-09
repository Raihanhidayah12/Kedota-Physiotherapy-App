import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_language.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../widgets/custom_date_picker.dart';
import 'history_screen.dart';

const _teal = Color(0xFF00A79D);
const _tealDark = Color(0xFF007F78);
const _background = Color(0xFFF5F8F8);
const _ink = Color(0xFF172B2D);
const _muted = Color(0xFF7C8C8E);

class RescheduleAppointmentScreen extends StatefulWidget {
  final AppointmentItem appointment;

  const RescheduleAppointmentScreen({super.key, required this.appointment});

  @override
  State<RescheduleAppointmentScreen> createState() =>
      _RescheduleAppointmentScreenState();
}

class _RescheduleAppointmentScreenState
    extends State<RescheduleAppointmentScreen> {
  final _service = SupabaseAuthService();
  late DateTime _date;
  late TimeOfDay _time;
  Set<String> _bookedTimes = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = DateTime.tryParse(widget.appointment.date) ?? DateTime.now();
    final parts = widget.appointment.time.split(':');
    _time = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    _loadBookedTimes();
  }

  Future<void> _loadBookedTimes() async {
    try {
      final rows = await _service.client
          .from('appointments')
          .select('id, appointment_time')
          .eq('appointment_date', _date.toIso8601String().substring(0, 10))
          .eq('service_type', widget.appointment.serviceType)
          .eq('clinic_name', widget.appointment.clinicName)
          .eq('appointment_status', 'upcoming')
          .neq('id', widget.appointment.id);
      if (!mounted) return;
      setState(() {
        _bookedTimes = (rows as List)
            .map((row) => row['appointment_time']?.toString().substring(0, 5))
            .whereType<String>()
            .toSet();
      });
    } catch (error) {
      debugPrint('Reschedule time availability load failed: $error');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => CustomDatePickerDialog(
        initialDate: _date.isBefore(DateTime.now())
            ? DateTime.now().add(const Duration(days: 1))
            : _date,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        selectableDay: (date) => date.weekday != DateTime.sunday,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _bookedTimes = {};
      });
      _loadBookedTimes();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildTimeSheet(),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Widget _buildTimeSheet() {
    final closingHour = _date.weekday == DateTime.saturday ? 18 : 20;
    final slots = [
      for (var hour = 8; hour < closingHour; hour++)
        TimeOfDay(hour: hour, minute: 0),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DFDE),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              t(context, 'reservationTime'),
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 3.5,
              children: slots.map((slot) {
                final selected = _time.hour == slot.hour;
                final slotDateTime = DateTime(
                  _date.year,
                  _date.month,
                  _date.day,
                  slot.hour,
                );
                final isPast =
                    _date.year == DateTime.now().year &&
                    _date.month == DateTime.now().month &&
                    _date.day == DateTime.now().day &&
                    !slotDateTime.isAfter(DateTime.now());
                final booked = _bookedTimes.contains(
                  '${slot.hour.toString().padLeft(2, '0')}:00',
                );
                final available = !isPast && !booked;
                return InkWell(
                  onTap: available ? () => Navigator.pop(context, slot) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !available
                          ? const Color(0xFFE9EEEE)
                          : selected
                          ? const Color(0xFFDDF5F2)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !available
                            ? const Color(0xFFD5DEDE)
                            : selected
                            ? _teal
                            : const Color(0xFFE3E9E9),
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Text(
                      '${slot.format(context)} WIB',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: !available
                            ? _muted
                            : selected
                            ? _tealDark
                            : _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<bool> _isSlotAvailable() async {
    final serviceType = widget.appointment.serviceType;
    final rows = await _service.client
        .from('appointments')
        .select('id')
        .eq('appointment_date', _date.toIso8601String().substring(0, 10))
        .eq('appointment_time', _formatTime(_time))
        .eq('service_type', serviceType)
        .eq('clinic_name', widget.appointment.clinicName)
        .neq('appointment_status', 'cancelled')
        .neq('id', widget.appointment.id);
    return (rows as List).isEmpty;
  }

  Future<void> _save() async {
    if (_date.weekday == DateTime.sunday) {
      _showMessage(t(context, 'reservationSundayClosed'));
      return;
    }
    setState(() => _saving = true);
    var saved = false;
    try {
      final reminderTitle = t(context, 'appointmentReminderTitle');
      final reminderBodyTemplate = t(context, 'appointmentReminderBody');
      final scheduleUpdatedTitle = t(
        context,
        'notificationScheduleUpdatedTitle',
      );
      final scheduleUpdatedBody = t(context, 'notificationScheduleUpdatedBody');
      final expiredTitle = t(context, 'expiredAppointmentTitle');
      final expiredBody = t(context, 'expiredAppointmentBody');
      if (!await _isSlotAvailable()) {
        if (mounted) _showMessage(t(context, 'reservationTimeUnavailable'));
        return;
      }
      final date = _date.toIso8601String().substring(0, 10);
      final time = _formatTime(_time);
      await _service.client.rpc(
        'reschedule_appointment',
        params: {
          'p_appointment_id': widget.appointment.id,
          'p_appointment_date': date,
          'p_appointment_time': time,
        },
      );
      final prefs = await SharedPreferences.getInstance();
      final expiredNotifications =
          prefs.getStringList('expired_notifications_sent') ?? [];
      expiredNotifications.remove(widget.appointment.id);
      await prefs.setStringList(
        'expired_notifications_sent',
        expiredNotifications,
      );
      try {
        final events = prefs.getStringList('reschedule_notifications') ?? [];
        events.add(
          jsonEncode({
            'appointment_id': widget.appointment.id,
            'booker_id': _service.client.auth.currentUser?.id,
            'service_type': widget.appointment.serviceType,
            'appointment_date': date,
            'appointment_time': time,
            'created_at': DateTime.now().toIso8601String(),
          }),
        );
        await prefs.setStringList(
          'reschedule_notifications',
          events.length > 20 ? events.sublist(events.length - 20) : events,
        );
      } catch (notificationError) {
        debugPrint(
          'Reschedule in-app notification save failed: $notificationError',
        );
      }
      await NotificationService().cancelAppointmentReminder(
        widget.appointment.id,
      );
      await NotificationService().scheduleAppointmentReminder(
        appointmentId: widget.appointment.id,
        date: date,
        time: time,
        title: reminderTitle,
        body: reminderBodyTemplate.replaceFirst('{time}', time),
      );
      await NotificationService().scheduleExpirationNotice(
        appointmentId: widget.appointment.id,
        date: date,
        time: time,
        title: expiredTitle,
        body: expiredBody,
      );
      await NotificationService().showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        title: scheduleUpdatedTitle,
        body: '$scheduleUpdatedBody $date, ${time.substring(0, 5)} WIB',
        payload: 'appointment:${widget.appointment.id}',
      );
      saved = true;
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted && !saved) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ink,
        title: Text(
          t(context, 'rescheduleAppointmentButton'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildIntroHeader(),
          const SizedBox(height: 18),
          _summaryCard(),
          const SizedBox(height: 24),
          Text(
            t(context, 'reservationStageSchedule'),
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _fieldTile(
            icon: Icons.calendar_month_outlined,
            label: t(context, 'reservationDate'),
            value: _formatDate(_date),
            onTap: _pickDate,
            selected: true,
          ),
          const SizedBox(height: 12),
          _fieldTile(
            icon: Icons.access_time_rounded,
            label: t(context, 'reservationTime'),
            value: '${_time.format(context)} WIB',
            onTap: _pickTime,
            selected: true,
          ),
          const SizedBox(height: 14),
          _buildScheduleHint(),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _teal.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      t(context, 'rescheduleSave'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroHeader() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFD4F5F3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.edit_calendar_rounded, color: _tealDark),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t(context, 'rescheduleAppointmentButton'),
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              t(context, 'reservationScheduleHint'),
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _summaryCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE1E9E8)),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFD4F5F3),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.event_note_rounded, color: _tealDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.appointment.serviceType,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.appointment.therapistName,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded, color: _muted),
      ],
    ),
  );

  Widget _buildScheduleHint() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF7F6),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFD4EEEC)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: _tealDark, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            t(context, 'reservationScheduleHint'),
            style: const TextStyle(color: _tealDark, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _fieldTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    bool selected = false,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF2FBFA) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? _teal : const Color(0xFFE1E9E8),
          width: selected ? 1.3 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFD4F5F3) : _background,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: _tealDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
    ),
  );
}
