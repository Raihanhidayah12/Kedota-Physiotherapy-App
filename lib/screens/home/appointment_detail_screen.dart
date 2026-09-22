import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_language.dart';
import '../../utils/app_snackbar.dart';
import '../home/history_screen.dart';
import 'reschedule_appointment_screen.dart';
import 'settle_payment_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c100 = Color(0xFFD4F5F3);
const _bg = Color(0xFFF5F8F8);
const _ink = Color(0xFF0E2C2F);
const _ink2 = Color(0xFF3D6065);
const _ink3 = Color(0xFF8AA8AC);
const _red = Color(0xFFD94F45);
const _redBg = Color(0xFFFFECEB);
const _clinicAddress =
    'Blok Kelapa No.29, Tunggulwulung, Kec. Lowokwaru, Kota Malang, Jawa Timur 65143';
const _clinicMapUrl = 'https://maps.app.goo.gl/6RoeDr21WjTfMjo86';
const _customerServicePhone = '6281645460939';

class AppointmentDetailScreen extends StatefulWidget {
  final AppointmentItem item;
  const AppointmentDetailScreen({super.key, required this.item});

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  String? _rescheduledDate;
  String? _rescheduledTime;

  String get _displayDate => _rescheduledDate ?? widget.item.date;
  String get _formattedDisplayDate => _formatAppointmentDate(_displayDate);
  String get _displayTime => _rescheduledTime ?? widget.item.time;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  AppointmentStatus get _status => widget.item.status;
  bool get _isMendatang => _status == AppointmentStatus.mendatang;
  bool get _isSelesai => _status == AppointmentStatus.selesai;
  bool get _isBatasWaktu => _status == AppointmentStatus.batasWaktu;
  bool get _isClinic => widget.item.serviceType.toLowerCase() == 'klinik';
  bool get _isDepositForfeited =>
      _isBatasWaktu &&
      widget.item.paymentPlan == 'deposit' &&
      widget.item.paymentStatus != 'paid';

  // Deposit juga dianggap hangus kalau scheduled time sudah lewat 15 menit
  // meskipun status DB belum terupdate ke 'expired' (race condition)
  bool get _isLocallyExpired {
    final scheduled = _scheduledDateTime;
    if (scheduled == null) return false;
    return !scheduled.add(const Duration(minutes: 15)).isAfter(DateTime.now());
  }

  bool get _isEffectivelyDepositForfeited =>
      _isDepositForfeited ||
      (_isLocallyExpired &&
          widget.item.paymentPlan == 'deposit' &&
          widget.item.paymentStatus != 'paid');

  bool get _hasOutstandingPayment =>
      !_isEffectivelyDepositForfeited &&
      widget.item.amountDue > 0 &&
      (widget.item.paymentStatus != 'paid' ||
          widget.item.paymentPlan == 'deposit');
  DateTime? get _scheduledDateTime {
    final date = DateTime.tryParse(_displayDate);
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(_displayTime);
    if (date == null || match == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
  }

  bool get _canReschedule {
    final scheduled = _scheduledDateTime;
    if (scheduled == null) return false;
    final now = DateTime.now();
    if (_isBatasWaktu && widget.item.paymentStatus == 'paid') {
      final elapsed = now.difference(scheduled);
      return elapsed >= Duration.zero && elapsed <= const Duration(hours: 24);
    }
    return scheduled.difference(now) >= const Duration(hours: 24);
  }

  bool get _isPaidNoShow =>
      _isBatasWaktu && widget.item.paymentStatus == 'paid';

  bool get _noShowRescheduleExpired {
    final scheduled = _scheduledDateTime;
    return _isPaidNoShow &&
        scheduled != null &&
        DateTime.now().isAfter(scheduled.add(const Duration(hours: 24)));
  }

  String get _displayAddress => _isClinic
      ? _clinicAddress
      : widget.item.address.isEmpty
      ? t(context, 'patientAddress')
      : widget.item.address;

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          t(context, 'historyDetailTitle'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Banner batas waktu ───────────────────────────────
                if (_isBatasWaktu && !_isEffectivelyDepositForfeited) ...[
                  _buildExpiredBanner(),
                  const SizedBox(height: 20),
                ],
                _sectionLabel(t(context, 'patientData')),
                const SizedBox(height: 12),
                _buildPatientCard(),
                const SizedBox(height: 24),
                _sectionLabel(t(context, 'detailSection')),
                const SizedBox(height: 12),
                _buildDetailCard(),
                if (_isSelesai) ...[
                  const SizedBox(height: 12),
                  _buildRecommendationBanner(),
                ],
                if (_isMendatang && widget.item.paymentPlan == 'deposit') ...[
                  const SizedBox(height: 12),
                  _buildDepositRescheduleNotice(),
                ],
                if (_isEffectivelyDepositForfeited) ...[
                  const SizedBox(height: 12),
                  _buildDepositForfeitedNotice(),
                ],
                if (_isPaidNoShow) ...[
                  const SizedBox(height: 12),
                  _buildNoShowRescheduleNotice(),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Expired banner ────────────────────────────────────────────────────────
  Widget _buildExpiredBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _redBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _red.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.warning_amber_rounded, color: _red, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(context, 'expiredAppointmentTitle'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _red,
                ),
              ),
              SizedBox(height: 3),
              Text(
                t(context, 'expiredAppointmentBody'),
                style: TextStyle(fontSize: 11, color: _red, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildDepositForfeitedNotice() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: _redBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _red.withValues(alpha: 0.16)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _red.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lightbulb_outline_rounded,
            color: _red,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            t(context, 'depositForfeitedBody'),
            style: const TextStyle(
              color: _ink2,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildDepositRescheduleNotice() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5E3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFDFA8)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x120E2C2F),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: Color(0xFFF0A62B),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lightbulb_outline_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            t(context, 'rescheduleDepositNotice'),
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildNoShowRescheduleNotice() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5E3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFDFA8)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: Color(0xFFF0A62B),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lightbulb_outline_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            t(
              context,
              _noShowRescheduleExpired
                  ? 'noShowRescheduleExpiredNotice'
                  : 'noShowRescheduleNotice',
            ),
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: _ink,
    ),
  );

  // ── Patient card ──────────────────────────────────────────────────────────
  Widget _buildPatientCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // avatar + name + badge
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _patientAvatar(52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.patientName.isEmpty
                        ? t(context, 'patientName')
                        : widget.item.patientName,
                    style: const TextStyle(
                      color: _c700,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.item.displayBookingCode),
                      );
                      showAppSnackBar(
                        context,
                        t(context, 'bookingCodeCopied'),
                        type: AppSnackBarType.success,
                        icon: Icons.copy_rounded,
                      );
                    },
                    child: Text(
                      widget.item.displayBookingCode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _statusBadge(),
          ],
        ),
        if (!_isSelesai) const SizedBox(height: 8),
        const Divider(height: 1, color: Color(0xFFF0F5F5)),
        const SizedBox(height: 14),

        // date + time (selesai: simpel tanpa alamat & keluhan)
        if (_isSelesai) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoChip(Icons.calendar_month_outlined, _formattedDisplayDate),
              _infoChip(Icons.access_time_rounded, _displayTime),
            ],
          ),
        ] else ...[
          // booking type
          if (!_isSelesai) ...[
            Row(
              children: [
                const Icon(Icons.sell_outlined, size: 16, color: _c500),
                const SizedBox(width: 8),
                Text(
                  widget.item.bookedForOther
                      ? t(context, 'reservationForOther')
                      : t(context, 'reservationForSelf'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: _ink2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: _c500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _displayAddress,
                  style: const TextStyle(fontSize: 12, color: _ink2),
                ),
              ),
            ],
          ),
          if (_isClinic) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openClinicMap,
              child: Row(
                children: [
                  const Icon(
                    Icons.location_searching_rounded,
                    size: 16,
                    color: _c500,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t(context, 'openClinicMap'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: _c700,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: _c700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // date + time + sesi
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _infoChip(Icons.calendar_month_outlined, _formattedDisplayDate),
              _infoChip(
                Icons.access_time_rounded,
                _displayTime.replaceAll(' WIB', ''),
                suffix: t(context, 'wib'),
              ),
              _infoChip(
                Icons.repeat_rounded,
                '${widget.item.sessionCount} ${t(context, 'sessionUnit')}',
              ),
            ],
          ),
          if (_isMendatang) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openCalendar,
                icon: const Icon(Icons.event_available_rounded, size: 17),
                label: Text(t(context, 'addToCalendar')),
                style: TextButton.styleFrom(
                  foregroundColor: _c700,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0F5F5)),
          const SizedBox(height: 14),

          if (_hasOutstandingPayment) ...[
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined, size: 16, color: _c500),
                const SizedBox(width: 8),
                Text(
                  '${t(context, 'remainingPayment')} : ',
                  style: const TextStyle(fontSize: 12, color: _ink2),
                ),
                Text(
                  _formatRupiah(widget.item.amountDue),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Keluhan
          _rowLabel(Icons.description_outlined, t(context, 'patientComplaint')),
          const SizedBox(height: 10),
          _complaintBox(
            widget.item.complaint.isEmpty
                ? t(context, 'patientComplaintBody')
                : widget.item.complaint,
          ),
        ],
      ],
    ),
  );

  Future<void> _openClinicMap() async {
    final opened = await launchUrl(
      Uri.parse(_clinicMapUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened || !mounted) return;
  }

  Future<void> _openCalendar() async {
    final dateTime = DateTime.tryParse(
      '${_displayDate.trim()} ${_displayTime.replaceAll(' WIB', '').trim()}',
    );
    if (dateTime == null) {
      if (mounted) {
        _showCalendarMessage(
          t(context, 'calendarDateInvalid'),
          icon: Icons.error_outline_rounded,
          color: _red,
        );
      }
      return;
    }

    final addedMessage = t(context, 'calendarAdded');
    final eventTitle =
        '${t(context, 'therapyAppointmentCalendarTitle')} - ${widget.item.serviceType}';
    final eventDetails = widget.item.complaint.isEmpty
        ? t(context, 'calendarAppointmentDetails')
        : widget.item.complaint;
    final eventLocation = _displayAddress;
    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'android.intent.action.INSERT',
        data: 'content://com.android.calendar/events',
        arguments: {
          'title': eventTitle,
          'description': eventDetails,
          'eventLocation': eventLocation,
          'beginTime': dateTime.millisecondsSinceEpoch,
          'endTime': dateTime
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          'eventTimezone': 'Asia/Jakarta',
          'hasAlarm': 1,
        },
      );
      await intent.launch();
    } else {
      final end = dateTime.add(const Duration(hours: 1));
      final calendarUri = Uri.https('calendar.google.com', '/calendar/render', {
        'action': 'TEMPLATE',
        'text': eventTitle,
        'dates': '${_calendarDate(dateTime)}/${_calendarDate(end)}',
        'ctz': 'Asia/Jakarta',
        'details': eventDetails,
        'location': eventLocation,
        'reminders': 'on',
        'reminder_method': 'popup',
        'reminder_minutes': '60',
      });
      await launchUrl(calendarUri, mode: LaunchMode.externalApplication);
    }
    if (mounted) {
      _showCalendarMessage(
        addedMessage,
        icon: Icons.event_available_rounded,
        color: _c700,
      );
    }
  }

  void _showCalendarMessage(
    String message, {
    required IconData icon,
    required Color color,
  }) {
    showAppSnackBar(
      context,
      message,
      type: color == _c700 ? AppSnackBarType.success : AppSnackBarType.info,
      icon: icon,
      duration: const Duration(seconds: 4),
    );
  }

  String _calendarDate(DateTime dateTime) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${dateTime.year}${twoDigits(dateTime.month)}${twoDigits(dateTime.day)}'
        'T${twoDigits(dateTime.hour)}${twoDigits(dateTime.minute)}${twoDigits(dateTime.second)}';
  }

  String _formatAppointmentDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;
    final isEnglish = AppLanguageScope.current(context) == AppLanguage.en;
    final weekdays = isEnglish
        ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final months = isEnglish
        ? const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ]
        : const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'Mei',
            'Jun',
            'Jul',
            'Agu',
            'Sep',
            'Okt',
            'Nov',
            'Des',
          ];
    return '${weekdays[parsed.weekday - 1]}, '
        '${parsed.day.toString().padLeft(2, '0')} '
        '${months[parsed.month - 1]} ${parsed.year}';
  }

  // ── Detail card ───────────────────────────────────────────────────────────
  Widget _buildDetailCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // therapist header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.therapistName,
                    style: const TextStyle(
                      color: _c700,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.therapistSipf?.isNotEmpty == true
                        ? widget.item.therapistSipf!
                        : t(context, 'therapistLicense'),
                    style: const TextStyle(fontSize: 11, color: _ink3),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _c100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.item.serviceType,
                style: const TextStyle(
                  color: _c700,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFF0F5F5)),
        const SizedBox(height: 16),

        if (widget.item.clinicName.isNotEmpty) ...[
          _rowLabel(
            Icons.location_city_outlined,
            t(context, 'reservationClinic'),
          ),
          const SizedBox(height: 8),
          Text(
            widget.item.clinicName,
            style: const TextStyle(color: _ink2, fontSize: 12),
          ),
          const SizedBox(height: 16),
        ],

        // ── Catatan Klinis ───────────────────────────────────────
        _rowLabel(
          Icons.description_outlined,
          t(context, 'clinicalNotesAfterSession'),
        ),
        const SizedBox(height: 10),
        if (_isMendatang)
          _placeholderChip(t(context, 'notesAfterTherapistInput')),
        if (_isSelesai)
          _clinicalNoteBox(
            widget.item.clinicalNote?.isNotEmpty == true
                ? widget.item.clinicalNote!
                : t(context, 'clinicalNoteCompleted'),
          ),
        if (_isBatasWaktu)
          _textBox(
            t(context, 'clinicalNoteExpired'),
            minHeight: 80,
            isWarning: true,
          ),
        if (_isMendatang) ...[
          const SizedBox(height: 16),
          _rowLabel(
            Icons.show_chart_rounded,
            t(context, 'progressMonitoringIndicator'),
          ),
          const SizedBox(height: 10),
          _placeholderChip(t(context, 'progressAfterTherapistInput')),
        ] else ...[
          const SizedBox(height: 16),
          _buildAssessmentSection(),
        ],
      ],
    ),
  );

  Widget _buildAssessmentSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: _rowLabel(
              Icons.show_chart_rounded,
              t(context, 'progressMonitoringIndicator'),
            ),
          ),
          if (_isSelesai)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _c100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.radio_button_checked_rounded, size: 12, color: _c700),
                  const SizedBox(width: 4),
                  Text(
                    '${t(context, 'sessionUnit')} ${widget.item.sessionCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _c700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      if (_isBatasWaktu)
        _placeholderChip(
          t(context, 'notesAfterTherapistInput'),
        ),
      if (_isSelesai) _buildScoreGrid(),
    ],
  );

  // ── Score grid 2×2 ───────────────────────────────────────────────────────
  Widget _buildScoreGrid() {
    final vas = widget.item.vasScore;
    final rom = widget.item.romScore;
    final mmt = widget.item.mmtScore;
    final odi = widget.item.odiScore;

    // If all scores are null, show a placeholder instead of an empty grid
    if (vas == null && rom == null && mmt == null && odi == null) {
      return _placeholderChip(t(context, 'notesAfterTherapistInput'));
    }

    // VAS: lower is better (pain reduced)
    // ROM: higher is better (range of motion improved)
    // MMT: higher is better (muscle strength improved)
    // ODI: lower is better (disability index reduced)

    String vasTrend() {
      if (vas == null) return '–';
      final pct = ((10 - vas) / 10.0 * 100).round();
      return _improving('$pct%');
    }

    String romTrend() {
      if (rom == null) return '–';
      final pct = (rom / 120.0 * 100).toStringAsFixed(2);
      return _improving('$pct%');
    }

    String mmtTrend() {
      if (mmt == null) return '–';
      final pct = (mmt / 5.0 * 100).round();
      return _improving('$pct%');
    }

    String odiTrend() {
      if (odi == null) return '–';
      final pct = ((50 - odi) / 50.0 * 100).round();
      return _improving('$pct%');
    }

    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0EAEA)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _scoreCell(
                  label: t(context, 'painScale'),
                  trend: vasTrend(),
                  trendUp: vas != null ? vas <= 5 : true,
                ),
              ),
              Container(width: 1, color: const Color(0xFFE0EAEA)),
              Expanded(
                child: _scoreCell(
                  label: t(context, 'romLabel'),
                  trend: romTrend(),
                  trendUp: true,
                  hasInfo: true,
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFE0EAEA)),
          Row(
            children: [
              Expanded(
                child: _scoreCell(
                  label: t(context, 'muscleStrength'),
                  trend: mmtTrend(),
                  trendUp: true,
                ),
              ),
              Container(width: 1, color: const Color(0xFFE0EAEA)),
              Expanded(
                child: _scoreCell(
                  label: t(context, 'odiLabel'),
                  trend: odiTrend(),
                  trendUp: odi != null ? odi <= 25 : false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreCell({
    required String label,
    required String trend,
    required bool trendUp,
    bool hasInfo = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: _ink3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (hasInfo)
              const Icon(Icons.crop_square_rounded, size: 14, color: _ink3),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 14,
              color: trendUp ? _c500 : const Color(0xFFD4920A),
            ),
            const SizedBox(width: 5),
            Text(
              trend,
              style: TextStyle(
                fontSize: 11,
                color: trendUp ? _c500 : const Color(0xFFD4920A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  String _improving(String percent) =>
      t(context, 'improvingPercent').replaceFirst('%s', percent);

  // ── Recommendation banner ─────────────────────────────────────────────────
  Widget _buildRecommendationBanner() {
    final rec = widget.item.therapistRecommendation;
    if (rec == null || rec.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFDC82)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFCC34).withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Color(0xFFD4920A),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '"$rec"',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF7A5800),
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────
  Widget? _buildBottomBar() {
    if (_isMendatang) {
      return SizedBox(
        height: 76,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: _bottomBtn(
                    label: t(context, 'upcomingAppointmentButton'),
                    color: _canReschedule ? _c500 : _ink3,
                    onTap: _canReschedule
                        ? _openReschedule
                        : () => _showRescheduleUnavailable(),
                  ),
                ),
                if (_hasOutstandingPayment) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _bottomBtn(
                      label: t(context, 'settlePayment'),
                      color: _c700,
                      onTap: _openPayment,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    if (_isBatasWaktu) {
      if (_isEffectivelyDepositForfeited) return null;
      return SizedBox(
        height: 76,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                if (_canReschedule)
                  Expanded(
                    child: _bottomBtn(
                      label: t(context, 'rescheduleAppointmentButton'),
                      color: _c500,
                      onTap: _openReschedule,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: _bottomBtn(
                    label: t(context, 'contactCustomerService'),
                    color: const Color(0xFF5B5FC8),
                    onTap: _contactCustomerService,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // selesai → tidak ada bottom bar
    return null;
  }

  Future<void> _openReschedule() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RescheduleAppointmentScreen(appointment: widget.item),
      ),
    );
    if (!mounted || updated != true) return;
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _showRescheduleUnavailable() {
    showAppSnackBar(
      context,
      t(context, 'reschedule24HourError'),
      type: AppSnackBarType.warning,
    );
  }

  Future<void> _contactCustomerService() async {
    final message = Uri.encodeComponent(
      t(context, 'customerServiceWhatsAppMessage')
          .replaceFirst('{bookingCode}', widget.item.displayBookingCode)
          .replaceFirst('{date}', widget.item.date)
          .replaceFirst('{time}', widget.item.time),
    );
    final uri = Uri.parse('https://wa.me/$_customerServicePhone?text=$message');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (mounted) {
      showAppSnackBar(
        context,
        t(context, 'whatsappOpenFailed'),
        type: AppSnackBarType.error,
      );
    }
  }

  Widget _bottomBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: _ink.withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );

  Widget _avatar(double size) {
    final photoUrl = widget.item.therapistPhotoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _avatarPlaceholder(size),
        ),
      );
    }
    return _avatarPlaceholder(size);
  }

  Widget _patientAvatar(double size) {
    final photoUrl = widget.item.profilePhotoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => _avatarPlaceholder(size),
        ),
      );
    }
    return _avatarPlaceholder(size);
  }

  Widget _avatarPlaceholder(double size) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFE8EFEF),
    ),
    child: const Icon(Icons.person_rounded, color: _ink3, size: 26),
  );

  Widget _rowLabel(IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 16, color: _c500),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
      ),
    ],
  );

  Widget _textBox(
    String text, {
    bool placeholder = false,
    bool isWarning = false,
    double minHeight = 0,
  }) => Container(
    width: double.infinity,
    constraints: BoxConstraints(minHeight: minHeight),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isWarning ? _redBg : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isWarning
            ? _red.withValues(alpha: 0.25)
            : const Color(0xFFE0EAEA),
      ),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: isWarning ? _red : (placeholder ? _ink3 : _ink2),
        fontStyle: placeholder ? FontStyle.italic : FontStyle.normal,
        height: 1.6,
      ),
      textAlign: TextAlign.justify,
    ),
  );

  /// Keluhan card — terpotong 2 baris, tap buka modal full text.
  Widget _complaintBox(String text) {
    return GestureDetector(
      onTap: () => _showComplaintSheet(text),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0EAEA)),
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: _ink2,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  /// Catatan Klinis — terpotong 2 baris, tap buka modal full text.
  Widget _clinicalNoteBox(String text) {
    return GestureDetector(
      onTap: () => _showClinicalNoteSheet(text),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0EAEA)),
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: _ink2,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  void _showClinicalNoteSheet(String text) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 18, color: _c500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t(context, 'clinicalNotesAfterSession'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded, color: _ink3, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF0F5F5)),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.40,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _ink2,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComplaintSheet(String text) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 18, color: _c500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t(context, 'patientComplaint'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded, color: _ink3, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF0F5F5)),
              const SizedBox(height: 14),
              // Teks keluhan — scrollable kalau sangat panjang
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _ink2,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderChip(String text, {bool isWarning = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: isWarning ? _redBg : const Color(0xFFF0F5F5),
      borderRadius: BorderRadius.circular(12),
      border: isWarning
          ? Border.all(color: _red.withValues(alpha: 0.25))
          : null,
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: isWarning ? _red : _ink3,
        fontStyle: FontStyle.italic,
      ),
    ),
  );

  Widget _infoChip(IconData icon, String text, {String? suffix}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: _c500),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
      if (suffix != null) ...[
        const SizedBox(width: 2),
        Text(suffix, style: const TextStyle(fontSize: 10, color: _ink3)),
      ],
    ],
  );

  Widget _statusBadge() {
    if (_isEffectivelyDepositForfeited) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _redBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          t(context, 'depositForfeitedTitle'),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _red,
          ),
        ),
      );
    }
    if (_hasOutstandingPayment) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _redBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          t(context, 'paymentPending'),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _red,
          ),
        ),
      );
    }
    final (labelKey, bg, fg) = switch (_status) {
      AppointmentStatus.mendatang => ('statusUpcoming', _c100, _c700),
      AppointmentStatus.selesai => ('statusDone', _c500, Colors.white),
      AppointmentStatus.batasWaktu => ('statusExpired', _redBg, _red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        t(context, labelKey),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Future<void> _openPayment() async {
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SettlePaymentScreen(appointment: widget.item),
      ),
    );
    if (paid == true && mounted) Navigator.of(context).pop(true);
  }

  String _formatRupiah(int amount) {
    final digits = amount.toString();
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      final start = (end - 3).clamp(0, end);
      groups.insert(0, digits.substring(start, end));
    }
    return 'Rp ${groups.join('.')}';
  }
}
