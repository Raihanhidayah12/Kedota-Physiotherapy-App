import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_language.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/notification_service.dart';
import '../../utils/app_snackbar.dart';
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

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 19) digits = digits.substring(0, 19);
    final groups = <String>[];
    for (var start = 0; start < digits.length; start += 4) {
      groups.add(digits.substring(start, min(start + 4, digits.length)));
    }
    final text = groups.join('  ');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);
    final text = digits.length > 2
        ? '${digits.substring(0, 2)}/${digits.substring(2)}'
        : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ServiceLocation {
  final String name;
  final String address;
  final String mapUrl;
  final LatLng point;

  const _ServiceLocation({
    required this.name,
    required this.address,
    required this.mapUrl,
    required this.point,
  });
}

const _clinicLocation = _ServiceLocation(
  name: 'Klinik Kedota Malang',
  address:
      'Blok Kelapa No.29, Tunggulwulung, Kec. Lowokwaru, Kota Malang, Jawa Timur 65143',
  mapUrl: 'https://maps.app.goo.gl/6RoeDr21WjTfMjo86',
  point: LatLng(-7.92952, 112.61989), // Malang, Jawa Timur
);



// Map tile URLs with cascading fallback system
// Primary: Google Maps tiles (requires API key) - configured for Indonesia
String get _googleMapsTiles => 
    'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&key=${dotenv.env['GOOGLE_MAPS_API_KEY'] ?? ''}&region=ID&language=id';

// Secondary: Geoapify tiles (requires API key) 
String get _geoapifyTiles => 
    'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=${dotenv.env['GEOAPIFY_API_KEY'] ?? ''}';

// Tertiary: OpenStreetMap tiles (free, no API key required)
const String _openStreetMapTiles = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

// Google Geocoding API URL  
String get _googleGeocodingUrl => 
    'https://maps.googleapis.com/maps/api/geocode/json?key=${dotenv.env['GOOGLE_MAPS_API_KEY'] ?? ''}';

// Geoapify Geocoding API key
String get _geoapifyKey => dotenv.env['GEOAPIFY_API_KEY'] ?? '';

// Kota yang tersedia untuk dipilih di step 3
const _availableCities = [
  'Malang',
  'Surabaya',
  'Sidoarjo',
  'Surakarta',
  'Yogyakarta',
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
    with TickerProviderStateMixin {
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
  final _qrBoundaryKey = GlobalKey();

  int _step = 0;
  bool _forSelf = true;
  bool _loading = true;
  bool _saving = false;
  bool _downloadingQr = false;
  DateTime? _birthDate;
  DateTime? _appointmentDate;
  DateTime? _paymentDeadlineUtc;
  Timer? _paymentDeadlineTimer;
  TimeOfDay? _appointmentTime;
  String _gender = 'male';
  final String _therapistGender = 'any';
  String _clinic = '';
  String _serviceType = '';
  String _selectedCity = ''; // Kota yang dipilih di step 3
  String _paymentMethod = 'qris';
  String _paymentPlan = 'full';
  int? _sessionCount;
  bool _therapistAvailability = false;
  bool _clinicPromoEligible = false;
  String? _expandedPaymentTutorial;
  Timer? _successTimer;
  Timer? _geocodeDebounce;
  int _successCountdown = 3;
  late final AnimationController _successAnimationController;
  late final AnimationController _stageEntranceController;
  late final Animation<double> _successScale;
  late final Animation<double> _successFade;
  Set<String> _bookedAppointmentTimes = {};
  bool _locating = false;
  LatLng _mapCenter = const LatLng(-7.9839, 112.6214); // Malang, Jawa Timur
  final _mapPointNotifier = ValueNotifier<LatLng>(const LatLng(-7.9839, 112.6214));
  
  // Track current tile service for fallback system
  int _currentTileService = 0; // 0=Google, 1=Geoapify, 2=OpenStreetMap
  
  // Get current tile URL with fallback system
  String get _currentTileUrl {
    switch (_currentTileService) {
      case 0:
        return _googleMapsTiles;
      case 1:
        return _geoapifyTiles;
      case 2:
        return _openStreetMapTiles;
      default:
        return _openStreetMapTiles; // Ultimate fallback
    }
  }
  
  // Try next tile service when current one fails
  void _fallbackToNextTileService() {
    if (_currentTileService < 2) {
      _currentTileService++;
      debugPrint('Falling back to tile service $_currentTileService');
      setState(() {}); // Rebuild to use new tile service
    }
  }

  bool get _isReschedule => widget.initialDate != null;
  bool get _isClinicService => _serviceType == _clinicService;
  bool get _isPaymentDeadlineExpired =>
      _paymentDeadlineUtc != null &&
      !DateTime.now().toUtc().isBefore(_paymentDeadlineUtc!);
  LatLng get _displayMapCenter =>
      _isClinicService ? _clinicLocation.point : _mapCenter;

  /// Format alamat untuk tampilan yang bersih seperti Google Maps
  String _formatAddressForDisplay(String rawAddress) {
    // Hapus bagian yang tidak perlu: Indonesia, country codes, dll
    String formatted = rawAddress
        .replaceAll(RegExp(r',\s*Indonesia\s*$', caseSensitive: false), '') // Hapus ", Indonesia" di akhir
        .replaceAll(RegExp(r',\s*ID\s*$'), '') // Hapus ", ID" di akhir  
        .replaceAll(RegExp(r',\s*JI\s*,\s*Indonesia\s*$'), '') // Hapus ", JI, Indonesia" 
        .replaceAll(RegExp(r',\s*Jawa Timur\s*,\s*Indonesia\s*$'), ', Jawa Timur') // Jaga "Jawa Timur"
        .replaceAll(RegExp(r',\s*East Java\s*,\s*Indonesia\s*$'), ', Jawa Timur') // Convert English
        .trim();

    // Hapus koma berlebih di akhir
    if (formatted.endsWith(',')) {
      formatted = formatted.substring(0, formatted.length - 1).trim();
    }

    return formatted;
  }

  @override
  void initState() {
    super.initState();
    _successAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _stageEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..forward();
    _successScale = CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    );
    _successFade = CurvedAnimation(
      parent: _successAnimationController,
      curve: const Interval(0, 0.42, curve: Curves.easeOut),
    );
    _loadProfile();
    _addressController.addListener(_onAddressChanged);
  }

  void _onAddressChanged() {
    // Rebuild supaya floating label ikut update
    if (mounted) setState(() {});
    _geocodeDebounce?.cancel();
    if (_isClinicService) return;
    _geocodeDebounce = Timer(const Duration(milliseconds: 900), () {
      final text = _addressController.text.trim();
      if (!_isClinicService && text.length >= 10) _geocodeAddress(text);
    });
  }

  Future<void> _geocodeAddress(String address) async {
    if (_isClinicService) return;
    
    // Primary: Google Geocoding API
    try {
      debugPrint('Attempting forward geocoding with Google Maps API');
      final dio = Dio();
      final encodedAddress = Uri.encodeComponent('$address, Indonesia');
      final response = await dio
          .get<Map<String, dynamic>>(
            '$_googleGeocodingUrl&address=$encodedAddress&region=ID&language=id&components=country:ID',
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted || _isClinicService) return;
      final results = (response.data?['results'] as List?) ?? [];
      if (results.isNotEmpty) {
        final firstResult = results.first as Map<String, dynamic>;
        final geometry = firstResult['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;
        if (location != null) {
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          final point = LatLng(lat, lng);
          setState(() => _mapCenter = point);
          _mapPointNotifier.value = point;
          try {
            _mapController.move(point, 16);
          } catch (_) {}
          debugPrint('Google forward geocoding successful');
          return; // Success, exit early
        }
      }
    } catch (error) {
      debugPrint('Google forward geocoding failed: $error');
    }

    // Secondary: Geoapify Geocoding API
    try {
      debugPrint('Attempting forward geocoding with Geoapify API');
      final dio = Dio();
      final encodedAddress = Uri.encodeComponent('$address, Indonesia');
      final response = await dio
          .get<Map<String, dynamic>>(
            'https://api.geoapify.com/v1/geocode/search?text=$encodedAddress&apiKey=$_geoapifyKey&lang=id&limit=1&filter=countrycode:id',
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted || _isClinicService) return;
      final features = (response.data?['features'] as List?) ?? [];
      if (features.isNotEmpty) {
        final firstFeature = features.first as Map<String, dynamic>;
        final geometry = firstFeature['geometry'] as Map<String, dynamic>?;
        final coordinates = geometry?['coordinates'] as List?;
        if (coordinates != null && coordinates.length >= 2) {
          final lng = (coordinates[0] as num).toDouble();
          final lat = (coordinates[1] as num).toDouble();
          final point = LatLng(lat, lng);
          setState(() => _mapCenter = point);
          _mapPointNotifier.value = point;
          try {
            _mapController.move(point, 16);
          } catch (_) {}
          debugPrint('Geoapify forward geocoding successful');
          return; // Success, exit early
        }
      }
    } catch (error) {
      debugPrint('Geoapify forward geocoding failed: $error');
    }

    // Tertiary: Nominatim (OpenStreetMap) - free, unlimited
    try {
      debugPrint('Attempting forward geocoding with Nominatim API');
      final dio = Dio();
      dio.options.headers['User-Agent'] = 'KedotaApp/1.0';
      final response = await dio
          .get<List<dynamic>>(
            'https://nominatim.openstreetmap.org/search',
            queryParameters: {
              'q': '$address, Indonesia',
              'format': 'json',
              'limit': 1,
              'countrycodes': 'id',
              'accept-language': 'id',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (!mounted || _isClinicService) return;
      final data = response.data;
      if (data != null && data.isNotEmpty) {
        final first = data.first as Map<String, dynamic>;
        final lat = double.tryParse(first['lat']?.toString() ?? '');
        final lon = double.tryParse(first['lon']?.toString() ?? '');
        if (lat != null && lon != null) {
          final point = LatLng(lat, lon);
          setState(() => _mapCenter = point);
          _mapPointNotifier.value = point;
          try {
            _mapController.move(point, 16);
          } catch (_) {}
          debugPrint('Nominatim forward geocoding successful');
          return; // Success, exit early
        }
      }
    } catch (error) {
      debugPrint('Nominatim forward geocoding fallback failed: $error');
    }
    
    debugPrint('All forward geocoding services failed');
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
          RegExp(r'^KDT-[A-F0-9]{12}$').hasMatch(savedMedicalCode)
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
      final profileGender = profile?['gender']?.toString().toLowerCase();
      if (profileGender == 'male' || profileGender == 'female') {
        _gender = profileGender!;
      }
    } catch (error) {
      debugPrint('Reservation profile load failed: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _stageEntranceController.forward(from: 0);
      }
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
      // Derive city from clinic name
      for (final city in _availableCities) {
        if (_clinic.contains(city)) {
          _selectedCity = city;
          break;
        }
      }
    }
    if (_selectedCity.isEmpty && _serviceType == _clinicService) {
      _selectedCity = 'Malang';
    }
    if (_serviceType == _clinicService) {
      _mapCenter = _clinicLocation.point;
      _mapPointNotifier.value = _clinicLocation.point;
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
    return 'KDT-$suffix';
  }

  Future<String> _generateUniqueMedicalCode() async {
    for (var attempt = 0; attempt < 20; attempt++) {
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
        rethrow;
      }
    }
    throw StateError('Unable to generate a unique medical code.');
  }

  @override
  void dispose() {
    _successTimer?.cancel();
    _geocodeDebounce?.cancel();
    _paymentDeadlineTimer?.cancel();
    _mapPointNotifier.dispose();
    _addressController.removeListener(_onAddressChanged);
    _successAnimationController.dispose();
    _stageEntranceController.dispose();
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
            _selectedCity.isEmpty ||
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
    if (_step == 3 && _sessionCount == null) {
      _showMessage(t(context, 'reservationChooseSession'));
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
      if (_paymentDeadlineUtc == null) _startPaymentDeadline();
      setState(() => _step++);
      _stageEntranceController.forward(from: 0);
      return;
    }
    if (_step == 5) {
      if (_isPaymentDeadlineExpired) return;
      if (_paymentMethod == 'card' &&
          !(_formKey.currentState?.validate() ?? false)) {
        return;
      }
      _saveReservation();
      return;
    }
    setState(() => _step++);
    _stageEntranceController.forward(from: 0);
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step--);
    _stageEntranceController.forward(from: 0);
  }

  void _startPaymentDeadline() {
    _paymentDeadlineTimer?.cancel();
    _paymentDeadlineUtc = DateTime.now().toUtc().add(
      const Duration(minutes: 10),
    );
    final remaining = _paymentDeadlineUtc!.difference(DateTime.now().toUtc());
    _paymentDeadlineTimer = Timer(remaining, () {
      if (mounted) setState(() {});
    });
  }

  void _returnToPaymentMethods() {
    _paymentDeadlineTimer?.cancel();
    setState(() {
      _paymentDeadlineUtc = null;
      _step = 4;
    });
    _stageEntranceController.forward(from: 0);
  }

  Future<void> _saveReservation() async {
    _paymentDeadlineTimer?.cancel();
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
            if (appointmentId != null) {
              await _service.persistEmrBookingCode(
                appointmentId: appointmentId,
                storedCode: insertedRows.first['booking_code']?.toString(),
              );
            }
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
        if (_paymentMethod == 'card') {
          _cardNameController.clear();
          _cardNumberController.clear();
          _cardExpiryController.clear();
          _cardCvvController.clear();
        }
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

  int get _basePrice =>
      _sessionCount == null ? 0 : _packagePrice(_sessionCount!);

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
        restrictToFutureMonths: true,
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
    final selected = await showDialog<TimeOfDay>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: _buildTimeSheet(),
      ),
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
        if (hour != 12) TimeOfDay(hour: hour, minute: 0),
    ];
    return _selectionSheet(
      t(context, 'reservationTime'),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.5,
        physics: const NeverScrollableScrollPhysics(),
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
            borderRadius: BorderRadius.circular(8),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: !isAvailable
                    ? const Color(0xFFE9EEEE)
                    : selected
                    ? const Color(0xFFF7FFFE)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
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
                '${slot.hour.toString().padLeft(2, '0')}:00',
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
      compact: true,
    );
  }

  Widget _selectionSheet(
    String title,
    Widget content, {
    bool compact = false,
  }) => SafeArea(
    child: Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: compact ? Colors.white : _background,
        borderRadius: BorderRadius.all(Radius.circular(compact ? 14 : 26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
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
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: _muted),
                tooltip: t(context, 'close'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    ),
  );

  Future<void> _openClinicMap() async {
    final opened = await launchUrl(
      Uri.parse(_clinicLocation.mapUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showMessage('Google Maps tidak dapat dibuka.');
    }
  }


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
      // Pakai akurasi tertinggi supaya koordinat presisi
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 15),
        ),
      );
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
    if (_isClinicService) return;
    setState(() => _mapCenter = point);
    _mapPointNotifier.value = point;
    // Pindahkan kamera langsung — tidak perlu postFrameCallback
    // karena MapController.move() bisa dipanggil kapan saja setelah map ready
    try {
      _mapController.move(point, 16);
    } catch (_) {
      // Controller belum ready (map belum render) — abaikan, initialCenter sudah benar
    }

    // Primary: Google reverse geocoding
    try {
      debugPrint('Attempting reverse geocoding with Google Maps API');
      final dio = Dio();
      final response = await dio
          .get<Map<String, dynamic>>(
            '$_googleGeocodingUrl&latlng=${point.latitude},${point.longitude}&language=id',
          )
          .timeout(const Duration(seconds: 10));
      final results = (response.data?['results'] as List?) ?? [];
      if (results.isNotEmpty) {
        final formattedAddress = results[0]['formatted_address'] as String?;
        if (formattedAddress != null && formattedAddress.isNotEmpty) {
          final cleanAddress = _formatAddressForDisplay(formattedAddress);
          setState(() => _addressController.text = cleanAddress);
          debugPrint('Google reverse geocoding successful: $cleanAddress');
          return; // Success, exit early
        }
      }
    } catch (error) {
      debugPrint('Google reverse geocoding failed: $error');
    }

    // Secondary: Geoapify reverse geocoding
    try {
      debugPrint('Attempting reverse geocoding with Geoapify API');
      final dio = Dio();
      final response = await dio
          .get<Map<String, dynamic>>(
            'https://api.geoapify.com/v1/geocode/reverse?lat=${point.latitude}&lon=${point.longitude}&apiKey=$_geoapifyKey&lang=id',
          )
          .timeout(const Duration(seconds: 10));
      
      if (!mounted) return;
      final features = (response.data?['features'] as List?) ?? [];
      if (features.isNotEmpty) {
        final firstFeature = features.first as Map<String, dynamic>;
        final properties = firstFeature['properties'] as Map<String, dynamic>?;
        final formattedAddress = properties?['formatted'] as String?;
        if (formattedAddress != null && formattedAddress.isNotEmpty) {
          final cleanAddress = _formatAddressForDisplay(formattedAddress);
          setState(() => _addressController.text = cleanAddress);
          debugPrint('Geoapify reverse geocoding successful: $cleanAddress');
          return; // Success, exit early
        }
      }
    } catch (error) {
      debugPrint('Geoapify reverse geocoding failed: $error');
    }

    // Tertiary: Nominatim (OpenStreetMap) reverse geocoding
    try {
      debugPrint('Attempting reverse geocoding with Nominatim API');
      final dio = Dio();
      dio.options.headers['User-Agent'] = 'KedotaApp/1.0';
      final response = await dio
          .get<Map<String, dynamic>>(
            'https://nominatim.openstreetmap.org/reverse',
            queryParameters: {
              'lat': point.latitude,
              'lon': point.longitude,
              'format': 'json',
              'addressdetails': 1,
              'zoom': 18,
              'accept-language': 'id',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final data = response.data;
      if (data != null) {
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        final parts = <String>[
          if ((addr['road'] ?? addr['footway'] ?? addr['path'] ?? '').toString().trim().isNotEmpty)
            [
              (addr['road'] ?? addr['footway'] ?? addr['path'] ?? '').toString().trim(),
              if ((addr['house_number'] ?? '').toString().trim().isNotEmpty)
                'No. ${addr['house_number']}',
            ].join(' '),
          if ((addr['suburb'] ?? addr['village'] ?? addr['neighbourhood'] ?? '').toString().trim().isNotEmpty)
            (addr['suburb'] ?? addr['village'] ?? addr['neighbourhood'] ?? '').toString().trim(),
          if ((addr['district'] ?? addr['county'] ?? '').toString().trim().isNotEmpty)
            (addr['district'] ?? addr['county'] ?? '').toString().trim(),
          if ((addr['city'] ?? addr['town'] ?? '').toString().trim().isNotEmpty)
            (addr['city'] ?? addr['town'] ?? '').toString().trim(),
          if ((addr['state'] ?? '').toString().trim().isNotEmpty)
            (addr['state'] ?? '').toString().trim(),
          if ((addr['postcode'] ?? '').toString().trim().isNotEmpty)
            (addr['postcode'] ?? '').toString().trim(),
        ];
        final address = parts.isNotEmpty
            ? parts.join(', ')
            : data['display_name']?.toString().split(', ').take(5).join(', ') ?? '';
        if (address.isNotEmpty) {
          final cleanAddress = _formatAddressForDisplay(address);
          setState(() => _addressController.text = cleanAddress);
          debugPrint('Nominatim reverse geocoding successful: $cleanAddress');
          return; // Success, exit early
        }
      }
    } catch (error) {
      debugPrint('Nominatim reverse geocoding fallback failed: $error');
    }

    // Final fallback: geocoding package
    try {
      debugPrint('Attempting reverse geocoding with geocoding package');
      final places = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (places.isNotEmpty && mounted) {
        final place = places.first;
        final parts = <String>[
          if ((place.street ?? '').trim().isNotEmpty) place.street!.trim(),
          if ((place.subLocality ?? '').trim().isNotEmpty)
            place.subLocality!.trim(),
          if ((place.locality ?? '').trim().isNotEmpty)
            place.locality!.trim(),
          if ((place.subAdministrativeArea ?? '').trim().isNotEmpty)
            place.subAdministrativeArea!.trim(),
          if ((place.administrativeArea ?? '').trim().isNotEmpty)
            place.administrativeArea!.trim(),
          if ((place.postalCode ?? '').trim().isNotEmpty)
            place.postalCode!.trim(),
        ];
        if (parts.isNotEmpty) {
          final cleanAddress = _formatAddressForDisplay(parts.join(', '));
          setState(() => _addressController.text = cleanAddress);
          debugPrint('Geocoding package reverse geocoding successful: $cleanAddress');
          return; // Success, exit early
        }
      }
    } catch (error) {
      debugPrint('Geocoding package fallback failed: $error');
    }
    
    debugPrint('All reverse geocoding services failed');
  }

  Future<void> _openExpandedMap() async {
    final clinicMap = _isClinicService;
    final expandedController = MapController();
    LatLng selectedPoint = _displayMapCenter;
    String selectedAddress = clinicMap
        ? _clinicLocation.address
        : _addressController.text.trim();

    // Listen perubahan dari forward geocoding (ketik di field)
    void onPointChanged() {
      if (clinicMap) return;
      final newPoint = _mapPointNotifier.value;
      selectedPoint = newPoint;
      expandedController.move(newPoint, 16);
    }

    _mapPointNotifier.addListener(onPointChanged);

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // ── Peta fullscreen ──────────────────────────────────────
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.55,
                  child: FlutterMap(
                    mapController: expandedController,
                    options: MapOptions(
                      initialCenter: selectedPoint,
                      initialZoom: 15,
                      onTap: _isReschedule || clinicMap
                          ? null
                          : (_, point) async {
                              setDialogState(() {
                                selectedPoint = point;
                                selectedAddress = '';
                              });
                              expandedController.move(point, 15);
                              // Three-tier reverse geocoding fallback for expanded map
                              
                              // Primary: Google reverse geocoding
                              try {
                                final dio = Dio();
                                final resp = await dio
                                    .get<Map<String, dynamic>>(
                                      '$_googleGeocodingUrl&latlng=${point.latitude},${point.longitude}&language=id',
                                    )
                                    .timeout(const Duration(seconds: 10));
                                final results = (resp.data?['results'] as List?) ?? [];
                                if (results.isNotEmpty) {
                                  final address = results[0]['formatted_address'] as String?;
                                  if (address != null && address.isNotEmpty) {
                                    final cleanAddress = _formatAddressForDisplay(address);
                                    setDialogState(
                                      () => selectedAddress = cleanAddress,
                                    );
                                    return;
                                  }
                                }
                              } catch (error) {
                                debugPrint('Google reverse geocoding failed in expanded map: $error');
                              }
                              
                              // Secondary: Geoapify reverse geocoding
                              try {
                                final dio = Dio();
                                final resp = await dio
                                    .get<Map<String, dynamic>>(
                                      'https://api.geoapify.com/v1/geocode/reverse?lat=${point.latitude}&lon=${point.longitude}&apiKey=$_geoapifyKey&lang=id',
                                    )
                                    .timeout(const Duration(seconds: 10));
                                final features = (resp.data?['features'] as List?) ?? [];
                                if (features.isNotEmpty) {
                                  final properties = features.first['properties'] as Map<String, dynamic>?;
                                  final address = properties?['formatted'] as String?;
                                  if (address != null && address.isNotEmpty) {
                                    setDialogState(
                                      () => selectedAddress = address,
                                    );
                                    return;
                                  }
                                }
                              } catch (error) {
                                debugPrint('Geoapify reverse geocoding failed in expanded map: $error');
                              }
                              
                              // Tertiary: Nominatim reverse geocoding
                              try {
                                final dio = Dio();
                                dio.options.headers['User-Agent'] = 'KedotaApp/1.0';
                                final resp = await dio
                                    .get<Map<String, dynamic>>(
                                      'https://nominatim.openstreetmap.org/reverse',
                                      queryParameters: {
                                        'lat': point.latitude,
                                        'lon': point.longitude,
                                        'format': 'json',
                                        'addressdetails': 1,
                                        'zoom': 18,
                                        'accept-language': 'id',
                                      },
                                    )
                                    .timeout(const Duration(seconds: 10));
                                final data = resp.data;
                                if (data != null) {
                                  final addr = data['address'] as Map<String, dynamic>? ?? {};
                                  final parts = <String>[
                                    if ((addr['road'] ?? '').toString().trim().isNotEmpty)
                                      addr['road'].toString().trim(),
                                    if ((addr['suburb'] ?? addr['village'] ?? '').toString().trim().isNotEmpty)
                                      (addr['suburb'] ?? addr['village']).toString().trim(),
                                    if ((addr['city'] ?? addr['town'] ?? '').toString().trim().isNotEmpty)
                                      (addr['city'] ?? addr['town']).toString().trim(),
                                  ];
                                  final address = parts.isNotEmpty
                                      ? parts.join(', ')
                                      : data['display_name']?.toString().split(', ').take(3).join(', ') ?? '';
                                  if (address.isNotEmpty) {
                                    final cleanAddress = _formatAddressForDisplay(address);
                                    setDialogState(
                                      () => selectedAddress = cleanAddress,
                                    );
                                  }
                                }
                              } catch (error) {
                                debugPrint('Nominatim reverse geocoding failed in expanded map: $error');
                              }
                            },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _currentTileUrl,
                        userAgentPackageName: 'com.kedota.physiotherapy',
                        errorTileCallback: (tile, error, stackTrace) {
                          debugPrint('Tile loading failed: $error');
                          _fallbackToNextTileService();
                        },
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedPoint,
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
                          TextSourceAttribution(_currentTileService == 0 
                              ? '© Google Maps' 
                              : _currentTileService == 1 
                                  ? '© Geoapify' 
                                  : '© OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Floating label alamat ─────────────────────────────────
                if (selectedAddress.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 48,
                    right: 48,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: _teal,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                selectedAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── Tombol ✕ pojok kanan atas ────────────────────────────
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      if (!_isReschedule && !clinicMap) {
                        // Langsung set koordinat dan address — tidak perlu geocode ulang
                        // karena selectedAddress sudah didapat saat tap di popup
                        setState(() {
                          _mapCenter = selectedPoint;
                          if (selectedAddress.isNotEmpty) {
                            _addressController.text = selectedAddress;
                          }
                        });
                        _mapPointNotifier.value = selectedPoint;
                        try {
                          _mapController.move(selectedPoint, 16);
                        } catch (_) {}
                        // Kalau belum ada address, baru geocode
                        if (selectedAddress.isEmpty) {
                          _setMapLocation(selectedPoint);
                        }
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: _ink,
                      ),
                    ),
                  ),
                ),

                // ── Field detail lokasi di bawah peta ────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: clinicMap
                        ? Text(
                            _clinicLocation.address,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _ink,
                            ),
                          )
                        : TextField(
                      controller: _addressController,
                      readOnly: _isReschedule,
                      decoration: InputDecoration(
                        hintText: t(context, 'reservationHomeCareAddressHint'),
                        hintStyle: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.edit_location_alt_outlined,
                          color: _teal,
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE4E3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE4E3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _teal,
                            width: 1.4,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: const TextStyle(fontSize: 12, color: _ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _mapPointNotifier.removeListener(onPointChanged);
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      reverseDuration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) =>
                          Stack(
                            alignment: Alignment.topCenter,
                            fit: StackFit.expand,
                            children: [
                              ...previousChildren,
                              if (currentChild != null) currentChild,
                            ],
                          ),
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0, 0.035),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: slide,
                            child: child,
                          ),
                        );
                      },
                      child: SingleChildScrollView(
                        key: ValueKey<int>(_step),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: _animateStageTree(_buildStep()),
                      ),
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
          children: List.generate(5, (index) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                margin: EdgeInsets.only(right: index == 4 ? 0 : 6),
                decoration: BoxDecoration(
                  color: index <= _step.clamp(0, 4)
                      ? _teal
                      : const Color(0xFFE1E9E8),
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

  Widget _animateStageTree(Widget child, [int depth = 0]) {
    if (child is! Column || depth >= 5) return child;

    final count = child.children.length;
    return Column(
      key: child.key,
      mainAxisAlignment: child.mainAxisAlignment,
      mainAxisSize: child.mainAxisSize,
      crossAxisAlignment: child.crossAxisAlignment,
      textDirection: child.textDirection,
      verticalDirection: child.verticalDirection,
      textBaseline: child.textBaseline,
      children: [
        for (var index = 0; index < count; index++)
          _stageEntranceItem(
            _animateStageTree(child.children[index], depth + 1),
            index,
            count,
          ),
      ],
    );
  }

  Widget _stageEntranceItem(Widget child, int index, int count) {
    final start = count <= 1
        ? 0.0
        : (index * 0.075).clamp(0.0, 0.55).toDouble();
    final end = (start + 0.45).clamp(start + 0.01, 1.0).toDouble();
    final animation = CurvedAnimation(
      parent: _stageEntranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    if (child is Flexible) {
      return Flexible(
        flex: child.flex,
        fit: child.fit,
        child: _stageEntranceVisual(
          _animateStageTree(child.child),
          animation,
        ),
      );
    }
    return _stageEntranceVisual(child, animation);
  }

  Widget _stageEntranceVisual(Widget child, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  Widget _buildModeStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t(context, 'reservationTitle'),
        style: const TextStyle(
          color: _ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        t(context, 'reservationForWho'),
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
      const SizedBox(height: 14),
      _choiceButton(t(context, 'reservationForSelf'), true),
      const SizedBox(height: 10),
      _choiceButton(t(context, 'reservationForOther'), false),
    ],
  );

  Widget _choiceButton(String label, bool self) => InkWell(
    onTap: () {
      setState(() {
        _forSelf = self;
        _step = 1;
      });
      _stageEntranceController.forward(from: 0);
    },
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _teal,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget _buildPatientStep() => _flatSection(
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
          enabled: !_forSelf,
        ),
        _field(
          _phoneController,
          t(context, 'reservationPhone'),
          readOnly: _forSelf,
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

  Widget _buildScheduleStep() {
    // Apakah kota yang dipilih adalah Malang (bisa klinik + home care)
    final isMalang = _selectedCity == 'Malang';
    // Apakah tempat sudah dipilih
    final cityPicked = _selectedCity.isNotEmpty;
    // Apakah layanan sudah dipilih (serviceType dan clinic sudah terisi)
    final servicePicked = cityPicked && _serviceType.isNotEmpty && _clinic.isNotEmpty;

    return _flatSection(
      t(context, 'reservationStageSchedule'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(context, 'reservationScheduleHint'),
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // ── 1. Pilih Tempat ───────────────────────────────────────────
          _fieldLabel(t(context, 'reservationPickPlace')),
          const SizedBox(height: 6),
          _dropdownField(
            value: _selectedCity.isEmpty ? null : _selectedCity,
            hint: '-- ${t(context, 'reservationPickPlace')} --',
            icon: Icons.location_city_outlined,
            items: _availableCities,
            onChanged: _isReschedule
                ? null
                : (city) {
                    if (city == null) return;
                    setState(() {
                      _selectedCity = city;
                      if (city == 'Malang') {
                        _serviceType = '';
                        _clinic = '';
                      } else {
                        _serviceType = _homeCareService;
                        _clinic = t(context, 'homeCareCity').replaceFirst('{city}', city);
                      }
                      _appointmentDate = null;
                      _appointmentTime = null;
                      _bookedAppointmentTimes = {};
                      _addressController.clear();
                    });
                  },
          ),
          const SizedBox(height: 14),

          // ── 2. Pilih Layanan ──────────────────────────────────────────
          _fieldLabel(t(context, 'reservationService')),
          const SizedBox(height: 6),
          if (!cityPicked)
            _lockedField(t(context, 'reservationPickServiceFirst'))
          else if (!isMalang)
            _readonlyServiceChip(
              t(context, 'homeCare'),
              Icons.home_rounded,
              _tealDark,
            )
          else
            _dropdownField(
              value: _serviceType.isEmpty
                  ? null
                  : _serviceType == _clinicService
                  ? t(context, 'klinik')
                  : t(context, 'homeCare'),
              hint: '-- ${t(context, 'reservationPickService')} --',
              icon: _serviceType == _clinicService
                  ? Icons.local_hospital_rounded
                  : Icons.home_rounded,
              items: [t(context, 'klinik'), t(context, 'homeCare')],
              onChanged: _isReschedule
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _serviceType = value == t(context, 'klinik')
                            ? _clinicService
                            : _homeCareService;
                        _clinic = _serviceType == _clinicService
                            ? _clinicLocation.name
                            : t(context, 'homeCareCity').replaceFirst('{city}', 'Malang');
                        if (_serviceType == _clinicService) {
                          _mapCenter = _clinicLocation.point;
                          _mapPointNotifier.value = _clinicLocation.point;
                        }
                        _appointmentDate = null;
                        _appointmentTime = null;
                        _bookedAppointmentTimes = {};
                        if (_serviceType != _homeCareService) {
                          _addressController.clear();
                        }
                      });
                      if (_isClinicService) {
                        try {
                          _mapController.move(_clinicLocation.point, 15);
                        } catch (_) {}
                      }
                    },
            ),
          const SizedBox(height: 14),

          // ── 3. Pilih Jadwal ───────────────────────────────────────────
          _fieldLabel(t(context, 'reservationDate')),
          const SizedBox(height: 6),
          if (!servicePicked)
            _lockedField(t(context, 'reservationPickDateFirst'))
          else
            _dateField(
              t(context, 'reservationDate'),
              _appointmentDate,
              _pickAppointmentDate,
              icon: Icons.calendar_month_outlined,
              showLabel: false,
            ),
          const SizedBox(height: 14),

          // ── 4. Pilih Jam ──────────────────────────────────────────────
          _fieldLabel(t(context, 'reservationTime')),
          const SizedBox(height: 6),
          if (!servicePicked || _appointmentDate == null)
            _lockedField(t(context, 'reservationPickTimeFirst'))
          else
            _timeField(showLabel: false),
          const SizedBox(height: 14),

          // ── 5. Alamat / Lokasi ────────────────────────────────────────
          if (servicePicked) ...[
            _fieldLabel(t(context, 'reservationAddress')),
            const SizedBox(height: 6),
            if (_serviceType == _homeCareService)
              _buildHomeCareLocation()
            else
              _buildClinicLocation(),
            const SizedBox(height: 16),
          ],

          // ── Konfirmasi ketersediaan terapis ───────────────────────────
          if (servicePicked)
            InkWell(
              onTap: () => setState(
                () => _therapistAvailability = !_therapistAvailability,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _therapistAvailability,
                      activeColor: _teal,
                      onChanged: (value) => setState(
                        () => _therapistAvailability = value ?? false,
                      ),
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
  }

  /// Field dropdown generic
  Widget _dropdownField({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: value != null ? _teal : const Color(0xFFDDE4E3),
        width: value != null ? 1.4 : 1,
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        hint: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            hint,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
        ),
        icon: const Padding(
          padding: EdgeInsets.only(right: 14),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: _teal),
        ),
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(icon, color: _teal, size: 17),
                      const SizedBox(width: 10),
                      Text(
                        item,
                        style: const TextStyle(fontSize: 13, color: _ink),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );

  /// Field terkunci (belum bisa dipilih) — tampil abu dengan ikon lock
  Widget _lockedField(String hint) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F5F4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFDDE4E3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.lock_outline_rounded, color: _muted, size: 16),
        const SizedBox(width: 10),
        Text(
          hint,
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      ],
    ),
  );

  /// Chip read-only untuk layanan yang tidak bisa diubah (non-Malang = Home Care)
  Widget _readonlyServiceChip(String label, IconData icon, Color color) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Icon(Icons.check_circle_rounded, color: color, size: 18),
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
                  initialCenter: _displayMapCenter,
                  initialZoom: 14,
                  onTap: _isReschedule || _isClinicService
                      ? null
                      : (_, point) => _setMapLocation(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: _currentTileUrl,
                    userAgentPackageName: 'com.kedota.physiotherapy',
                    errorTileCallback: (tile, error, stackTrace) {
                      debugPrint('Tile loading failed: $error');
                      _fallbackToNextTileService();
                    },
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _displayMapCenter,
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
                      TextSourceAttribution(_currentTileService == 0 
                          ? '© Google Maps' 
                          : _currentTileService == 1 
                              ? '© Geoapify' 
                              : '© OpenStreetMap contributors'),
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
      // Field alamat di atas peta
      _field(
        _addressController,
        t(context, 'reservationAddress'),
        hint: t(context, 'reservationHomeCareAddressHint'),
        icon: Icons.location_on_outlined,
        readOnly: _isReschedule,
        showLabel: false,
      ),
      const SizedBox(height: 10),

      // Peta
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            SizedBox(
              height: 180,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _mapCenter,
                  initialZoom: 15,
                  onTap: _isReschedule
                      ? null
                      : (_, point) => _setMapLocation(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: _currentTileUrl,
                    userAgentPackageName: 'com.kedota.physiotherapy',
                    errorTileCallback: (tile, error, stackTrace) {
                      debugPrint('Tile loading failed: $error');
                      _fallbackToNextTileService();
                    },
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
                      TextSourceAttribution(_currentTileService == 0 
                          ? '© Google Maps' 
                          : _currentTileService == 1 
                              ? '© Geoapify' 
                              : '© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
            // Tombol expand
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                child: IconButton(
                  tooltip: t(context, 'reservationMapExpand'),
                  onPressed: _openExpandedMap,
                  icon: const Icon(
                    Icons.fullscreen_rounded,
                    color: _tealDark,
                    size: 20,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),

      // Gunakan Lokasi Terkini
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
          label: Text(t(context, 'openClinicMap')),
          style: TextButton.styleFrom(foregroundColor: _tealDark),
        ),
      ),
    ],
  );

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
        _fieldLabel(t(context, 'reservationPaymentPlan')),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _optionTile(
                t(context, 'reservationPaymentPlanFull'),
                _paymentPlan == 'full',
                () => setState(() => _paymentPlan = 'full'),
                compact: true,
                prominent: true,
              ),
            ),
            Expanded(
              child: _optionTile(
                t(context, 'reservationPaymentPlanDeposit'),
                _paymentPlan == 'deposit',
                () => setState(() => _paymentPlan = 'deposit'),
                compact: true,
                prominent: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCompactOrderSummary(),
        const SizedBox(height: 12),
        Text(
          t(context, 'reservationPaymentDeadline'),
          style: const TextStyle(
            color: Color(0xFFC65353),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _sessionChoice() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel(t(context, 'reservationChooseSession')),
      const SizedBox(height: 6),
      Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _sessionCount,
            isExpanded: true,
            itemHeight: 58,
            menuMaxHeight: 250,
            borderRadius: BorderRadius.circular(14),
            dropdownColor: Colors.white,
            hint: Text(
              '-- ${t(context, 'reservationChooseSession')} --',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _teal,
            ),
            items: [1, 3, 6, 9]
                .map(
                  (count) => DropdownMenuItem<int>(
                    value: count,
                    child: Row(
                      children: [
                        Text(
                          '${count}x ${t(context, 'reservationSessionUnit')}',
                          style: const TextStyle(color: _ink, fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          _formatRupiah(_packagePrice(count)),
                          style: const TextStyle(color: _ink, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            selectedItemBuilder: (context) => [1, 3, 6, 9]
                .map(
                  (count) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${count}x ${t(context, 'reservationSessionUnit')}',
                      style: const TextStyle(color: _ink, fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: (count) => setState(() => _sessionCount = count),
          ),
        ),
      ),
    ],
  );

  Widget _buildCompactOrderSummary() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t(context, 'reservationOrderSummary'),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      _compactOrderInfo(
        t(context, 'reservationOrderPatient'),
        _nameController.text,
      ),
      _compactOrderInfo(
        t(context, 'reservationOrderService'),
        _serviceType == _homeCareService
            ? t(context, 'homeCare')
            : t(context, 'klinik'),
      ),
      _compactOrderInfo(
        t(context, 'reservationOrderSessionCount'),
        _sessionCount == null
            ? '---'
            : '${_sessionCount}x ${t(context, 'reservationSessionUnit')}'
                  '${_appointmentDate == null || _appointmentTime == null ? '' : ' (${_appointmentScheduleSummary()})'}',
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              t(context, 'reservationPaymentSummary'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            t(context, 'reservationOrderPrice'),
            style: const TextStyle(fontSize: 13, color: _ink),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _compactSummaryLine(t(context, 'reservationBasePrice'), _formatRupiah(_basePrice)),
      _compactSummaryLine(t(context, 'reservationTravelFee'), _formatRupiah(_travelFee)),
      _compactPaymentPlanLine(
        t(context, 'reservationPaymentPlan'),
        _paymentPlan == 'full'
            ? t(context, 'reservationPaymentPlanFull')
            : t(context, 'reservationPaymentPlanDeposit'),
        _formatRupiah(_amountDue),
      ),
      _compactSummaryLine(
        t(context, 'reservationOrderDiscount'),
        _discountAmount == 0 ? '--' : '- ${_formatRupiah(_discountAmount)}',
        valuePrice: _formatRupiah(0),
      ),
      _compactSummaryLine(
        t(context, 'reservationAmountDue'),
        _formatRupiah(_amountDue),
        bold: true,
      ),
      const SizedBox(height: 6),
      Text(
        t(context, 'reservationTaxAdminDisclaimer'),
        style: const TextStyle(fontSize: 12, color: _muted),
      ),
    ],
  );

  Widget _compactOrderInfo(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(width: 6),
        const Text(':', style: TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value.isEmpty ? '-' : value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _ink),
          ),
        ),
      ],
    ),
  );

  Widget _compactSummaryLine(
    String label,
    String value, {
    String? valuePrice,
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        if (valuePrice != null) ...[
          Expanded(
            child: Row(
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
                const SizedBox(width: 6),
                Text(value, style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          Text(valuePrice, style: const TextStyle(fontSize: 12, color: _ink)),
        ] else ...[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: _ink,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _compactPaymentPlanLine(String label, String plan, String price) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(width: 6),
            Text(': $plan', style: const TextStyle(fontSize: 12, color: _ink)),
            const Spacer(),
            Text(price, style: const TextStyle(fontSize: 12, color: _ink)),
          ],
        ),
      );

  String _appointmentScheduleSummary() {
    final date = _appointmentDate!;
    final time = _appointmentTime!;
    final isIndonesian = AppLanguageScope.current(context) == AppLanguage.id;
    const englishMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const indonesianMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final months = isIndonesian ? indonesianMonths : englishMonths;
    final start = DateTime(2020, 1, 1, time.hour, time.minute);
    final end = start.add(const Duration(hours: 1));
    String clock(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '${date.day}, ${months[date.month - 1]} ${date.year} '
        '${clock(start)} - ${clock(end)} WIB';
  }

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

  // ── Logo aset per metode ───────────────────────────────────────────────────
  static const _paymentLogos = <String, String>{
    'qris': 'assets/payment/qris.png',
    'ovo': 'assets/payment/ovo.png',
    'gopay': 'assets/payment/gopay.png',
    'shopeepay': 'assets/payment/Spay.png',
    'bca': 'assets/payment/bca.png',
    'bni': 'assets/payment/bni.png',
    'bri': 'assets/payment/bri.png',
    'permata': 'assets/payment/permata.png',
    'mandiri': 'assets/payment/mandiri.png',
  };

  static const _cardPaymentLogos = [
    'assets/payment/visa logo.png',
    'assets/payment/mastercard logo.png',
    'assets/payment/jcb logo.png',
    'assets/payment/gpn.png',
    'assets/payment/American_Express_Logo logo.png',
  ];

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
        // ── QRIS & E-Wallet ─────────────────────────────────────────────
        _paymentSectionLabel(t(context, 'paymentGroupQrisEwallet')),
        const SizedBox(height: 8),
        _paymentOption('qris', t(context, 'reservationPaymentQris')),
        _paymentOption('ovo', 'OVO'),
        _paymentOption('gopay', 'GoPay'),
        _paymentOption('shopeepay', 'ShopeePay'),
        const SizedBox(height: 10),
        // ── Transfer Bank ────────────────────────────────────────────────
        _paymentSectionLabel(t(context, 'paymentGroupBank')),
        const SizedBox(height: 8),
        _paymentOption('bca', 'BCA'),
        _paymentOption('bni', 'BNI'),
        _paymentOption('bri', 'BRI'),
        _paymentOption('permata', 'Permata'),
        _paymentOption('mandiri', 'Mandiri'),
        const SizedBox(height: 10),
        // ── Kartu Kredit / Debit ─────────────────────────────────────────
        _paymentSectionLabel(t(context, 'paymentGroupCard')),
        const SizedBox(height: 8),
        _paymentOptionCard(),
      ],
    ),
  );

  Widget _paymentSectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _muted,
        letterSpacing: 0.3,
      ),
    ),
  );

  Widget _paymentOption(String value, String label) {
    final selected = _paymentMethod == value;
    final logoPath = _paymentLogos[value];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() => _paymentMethod = value);
          if (_paymentDeadlineUtc == null || _isPaymentDeadlineExpired) {
            _startPaymentDeadline();
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDDF5F2) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _teal : const Color(0xFFE6ECEB),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 26,
                child: logoPath != null
                    ? Image.asset(
                        logoPath,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, _) => Icon(
                          Icons.payments_outlined,
                          color: selected ? _tealDark : _muted,
                          size: 22,
                        ),
                      )
                    : Icon(
                        Icons.payments_outlined,
                        color: selected ? _tealDark : _muted,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? _tealDark : _ink,
                  ),
                ),
              ),
              Text(
                _formatRupiah(_amountDue),
                style: TextStyle(
                  color: selected ? _tealDark : _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? _teal : const Color(0xFFBFCFCF),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentOptionCard() {
    final selected = _paymentMethod == 'card';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() => _paymentMethod = 'card');
          if (_paymentDeadlineUtc == null || _isPaymentDeadlineExpired) {
            _startPaymentDeadline();
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDDF5F2) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _teal : const Color(0xFFE6ECEB),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              // Logo kartu berjajar
              Row(
                children: _cardPaymentLogos.map((logo) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Image.asset(
                    logo,
                    width: 28,
                    height: 20,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, _) => const SizedBox(width: 28),
                  ),
                )).toList(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t(context, 'reservationPaymentCardDebit'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? _tealDark : _ink,
                  ),
                ),
              ),
              Text(
                _formatRupiah(_amountDue),
                style: TextStyle(
                  color: selected ? _tealDark : _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? _teal : const Color(0xFFBFCFCF),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          fontSize: 20,
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

  Widget _buildPaymentMethodHeader() {
    final logoPath = _paymentLogos[_paymentMethod];
    return Row(
      children: [
        if (logoPath != null)
          Image.asset(
            logoPath,
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, _) => const Icon(
              Icons.payments_outlined,
              color: _teal,
              size: 28,
            ),
          )
        else
          const Icon(Icons.payments_outlined, color: _teal, size: 28),
        const SizedBox(width: 8),
        Text(
          switch (_paymentMethod) {
            'qris' => 'QRIS',
            'ovo' => 'OVO',
            'gopay' => 'GoPay',
            'shopeepay' => 'ShopeePay',
            'bca' => 'BANK BCA',
            'bni' => 'BANK BNI',
            'bri' => 'BANK BRI',
            'permata' => 'BANK PERMATA',
            'mandiri' => 'BANK MANDIRI',
            _ => _paymentMethod.toUpperCase(),
          },
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _buildQrisDetail() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t(context, 'reservationQrisDescription'),
        style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
      ),
      const SizedBox(height: 16),
      const Center(
        child: Text(
          'Kedota Physiotherapy',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        child: _paymentAmountBlock(centered: true, compact: true),
      ),
      if (_isPaymentDeadlineExpired) ...[
        const SizedBox(height: 20),
        _paymentDeadlineMessage(),
      ] else ...[
        const SizedBox(height: 16),
        Center(
          child: RepaintBoundary(
            key: _qrBoundaryKey,
            child: _buildQrVisual(),
          ),
        ),
        const SizedBox(height: 12),
        _paymentDeadlineMessage(showSuccessNote: false),
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 230,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _downloadingQr ? null : _downloadQr,
              icon: _downloadingQr
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, size: 17),
              label: Text(t(context, 'downloadQr')),
              style: OutlinedButton.styleFrom(
                foregroundColor: _teal,
                backgroundColor: Colors.white,
                side: BorderSide.none,
                elevation: 2,
                shadowColor: const Color(0x18000000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _paymentSuccessNote(),
      ],
    ],
  );

  Widget _buildWalletDetail() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Image.asset(
            _paymentLogos[_paymentMethod]!,
            width: 36,
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.account_balance_wallet_outlined, size: 30),
          ),
          const SizedBox(width: 6),
          Text(
            _paymentMethod == 'ovo'
                ? 'OVO'
                : _paymentMethod == 'gopay'
                ? 'GoPay'
                : 'ShopeePay',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      SizedBox(width: double.infinity, child: _paymentAmountBlock()),
      const SizedBox(height: 8),
      _paymentDeadlineMessage(),
    ],
  );

  Widget _paymentAmountBlock({bool centered = false, bool compact = false}) =>
      Column(
    crossAxisAlignment:
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
    children: [
      Text(
        t(context, 'reservationPaymentAmount'),
        style: TextStyle(color: _muted, fontSize: compact ? 11 : 14),
      ),
      const SizedBox(height: 2),
      Text(
        _formatRupiah(_amountDue),
        style: TextStyle(
          color: _teal,
          fontSize: compact ? 22 : 32,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _paymentDeadlineMessage({bool showSuccessNote = true}) {
    if (_isPaymentDeadlineExpired) {
      return Column(
        children: [
          Text(
            t(context, 'paymentDeadlineExpired'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC65353),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t(context, 'paymentDeadlineRetry'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
        ],
      );
    }

    final deadline = _paymentDeadlineUtc;
    if (deadline == null) return const SizedBox.shrink();
    return Column(
      children: [
        Text.rich(
          TextSpan(
            style: const TextStyle(color: _muted, fontSize: 12),
            children: [
              TextSpan(text: '${t(context, 'paymentDeadlineBefore')} '),
              TextSpan(
                text: _formatPaymentDeadlineWib(deadline),
                style: const TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        if (showSuccessNote) ...[
          const SizedBox(height: 4),
          _paymentSuccessNote(),
        ],
      ],
    );
  }

  Widget _paymentSuccessNote() => Text(
    t(context, 'paymentSuccessAutoUpdate'),
    textAlign: TextAlign.center,
    style: const TextStyle(color: _muted, fontSize: 10),
  );

  Widget _buildQrVisual() => Container(
    width: 260,
    height: 260,
    color: Colors.white,
    padding: const EdgeInsets.all(14),
    child: const CustomPaint(painter: _QrisPatternPainter()),
  );

  Future<void> _downloadQr() async {
    if (_isPaymentDeadlineExpired || _downloadingQr) return;
    setState(() => _downloadingQr = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject =
          _qrBoundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('QR image is not ready');
      }
      final image = await renderObject.toImage(pixelRatio: 3);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) throw StateError('Could not encode QR image');
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        final saver = FileSaver.instance;
        final filename =
            'kedota_qris_${DateTime.now().millisecondsSinceEpoch}';
        // file_saver's saveAs is unimplemented on web; use its browser
        // download path there and the native file picker on mobile.
        final path = kIsWeb
            ? await saver.saveFile(
                name: filename,
                bytes: bytes,
                fileExtension: 'png',
                mimeType: MimeType.png,
              )
            : await saver.saveAs(
                name: filename,
                bytes: bytes,
                fileExtension: 'png',
                mimeType: MimeType.png,
              );
        if (!mounted) return;
        if (path != null) {
          showAppSnackBar(
            context,
            t(context, 'qrisDownloadSuccess'),
            type: AppSnackBarType.success,
          );
        }
      } finally {
        image.dispose();
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          t(context, 'qrisDownloadFailed'),
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingQr = false);
    }
  }

  String _formatPaymentDeadlineWib(DateTime deadlineUtc) {
    final deadline = deadlineUtc.toUtc().add(const Duration(hours: 7));
    final isIndonesian = AppLanguageScope.current(context) == AppLanguage.id;
    const englishMonths = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const indonesianMonths = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final months = isIndonesian ? indonesianMonths : englishMonths;
    final hour = deadline.hour.toString().padLeft(2, '0');
    final minute = deadline.minute.toString().padLeft(2, '0');
    return '${deadline.day} ${months[deadline.month - 1]}, $hour:$minute WIB';
  }

  Widget _buildBankDetail() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildPaymentMethodHeader(),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _paymentAmountBlock(compact: true)),
          _copyPaymentButton(
            _amountDue.toString(),
            successMessageKey: 'reservationAmountCopied',
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        t(context, 'reservationVirtualAccountShort'),
        style: const TextStyle(color: _muted, fontSize: 11),
      ),
      const SizedBox(height: 2),
      Row(
        children: [
          Expanded(
            child: Text(
              _bankAccountDisplay,
              style: const TextStyle(
                color: _teal,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: .2,
              ),
            ),
          ),
          _copyPaymentButton(
            _bankAccountDisplay.replaceAll(' ', ''),
            successMessageKey: 'reservationAccountCopied',
          ),
        ],
      ),
      const SizedBox(height: 8),
      _paymentDeadlineMessage(),
      const SizedBox(height: 14),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _paymentTutorial(
              id: 'mbca',
              title: _bankAppInstructionTitle,
              steps: _bankPaymentSteps,
              bankStyle: true,
            ),
            _paymentTutorial(
              id: 'ibanking',
              title: t(context, 'reservationBankIbanking'),
              steps: _bankPaymentSteps,
              bankStyle: true,
            ),
            _paymentTutorial(
              id: 'atm',
              title: t(context, 'reservationBankAtm'),
              steps: _bankPaymentSteps,
              bankStyle: true,
            ),
          ],
        ),
      ),
    ],
  );

  List<String> get _bankPaymentSteps => [
    t(context, 'reservationBankStep1'),
    t(context, 'reservationBankStep2'),
    t(context, 'reservationBankStep3'),
  ];

  String get _bankAccountDisplay => switch (_paymentMethod) {
    'bca' => '1234 5678 9012 3456',
    'bni' => '9876 5432 1098 7654',
    'bri' => '4567 8901 2345 6789',
    'mandiri' => '6543 2109 8765 4321',
    'permata' => '3210 9876 5432 1098',
    _ => '8808 1234 5678 9012',
  };

  String get _bankAppInstructionTitle => switch (_paymentMethod) {
    'bca' => t(context, 'reservationBankMbca'),
    'bni' => t(context, 'reservationBankBniApp'),
    'bri' => t(context, 'reservationBankBriApp'),
    'mandiri' => t(context, 'reservationBankMandiriApp'),
    'permata' => t(context, 'reservationBankPermataApp'),
    _ => t(context, 'reservationBankMbca'),
  };

  Widget _copyPaymentButton(
    String value, {
    required String successMessageKey,
  }) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 2),
    child: Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: const Color(0x16000000),
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: () => _copyPaymentValue(
          value,
          successMessageKey: successMessageKey,
        ),
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t(context, 'reservationCopyShort'),
                style: const TextStyle(
                  color: _teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.copy_rounded, size: 15, color: _teal),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildCardDetail() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _paymentAmountBlock(compact: true),
      const SizedBox(height: 12),
      Text(
        t(context, 'reservationCardForm'),
        style: const TextStyle(color: _muted, fontSize: 11),
      ),
      const SizedBox(height: 5),
      Row(
        children: _cardPaymentLogos.map((logo) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Image.asset(
            logo,
            width: 36,
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, _) => const SizedBox(width: 36),
          ),
        )).toList(),
      ),
      _cardInputField(
        _cardNameController,
        t(context, 'reservationCardholder'),
        hint: t(context, 'reservationCardholderHint'),
        icon: Icons.person_outline_rounded,
        textCapitalization: TextCapitalization.words,
        validator: (value) => value == null || value.trim().isEmpty
            ? t(context, 'reservationFieldRequired')
            : null,
      ),
      _cardInputField(
        _cardNumberController,
        t(context, 'reservationCardNumber'),
        hint: '1234  5678  9012  3456',
        keyboardType: TextInputType.number,
        inputFormatters: [_CardNumberInputFormatter()],
        validator: _validateCardNumber,
        icon: Icons.credit_card_rounded,
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _cardInputField(
              _cardExpiryController,
              t(context, 'reservationCardExpiry'),
              hint: 'MM/YY',
              keyboardType: TextInputType.number,
              inputFormatters: [_CardExpiryInputFormatter()],
              validator: _validateCardExpiry,
              icon: Icons.calendar_today_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _cardInputField(
              _cardCvvController,
              t(context, 'reservationCardCvv'),
              hint: '***',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              validator: _validateCardCvv,
              obscureText: true,
              icon: Icons.lock_outline_rounded,
            ),
          ),
        ],
      ),
      const SizedBox(height: 13),
      Text(
        t(context, 'reservationCardInstructions'),
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      for (final (index, key) in [
        'reservationCardStep1',
        'reservationCardStep2',
        'reservationCardStep3',
        'reservationCardStep4',
      ].indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            '${index + 1}. ${t(context, key)}',
            style: const TextStyle(color: _muted, fontSize: 11, height: 1.45),
          ),
        ),
    ],
  );

  Widget _cardInputField(
    TextEditingController controller,
    String label, {
    required String? Function(String?) validator,
    String? hint,
    IconData? icon,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        FormField<String>(
          initialValue: controller.text,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          builder: (fieldState) {
            final hasError = fieldState.hasError;
            final borderColor = hasError
                ? const Color(0xFFFF4D4F)
                : const Color(0xFFE1E9E8);
            final outline = OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor, width: hasError ? 1.4 : 1),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fieldState.errorText != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 4),
                    child: Text(
                      fieldState.errorText!,
                      style: const TextStyle(
                        color: Color(0xFFE14D4D),
                        fontSize: 9,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
                  obscureText: obscureText,
                  inputFormatters: inputFormatters,
                  onChanged: fieldState.didChange,
                  decoration: _decoration(label, hint, icon: icon).copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    border: outline,
                    enabledBorder: outline,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: hasError ? const Color(0xFFFF4D4F) : _teal,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  String? _validateCardNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return t(context, 'reservationFieldRequired');
    if (!_hasValidNetworkLength(digits) || !_passesLuhn(digits)) {
      return t(context, 'reservationCardNumberInvalid');
    }
    return null;
  }

  bool _hasValidNetworkLength(String digits) {
    if (digits.startsWith('4')) {
      return const {13, 16, 19}.contains(digits.length);
    }
    if (RegExp(r'^3[47]').hasMatch(digits)) return digits.length == 15;

    final firstTwo = int.tryParse(digits.substring(0, min(2, digits.length)));
    final firstFour =
        digits.length >= 4 ? int.tryParse(digits.substring(0, 4)) : null;
    final isMastercard =
        (firstTwo != null && firstTwo >= 51 && firstTwo <= 55) ||
        (firstFour != null && firstFour >= 2221 && firstFour <= 2720);
    if (isMastercard) return digits.length == 16;

    final jcbPrefix = digits.length >= 4 ? int.tryParse(digits.substring(0, 4)) : null;
    if (jcbPrefix != null && jcbPrefix >= 3528 && jcbPrefix <= 3589) {
      return digits.length >= 16 && digits.length <= 19;
    }

    // GPN and other domestic debit cards commonly use 16 digit PANs.
    return digits.length == 16;
  }

  bool _passesLuhn(String digits) {
    var sum = 0;
    var doubleDigit = false;
    for (var index = digits.length - 1; index >= 0; index--) {
      var digit = int.parse(digits[index]);
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleDigit = !doubleDigit;
    }
    return sum % 10 == 0;
  }

  String? _validateCardExpiry(String? value) {
    if (value == null || value.trim().isEmpty) {
      return t(context, 'reservationFieldRequired');
    }
    final parts = value.split('/');
    if (parts.length != 2 || parts[0].length != 2 || parts[1].length != 2) {
      return t(context, 'reservationCardExpiryInvalid');
    }
    final month = int.tryParse(parts[0]);
    final shortYear = int.tryParse(parts[1]);
    if (month == null || shortYear == null || month < 1 || month > 12) {
      return t(context, 'reservationCardExpiryInvalid');
    }
    final now = DateTime.now();
    final year = 2000 + shortYear;
    if (year < now.year || (year == now.year && month < now.month)) {
      return t(context, 'reservationCardExpired');
    }
    return null;
  }

  String? _validateCardCvv(String? value) {
    final digits = value ?? '';
    if (digits.isEmpty) return t(context, 'reservationFieldRequired');
    final cardDigits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final isAmex = RegExp(r'^3[47]').hasMatch(cardDigits);
    if (!RegExp(isAmex ? r'^\d{4}$' : r'^\d{3}$').hasMatch(digits)) {
      return t(context, 'reservationCardCvvInvalid');
    }
    return null;
  }

  Future<void> _copyPaymentValue(
    String value, {
    String successMessageKey = 'reservationAccountCopied',
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    showAppSnackBar(
      context,
      t(context, successMessageKey),
      type: AppSnackBarType.success,
      duration: const Duration(seconds: 2),
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
    bool bankStyle = false,
  }) {
    final expanded = _expandedPaymentTutorial == id;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bankStyle ? Colors.transparent : const Color(0xFFF5F8F8),
        borderRadius: BorderRadius.circular(bankStyle ? 0 : 10),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _expandedPaymentTutorial = expanded ? null : id),
            borderRadius: BorderRadius.circular(bankStyle ? 14 : 10),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: bankStyle ? 12 : 12,
                vertical: bankStyle ? 13 : 14,
              ),
              child: Row(
                children: [
                  if (!bankStyle) ...[
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: _teal,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: bankStyle ? const Color(0xFF5F6A6B) : _ink,
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
          if (bankStyle && id != 'atm')
            const Divider(height: 1, thickness: 1, color: Color(0xFFE6EAEA)),
          if (expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(bankStyle ? 12 : 38, 0, 14, 14),
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

  Widget _optionTile(
    String label,
    bool selected,
    VoidCallback? onTap, {
    bool compact = false,
    bool prominent = false,
  }) {
    final child = compact
        ? Container(
            height: prominent ? 58 : 46,
            padding: EdgeInsets.symmetric(horizontal: prominent ? 14 : 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFDDF5F2) : Colors.white,
              borderRadius: BorderRadius.circular(prominent ? 14 : 10),
              border: Border.all(
                color: selected ? _teal : const Color(0xFFE6ECEB),
                width: selected ? 1.5 : 1,
              ),
            boxShadow: prominent
                ? const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 9,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
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
                      fontSize: prominent ? 14 : 11,
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
        borderRadius: BorderRadius.circular(prominent ? 14 : 10),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 2 : 4,
          vertical: prominent ? 0 : compact ? 4 : 8,
        ),
        child: child,
      ),
    );
  }

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
    bool showLabel = true,
    bool compact = false,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Widget? suffixIcon,
  }) => Padding(
    padding: EdgeInsets.only(top: showLabel ? (compact ? 8 : 12) : 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            label,
            style: TextStyle(
              color: _muted,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 4 : 5),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          obscureText: obscureText,
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
            isDense: compact,
            contentPadding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 11 : 15,
            ),
            counterText: compact ? '' : null,
            suffixIcon: suffixIcon ?? (readOnly
                ? const Icon(
                    Icons.lock_outline_rounded,
                    size: 17,
                    color: _muted,
                  )
                : null),
          ),
        ),
      ],
    ),
  );

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: _muted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  );

  InputDecoration _decoration(String label, String? hint, {IconData? icon}) =>
      InputDecoration(
        labelText: null,
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
    bool showLabel = true,
    bool enabled = true,
  }) => Padding(
    padding: EdgeInsets.only(top: showLabel ? 12 : 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          _fieldLabel(label),
          const SizedBox(height: 5),
        ],
        InkWell(
          onTap: enabled ? onTap : null,
          child: InputDecorator(
            decoration: _decoration(label, null, icon: icon).copyWith(
              filled: true,
              fillColor: enabled ? Colors.white : const Color(0xFFE7ECEC),
              suffixIcon: enabled
                  ? null
                  : const Icon(
                      Icons.lock_outline_rounded,
                      size: 17,
                      color: _muted,
                    ),
            ),
            child: Text(
              value == null ? '--/--/----' : _formatDate(value),
              style: TextStyle(color: value == null ? _muted : _ink),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _timeField({bool showLabel = true}) => Padding(
    padding: EdgeInsets.only(top: showLabel ? 12 : 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          _fieldLabel(t(context, 'reservationTime')),
          const SizedBox(height: 5),
        ],
        InkWell(
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
      ],
    ),
  );

  Widget _segmented(
    String label,
    List<(String, String)> values,
    String selected,
    ValueChanged<String> onChanged,
    {bool enabled = true}
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
                    enabled ? () => onChanged(value.$1) : null,
                    compact: true,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );

  Widget _buildBottomAction() => _step == 0 ||
          (_step == 5 &&
              _paymentMethod == 'qris' &&
              !_isPaymentDeadlineExpired)
      ? const SizedBox.shrink()
      : SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving
                    ? null
                    : _step == 5 && _isPaymentDeadlineExpired
                    ? _returnToPaymentMethods
                    : _next,
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
                              _step == 5
                                  ? _isPaymentDeadlineExpired
                                        ? 'paymentDeadlineRetryButton'
                                        : 'reservationPayNow'
                                  : 'reservationNext',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (_step != 5) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
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
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 1)),
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

class _QrisPatternPainter extends CustomPainter {
  // Visual placeholder until a payment provider supplies a real QRIS payload.
  const _QrisPatternPainter();

  static const int _moduleCount = 29;

  @override
  void paint(Canvas canvas, Size size) {
    final module = size.width / _moduleCount;
    final paint = Paint()..color = Colors.black;

    bool finderModule(int x, int y, int originX, int originY) {
      final dx = x - originX;
      final dy = y - originY;
      if (dx < 0 || dx > 6 || dy < 0 || dy > 6) return false;
      return dx == 0 || dx == 6 || dy == 0 || dy == 6 ||
          (dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4);
    }

    for (var y = 0; y < _moduleCount; y++) {
      for (var x = 0; x < _moduleCount; x++) {
        final inFinderArea =
            (x <= 7 && y <= 7) ||
            (x >= 21 && y <= 7) ||
            (x <= 7 && y >= 21);
        final inAlignmentArea = x >= 20 && x <= 24 && y >= 20 && y <= 24;
        var isBlack = false;

        if (inFinderArea) {
          isBlack =
              finderModule(x, y, 0, 0) ||
              finderModule(x, y, 22, 0) ||
              finderModule(x, y, 0, 22);
        } else if (inAlignmentArea) {
          final dx = x - 20;
          final dy = y - 20;
          isBlack = dx == 0 || dx == 4 || dy == 0 || dy == 4 ||
              (dx == 2 && dy == 2);
        } else if (x == 6 || y == 6) {
          isBlack = (x + y).isEven;
        } else {
          final pattern = (x * 17 + y * 31 + x * y * 7 + x * x * 3) % 11;
          isBlack = pattern < 5;
        }

        if (isBlack) {
          canvas.drawRect(
            Rect.fromLTWH(
              x * module,
              y * module,
              module * 0.94,
              module * 0.94,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrisPatternPainter oldDelegate) => false;
}
