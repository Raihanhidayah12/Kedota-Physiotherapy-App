import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import 'appointment_detail_screen.dart';
import 'reservation_flow_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c100 = Color(0xFFD4F5F3);
const _bg = Color(0xFFF5F8F8);
const _ink = Color(0xFF0E2C2F);
const _ink3 = Color(0xFF8AA8AC);

// ─── Dummy data ───────────────────────────────────────────────────────────────

enum AppointmentStatus { mendatang, selesai, batasWaktu }

String appointmentBookingCode(String appointmentId) {
  final normalizedId = appointmentId.replaceAll('-', '').toUpperCase();
  if (normalizedId.isEmpty) return 'KDT-2026000000';
  final codePart = normalizedId.length > 8
      ? normalizedId.substring(0, 8)
      : normalizedId.padRight(8, '0');
  return 'KDT-2026$codePart';
}

class AppointmentItem {
  final String id;
  final String therapistName;
  final String serviceType;
  final String date;
  final String time;
  final String patientName;
  final String medicalCode;
  final String address;
  final String complaint;
  final String clinicName;
  final int sessionCount;
  final String paymentStatus;
  final String paymentPlan;
  final int amountDue;
  final String bookingCode;
  final AppointmentStatus status;

  const AppointmentItem({
    this.id = '',
    required this.therapistName,
    required this.serviceType,
    required this.date,
    required this.time,
    this.patientName = '',
    this.medicalCode = '',
    this.address = '',
    this.complaint = '',
    this.clinicName = '',
    this.sessionCount = 1,
    this.paymentStatus = 'paid',
    this.paymentPlan = 'full',
    this.amountDue = 0,
    this.bookingCode = '',
    required this.status,
  });

  String get displayBookingCode =>
      bookingCode.isEmpty ? appointmentBookingCode(id) : bookingCode;
}

// ─── Body widget ──────────────────────────────────────────────────────────────

class HistoryBody extends StatefulWidget {
  final int initialFilterIndex;

  const HistoryBody({super.key, this.initialFilterIndex = 0});

  @override
  State<HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<HistoryBody>
    with TickerProviderStateMixin {
  int _filterIndex = 0;
  List<AppointmentItem> _savedAppointments = [];
  List<AppointmentItem> _savedUpcomingAppointments = [];
  bool _loadingAppointments = false;

  // ── animation controllers ─────────────────────────────────────────────────
  late AnimationController _headerCtrl;
  late AnimationController _contentCtrl;

  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _btnFade;
  late Animation<Offset> _btnSlide;
  late Animation<double> _chipsFade;
  late Animation<Offset> _chipsSlide;

  static const _kContent = 8;
  late List<Animation<double>> _contentFades;
  late List<Animation<Offset>> _contentSlides;

  @override
  void initState() {
    super.initState();
    _filterIndex = widget.initialFilterIndex;
    _setupAnimations();
    _loadAppointments();
    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  Future<void> _loadAppointments() async {
    if (mounted) setState(() => _loadingAppointments = true);
    try {
      final service = SupabaseAuthService();
      final user = service.client.auth.currentUser;
      if (user == null) return;
      await service.expireOverdueAppointments();
      final rows = await service.client
          .from('appointments')
          .select()
          .eq('booker_id', user.id)
          .order('appointment_date', ascending: false);
      final appointments = (rows as List)
          .map((row) => _appointmentFromRow(row as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _savedAppointments = appointments;
        _savedUpcomingAppointments = appointments
            .where((item) => item.status == AppointmentStatus.mendatang)
            .toList();
      });
    } catch (error) {
      debugPrint('History appointments load failed: $error');
    } finally {
      if (mounted) setState(() => _loadingAppointments = false);
    }
  }

  AppointmentItem _appointmentFromRow(Map<String, dynamic> row) {
    final rawStatus = row['appointment_status']?.toString();
    final appointmentDate = row['appointment_date']?.toString() ?? '';
    final appointmentTime = row['appointment_time']?.toString() ?? '';
    final scheduledAt = DateTime.tryParse('$appointmentDate $appointmentTime');
    final locallyExpired =
        scheduledAt != null &&
        !scheduledAt.add(const Duration(minutes: 15)).isAfter(DateTime.now());
    final status = switch (rawStatus) {
      'completed' => AppointmentStatus.selesai,
      'cancelled' => AppointmentStatus.batasWaktu,
      'expired'
          when scheduledAt != null && scheduledAt.isAfter(DateTime.now()) =>
        AppointmentStatus.mendatang,
      'expired' => AppointmentStatus.batasWaktu,
      _ when locallyExpired => AppointmentStatus.batasWaktu,
      _ => AppointmentStatus.mendatang,
    };
    return AppointmentItem(
      id: row['id']?.toString() ?? '',
      therapistName: row['therapist_name']?.toString() ?? 'Kedota Therapist',
      serviceType: row['service_type']?.toString() ?? 'Home Care',
      date: row['appointment_date']?.toString() ?? '-',
      time: row['appointment_time']?.toString() ?? '- WIB',
      patientName: row['patient_full_name']?.toString() ?? '',
      medicalCode: row['patient_medical_code']?.toString() ?? '',
      address: row['address']?.toString() ?? '',
      complaint: row['patient_complaint']?.toString() ?? '',
      clinicName: row['clinic_name']?.toString() ?? '',
      sessionCount: int.tryParse(row['session_count']?.toString() ?? '') ?? 1,
      paymentStatus: row['payment_status']?.toString() ?? 'paid',
      paymentPlan: row['payment_plan']?.toString() ?? 'full',
      amountDue: int.tryParse(row['amount_due']?.toString() ?? '') ?? 0,
      bookingCode: row['booking_code']?.toString() ?? '',
      status: status,
    );
  }

  void _setupAnimations() {
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _titleFade = CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(-0.2, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
          ),
        );

    _btnFade = CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.1, 0.65, curve: Curves.easeOut),
    );
    _btnSlide = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerCtrl,
            curve: const Interval(0.1, 0.65, curve: Curves.easeOutCubic),
          ),
        );

    _chipsFade = CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _chipsSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerCtrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _contentFades = List.generate(_kContent, (i) {
      final s = (i * 0.13).clamp(0.0, 1.0);
      final e = (s + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _contentCtrl,
        curve: Interval(s, e, curve: Curves.easeOut),
      );
    });
    _contentSlides = List.generate(_kContent, (i) {
      final s = (i * 0.13).clamp(0.0, 1.0);
      final e = (s + 0.35).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _contentCtrl,
          curve: Interval(s, e, curve: Curves.easeOutCubic),
        ),
      );
    });
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HistoryBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _headerCtrl.reset();
    _contentCtrl.reset();
    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  Widget _anim(int index, Widget child) => FadeTransition(
    opacity: _contentFades[index],
    child: SlideTransition(position: _contentSlides[index], child: child),
  );

  bool get _showUpcoming => _filterIndex == 0 || _filterIndex == 1;
  bool get _showPreviousHistory => _filterIndex != 1;

  List<AppointmentItem> get _filteredHistory {
    final history = _savedAppointments;
    if (_filterIndex == 0) {
      return history
          .where((e) => e.status != AppointmentStatus.mendatang)
          .toList();
    }
    if (_filterIndex == 1) {
      return history
          .where((e) => e.status == AppointmentStatus.mendatang)
          .toList();
    }
    if (_filterIndex == 2) {
      return history
          .where((e) => e.status == AppointmentStatus.selesai)
          .toList();
    }
    return history
        .where((e) => e.status == AppointmentStatus.batasWaktu)
        .toList();
  }

  Color _accentBorder(AppointmentStatus s) => switch (s) {
    AppointmentStatus.mendatang => _c500,
    AppointmentStatus.selesai => _c500,
    AppointmentStatus.batasWaktu => const Color(0xFFD94F45),
  };

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return ColoredBox(
      color: _bg,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(topPad)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_showUpcoming) ...[
                  const SizedBox(height: 24),
                  _anim(
                    0,
                    _buildSectionLabel(
                      t(context, 'upcomingAppointmentSection'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _anim(
                    1,
                    _savedUpcomingAppointments.isEmpty
                        ? _buildUpcomingEmptyState()
                        : Column(
                            children: [
                              for (final appointment
                                  in _savedUpcomingAppointments) ...[
                                _buildUpcomingCard(appointment),
                                if (appointment !=
                                    _savedUpcomingAppointments.last)
                                  const SizedBox(height: 14),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 28),
                ],
                if (_showPreviousHistory) ...[
                  if (!_showUpcoming) const SizedBox(height: 24),
                  _anim(2, _buildSectionLabel(t(context, 'previousHistory'))),
                  const SizedBox(height: 14),
                  ..._buildHistoryList(),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(double topPad) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(20, topPad + 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _titleFade,
                  child: SlideTransition(
                    position: _titleSlide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(context, 'historyTitle'),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t(context, 'historySubtitle'),
                          style: const TextStyle(fontSize: 13, color: _ink3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FadeTransition(
                opacity: _btnFade,
                child: SlideTransition(
                  position: _btnSlide,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRefreshBtn(),
                      const SizedBox(width: 8),
                      _buildNewAppointmentBtn(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _chipsFade,
            child: SlideTransition(
              position: _chipsSlide,
              child: _buildFilterChips(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewAppointmentBtn() => GestureDetector(
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ReservationFlowScreen())),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _c500,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            t(context, 'buatJanjiTemu'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildRefreshBtn() => Tooltip(
    message: t(context, 'refreshHistory'),
    child: Material(
      color: _c100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _loadingAppointments ? null : _loadAppointments,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: _loadingAppointments
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _c700,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: _c700, size: 20),
          ),
        ),
      ),
    ),
  );

  // ── filter chips ──────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    final labels = [
      t(context, 'filterAll'),
      t(context, 'filterUpcoming'),
      t(context, 'filterDone'),
      t(context, 'filterNoShow'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == _filterIndex;
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? _c100 : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? _c500 : const Color(0xFFCCD6D7),
                  width: 1.5,
                ),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? _c700 : _ink3,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── section label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: _ink,
    ),
  );

  Widget _buildUpcomingEmptyState() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE1E9E8)),
    ),
    child: Column(
      children: [
        const Icon(Icons.event_available_rounded, color: _ink3, size: 34),
        const SizedBox(height: 8),
        Text(
          t(context, 'noAppointments'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ink3,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  // ── upcoming card ─────────────────────────────────────────────────────────

  Widget _buildUpcomingCard(AppointmentItem item) {
    final paymentStatus = item.paymentStatus.toLowerCase();
    final paymentPlan = item.paymentPlan.toLowerCase();
    final hasOutstandingPayment =
        (paymentPlan == 'deposit' && paymentStatus != 'paid') ||
        (item.amountDue > 0 && paymentStatus != 'paid');
    const paymentWarning = Color(0xFFD94F45);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(
            color: hasOutstandingPayment ? paymentWarning : _c500,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // avatar + info + badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.serviceType,
                        style: const TextStyle(
                          color: _c700,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _infoRow(
                        Icons.calendar_month_outlined,
                        _formatAppointmentDate(item.date),
                      ),
                      const SizedBox(height: 4),
                      _infoRow(Icons.access_time_rounded, item.time),
                      const SizedBox(height: 4),
                      _infoRow(
                        Icons.confirmation_number_outlined,
                        item.displayBookingCode,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: hasOutstandingPayment ? paymentWarning : _c500,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasOutstandingPayment
                        ? t(context, 'paymentPending')
                        : t(context, 'statusUpcoming'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF0F5F5)),
            const SizedBox(height: 12),
            // therapist row
            Row(
              children: [
                Text(
                  t(context, 'terapisLabel'),
                  style: const TextStyle(fontSize: 12, color: _ink3),
                ),
                const Spacer(),
                Text(
                  item.therapistName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Lihat Detail button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppointmentDetailScreen(item: item),
                    ),
                  );
                  if (mounted) _loadAppointments();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: hasOutstandingPayment ? paymentWarning : _c500,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t(context, 'lihatDetail'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── history list ──────────────────────────────────────────────────────────

  List<Widget> _buildHistoryList() {
    final items = _filteredHistory;
    if (items.isEmpty) {
      return [
        _anim(
          3,
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 52,
                    color: _ink3.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t(context, 'noHistoryLabel'),
                    style: const TextStyle(fontSize: 14, color: _ink3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final animIndex = (3 + i).clamp(0, _kContent - 1);
      widgets.add(_anim(animIndex, _buildHistoryCard(items[i])));
      if (i < items.length - 1) widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Widget _buildHistoryCard(AppointmentItem item) {
    final isSelesai = item.status == AppointmentStatus.selesai;
    final hasOutstandingPayment =
        (item.paymentPlan == 'deposit' && item.paymentStatus != 'paid') ||
        (item.amountDue > 0 && item.paymentStatus != 'paid');
    final accentColor = _accentBorder(item.status);
    final serviceColor = isSelesai ? _c700 : _ink;

    final badgeBg = hasOutstandingPayment
        ? const Color(0xFFFFECEB)
        : isSelesai
        ? Colors.transparent
        : const Color(0xFFFFECEB);
    final badgeFg = hasOutstandingPayment
        ? const Color(0xFFD94F45)
        : isSelesai
        ? _c700
        : const Color(0xFFD94F45);
    final badgeBorder = hasOutstandingPayment
        ? const Color(0xFFD94F45)
        : isSelesai
        ? _c700
        : const Color(0xFFD94F45);
    final badgeLabel = hasOutstandingPayment
        ? t(context, 'paymentPending')
        : isSelesai
        ? t(context, 'statusDone')
        : t(context, 'statusExpired');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.serviceType,
                        style: TextStyle(
                          color: serviceColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _infoRow(
                        Icons.calendar_month_outlined,
                        _formatAppointmentDate(item.date),
                        fontSize: 11,
                      ),
                      const SizedBox(height: 3),
                      _infoRow(
                        Icons.access_time_rounded,
                        item.time,
                        fontSize: 11,
                      ),
                      const SizedBox(height: 3),
                      _infoRow(
                        Icons.confirmation_number_outlined,
                        item.displayBookingCode,
                        fontSize: 11,
                      ),
                    ],
                  ),
                ),
                // badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeBorder, width: 1.2),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: badgeFg,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF0F5F5)),
            const SizedBox(height: 10),
            if (hasOutstandingPayment) ...[
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 15,
                    color: Color(0xFFD94F45),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${t(context, 'remainingPayment')}: ${_formatRupiah(item.amountDue)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD94F45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Text(
                  t(context, 'terapisLabel'),
                  style: const TextStyle(fontSize: 12, color: _ink3),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.therapistName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AppointmentDetailScreen(item: item),
                      ),
                    );
                    if (mounted) _loadAppointments();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t(context, 'lihatDetail'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _c500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: _c500,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
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
    return '${weekdays[parsed.weekday - 1]}, ${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  // ── shared widgets ────────────────────────────────────────────────────────

  Widget _buildAvatar({double size = 52}) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFE8EFEF),
    ),
    child: const Icon(Icons.person_rounded, color: _ink3, size: 26),
  );

  Widget _infoRow(IconData icon, String text, {double fontSize = 12}) => Row(
    children: [
      Icon(icon, size: 13, color: _ink3),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          text,
          style: TextStyle(fontSize: fontSize, color: _ink),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
