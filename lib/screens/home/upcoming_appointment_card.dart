import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import 'history_screen.dart';

const _c700 = Color(0xFF007F78);
const _c500 = Color(0xFF00A79D);
const _ink = Color(0xFF0E2C2F);
const _ink3 = Color(0xFF8AA8AC);
const _paymentWarning = Color(0xFFD94F45);

class UpcomingAppointmentCard extends StatelessWidget {
  final AppointmentItem item;
  final VoidCallback? onTap;

  const UpcomingAppointmentCard({super.key, required this.item, this.onTap});

  bool get _hasOutstandingPayment {
    final paymentStatus = item.paymentStatus.toLowerCase();
    final paymentPlan = item.paymentPlan.toLowerCase();
    return (paymentPlan == 'deposit' && paymentStatus != 'paid') ||
        (item.amountDue > 0 && paymentStatus != 'paid');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          top: BorderSide(
            color: (_hasOutstandingPayment ? _paymentWarning : _c500)
                .withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120E2C2F),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        item.patientName.isEmpty
                            ? t(context, 'patientName')
                            : item.patientName,
                        style: const TextStyle(
                          color: _c700,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _infoRow(
                        Icons.sell_outlined,
                        item.bookedForOther
                            ? t(context, 'reservationForOther')
                            : t(context, 'reservationForSelf'),
                      ),
                    ],
                  ),
                ),
                _statusBadge(context),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _infoRow(
                    Icons.calendar_month_outlined,
                    _formatAppointmentDate(item.date),
                  ),
                ),
                _verticalDivider(),
                Expanded(child: _infoRow(Icons.access_time_rounded, item.time)),
                _verticalDivider(),
                Expanded(
                  child: _infoRow(
                    Icons.radio_button_checked_rounded,
                    '${t(context, 'sessionUnit')} ${item.sessionCount}',
                  ),
                ),
              ],
            ),
            const Divider(height: 1, color: Color(0xFFF0F5F5)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _infoRow(
                    Icons.medical_services_outlined,
                    '${t(context, 'serviceCat')}: ${item.serviceType}',
                  ),
                ),
                _verticalDivider(),
                Expanded(
                  child: _infoRow(
                    Icons.person_outline_rounded,
                    '${t(context, 'terapisLabel')}: ${item.therapistName}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _hasOutstandingPayment ? _paymentWarning : _c500,
                    borderRadius: BorderRadius.circular(10),
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
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: (_hasOutstandingPayment ? _paymentWarning : _c500).withValues(
        alpha: 0.12,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      _hasOutstandingPayment
          ? t(context, 'paymentPending')
          : t(context, 'statusUpcoming'),
      style: const TextStyle(
        color: _c700,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _buildAvatar() => Container(
    width: 56,
    height: 56,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFE8EFEF),
    ),
    child: const Icon(Icons.person_rounded, color: _ink3, size: 26),
  );

  Widget _infoRow(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 13, color: _ink3),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, color: _ink),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _verticalDivider() => Container(
    width: 1,
    height: 16,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: const Color(0xFFE0EAEA),
  );

  String _formatAppointmentDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    const weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
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
}
