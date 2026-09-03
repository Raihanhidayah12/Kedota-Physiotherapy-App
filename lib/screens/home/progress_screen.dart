import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _c900 = Color(0xFF004D47);
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c300 = Color(0xFF5ECFC9);
const _c100 = Color(0xFFD4F5F3);
const _bg   = Color(0xFFF0F7F7);
const _ink  = Color(0xFF0E2C2F);
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
  late Animation<double> _headerExpand;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;

  static const _kContent = 5;
  late List<Animation<double>> _contentFades;
  late List<Animation<Offset>> _contentSlides;

  int _selectedWeek = 0; // 0 = minggu ini, 1 = minggu lalu, 2 = 2 minggu lalu

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _headerExpand = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic),
    );
    _titleFade = CurvedAnimation(
        parent: _headerCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _titleSlide = Tween<Offset>(begin: const Offset(-0.2, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _headerCtrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _contentFades = List.generate(_kContent, (i) {
      final s = (i * 0.18).clamp(0.0, 1.0);
      final e = (s + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
          parent: _contentCtrl, curve: Interval(s, e, curve: Curves.easeOut));
    });
    _contentSlides = List.generate(_kContent, (i) {
      final s = (i * 0.18).clamp(0.0, 1.0);
      final e = (s + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
          .animate(CurvedAnimation(
              parent: _contentCtrl,
              curve: Interval(s, e, curve: Curves.easeOutCubic)));
    });

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _contentCtrl.forward();
    });
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

  // ── Data dummy ────────────────────────────────────────────────────────────

  final _weeklyData = [
    // minggu ini
    [8.0, 7.5, 6.5, 6.0, 5.0, 4.5, 4.0],
    // minggu lalu
    [9.0, 8.5, 8.0, 7.5, 7.0, 6.5, 6.0],
    // 2 minggu lalu
    [10.0, 9.5, 9.0, 8.5, 8.0, 7.5, 7.0],
  ];

  final _sessionData = [
    _SessionItem(date: 'Sel, 29 Agu', therapist: 'Marvin McKinney', service: 'Home Care', score: 4.0, duration: '60 min', status: _SStatus.done),
    _SessionItem(date: 'Sel, 22 Agu', therapist: 'Marvin McKinney', service: 'Home Care', score: 5.0, duration: '60 min', status: _SStatus.done),
    _SessionItem(date: 'Sel, 15 Agu', therapist: 'Sinta Dewi',      service: 'Klinik',    score: 6.5, duration: '45 min', status: _SStatus.done),
    _SessionItem(date: 'Sel, 08 Agu', therapist: 'Sinta Dewi',      service: 'Klinik',    score: 7.0, duration: '45 min', status: _SStatus.done),
    _SessionItem(date: 'Sel, 01 Agu', therapist: 'Budi Santoso',    service: 'Home Care', score: 8.0, duration: '60 min', status: _SStatus.done),
  ];

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
                _anim(0, _buildWeekSelector()),
                const SizedBox(height: 20),
                _anim(1, _buildPainChart()),
                const SizedBox(height: 20),
                _anim(2, _buildStatRow()),
                const SizedBox(height: 28),
                _anim(3, _buildSectionLabel('Riwayat Sesi')),
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
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _headerExpand,
            builder: (context, child) => Align(
              alignment: Alignment.topCenter,
              heightFactor: _headerExpand.value,
              child: child,
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_c900, _c700, _c500],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(right: -50, top: -50,
                      child: _circle(180, Colors.white, 0.05)),
                  Positioned(right: 30, top: 30,
                      child: _circle(70, Colors.white, 0.07)),
                  Positioned(left: -30, bottom: -20,
                      child: _circle(120, _c300, 0.15)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 16,
                      20,
                      24,
                    ),
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Progress',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pantau perkembangan rehabilitasi Anda',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 18),
                            // ── Summary chips ──────────────────────────
                            Row(
                              children: [
                                _buildHeaderChip(
                                    Icons.event_available_rounded, '12', 'Total Sesi'),
                                const SizedBox(width: 10),
                                _buildHeaderChip(
                                    Icons.trending_down_rounded, '4.0', 'Pain Score'),
                                const SizedBox(width: 10),
                                _buildHeaderChip(
                                    Icons.timer_outlined, '60 min', 'Rata-rata'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildHeaderChip(IconData icon, String value, String label) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 9)),
              ],
            ),
          ],
        ),
      );

  Widget _circle(double size, Color color, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      );

  // ── Week selector ─────────────────────────────────────────────────────────

  Widget _buildWeekSelector() {
    final labels = ['Minggu Ini', 'Minggu Lalu', '2 Minggu Lalu'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == _selectedWeek;
          return GestureDetector(
            onTap: () => setState(() => _selectedWeek = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? _c500 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: active
                        ? _c500.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : _ink3,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Pain score chart ──────────────────────────────────────────────────────

  Widget _buildPainChart() => Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _ink.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pain Score',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _ink)),
                      SizedBox(height: 2),
                      Text('Skala 0–10 (lebih rendah lebih baik)',
                          style: TextStyle(fontSize: 11, color: _ink3)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _c100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_down_rounded,
                          size: 13, color: _c700),
                      const SizedBox(width: 4),
                      Text('−4.0 pts',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _c700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: CustomPaint(
                painter: _PainChartPainter(_weeklyData[_selectedWeek]),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      );

  // ── Stat row ──────────────────────────────────────────────────────────────

  Widget _buildStatRow() => Row(
        children: [
          Expanded(child: _buildStatCard(
              Icons.check_circle_rounded, '12', 'Sesi Selesai', _c500, _c100)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(
              Icons.schedule_rounded, '2', 'Sesi Mendatang',
              const Color(0xFFD4920A), const Color(0xFFFFEEB0))),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(
              Icons.sentiment_satisfied_rounded, '83%', 'Kepuasan',
              const Color(0xFF5B5FC8), const Color(0xFFEEEFFF))),
        ],
      );

  Widget _buildStatCard(
          IconData icon, String value, String label, Color fg, Color bg) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: 20),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: fg)),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: _ink3)),
          ],
        ),
      );

  // ── Section label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) => Text(
        label,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
      );

  // ── Session list ──────────────────────────────────────────────────────────

  Widget _buildSessionList() => Column(
        children: _sessionData
            .asMap()
            .entries
            .map((e) => Padding(
                  padding: EdgeInsets.only(
                      bottom: e.key < _sessionData.length - 1 ? 12 : 0),
                  child: _buildSessionCard(e.value),
                ))
            .toList(),
      );

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
              // Pain score circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _painColor(item.score).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    item.score.toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _painColor(item.score),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.therapist,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _c100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(item.service,
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _c700)),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.timer_outlined, size: 11, color: _ink3),
                        const SizedBox(width: 3),
                        Text(item.duration,
                            style: const TextStyle(
                                fontSize: 10, color: _ink3)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(item.date,
                      style: const TextStyle(fontSize: 11, color: _ink2)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _c500,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Selesai',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Color _painColor(double score) {
    if (score <= 3) return _c500;
    if (score <= 6) return const Color(0xFFD4920A);
    return const Color(0xFFD94F45);
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

enum _SStatus { done, upcoming }

class _SessionItem {
  final String date;
  final String therapist;
  final String service;
  final double score;
  final String duration;
  final _SStatus status;

  const _SessionItem({
    required this.date,
    required this.therapist,
    required this.service,
    required this.score,
    required this.duration,
    required this.status,
  });
}

// ─── Pain chart painter ───────────────────────────────────────────────────────

class _PainChartPainter extends CustomPainter {
  final List<double> data;
  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  const _PainChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 10.0, padR = 10.0, padT = 8.0, padB = 28.0;
    final chartW = size.width - padL - padR;
    final chartH = size.height - padT - padB;

    double xOf(int i) => padL + i * chartW / (data.length - 1);
    double yOf(double v) => padT + chartH - (v / 10.0) * chartH;

    // grid
    final gridPaint = Paint()
      ..color = const Color(0xFFF0F5F5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 5; i++) {
      final y = padT + i * chartH / 5;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);
    }

    // fill
    final fillPath = Path()..moveTo(xOf(0), yOf(data[0]));
    for (var i = 1; i < data.length; i++) {
      final cpx = (xOf(i - 1) + xOf(i)) / 2;
      fillPath.cubicTo(cpx, yOf(data[i - 1]), cpx, yOf(data[i]), xOf(i), yOf(data[i]));
    }
    fillPath
      ..lineTo(xOf(data.length - 1), padT + chartH)
      ..lineTo(xOf(0), padT + chartH)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x4000A79D), Color(0x0000A79D)],
        ).createShader(Rect.fromLTWH(0, padT, size.width, chartH)),
    );

    // line
    final linePath = Path()..moveTo(xOf(0), yOf(data[0]));
    for (var i = 1; i < data.length; i++) {
      final cpx = (xOf(i - 1) + xOf(i)) / 2;
      linePath.cubicTo(cpx, yOf(data[i - 1]), cpx, yOf(data[i]), xOf(i), yOf(data[i]));
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = _c500
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // dots
    for (var i = 0; i < data.length; i++) {
      final isLast = i == data.length - 1;
      if (isLast) {
        canvas.drawCircle(Offset(xOf(i), yOf(data[i])), 8,
            Paint()..color = _c500.withValues(alpha: 0.2));
      }
      canvas.drawCircle(Offset(xOf(i), yOf(data[i])), isLast ? 5 : 3.5,
          Paint()..color = isLast ? _c700 : _c300);
      canvas.drawCircle(Offset(xOf(i), yOf(data[i])), isLast ? 2.5 : 1.5,
          Paint()..color = Colors.white);
    }

    // day labels
    for (var i = 0; i < _days.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: _days[i],
          style: const TextStyle(
              color: Color(0xFF8AA8AC), fontSize: 9, fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(xOf(i) - tp.width / 2, padT + chartH + 8));
    }
  }

  @override
  bool shouldRepaint(_PainChartPainter old) => old.data != data;
}
