import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c100 = Color(0xFFD4F5F3);
const _bg = Color(0xFFF0F7F7);
const _ink = Color(0xFF0E2C2F);
const _ink2 = Color(0xFF3D6065);
const _ink3 = Color(0xFF8AA8AC);

class ProgressBody extends StatefulWidget {
  const ProgressBody({super.key});

  @override
  State<ProgressBody> createState() => _ProgressBodyState();
}

class _ProgressBodyState extends State<ProgressBody>
    with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;

  static const _kContent = 5;
  late List<Animation<double>> _contentFades;
  late List<Animation<Offset>> _contentSlides;

  bool _loading = true;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _titleFade = CurvedAnimation(
      parent: _headerCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(-0.2, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerCtrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
          ),
        );

    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _contentFades = List.generate(_kContent, (i) {
      final s = (i * 0.18).clamp(0.0, 1.0);
      final e = (s + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _contentCtrl,
        curve: Interval(s, e, curve: Curves.easeOut),
      );
    });
    _contentSlides = List.generate(_kContent, (i) {
      final s = (i * 0.18).clamp(0.0, 1.0);
      final e = (s + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _contentCtrl,
          curve: Interval(s, e, curve: Curves.easeOutCubic),
        ),
      );
    });

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _contentCtrl.forward();
    });
    _loadProgressData();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProgressBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _headerCtrl.reset();
    _contentCtrl.reset();
    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  Widget _anim(int i, Widget child) => FadeTransition(
    opacity: _contentFades[i],
    child: SlideTransition(position: _contentSlides[i], child: child),
  );

  Future<void> _loadProgressData() async {
    try {
      final service = SupabaseAuthService();
      final user = service.client.auth.currentUser;
      if (user == null) return;
      await service.expireOverdueAppointments();
      final rows = await service.client
          .from('appointments')
          .select()
          .eq('booker_id', user.id)
          .order('appointment_date', ascending: false)
          .order('appointment_time', ascending: false);
      if (!mounted) return;
      setState(() {
        _appointments = (rows as List)
            .map((row) => row as Map<String, dynamic>)
            .toList();
      });
    } catch (error) {
      debugPrint('Progress data load failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _totalSessions => _appointments.fold(0, (total, appointment) {
    final count = int.tryParse(appointment['session_count']?.toString() ?? '');
    return total + (count == null || count < 1 ? 1 : count);
  });

  int get _completedSessions => _appointments
      .where((appointment) => appointment['appointment_status'] == 'completed')
      .length;

  int get _upcomingSessions => _appointments
      .where((appointment) => appointment['appointment_status'] == 'upcoming')
      .length;

  int get _remainingSessions =>
      (_totalSessions - _completedSessions).clamp(0, _totalSessions);

  double get _progressValue => _totalSessions == 0
      ? 0
      : (_completedSessions / _totalSessions).clamp(0.0, 1.0);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: CustomScrollView(
        slivers: [
          _buildSliverHeader(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _anim(0, _buildPackageProgress()),
                const SizedBox(height: 20),
                _anim(1, _buildProgressChart()),
                const SizedBox(height: 20),
                _anim(2, _buildStatRow()),
                const SizedBox(height: 24),
                _anim(
                  3,
                  _buildSectionLabel(t(context, 'progressSessionHistoryTitle')),
                ),
                const SizedBox(height: 14),
                _anim(4, _buildSessionList()),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliver header ─────────────────────────────────────────────────────────

  Widget _buildSliverHeader() => SliverToBoxAdapter(
    child: Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 20,
        20,
        20,
      ),
      child: FadeTransition(
        opacity: _titleFade,
        child: SlideTransition(
          position: _titleSlide,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(context, 'progressTitle'),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t(context, 'progressSubtitle'),
                style: const TextStyle(fontSize: 13, color: _ink3),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildPackageProgress() {
    final progressLabel = t(context, 'progressSessionCount')
        .replaceFirst('{completed}', _completedSessions.toString())
        .replaceFirst('{total}', _totalSessions.toString());
    final remainingLabel = t(
      context,
      'progressSessionsRemaining',
    ).replaceFirst('{count}', _remainingSessions.toString());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _c100),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: _c500))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _c100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: _c700,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t(context, 'progressPackageTitle'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                    Text(
                      '${(_progressValue * 100).round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _c700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  progressLabel,
                  style: const TextStyle(fontSize: 12, color: _ink2),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progressValue,
                    minHeight: 10,
                    backgroundColor: _c100,
                    valueColor: const AlwaysStoppedAnimation<Color>(_c500),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  remainingLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _c700,
                  ),
                ),
                if (_totalSessions > 0) ...[
                  const SizedBox(height: 14),
                  _buildSessionMarkers(),
                ],
              ],
            ),
    );
  }

  Widget _buildSessionMarkers() => Row(
    children: List.generate(_totalSessions, (index) {
      final completed = index < _completedSessions;
      return Expanded(
        child: Container(
          height: 5,
          margin: EdgeInsets.only(right: index == _totalSessions - 1 ? 0 : 4),
          decoration: BoxDecoration(
            color: completed ? _c500 : const Color(0xFFE4EEEE),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      );
    }),
  );

  Widget _buildProgressChart() => Container(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE4EEEE)),
      boxShadow: [
        BoxShadow(
          color: _ink.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: _loading
        ? const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator(color: _c500)),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(context, 'progressChartTitle'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                t(context, 'progressChartDesc'),
                style: const TextStyle(fontSize: 11, color: _ink3),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 145,
                child: CustomPaint(
                  painter: _SessionProgressChartPainter(
                    totalSessions: _totalSessions,
                    completedSessions: _completedSessions,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chartLegend(_c500, t(context, 'progressChartCompleted')),
                  const SizedBox(width: 14),
                  _chartLegend(
                    const Color(0xFFE4EEEE),
                    t(context, 'progressChartRemaining'),
                  ),
                ],
              ),
            ],
          ),
  );

  Widget _chartLegend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 10, color: _ink3)),
    ],
  );

  // ── Stat row ──────────────────────────────────────────────────────────────

  Widget _buildStatRow() => Row(
    children: [
      Expanded(
        child: _buildStatCard(
          Icons.check_circle_rounded,
          _completedSessions.toString(),
          t(context, 'progressStatCompleted'),
          _c500,
          _c100,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _buildStatCard(
          Icons.schedule_rounded,
          _upcomingSessions.toString(),
          t(context, 'progressStatUpcoming'),
          const Color(0xFFD4920A),
          const Color(0xFFFFEEB0),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _buildStatCard(
          Icons.hourglass_empty_rounded,
          _remainingSessions.toString(),
          t(context, 'progressStatRemaining'),
          _c700,
          _c100,
        ),
      ),
    ],
  );

  Widget _buildStatCard(
    IconData icon,
    String value,
    String label,
    Color fg,
    Color bg,
  ) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE4EEEE)),
      boxShadow: [
        BoxShadow(
          color: _ink.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: fg, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: _ink3),
        ),
      ],
    ),
  );

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: _ink,
    ),
  );

  // ── Session list ──────────────────────────────────────────────────────────

  Widget _buildSessionList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _c500));
    }
    if (_appointments.isEmpty) {
      return Center(
        child: Text(
          t(context, 'progressNoSessions'),
          style: const TextStyle(color: _ink3),
        ),
      );
    }

    return Column(
      children: _appointments
          .asMap()
          .entries
          .map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key < _appointments.length - 1 ? 12 : 0,
              ),
              child: _buildSessionCard(_sessionFromAppointment(entry.value)),
            ),
          )
          .toList(),
    );
  }

  _SessionItem _sessionFromAppointment(Map<String, dynamic> appointment) {
    final status = appointment['appointment_status']?.toString();
    return _SessionItem(
      date: appointment['appointment_date']?.toString() ?? '-',
      time: appointment['appointment_time']?.toString() ?? '-',
      therapist:
          appointment['therapist_name']?.toString() ??
          t(context, 'therapistDefault'),
      service: appointment['service_type']?.toString() ?? 'Home Care',
      score: double.tryParse(appointment['pain_score']?.toString() ?? ''),
      duration: appointment['duration_minutes'] == null
          ? '-'
          : '${appointment['duration_minutes']} min',
      status: status == 'completed' ? _SStatus.done : _SStatus.upcoming,
    );
  }

  Widget _buildSessionCard(_SessionItem item) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: _ink.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSessionLeading(item),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.therapist,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _c100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.service == 'Home Care'
                            ? t(context, 'progressServiceHomeCare')
                            : t(context, 'progressServiceKlinik'),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _c700,
                        ),
                      ),
                    ),
                    if (item.duration != '-') ...[
                      const SizedBox(width: 6),
                      Icon(Icons.timer_outlined, size: 11, color: _ink3),
                      const SizedBox(width: 3),
                      Text(
                        item.duration,
                        style: const TextStyle(fontSize: 10, color: _ink3),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.date,
                style: const TextStyle(fontSize: 11, color: _ink2),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 11, color: _ink3),
                  const SizedBox(width: 3),
                  Text(
                    item.time.length >= 5
                        ? '${item.time.substring(0, 5)} WIB'
                        : item.time,
                    style: const TextStyle(fontSize: 10, color: _ink3),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _c500,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.status == _SStatus.done
                      ? t(context, 'progressSessionDone')
                      : t(context, 'statusUpcoming'),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildSessionLeading(_SessionItem item) {
    final color = item.status == _SStatus.done
        ? _c500
        : const Color(0xFFD4920A);
    return Container(
      width: 52,
      height: 58,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.status == _SStatus.done
                ? Icons.check_circle_outline_rounded
                : Icons.event_available_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 3),
          Text(
            item.score == null
                ? t(context, 'progressSessionLabel')
                : item.score!.toString(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

enum _SStatus { done, upcoming }

class _SessionItem {
  final String date;
  final String time;
  final String therapist;
  final String service;
  final double? score;
  final String duration;
  final _SStatus status;

  const _SessionItem({
    required this.date,
    required this.time,
    required this.therapist,
    required this.service,
    required this.score,
    required this.duration,
    required this.status,
  });
}

class _SessionProgressChartPainter extends CustomPainter {
  final int totalSessions;
  final int completedSessions;

  const _SessionProgressChartPainter({
    required this.totalSessions,
    required this.completedSessions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0;
    const right = 8.0;
    const top = 10.0;
    const bottom = 26.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final safeTotal = totalSessions < 1 ? 1 : totalSessions;
    final safeCompleted = completedSessions.clamp(0, safeTotal);

    final gridPaint = Paint()
      ..color = const Color(0xFFEAF1F1)
      ..strokeWidth = 1;
    for (var step = 0; step <= 4; step++) {
      final y = top + chartHeight * step / 4;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    double xFor(int session) => left + chartWidth * session / safeTotal;
    double yFor(int session) {
      final ratio = session == 0
          ? 0.0
          : (session.clamp(0, safeCompleted) / safeTotal);
      return top + chartHeight - chartHeight * ratio;
    }

    final path = Path()..moveTo(xFor(0), yFor(0));
    for (var session = 1; session <= safeTotal; session++) {
      path.lineTo(xFor(session), yFor(session));
    }

    final fillPath = Path.from(path)
      ..lineTo(xFor(safeTotal), top + chartHeight)
      ..lineTo(xFor(0), top + chartHeight)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = _c500.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _c500
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (var session = 0; session <= safeTotal; session++) {
      canvas.drawCircle(
        Offset(xFor(session), yFor(session)),
        session == safeCompleted && safeCompleted > 0 ? 5 : 3,
        Paint()..color = session <= safeCompleted ? _c700 : _ink3,
      );
    }

    _drawLabel(canvas, '0%', Offset(0, top + chartHeight - 6));
    _drawLabel(canvas, '100%', Offset(0, top - 4));
    _drawLabel(canvas, 'S1', Offset(xFor(0) - 5, size.height - 16));
    _drawLabel(
      canvas,
      'S$safeTotal',
      Offset(xFor(safeTotal) - 8, size.height - 16),
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 9, color: _ink3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_SessionProgressChartPainter oldDelegate) =>
      oldDelegate.totalSessions != totalSessions ||
      oldDelegate.completedSessions != completedSessions;
}
