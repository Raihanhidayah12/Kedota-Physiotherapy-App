import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _c900 = Color(0xFF004D47);
const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _c100 = Color(0xFFD4F5F3);
const _bg   = Color(0xFFF0F7F7);
const _ink  = Color(0xFF0E2C2F);
const _ink2 = Color(0xFF3D6065);
const _ink3 = Color(0xFF8AA8AC);

// ─── Dummy data ───────────────────────────────────────────────────────────────

enum AppointmentStatus { mendatang, selesai, batasWaktu, dibatalkan }

class AppointmentItem {
  final String therapistName;
  final String serviceType;
  final String date;
  final String time;
  final AppointmentStatus status;

  const AppointmentItem({
    required this.therapistName,
    required this.serviceType,
    required this.date,
    required this.time,
    required this.status,
  });
}

final _dummyUpcoming = AppointmentItem(
  therapistName: 'Terapis Marvin McKinney',
  serviceType: 'Home Care',
  date: 'Selasa, 18 Agustus 2026',
  time: '11:00 – 12:00 WIB',
  status: AppointmentStatus.mendatang,
);

final _dummyHistory = [
  AppointmentItem(
    therapistName: 'Terapis Marvin McKinney',
    serviceType: 'Home Care',
    date: 'Selasa, 11 Agustus 2026',
    time: '11:00 – 12:00 WIB',
    status: AppointmentStatus.selesai,
  ),
  AppointmentItem(
    therapistName: 'Terapis Marvin McKinney',
    serviceType: 'Home Care',
    date: 'Selasa, 04 Agustus 2026',
    time: '11:00 – 12:00 WIB',
    status: AppointmentStatus.selesai,
  ),
  AppointmentItem(
    therapistName: 'Terapis Sinta Dewi',
    serviceType: 'Klinik',
    date: 'Senin, 28 Juli 2026',
    time: '09:00 – 10:00 WIB',
    status: AppointmentStatus.batasWaktu,
  ),
  AppointmentItem(
    therapistName: 'Terapis Sinta Dewi',
    serviceType: 'Klinik',
    date: 'Senin, 21 Juli 2026',
    time: '09:00 – 10:00 WIB',
    status: AppointmentStatus.selesai,
  ),
  AppointmentItem(
    therapistName: 'Terapis Budi Santoso',
    serviceType: 'Home Care',
    date: 'Jumat, 10 Juli 2026',
    time: '14:00 – 15:00 WIB',
    status: AppointmentStatus.dibatalkan,
  ),
];

// ─── Filter tab keys ──────────────────────────────────────────────────────────
const _filterTabKeys = ['filterAll', 'filterUpcoming', 'filterDone', 'filterCancelled'];

// ─── Body widget ──────────────────────────────────────────────────────────────

class HistoryBody extends StatefulWidget {
  const HistoryBody({super.key});

  @override
  State<HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<HistoryBody>
    with TickerProviderStateMixin {
  int _filterIndex = 0;
  String _sortKey = 'sortNewest';

  // ── animation controllers ─────────────────────────────────────────────────
  late AnimationController _headerCtrl;
  late AnimationController _contentCtrl;

  // header expand animation (height expand from top-to-bottom, not fade)
  late Animation<double> _headerExpand;
  
  // header sub-elements
  late Animation<double>  _titleFade;
  late Animation<Offset>  _titleSlide;
  late Animation<double>  _btnFade;
  late Animation<Offset>  _btnSlide;
  late Animation<double>  _chipsFade;
  late Animation<Offset>  _chipsSlide;

  // content sections: 0=upcoming label, 1=upcoming card, 2=history label, 3-7=history cards
  static const _kContent = 8;
  late List<Animation<double>>  _contentFades;
  late List<Animation<Offset>>  _contentSlides;

  @override
  void initState() {
    super.initState();

    // ── header (800 ms) ─────────────────────────────────────────────────────
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _headerExpand = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic),
    );

    _titleFade = CurvedAnimation(
        parent: _headerCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
    _titleSlide = Tween<Offset>(
            begin: const Offset(-0.25, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _headerCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)));

    _btnFade = CurvedAnimation(
        parent: _headerCtrl,
        curve: const Interval(0.1, 0.65, curve: Curves.easeOut));
    _btnSlide = Tween<Offset>(
            begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _headerCtrl,
            curve: const Interval(0.1, 0.65, curve: Curves.easeOutCubic)));

    _chipsFade = CurvedAnimation(
        parent: _headerCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _chipsSlide = Tween<Offset>(
            begin: const Offset(0, 0.6), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _headerCtrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));

    // ── content stagger (1200 ms) ─────────────────────────────────────────
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));

    _contentFades = List.generate(_kContent, (i) {
      final s = (i * 0.13).clamp(0.0, 1.0);
      final e = (s + 0.35).clamp(0.0, 1.0);
      return CurvedAnimation(
          parent: _contentCtrl,
          curve: Interval(s, e, curve: Curves.easeOut));
    });
    _contentSlides = List.generate(_kContent, (i) {
      final s = (i * 0.13).clamp(0.0, 1.0);
      final e = (s + 0.35).clamp(0.0, 1.0);
      return Tween<Offset>(
              begin: const Offset(0, 0.15), end: Offset.zero)
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
  void didUpdateWidget(HistoryBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger ulang animasi saat widget key berubah
    _headerCtrl.reset();
    _contentCtrl.reset();
    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  // ── stagger helper ─────────────────────────────────────────────────────────
  Widget _anim(int index, Widget child) => FadeTransition(
        opacity: _contentFades[index],
        child: SlideTransition(position: _contentSlides[index], child: child),
      );

  // ── filter logic ─────────────────────────────────────────────────────────
  List<AppointmentItem> get _filteredHistory {
    if (_filterIndex == 0) return _dummyHistory;
    final target = switch (_filterIndex) {
      1 => AppointmentStatus.mendatang,
      2 => AppointmentStatus.selesai,
      _ => AppointmentStatus.dibatalkan,
    };
    return _dummyHistory.where((e) => e.status == target).toList();
  }

  // ── status helpers ────────────────────────────────────────────────────────

  String _statusLabel(BuildContext ctx, AppointmentStatus s) => switch (s) {
        AppointmentStatus.mendatang  => t(ctx, 'statusUpcoming'),
        AppointmentStatus.selesai    => t(ctx, 'statusDone'),
        AppointmentStatus.batasWaktu => t(ctx, 'statusExpired'),
        AppointmentStatus.dibatalkan => t(ctx, 'statusCancelled'),
      };

  Color _statusBg(AppointmentStatus s) => switch (s) {
        AppointmentStatus.mendatang  => _c100,
        AppointmentStatus.selesai    => _c500,
        AppointmentStatus.batasWaktu => const Color(0xFFFFECEB),
        AppointmentStatus.dibatalkan => const Color(0xFFF0F0F0),
      };

  Color _statusFg(AppointmentStatus s) => switch (s) {
        AppointmentStatus.mendatang  => _c700,
        AppointmentStatus.selesai    => Colors.white,
        AppointmentStatus.batasWaktu => const Color(0xFFD94F45),
        AppointmentStatus.dibatalkan => const Color(0xFF999999),
      };

  Color _avatarBg(AppointmentStatus s) => switch (s) {
        AppointmentStatus.mendatang  => _c100,
        AppointmentStatus.selesai    => const Color(0xFFE0F8F6),
        AppointmentStatus.batasWaktu => const Color(0xFFFFE8E6),
        AppointmentStatus.dibatalkan => const Color(0xFFF0F0F0),
      };

  Color _avatarFg(AppointmentStatus s) => switch (s) {
        AppointmentStatus.mendatang  => _c700,
        AppointmentStatus.selesai    => _c500,
        AppointmentStatus.batasWaktu => const Color(0xFFD94F45),
        AppointmentStatus.dibatalkan => const Color(0xFFAAAAAA),
      };

  // ── build ─────────────────────────────────────────────────────────────────

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
                const SizedBox(height: 22),
                _anim(0, _buildSectionLabel(t(context, 'upcomingAppointmentSection'))),
                const SizedBox(height: 12),
                _anim(1, _buildUpcomingCard(_dummyUpcoming)),
                const SizedBox(height: 28),
                _anim(2, _buildSectionLabel(t(context, 'previousHistory'))),
                const SizedBox(height: 14),
                ..._buildHistoryList(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── sliver header ─────────────────────────────────────────────────────────

  Widget _buildSliverHeader() => SliverToBoxAdapter(
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _headerExpand,
            builder: (context, child) {
              return Align(
                alignment: Alignment.topCenter,
                heightFactor: _headerExpand.value,
                child: child,
              );
            },
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
                  Positioned(
                    right: -50,
                    top: -50,
                    child: _circle(180, Colors.white, 0.05),
                  ),
                  Positioned(
                    left: -30,
                    bottom: -20,
                    child: _circle(120, Colors.white, 0.04),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 16,
                      20,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // title row
                        Row(
                          children: [
                            // title — slides from left
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
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        t(context, 'historySubtitle'),
                                        style: const TextStyle(
                                          color: _c100,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // sort + date — slides from right
                            FadeTransition(
                              opacity: _btnFade,
                              child: SlideTransition(
                                position: _btnSlide,
                                child: Row(
                                  children: [
                                    _buildSortButton(),
                                    const SizedBox(width: 8),
                                    _buildDateButton(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // filter chips — slides from bottom
                        FadeTransition(
                          opacity: _chipsFade,
                          child: SlideTransition(
                            position: _chipsSlide,
                            child: _buildFilterChips(),
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
      );

  Widget _circle(double size, Color color, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      );

  Widget _buildSortButton() => GestureDetector(
        onTap: _showSortSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sort_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                t(context, _sortKey),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      );

  Widget _buildDateButton() => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: const Icon(Icons.calendar_month_outlined,
            color: Colors.white, size: 18),
      );

  Widget _buildFilterChips() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: List.generate(_filterTabKeys.length, (i) {
            final active = i == _filterIndex;
            return GestureDetector(
              onTap: () => setState(() => _filterIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: i < _filterTabKeys.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  t(context, _filterTabKeys[i]),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? _c700 : Colors.white,
                  ),
                ),
              ),
            );
          }),
        ),
      );

  // ── section label ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      );

  // ── upcoming card ─────────────────────────────────────────────────────────

  Widget _buildUpcomingCard(AppointmentItem item) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_c700, _c500],
          ),
          boxShadow: [
            BoxShadow(
              color: _c700.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: _circle(100, Colors.white, 0.06),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // top row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.medical_services_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.therapistName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                item.serviceType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          t(context, 'statusUpcoming'),
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
                  // info box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: _infoItem(Icons.calendar_month_outlined,
                              item.date.split(', ').first, item.date.split(', ').last),
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          color: Colors.white.withValues(alpha: 0.25),
                          margin:
                              const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        Flexible(
                          child: _infoItem(Icons.access_time_rounded,
                              item.time.split(' – ').first,
                              '– ${item.time.split(' – ').last}'),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              color: _c700, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _infoItem(IconData icon, String top, String bottom) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(top,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                Text(bottom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10)),
              ],
            ),
          ),
        ],
      );

  // ── history list ──────────────────────────────────────────────────────────

  List<Widget> _buildHistoryList() {
    final items = _filteredHistory;
    if (items.isEmpty) {
      return [
        _anim(3, Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.history_toggle_off_rounded,
                    size: 52, color: _ink3.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(t(context, 'noAppointments'),
                    style: const TextStyle(fontSize: 14, color: _ink3)),
              ],
            ),
          ),
        )),
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

  Widget _buildHistoryCard(AppointmentItem item) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _ink.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // top colored accent bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18)),
                color: _statusFg(item.status)
                    .withValues(alpha: 0.6),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  // header row
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _avatarBg(item.status),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.medical_services_rounded,
                          color: _avatarFg(item.status),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.therapistName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.serviceType,
                              style: const TextStyle(
                                  fontSize: 11, color: _ink3),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusBg(item.status),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(context, item.status),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _statusFg(item.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // divider
                  const Divider(height: 1, color: Color(0xFFF0F5F5)),
                  const SizedBox(height: 12),
                  // info + button row
                  Row(
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 14, color: _c500),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(item.date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: _ink2)),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.access_time_rounded,
                          size: 14, color: _c500),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(item.time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: _ink2)),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _c100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t(context, 'detail'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _c700,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.arrow_forward_rounded,
                                  size: 12, color: _c700),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ── sort bottom sheet ─────────────────────────────────────────────────────

  void _showSortSheet() {
    final sortOptions = [
      ('sortNewest', Icons.arrow_downward_rounded),
      ('sortOldest', Icons.arrow_upward_rounded),
      ('sortByDate', Icons.category_rounded),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE5E5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              t(ctx, 'sortLabel'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            for (final opt in sortOptions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _sortKey == opt.$1
                        ? _c100
                        : const Color(0xFFF5F8F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    opt.$2,
                    size: 16,
                    color: _sortKey == opt.$1 ? _c700 : _ink3,
                  ),
                ),
                title: Text(
                  t(ctx, opt.$1),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _sortKey == opt.$1 ? _c700 : _ink,
                  ),
                ),
                trailing: _sortKey == opt.$1
                    ? const Icon(Icons.check_circle_rounded, color: _c500)
                    : null,
                onTap: () {
                  setState(() => _sortKey = opt.$1);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}
