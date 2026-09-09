import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/notification_service.dart';
import '../../utils/phone_validator.dart';
import '../../widgets/custom_bottom_sheet.dart';
import '../../widgets/custom_date_picker.dart';
import 'main_screen.dart';

const _teal = Color(0xFF00A79D);
const _tealDark = Color(0xFF007F78);
const _background = Color(0xFFF5F8F8);
const _ink = Color(0xFF172B2D);
const _muted = Color(0xFF7C8C8E);
const _homeCareService = 'home_care';
const _clinicService = 'clinic';
const _sessionPackagePrices = <int, int>{
  1: 225000,
  3: 660000,
  6: 1290000,
  9: 1890000,
};
const _homeCareTravelFee = 25000;
const _depositPercent = 30;

class _ServiceLocation {
  final String name;
  final String address;
  final String mapUrl;

  const _ServiceLocation({
    required this.name,
    required this.address,
    required this.mapUrl,
  });
}

const _clinicLocation = _ServiceLocation(
  name: 'Klinik Kedota Malang',
  address:
      'Blok Kelapa No.29, Tunggulwulung, Kec. Lowokwaru, Kota Malang, Jawa Timur 65143',
  mapUrl: 'https://maps.app.goo.gl/6RoeDr21WjTfMjo86',
);

const _homeCareLocations = [
  _ServiceLocation(
    name: 'Home Care Surabaya',
    address: 'Kunjungan ke Rumah',
    mapUrl: 'https://maps.app.goo.gl/BKJHTHqbi6AbTYu5A',
  ),
  _ServiceLocation(
    name: 'Home Care Sidoarjo',
    address: 'Kunjungan ke Rumah',
    mapUrl: 'https://maps.app.goo.gl/cVyYPBepqdLHBLNb6',
  ),
  _ServiceLocation(
    name: 'Home Care Surakarta',
    address: 'Kunjungan ke Rumah',
    mapUrl: 'https://maps.app.goo.gl/tEg3aaZokSEpNmRF7',
  ),
  _ServiceLocation(
    name: 'Home Care Yogyakarta',
    address: 'Kunjungan ke Rumah',
    mapUrl: 'https://maps.app.goo.gl/JZRHQ9e7iMULrjtB9',
  ),
];

class ReservationFlowScreen extends StatefulWidget {
  final bool clinicNewPatientPromo;
  final String? initialAppointmentId;
  final String? initialServiceType;
  final String? initialClinic;
  final String? initialDate;
  final String? initialTime;
  final String? initialAddress;
  final String? initialComplaint;
  final int? initialSessionCount;

  const ReservationFlowScreen({
    super.key,
    this.clinicNewPatientPromo = false,
    this.initialAppointmentId,
    this.initialServiceType,
    this.initialClinic,
    this.initialDate,
    this.initialTime,
    this.initialAddress,
    this.initialComplaint,
    this.initialSessionCount,
  });

  @override
  State<ReservationFlowScreen> createState() => _ReservationFlowScreenState();
}

class _ReservationFlowScreenState extends State<ReservationFlowScreen>
    with SingleTickerProviderStateMixin {
  final _service = SupabaseAuthService();
  final _formKey = GlobalKey<FormState>();
  final _nikController = TextEditingController();
  final _medicalCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _complaintController = TextEditingController();
  final _addressController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _mapController = MapController();

  int _step = 0;
  bool _forSelf = true;
  bool _loading = true;
  bool _saving = false;
  DateTime? _birthDate;
  DateTime? _appointmentDate;
  TimeOfDay? _appointmentTime;
  String _gender = 'male';
  final String _therapistGender = 'any';
  String _clinic = _clinicLocation.name;
  String _serviceType = _clinicService;
  String _paymentMethod = 'qris';
  String _paymentPlan = 'full';
  int _sessionCount = 1;
  bool _therapistAvailability = false;
  bool _clinicPromoEligible = false;
  String? _expandedPaymentTutorial;
  Timer? _successTimer;
  int _successCountdown = 3;
  late final AnimationController _successAnimationController;
  late final Animation<double> _successScale;
  late final Animation<double> _successFade;
  Set<String> _bookedAppointmentTimes = {};
  bool _locating = false;
  LatLng _mapCenter = const LatLng(-7.9839, 112.6214);

  bool get _isReschedule => widget.initialDate != null;

  @override
  void initState() {
    super.initState();
    _successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _successScale = CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    );
    _successFade = CurvedAnimation(
      parent: _successAnimationController,
      curve: const Interval(0, 0.42, curve: Curves.easeOut),
    );
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _service.checkUserProfileExists();
      final user = _service.client.auth.currentUser;
      if (widget.clinicNewPatientPromo && user != null) {
        final existingAppointments = await _service.client
            .from('appointments')
            .select('id')
            .eq('booker_id', user.id)
            .limit(1);
        _clinicPromoEligible = (existingAppointments as List).isEmpty;
      }
      _nikController.text = profile?['nik']?.toString() ?? '';
      final savedMedicalCode =
          profile?['medical_code']?.toString().trim() ?? '';
      final medicalCode =
          RegExp(r'^KED-[A-F0-9]{12}$').hasMatch(savedMedicalCode)
          ? savedMedicalCode
          : await _generateUniqueMedicalCode();
      _medicalCodeController.text = medicalCode;
      if (medicalCode != savedMedicalCode && user != null) {
        await _service.client
            .from('profiles')
            .update({'medical_code': medicalCode})
            .eq('id', user.id);
      }
      _nameController.text =
          profile?['full_name']?.toString() ??
          user?.userMetadata?['full_name']?.toString() ??
          '';
      _phoneController.text =
          profile?['phone']?.toString() ?? user?.phone?.toString() ?? '';
      _addressController.text = profile?['address']?.toString() ?? '';
      _applyRescheduleData();
      final birthDate = profile?['birth_date']?.toString();
      if (birthDate != null && birthDate.length >= 10) {
        _birthDate = DateTime.tryParse(birthDate.substring(0, 10));
      }
    } catch (error) {
      debugPrint('Reservation profile load failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyRescheduleData() {
    final serviceType = widget.initialServiceType;
    if (serviceType != null) {
      _serviceType = serviceType == 'Home Care'
          ? _homeCareService
          : _clinicService;
    }
    if (widget.initialClinic?.isNotEmpty == true) {
      _clinic = widget.initialClinic!;
    }
    if (widget.initialAddress?.isNotEmpty == true) {
      _addressController.text = widget.initialAddress!;
    }
    if (widget.initialComplaint?.isNotEmpty == true) {
      _complaintController.text = widget.initialComplaint!;
    }
    if (widget.initialSessionCount != null && widget.initialSessionCount! > 0) {
      _sessionCount = widget.initialSessionCount!;
    }
    final parsedDate = DateTime.tryParse(widget.initialDate ?? '');
    if (parsedDate != null && parsedDate.weekday != DateTime.sunday) {
      _appointmentDate = parsedDate;
    }
    final timeMatch = RegExp(
      r'^(\d{1,2}):(\d{2})',
    ).firstMatch(widget.initialTime ?? '');
    if (timeMatch != null) {
      _appointmentTime = TimeOfDay(
        hour: int.parse(timeMatch.group(1)!),
        minute: int.parse(timeMatch.group(2)!),
      );
    }
    if (_isReschedule) _step = 2;
  }

  String _generateMedicalCode() {
    const alphabet = '0123456789ABCDEF';
    final random = Random.secure();
    final suffix = List.generate(
      12,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return 'KED-$suffix';
  }

  Future<String> _generateUniqueMedicalCode() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final candidate = _generateMedicalCode();
      try {
        final existing = await _service.client
            .from('profiles')
            .select('id')
            .eq('medical_code', candidate)
            .maybeSingle();
        if (existing == null) return candidate;
      } catch (error) {
        debugPrint('Medical code uniqueness check failed: $error');
        return candidate;
      }
    }
    return _generateMedicalCode();
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _successAnimationController.dispose();
    for (final controller in [
      _nikController,
      _medicalCodeController,
      _nameController,
      _phoneController,
      _complaintController,
      _addressController,
      _cardNameController,
      _cardNumberController,
      _cardExpiryController,
      _cardCvvController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _next() async {
    if (_isReschedule && _step == 2) {
      _updateRescheduledAppointment();
      return;
    }
    if (_step == 1 && !(_formKey.currentState?.validate() ?? false)) return;
    if (_step == 2 &&
        (_clinic.isEmpty ||
            _serviceType.isEmpty ||
            _appointmentDate == null ||
            _appointmentTime == null)) {
      _showMessage(t(context, 'reservationDate'));
      return;
    }
    if (_step == 2 && _appointmentDate?.weekday == DateTime.sunday) {
      _showMessage(t(context, 'reservationSundayClosed'));
      return;
    }
    if (_step == 2 &&
        _serviceType == _homeCareService &&
        _addressController.text.trim().isEmpty) {
      _showMessage(t(context, 'reservationHomeCareAddressHint'));
      return;
    }
    if (_step == 2 && !_therapistAvailability) {
      _showMessage(t(context, 'reservationAvailabilityRequired'));
      return;
    }
    if (_step == 2) {
      final slotAvailable = await _isAppointmentTimeAvailable(
        _appointmentDate!,
        _appointmentTime!,
        excludeAppointmentId: widget.initialAppointmentId,
      );
      if (!mounted) return;
      if (!slotAvailable) {
        _showMessage(t(context, 'reservationTimeUnavailable'));
        return;
      }
    }
    if (_step == 4) {
      setState(() => _step++);
      return;
    }
    if (_step == 5) {
      _saveReservation();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step--);
  }

  Future<void> _saveReservation() async {
    final user = _service.client.auth.currentUser;
    if (user == null) return;
    final appointmentDate = _appointmentDate!;
    final appointmentTime = _appointmentTime!;
    final slotUnavailableMessage = t(context, 'reservationTimeUnavailable');
    final reminderTitle = t(context, 'appointmentReminderTitle');
    final reminderBody = t(
      context,
      'appointmentReminderBody',
    ).replaceFirst('{time}', _formatTime(appointmentTime));
    final pendingPaymentTitle = t(context, 'paymentPendingNotificationTitle');
    final pendingPaymentBody = t(context, 'paymentPendingNotificationBody');
    final expiredTitle = t(context, 'expiredAppointmentTitle');
    final expiredBody = t(context, 'expiredAppointmentBody');
    final slotAvailable = await _isAppointmentTimeAvailable(
      appointmentDate,
      appointmentTime,
      excludeAppointmentId: widget.initialAppointmentId,
    );
    if (!mounted) return;
    if (!slotAvailable) {
      _showMessage(slotUnavailableMessage);
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'booker_id': user.id,
        'patient_is_self': _forSelf,
        'patient_nik': _nikController.text.trim(),
        'patient_medical_code': _medicalCodeController.text.trim(),
        'patient_full_name': _nameController.text.trim(),
        'patient_birth_date': _birthDate!.toIso8601String().substring(0, 10),
        'patient_phone': PhoneValidator.normalizePhoneNumber(
          _phoneController.text.trim(),
        ),
        'patient_gender': _gender,
        'clinic_name': _clinic,
        'service_type': _serviceType == _homeCareService
            ? 'Home Care'
            : 'Klinik',
        'appointment_date': _appointmentDate!.toIso8601String().substring(
          0,
          10,
        ),
        'appointment_time': _formatTime(_appointmentTime!),
        'address': _addressController.text.trim(),
        'therapist_gender_preference': _therapistGender,
        'therapist_availability_requested': _therapistAvailability,
        'session_count': _sessionCount,
        'payment_plan': _paymentPlan,
        'payment_method': _paymentMethod,
        'payment_status': _paymentPlan == 'full' ? 'paid' : 'pending',
        'appointment_status': 'upcoming',
        'patient_complaint': _complaintController.text.trim(),
        'base_price': _basePrice,
        'travel_fee': _travelFee,
        'discount_amount': _discountAmount,
        'total_amount': _totalPrice,
        'amount_due': _amountDue,
        'discount_code': _clinicPromoEligible && _serviceType == _clinicService
            ? 'NEWCLINIC10'
            : null,
        'discount_percent':
            _clinicPromoEligible && _serviceType == _clinicService ? 10 : 0,
      };

      // Allow the demo payment flow to work while older Supabase schemas
      // are being migrated by dropping only columns named in schema errors.
      String? appointmentId;
      for (var attempt = 0; attempt < 20; attempt++) {
        try {
          final insertedRows = await _service.client
              .from('appointments')
              .insert(payload)
              .select('id, booking_code');
          if (insertedRows.isNotEmpty) {
            appointmentId = insertedRows.first['id']?.toString();
          }
          break;
        } catch (error) {
          final match = RegExp(
            r"the '([^']+)' column of 'appointments'",
          ).firstMatch(error.toString());
          final missingColumn = match?.group(1);
          if (missingColumn == null || !payload.containsKey(missingColumn)) {
            rethrow;
          }
          payload.remove(missingColumn);
          if (attempt == 19) rethrow;
        }
      }
      if (appointmentId != null) {
        await NotificationService().scheduleAppointmentReminder(
          appointmentId: appointmentId,
          date: payload['appointment_date'].toString(),
          time: payload['appointment_time'].toString(),
          title: reminderTitle,
          body: reminderBody,
        );
        await NotificationService().scheduleExpirationNotice(
          appointmentId: appointmentId,
          date: payload['appointment_date'].toString(),
          time: payload['appointment_time'].toString(),
          title: expiredTitle,
          body: expiredBody,
        );
        if (_paymentPlan == 'deposit') {
          await NotificationService().showNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
            title: pendingPaymentTitle,
            body: pendingPaymentBody,
            payload: 'deposit:$appointmentId',
          );
        }
      }
      if (mounted) {
        await NotificationService().showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
          title: t(context, 'notificationReservationTitle'),
          body: t(context, 'notificationReservationBody')
              .replaceFirst(
                '{service}',
                _serviceType == _clinicService
                    ? t(context, 'klinik')
                    : t(context, 'homeCare'),
              )
              .replaceFirst('{date}', _formatDate(_appointmentDate!))
              .replaceFirst('{time}', _formatTime(_appointmentTime!)),
          payload: appointmentId == null ? null : 'appointment:$appointmentId',
        );
        setState(() => _step = 6);
        _startSuccessRedirect();
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _isAppointmentTimeAvailable(
    DateTime date,
    TimeOfDay time, {
    String? excludeAppointmentId,
  }) async {
    try {
      final serviceType = _serviceType == _clinicService
          ? 'Klinik'
          : 'Home Care';
      final query = _service.client
          .from('appointments')
          .select('id')
          .eq('appointment_date', date.toIso8601String().substring(0, 10))
          .eq('appointment_time', _formatTime(time))
          .eq('service_type', serviceType)
          .eq('clinic_name', _clinic)
          .neq('appointment_status', 'cancelled');
      if (excludeAppointmentId != null) {
        query.neq('id', excludeAppointmentId);
      }
      final rows = await query;
      return (rows as List).isEmpty;
    } catch (error) {
      debugPrint('Appointment slot validation failed: $error');
      return false;
    }
  }

  Future<void> _updateRescheduledAppointment() async {
    final appointmentId = widget.initialAppointmentId;
    if (appointmentId == null ||
        _appointmentDate == null ||
        _appointmentTime == null) {
      _showMessage(t(context, 'reservationDate'));
      return;
    }
    setState(() => _saving = true);
    try {
      final slotAvailable = await _isAppointmentTimeAvailable(
        _appointmentDate!,
        _appointmentTime!,
        excludeAppointmentId: appointmentId,
      );
      if (!mounted) return;
      if (!slotAvailable) {
        _showMessage(t(context, 'reservationTimeUnavailable'));
        return;
      }
      final reminderTitle = t(context, 'appointmentReminderTitle');
      final reminderBody = t(
        context,
        'appointmentReminderBody',
      ).replaceFirst('{time}', _formatTime(_appointmentTime!));
      await _service.client
          .from('appointments')
          .update({
            'appointment_date': _appointmentDate!.toIso8601String().substring(
              0,
              10,
            ),
            'appointment_time': _formatTime(_appointmentTime!),
          })
          .eq('id', appointmentId);
      await NotificationService().cancelAppointmentReminder(appointmentId);
      await NotificationService().scheduleAppointmentReminder(
        appointmentId: appointmentId,
        date: _appointmentDate!.toIso8601String().substring(0, 10),
        time: _formatTime(_appointmentTime!),
        title: reminderTitle,
        body: reminderBody,
      );
      if (mounted) {
        Navigator.of(context).pop({
          'appointment_date': _appointmentDate!.toIso8601String().substring(
            0,
            10,
          ),
          'appointment_time': _formatTime(_appointmentTime!),
          'updated': true,
        });
      }
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  int _packagePrice(int count) => _sessionPackagePrices[count] ?? 225000;

  int get _basePrice => _packagePrice(_sessionCount);

  int get _travelFee =>
      _serviceType == _homeCareService ? _homeCareTravelFee : 0;

  int get _discountAmount =>
      _clinicPromoEligible && _serviceType == _clinicService
      ? (_basePrice * 10 ~/ 100)
      : 0;

  int get _totalPrice => _basePrice + _travelFee - _discountAmount;

  int get _amountDue => _paymentPlan == 'deposit'
      ? (_totalPrice * _depositPercent ~/ 100)
      : _totalPrice;

  String _formatRupiah(int amount) {
    final digits = amount.toString();
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      final start = (end - 3).clamp(0, end);
      groups.insert(0, digits.substring(start, end));
    }
    return 'Rp ${groups.join('.')}';
  }

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    final date = await showDialog<DateTime>(
      context: context,
      builder: (_) => CustomDatePickerDialog(
        initialDate: _birthDate ?? DateTime(2000),
        firstDate: DateTime(1900),
        lastDate: today,
      ),
    );
    if (date != null) setState(() => _birthDate = date);
  }

  Future<void> _pickAppointmentDate() async {
    final today = DateTime.now();
    var initialDate = today.add(const Duration(days: 1));
    if (initialDate.weekday == DateTime.sunday) {
      initialDate = initialDate.add(const Duration(days: 1));
    }
    final date = await showDialog<DateTime>(
      context: context,
      builder: (_) => CustomDatePickerDialog(
        initialDate: initialDate,
        firstDate: today,
        lastDate: today.add(const Duration(days: 365)),
        selectableDay: (date) => date.weekday != DateTime.sunday,
      ),
    );
    if (!mounted) return;
    if (date == null) return;
    if (date.weekday == DateTime.sunday) {
      _showMessage(t(context, 'reservationSundayClosed'));
      return;
    }
    setState(() {
      _appointmentDate = date;
      _appointmentTime = null;
      _bookedAppointmentTimes = {};
    });
    await _loadBookedAppointmentTimes(date);
  }

  Future<void> _loadBookedAppointmentTimes(DateTime date) async {
    try {
      final serviceType = _serviceType == _clinicService
          ? 'Klinik'
          : 'Home Care';
      final rows = await _service.client
          .from('appointments')
          .select('appointment_time')
          .eq('appointment_date', date.toIso8601String().substring(0, 10))
          .eq('service_type', serviceType)
          .eq('clinic_name', _clinic)
          .eq('appointment_status', 'upcoming');
      final booked = <String>{};
      for (final row in rows as List) {
        final data = row as Map<String, dynamic>;
        final rawTime = data['appointment_time']?.toString() ?? '';
        if (rawTime.length >= 5) booked.add(rawTime.substring(0, 5));
      }
      if (mounted) setState(() => _bookedAppointmentTimes = booked);
    } catch (error) {
      debugPrint('Appointment time availability load failed: $error');
    }
  }

  Future<void> _pickAppointmentTime() async {
    if (_appointmentDate == null) {
      _showMessage(t(context, 'reservationDate'));
      return;
    }
    if (_appointmentDate!.weekday == DateTime.sunday) {
      _showMessage(t(context, 'reservationSundayClosed'));
      return;
    }
    await _loadBookedAppointmentTimes(_appointmentDate!);
    if (!mounted) return;
    final selected = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildTimeSheet(),
    );
    if (selected != null && mounted) {
      setState(() => _appointmentTime = selected);
    }
  }

  Widget _buildTimeSheet() {
    final closingHour = _appointmentDate!.weekday == DateTime.saturday
        ? 18
        : 20;
    final slots = [
      for (var hour = 8; hour < closingHour; hour++)
        TimeOfDay(hour: hour, minute: 0),
    ];
    return _selectionSheet(
      t(context, 'reservationTime'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 3.5,
        children: slots.map((slot) {
          final selected = _appointmentTime?.hour == slot.hour;
          final slotDateTime = DateTime(
            _appointmentDate!.year,
            _appointmentDate!.month,
            _appointmentDate!.day,
            slot.hour,
          );
          final isPast =
              _appointmentDate!.year == DateTime.now().year &&
              _appointmentDate!.month == DateTime.now().month &&
              _appointmentDate!.day == DateTime.now().day &&
              !slotDateTime.isAfter(DateTime.now());
          final isBooked = _bookedAppointmentTimes.contains(
            '${slot.hour.toString().padLeft(2, '0')}:00',
          );
          final isAvailable = !isPast && !isBooked;
          return InkWell(
            onTap: isAvailable ? () => Navigator.of(context).pop(slot) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: !isAvailable
                    ? const Color(0xFFE9EEEE)
                    : selected
                    ? const Color(0xFFDDF5F2)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !isAvailable
                      ? const Color(0xFFD5DEDE)
                      : selected
                      ? _teal
                      : const Color(0xFFE3E9E9),
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Text(
                '${slot.format(context)} WIB',
                style: TextStyle(
                  color: !isAvailable
                      ? _muted
                      : selected
                      ? _tealDark
                      : _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _selectionSheet(String title, Widget content) => SafeArea(
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
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
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    ),
  );

  Future<void> _pickClinic() async {
    final locations = _serviceType == _homeCareService
        ? _homeCareLocations
        : [_clinicLocation];
    final clinic = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _selectionSheet(
        _serviceType == _homeCareService
            ? t(context, 'reservationHomeCareLocation')
            : t(context, 'reservationClinic'),
        Column(
          children: locations
              .map(
                (location) => _sheetOption(
                  location.name,
                  _serviceType == _homeCareService
                      ? Icons.home_work_rounded
                      : Icons.local_hospital_rounded,
                  subtitle: location.address,
                  mapUrl: location.mapUrl,
                ),
              )
              .toList(),
        ),
      ),
    );
    if (clinic == null) return;
    final selected = locations.firstWhere(
      (location) => location.name == clinic,
    );
    setState(() {
      _clinic = selected.name;
    });
  }

  Future<void> _openClinicMap() async {
    final opened = await launchUrl(
      Uri.parse(_clinicLocation.mapUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showMessage('Google Maps tidak dapat dibuka.');
    }
  }

  Widget _sheetOption(
    String label,
    IconData icon, {
    String? subtitle,
    String? mapUrl,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: () => Navigator.of(context).pop(label),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _clinic == label ? _teal : const Color(0xFFE3EAE9),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: _teal, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_clinic == label)
              const Icon(Icons.check_circle_rounded, color: _teal, size: 20),
            if (mapUrl != null)
              IconButton(
                tooltip: 'Buka di Maps',
                icon: const Icon(Icons.map_outlined, color: _teal),
                onPressed: () => launchUrl(
                  Uri.parse(mapUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        _showMessage(t(context, 'locationServiceDisabled'));
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showMessage(t(context, 'locationPermissionDenied'));
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      await _setMapLocation(point);
    } catch (error) {
      debugPrint('Current location failed: $error');
      if (!mounted) return;
      _showMessage(t(context, 'locationUnavailable'));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _setMapLocation(LatLng point) async {
    setState(() => _mapCenter = point);
    _mapController.move(point, 16);
    try {
      final places = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (places.isEmpty || !mounted) return;
      final place = places.first;
      final address = [
        place.street,
        place.subLocality,
        place.locality,
        place.administrativeArea,
      ].where((part) => part != null && part.trim().isNotEmpty).join(', ');
      if (address.isNotEmpty) _addressController.text = address;
    } catch (error) {
      debugPrint('Reverse geocoding failed: $error');
    }
  }

  Future<void> _openExpandedMap() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: _background,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t(context, 'reservationMapTitle'),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: t(context, 'closeBtn'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                t(context, 'reservationMapHint'),
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildMapPreview(
                  height: 410,
                  controller: MapController(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(t(context, 'closeBtn')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    CustomBottomSheet.show(
      context,
      type: BottomSheetType.error,
      title: t(context, 'failedTitle'),
      subtitle: message,
      singleButtonText: t(context, 'closeBtn'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: _step == 6
          ? null
          : AppBar(
              backgroundColor: _background,
              elevation: 0,
              centerTitle: true,
              title: Text(
                t(context, 'reservationTitle'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _back,
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : _step == 6
          ? SafeArea(child: _buildSuccess())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildProgress(),
                  Expanded(
                    child: SingleChildScrollView(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: _buildStep(),
                    ),
                  ),
                  _buildBottomAction(),
                ],
              ),
            ),
    );
  }

  Widget _buildProgress() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${(_step + 1).clamp(1, 6).toString().padLeft(2, '0')} / 06',
              style: const TextStyle(
                color: _teal,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _stepTitle,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: List.generate(6, (index) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                margin: EdgeInsets.only(right: index == 5 ? 0 : 6),
                decoration: BoxDecoration(
                  color: index <= _step ? _teal : const Color(0xFFE1E9E8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
      ],
    ),
  );

  String get _stepTitle => switch (_step) {
    0 => t(context, 'reservationForWho'),
    1 => t(context, 'reservationStagePatient'),
    2 => t(context, 'reservationStageSchedule'),
    3 => t(context, 'reservationStageSession'),
    4 => t(context, 'reservationStagePayment'),
    5 => t(context, 'reservationPayNow'),
    6 => t(context, 'reservationSuccess'),
    _ => t(context, 'reservationStagePayment'),
  };

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildModeStep();
      case 1:
        return _buildPatientStep();
      case 2:
        return _buildScheduleStep();
      case 3:
        return _buildSessionStep();
      case 4:
        return _buildPaymentStep();
      case 5:
        return _buildPaymentDetailStep();
      default:
        return _buildPaymentStep();
    }
  }

  Widget _buildModeStep() => _section(
    t(context, 'reservationForWho'),
    Column(
      children: [
        _choiceButton(t(context, 'reservationForSelf'), true),
        const SizedBox(height: 10),
        _choiceButton(t(context, 'reservationForOther'), false),
      ],
    ),
  );

  Widget _choiceButton(String label, bool self) => InkWell(
    onTap: () => setState(() => _forSelf = self),
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: _forSelf == self ? const Color(0xFFDDF5F2) : Colors.white,
        border: Border.all(color: _forSelf == self ? _teal : Colors.white),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _forSelf == self ? _tealDark : _ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _buildPatientStep() => _section(
    t(context, 'reservationPatientData'),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, 'reservationPatientDataDesc'),
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _field(
          _nikController,
          t(context, 'reservationNik'),
          readOnly: _forSelf,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 16,
          validator: (value) =>
              value?.trim().length == 16 ? null : t(context, 'nikLengthError'),
          icon: Icons.badge_outlined,
        ),
        _field(
          _medicalCodeController,
          t(context, 'reservationMedicalCode'),
          readOnly: true,
          icon: Icons.qr_code_2_rounded,
        ),
        _field(
          _nameController,
          t(context, 'reservationFullName'),
          readOnly: _forSelf,
          icon: Icons.person_outline_rounded,
        ),
        _dateField(
          t(context, 'reservationBirthDate'),
          _birthDate,
          _pickBirthDate,
          icon: Icons.calendar_today_outlined,
        ),
        _field(
          _phoneController,
          t(context, 'reservationPhone'),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[+0-9]')),
          ],
          maxLength: 14,
          validator: (value) =>
              PhoneValidator.isValidIndonesianPhone(value ?? '')
              ? null
              : t(context, 'validPhoneError'),
          icon: Icons.phone_outlined,
        ),
        _segmented(
          t(context, 'reservationGender'),
          [
            ('male', t(context, 'reservationMale')),
            ('female', t(context, 'reservationFemale')),
          ],
          _gender,
          (value) => setState(() => _gender = value),
        ),
        _field(
          _complaintController,
          t(context, 'reservationComplaint'),
          hint: t(context, 'reservationComplaintHint'),
          maxLines: 3,
          validator: (value) {
            final complaint = value?.trim() ?? '';
            return complaint.length < 10
                ? t(context, 'reservationComplaintMinLength')
                : null;
          },
          icon: Icons.notes_outlined,
        ),
      ],
    ),
  );

  Widget _buildScheduleStep() => _section(
    t(context, 'reservationStageSchedule'),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, 'reservationScheduleHint'),
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        _serviceChoice(),
        _selectionField(
          t(context, 'reservationClinic'),
          _clinic,
          t(context, 'reservationClinic'),
          Icons.location_city_outlined,
          _isReschedule ? null : _pickClinic,
        ),
        _dateField(
          t(context, 'reservationDate'),
          _appointmentDate,
          _pickAppointmentDate,
          icon: Icons.calendar_today_outlined,
        ),
        _timeField(),
        if (_serviceType == _homeCareService) _buildHomeCareLocation(),
        if (_serviceType == _clinicService) ...[
          const SizedBox(height: 20),
          _buildClinicLocation(),
        ],
        InkWell(
          onTap: () =>
              setState(() => _therapistAvailability = !_therapistAvailability),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _therapistAvailability,
                  activeColor: _teal,
                  onChanged: (value) =>
                      setState(() => _therapistAvailability = value ?? false),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t(context, 'reservationTherapistAvailability'),
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildMapPreview({double height = 142, MapController? controller}) =>
      Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: height,
              child: FlutterMap(
                mapController: controller ?? _mapController,
                options: MapOptions(
                  initialCenter: _mapCenter,
                  initialZoom: 14,
                  onTap: _isReschedule
                      ? null
                      : (_, point) => _setMapLocation(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.kedota.physiotherapy',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _mapCenter,
                        width: 42,
                        height: 42,
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: _teal,
                          size: 38,
                        ),
                      ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              child: IconButton(
                tooltip: t(context, 'reservationMapExpand'),
                onPressed: _openExpandedMap,
                icon: const Icon(Icons.fullscreen_rounded, color: _tealDark),
              ),
            ),
          ),
        ],
      );

  Widget _buildHomeCareLocation() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _field(
        _addressController,
        t(context, 'reservationAddress'),
        hint: t(context, 'reservationHomeCareAddressHint'),
        icon: Icons.location_on_outlined,
        readOnly: _isReschedule,
      ),
      const SizedBox(height: 12),
      _buildMapPreview(),
      InkWell(
        onTap: _isReschedule || _locating ? null : _useCurrentLocation,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _tealDark,
                      ),
                    )
                  : const Icon(
                      Icons.my_location_rounded,
                      size: 16,
                      color: _tealDark,
                    ),
              const SizedBox(width: 7),
              Text(
                t(context, 'reservationUseCurrentLocation'),
                style: const TextStyle(
                  color: _tealDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildClinicLocation() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF8F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC9E9E6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_rounded, color: _tealDark, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _clinicLocation.address,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _buildMapPreview(),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _openClinicMap,
          icon: const Icon(Icons.directions_rounded, size: 17),
          label: const Text('Arahkan ke Google Maps'),
          style: TextButton.styleFrom(foregroundColor: _tealDark),
        ),
      ),
    ],
  );

  Widget _serviceChoice() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, 'reservationService'),
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _serviceCard(
                value: _homeCareService,
                title: t(context, 'homeCare'),
                description: t(context, 'homeCareDesc'),
                icon: Icons.home_rounded,
                color: _tealDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _serviceCard(
                value: _clinicService,
                title: t(context, 'klinik'),
                description: t(context, 'klinikDesc'),
                icon: Icons.local_hospital_rounded,
                color: const Color(0xFF5B5FC8),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _serviceCard({
    required String value,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final selected = _serviceType == value;
    return InkWell(
      onTap: _isReschedule
          ? null
          : () => setState(() {
              _serviceType = value;
              _clinic = value == _clinicService ? _clinicLocation.name : '';
              if (_serviceType != _homeCareService) _addressController.clear();
            }),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 13, 10, 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : const Color(0xFFE1E9E8),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: selected ? 0.16 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const Spacer(),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? color : const Color(0xFFB4C5C5),
                  size: 19,
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 10, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStep() => _flatSection(
    t(context, 'reservationChooseSession'),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, 'reservationSessionHint'),
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _sessionChoice(),
        const SizedBox(height: 18),
        Text(
          t(context, 'reservationPaymentPlan'),
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        Row(
          children: [
            Expanded(
              child: _optionTile(
                t(context, 'reservationPaymentPlanFull'),
                _paymentPlan == 'full',
                () => setState(() => _paymentPlan = 'full'),
                compact: true,
              ),
            ),
            Expanded(
              child: _optionTile(
                t(context, 'reservationPaymentPlanDeposit'),
                _paymentPlan == 'deposit',
                () => setState(() => _paymentPlan = 'deposit'),
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildOrderSummary(),
        const SizedBox(height: 12),
        Text(
          t(context, 'reservationPaymentDeadline'),
          style: const TextStyle(
            color: Color(0xFFC65353),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _sessionChoice() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, 'reservationChooseSession'),
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.25,
          children: [1, 3, 6, 9].map((count) => _sessionCard(count)).toList(),
        ),
      ],
    ),
  );

  Widget _sessionCard(int count) {
    final selected = _sessionCount == count;
    final price = _packagePrice(count);
    return InkWell(
      onTap: () => setState(() => _sessionCount = count),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDDF5F2) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _teal : const Color(0xFFE1E9E8),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _teal.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _teal : const Color(0xFFEAF3F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : _tealDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, 'reservationSessionUnit'),
                    style: TextStyle(
                      color: selected ? _tealDark : _ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatRupiah(price),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? _teal : const Color(0xFFB4C5C5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final date = _appointmentDate == null
        ? '-'
        : _formatDate(_appointmentDate!);
    final time = _appointmentTime?.format(context) ?? '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, 'reservationOrderSummary'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        _summaryLine(t(context, 'reservationFullName'), _nameController.text),
        _summaryLine(
          t(context, 'reservationService'),
          _serviceType == _homeCareService
              ? t(context, 'homeCare')
              : t(context, 'klinik'),
        ),
        if (_clinicPromoEligible && _serviceType == _clinicService)
          _summaryLine(
            t(context, 'reservationDiscount'),
            '-10%',
            color: _tealDark,
          ),
        _summaryLine(t(context, 'reservationDate'), '$date, $time'),
        const SizedBox(height: 12),
        Text(
          t(context, 'reservationPaymentSummary'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        _summaryLine(
          t(context, 'reservationBasePrice'),
          _formatRupiah(_basePrice),
        ),
        _summaryLine(
          t(context, 'reservationTravelFee'),
          _formatRupiah(_travelFee),
        ),
        if (_discountAmount > 0)
          _summaryLine(
            t(context, 'reservationDiscountAmount'),
            '- ${_formatRupiah(_discountAmount)}',
            color: _tealDark,
          ),
        const Divider(height: 16),
        _summaryLine(
          t(context, 'reservationTotal'),
          _formatRupiah(_totalPrice),
          bold: true,
        ),
        _summaryLine(
          t(context, 'reservationAmountDue'),
          _formatRupiah(_amountDue),
          bold: true,
        ),
      ],
    );
  }

  Widget _summaryLine(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _muted,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value.isEmpty ? '-' : value,
          style: TextStyle(
            fontSize: 11,
            color: color ?? _ink,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _buildPaymentStep() => _flatSection(
    t(context, 'reservationChoosePayment'),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(context, 'reservationPaymentAvailable'),
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        _paymentGroup(t(context, 'reservationPaymentQrisWallet'), [
          _paymentOption(
            'qris',
            t(context, 'reservationPaymentQris'),
            Icons.qr_code_2_rounded,
          ),
          _paymentOption('ovo', 'OVO', Icons.account_balance_wallet_rounded),
          _paymentOption(
            'gopay',
            'Gopay',
            Icons.account_balance_wallet_rounded,
          ),
          _paymentOption(
            'shopeepay',
            'Shopee Pay',
            Icons.shopping_bag_outlined,
          ),
        ]),
        const SizedBox(height: 18),
        _paymentGroup(t(context, 'reservationPaymentBankTransfer'), [
          _paymentOption('bca', 'BCA', Icons.account_balance_rounded),
          _paymentOption('bni', 'BNI', Icons.account_balance_rounded),
          _paymentOption('bri', 'BRI', Icons.account_balance_rounded),
          _paymentOption('permata', 'PERMATA', Icons.account_balance_rounded),
          _paymentOption('mandiri', 'Mandiri', Icons.account_balance_rounded),
        ]),
        const SizedBox(height: 18),
        _paymentGroup(t(context, 'reservationPaymentCardDebit'), [
          _paymentOption(
            'card',
            'VISA   Mastercard   JCB   GPN',
            Icons.credit_card_rounded,
          ),
        ]),
      ],
    ),
  );

  Widget _buildPaymentDetailStep() {
    final titleKey = switch (_paymentMethod) {
      'qris' => 'reservationPaymentInstructionQris',
      'ovo' || 'gopay' || 'shopeepay' => 'reservationPaymentInstructionWallet',
      'bca' ||
      'bni' ||
      'bri' ||
      'permata' ||
      'mandiri' => 'reservationPaymentInstructionBank',
      _ => 'reservationPaymentInstructionCard',
    };
    return _paymentDetailSection(t(context, titleKey), switch (_paymentMethod) {
      'qris' => _buildQrisDetail(),
      'ovo' || 'gopay' || 'shopeepay' => _buildWalletDetail(),
      'bca' || 'bni' || 'bri' || 'permata' || 'mandiri' => _buildBankDetail(),
      _ => _buildCardDetail(),
    });
  }

  Widget _paymentDetailSection(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
      const SizedBox(height: 10),
      child,
    ],
  );

  Widget _paymentTotal() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t(context, 'reservationTotal'),
        style: const TextStyle(color: _muted, fontSize: 11),
      ),
      const SizedBox(height: 4),
      Text(
        _formatRupiah(_amountDue),
        style: const TextStyle(
          color: _teal,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _buildQrisDetail() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t(context, 'reservationPaymentHowTo'),
        style: const TextStyle(color: _muted, fontSize: 10),
      ),
      const SizedBox(height: 4),
      _paymentTotal(),
      const SizedBox(height: 14),
      Center(
        child: Container(
          width: 190,
          height: 190,
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: const Center(
            child: Icon(
              Icons.qr_code_2_rounded,
              size: 160,
              color: Colors.black,
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      _paymentTutorial(
        id: 'qris',
        title: t(context, 'reservationPaymentHowTo'),
        steps: [
          t(context, 'reservationQrisStep1'),
          t(context, 'reservationQrisStep2'),
          t(context, 'reservationQrisStep3'),
        ],
      ),
      const SizedBox(height: 8),
      Center(
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Unduh QR'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _teal,
            side: const BorderSide(color: Color(0xFFE0EAEA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildWalletDetail() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded, color: _teal),
          const SizedBox(width: 8),
          Text(
            _paymentMethod.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _paymentTotal(),
      const SizedBox(height: 10),
      Text(
        'Selesaikan pembayaran sebelum batas waktu yang ditentukan.',
        style: const TextStyle(color: _muted, fontSize: 11),
      ),
      const SizedBox(height: 14),
      _paymentTutorial(
        id: 'wallet',
        title: t(context, 'reservationPaymentHowTo'),
        steps: [
          t(context, 'reservationWalletStep1'),
          t(context, 'reservationWalletStep2'),
          t(context, 'reservationWalletStep3'),
        ],
      ),
    ],
  );

  Widget _buildBankDetail() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.account_balance_rounded, color: _teal),
          const SizedBox(width: 8),
          Text(
            _paymentMethod.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _paymentTotal(),
      const SizedBox(height: 16),
      _detailValue(
        t(context, 'reservationVirtualAccount'),
        '8808 1234 5678 9012',
        onCopy: () => _copyPaymentValue('8808123456789012'),
      ),
      const SizedBox(height: 16),
      _paymentTutorial(
        id: 'mbca',
        title: t(context, 'reservationBankMbca'),
        steps: [
          t(context, 'reservationBankStep1'),
          t(context, 'reservationBankStep2'),
          t(context, 'reservationBankStep3'),
        ],
      ),
      const SizedBox(height: 8),
      _paymentTutorial(
        id: 'ibanking',
        title: t(context, 'reservationBankIbanking'),
        steps: [
          t(context, 'reservationBankStep1'),
          t(context, 'reservationBankStep2'),
          t(context, 'reservationBankStep3'),
        ],
      ),
      const SizedBox(height: 8),
      _paymentTutorial(
        id: 'atm',
        title: t(context, 'reservationBankAtm'),
        steps: [
          t(context, 'reservationBankStep1'),
          t(context, 'reservationBankStep2'),
          t(context, 'reservationBankStep3'),
        ],
      ),
    ],
  );

  Widget _buildCardDetail() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _paymentTotal(),
      const SizedBox(height: 12),
      _field(_cardNameController, t(context, 'reservationCardholder')),
      _field(
        _cardNumberController,
        t(context, 'reservationCardNumber'),
        keyboardType: TextInputType.number,
      ),
      Row(
        children: [
          Expanded(
            child: _field(
              _cardExpiryController,
              t(context, 'reservationCardExpiry'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _field(
              _cardCvvController,
              t(context, 'reservationCardCvv'),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _paymentTutorial(
        id: 'card',
        title: t(context, 'reservationPaymentHowTo'),
        steps: [
          t(context, 'reservationCardStep1'),
          t(context, 'reservationCardStep2'),
          t(context, 'reservationCardStep3'),
        ],
      ),
    ],
  );

  Future<void> _copyPaymentValue(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(context, 'reservationAccountCopied')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _detailValue(String label, String value, {VoidCallback? onCopy}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onCopy != null)
                IconButton(
                  tooltip: t(context, 'reservationCopyAccount'),
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, color: _teal),
                ),
            ],
          ),
        ],
      );

  Widget _paymentTutorial({
    required String id,
    required String title,
    required List<String> steps,
  }) {
    final expanded = _expandedPaymentTutorial == id;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _expandedPaymentTutorial = expanded ? null : id),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: _teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _muted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(38, 0, 14, 14),
              child: Column(
                children: [
                  for (var index = 0; index < steps.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}.',
                            style: const TextStyle(
                              color: _tealDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              steps[index],
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
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
        ],
      ),
    );
  }

  Widget _paymentGroup(String title, List<Widget> options) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 8),
      ...options,
    ],
  );

  Widget _flatSection(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );

  Widget _paymentOption(String value, String label, IconData icon) {
    final selected = _paymentMethod == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = value),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDDF5F2) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _teal : const Color(0xFFE6ECEB),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: selected
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x0D172B2D),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: selected ? _tealDark : _muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                _formatRupiah(_amountDue),
                style: TextStyle(
                  color: selected ? _tealDark : _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionTile(
    String label,
    bool selected,
    VoidCallback onTap, {
    bool compact = false,
  }) {
    final child = compact
        ? Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFDDF5F2) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? _teal : const Color(0xFFE6ECEB),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: selected ? _teal : const Color(0xFFB7C2C2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? _tealDark : _muted,
                    ),
                  ),
                ),
              ],
            ),
          )
        : Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? _teal : _muted,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 14)),
              ),
            ],
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 2 : 4,
          vertical: compact ? 4 : 8,
        ),
        child: child,
      ),
    );
  }

  Widget _section(String title, Widget child) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 520),
    curve: Curves.easeOutCubic,
    builder: (context, value, animatedChild) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - value)),
        child: animatedChild,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D172B2D),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    IconData? icon,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      validator:
          validator ??
          (value) => value == null || value.trim().isEmpty ? label : null,
      decoration: _decoration(label, hint, icon: icon).copyWith(
        filled: true,
        fillColor: readOnly ? const Color(0xFFE7ECEC) : Colors.white,
        suffixIcon: readOnly
            ? const Icon(Icons.lock_outline_rounded, size: 17, color: _muted)
            : null,
      ),
    ),
  );

  InputDecoration _decoration(String label, String? hint, {IconData? icon}) =>
      InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: icon == null ? null : Icon(icon, size: 19, color: _muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE1E9E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE1E9E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _teal, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
      );

  Widget _dateField(
    String label,
    DateTime? value,
    VoidCallback onTap, {
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: _decoration(label, null, icon: icon),
        child: Text(
          value == null ? '--/--/----' : _formatDate(value),
          style: TextStyle(color: value == null ? _muted : _ink),
        ),
      ),
    ),
  );

  Widget _timeField() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: InkWell(
      onTap: _pickAppointmentTime,
      child: InputDecorator(
        decoration: _decoration(
          t(context, 'reservationTime'),
          null,
          icon: Icons.access_time_outlined,
        ),
        child: Text(
          _appointmentTime == null
              ? '--:-- WIB'
              : '${_appointmentTime!.format(context)} WIB',
        ),
      ),
    ),
  );

  Widget _selectionField(
    String label,
    String value,
    String placeholder,
    IconData icon,
    VoidCallback? onTap,
  ) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _decoration(label, placeholder, icon: icon).copyWith(
          suffixIcon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _teal,
          ),
        ),
        child: Text(
          value.isEmpty ? placeholder : value,
          style: TextStyle(
            color: value.isEmpty ? _muted : _ink,
            fontSize: 13,
            fontWeight: value.isEmpty ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ),
    ),
  );

  Widget _segmented(
    String label,
    List<(String, String)> values,
    String selected,
    ValueChanged<String> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
        Row(
          children: values
              .map(
                (value) => Expanded(
                  child: _optionTile(
                    value.$2,
                    selected == value.$1,
                    () => onChanged(value.$1),
                    compact: true,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );

  Widget _buildBottomAction() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: _teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 5,
            shadowColor: _teal.withValues(alpha: 0.28),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      t(
                        context,
                        _step == 5 ? 'reservationPayNow' : 'reservationNext',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
      ),
    ),
  );

  Widget _buildSuccess() => Column(
    children: [
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _successFade,
                  child: ScaleTransition(
                    scale: _successScale,
                    child: Container(
                      width: 116,
                      height: 116,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE0F5EE),
                        border: Border.all(
                          color: const Color(0xFFC7EBDD),
                          width: 8,
                        ),
                      ),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF41B883),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 58,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  t(context, 'paymentSuccessTitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(context, 'paymentSuccessDesc')
                      .replaceFirst('{date}', _formatDate(_appointmentDate!))
                      .replaceFirst(
                        '{clinic}',
                        _clinic.replaceFirst('Klinik Kedota ', ''),
                      ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Text(
          t(
            context,
            'paymentReturningHome',
          ).replaceFirst('{seconds}', '$_successCountdown'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 11),
        ),
      ),
    ],
  );

  void _startSuccessRedirect() {
    _successTimer?.cancel();
    _successCountdown = 3;
    _successAnimationController
      ..reset()
      ..forward();
    _successTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_successCountdown <= 1) {
        timer.cancel();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 2)),
          (route) => false,
        );
        return;
      }
      setState(() => _successCountdown--);
    });
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
