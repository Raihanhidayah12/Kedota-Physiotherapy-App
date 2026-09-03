import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { en, id }

// ─── Persistence key ──────────────────────────────────────────────────────────
const _kLangKey = 'app_language';

// ─── Global notifier — default: Bahasa Indonesia untuk pengguna baru ─────────
// Default: Indonesian for new users
final appLanguageNotifier = ValueNotifier<AppLanguage>(AppLanguage.id);

/// Load bahasa tersimpan dari SharedPreferences.
/// Pengguna baru (belum ada key tersimpan) → otomatis Indonesia.
///
/// Load saved language from SharedPreferences.
/// New users (no saved key) → defaults to Indonesian.
Future<void> loadSavedLanguage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLangKey);
    // Hanya set EN kalau user memang sudah pilih EN sebelumnya.
    // Only set EN if the user explicitly chose EN before.
    appLanguageNotifier.value =
        saved == 'en' ? AppLanguage.en : AppLanguage.id;
  } catch (e) {
    // Gagal baca storage → tetap Indonesia (default)
    // Failed to read storage → stay Indonesian (default)
    appLanguageNotifier.value = AppLanguage.id;
    debugPrint('loadSavedLanguage error: $e');
  }
}

/// Simpan bahasa ke SharedPreferences.
/// Save language to SharedPreferences.
Future<void> _saveLanguage(AppLanguage lang) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kLangKey, lang == AppLanguage.en ? 'en' : 'id');
}

// ─── InheritedNotifier scope ──────────────────────────────────────────────────
class AppLanguageScope extends InheritedNotifier<ValueNotifier<AppLanguage>> {
  const AppLanguageScope({
    super.key,
    required ValueNotifier<AppLanguage> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppLanguage current(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AppLanguageScope>()
            ?.notifier
            ?.value ??
        AppLanguage.id;
  }

  /// Toggle bahasa dan langsung simpan ke storage.
  /// Toggle language and immediately persist to storage.
  static void toggle(BuildContext context) {
    final notifier = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>()
        ?.notifier;
    if (notifier == null) return;
    final next = notifier.value == AppLanguage.en
        ? AppLanguage.id
        : AppLanguage.en;
    notifier.value = next;
    _saveLanguage(next); // fire-and-forget — tidak perlu await di sini
  }
}

// ─── Helper function ──────────────────────────────────────────────────────────
String t(BuildContext context, String key) {
  final language = AppLanguageScope.current(context);
  return _translations[language]?[key] ??
      _translations[AppLanguage.id]![key] ??
      key;
}

// ─── Translations ─────────────────────────────────────────────────────────────
const _translations = {
  AppLanguage.en: {
    'language': 'Language',
    'skip': 'Skip',
    'back': 'Back',
    'next': 'Next',
    'getStarted': 'Get Started',
    'welcomeTo': 'Pesan Jadwal',
    'kedotaPhysiotherapy': 'Tanpa Ribet!',
    'onboardingWelcomeDesc':
        'Schedule your consultation easily and efficiently, anytime you need it.',
    'recoveryWith': 'Pantau Kesehatan',
    'guidance': 'Lebih Mudah',
    'onboardingRecoveryDesc':
        'Monitor your vital health progress in real-time, right from your phone.',
    'startYour': 'Perawatan Medis',
    'journey': 'Dirumah Anda',
    'onboardingJourneyDesc':
        'Schedule home medical care sessions easily and comfortably.',
    'tagline': 'Your comfort, our care',
    'splashTitle': 'Kedota',
    'splashSubtitle': 'Physiotherapy',
    'splashTagline': 'Your comfort, our care',
    'welcomeToSignIn': 'Welcome To\n',
    'physiotherapyApp': ' Physiotherapy App',
    'signInSubtitle':
        'A calm space to continue your healing journey with Kedota.',
    'phoneNumber': 'Phone Number',
    'enterPin': 'Enter 6-digit PIN',
    'continuePhone': 'Continue with Phone Number',
    'orContinueWith': 'or continue with',
    'continueGoogle': 'Google',
    'continueApple': 'Apple',
    'dontHaveAccount': "Don't have an account? ",
    'signUp': 'Sign Up',
    'signIn': 'Sign In',
    'tryAgainSeconds': 'Try again in {seconds} seconds',
    'accountLocked': 'Account temporarily locked',
    'enterPhoneError': 'Please enter your phone number',
    'validPhoneError': 'Please enter a valid Indonesian phone number',
    'numberNotRegistered':
        'This number is not registered. Please sign up first.',
    'enterSixPinError': 'Please enter a 6-digit PIN',
    'tooManyAttempts': 'Too many failed PIN attempts. {time}.',
    'lockedAlert':
        'Too many failed PIN attempts. Your account is temporarily locked for 5 minutes. A security alert has been sent to {phone}.',
    'wrongPin': 'Wrong PIN. {attempts} attempts remaining.',
    'createAccount': 'Create Account',
    'createAccountSubtitle':
        'Register your account with one modern, secure step.',
    'phoneExample': 'Example: 81234567890',
    'continue': 'Continue',
    'or': 'OR',
    'alreadyHaveAccount': 'Already have an account? ',
    'phoneRequiredPeriod': 'Please enter your phone number.',
    'invalidPhoneFormat': 'Invalid phone number format.',
    'phoneAlreadyRegistered': 'This phone number is already registered.',
    'phoneAlreadyRegisteredDesc':
        'This number is linked to another account. Please use a different number or sign in with the registered account.',
    'signInOrUseAnother':
        'Please sign in to your account or use another number.',
    'useAnotherNumber': 'Use Another Number',
    'socialSignInSuccess':
        '{provider} sign-in successful. Please complete your profile.',
    'fullNameRequired': 'Full name is required.',
    'invalidEmail': 'Invalid email format.',
    'birthDateRequired': 'Birth date is required.',
    'gender': 'Gender',
    'male': 'Male',
    'female': 'Female',
    'otherGender': 'Other',
    'genderRequired': 'Gender is required.',
    'pinEmpty': 'PIN cannot be empty.',
    'pinNumbersOnly': 'PIN can only contain numbers.',
    'pinSixDigits': 'PIN must be 6 digits.',
    'pinMismatch': 'PIN confirmation does not match.',
    'registrationSuccessfulToast': 'Registration successful.',
    'completeProfile': 'Complete Your Profile',
    'completeProfilePhone': 'Please complete your details before continuing.',
    'completeProfileSocial':
        'Your details have been filled automatically. Please review and continue.',
    'completeProfileMessage': 'Please complete your profile to continue.',
    'fullName': 'Full Name',
    'email': 'Email',
    'birthDate': 'Birth Date',
    'createPin': 'Create PIN',
    'createPinDesc':
        'Create a 6-digit PIN to protect your account. This PIN will be used as an additional security layer.',
    'confirmPinDesc': 'Re-enter the 6-digit PIN you just created.',
    'pin': 'PIN',
    'confirmPin': 'Confirm PIN',
    'savePin': 'Save PIN',
    'registrationSuccessful': 'Registration Successful',
    'registrationSuccessDesc':
        'Your account has been created. You will be redirected to the Sign In page.',
    'goToSignIn': 'Go to Sign In',
    'otpInvalid': 'The OTP you entered is invalid. Please try again.',
    'pinCreated': 'PIN created: {pin}',
    'verifyPhone': 'Verify your phone',
    'sentCode': 'We sent a 4-digit code to {phone}.',
    'enterOtp': 'Enter OTP',
    'otpExpires': 'OTP expires in {seconds} seconds',
    'otpExpired': 'OTP expired. Please resend OTP.',
    'verifyOtp': 'Verify OTP',
    'enterOtpSentTo': 'Enter the 4-digit OTP code sent to number ',
    'resendIn': 'Resend in ',
    'otpSentTitle': 'OTP Code Sent',
    'otpResent': 'OTP resent successfully.',
    'resendOtp': 'Resend OTP',
    'sendOtp': 'Send OTP',
    'forgotPin': 'Forgot PIN',
    'forgotPinDesc': 'Enter your phone number to reset your PIN.',
    'resetPin': 'Reset PIN',
    'pinResetSent': 'PIN reset instructions sent to your phone.',
    'welcome': 'Welcome',
    'unregisteredDialogContent':
        'This phone number is not registered. Would you like to sign up now?',
    'googleAccountNotRegistered':
        'This Google account is not registered. Please sign up first.',
    'googleUnregisteredDialogContent':
        'This Google account is not registered. Would you like to sign up now?',
    'continueSignUp': 'Continue to Sign Up',
    'phoneNotRegisteredOrIncomplete':
        'Phone number not registered or profile incomplete.',
    'wrongPinOrSignInFailed': 'Wrong PIN or Sign in failed.',
    'enterPinDesc': 'Please enter your 6-digit PIN to sign in.',
    'signedInSuccessfully': 'Signed in successfully',
    'noInternetTitle': 'No Internet Connection',
    'noInternetSubtitle': 'Please check your internet connection',
    'otpLimitTitle': 'OTP Request Limit!',
    'otpLimitSubtitle': 'Wait 30 seconds before sending another OTP code!',
    'verificationLimitTitle': 'Verification Rate Limit',
    'verificationLimitSubtitle':
        'Wait 30 seconds before sending another verification',
    'pinLimitTitle': 'PIN Request Limit.',
    'pinLimitSubtitle': 'Please wait 30 seconds to enter your PIN.',
    'dormantAccountTitle': 'Account Inactive > 60 Days',
    'dormantAccountSubtitle':
        'Your account has been inactive for more than 60 days. For security reasons, OTP will be sent to your registered email.',
    'sentEmailCode': 'We sent a 4-digit code to email {email}.',
    'continueEmail': 'Continue to Email OTP',
    'createNewPin': 'Create New PIN',
    'createNewPinDesc': 'Enter a new 6-digit PIN for your account.',
    'confirmNewPin': 'Confirm New PIN',
    'pinUpdatedSuccessTitle': 'PIN Updated Successfully',
    'pinUpdatedSuccessDesc':
        'Your PIN has been updated. Please sign in using your new PIN.',
    'wait30Seconds': 'Wait {seconds} seconds...',
    'verifyBirthDateTitle': 'Verify Birth Date',
    'verifyBirthDateDesc':
        'Please select your birth date to verify account identity.',
    'selectBirthDateHint': 'dd/mm/yyyy',
    'selectBirthDateError': 'Please select your birth date first.',
    'birthDateMismatchError':
        'Birth date does not match. Please wait 3 seconds to try again.',
    'confirmPinMismatchError':
        'Confirmation PIN does not match. Please recreate.',
    'sameAsOldPinError': 'New PIN cannot be the same as your old PIN.',
    'googleProfileTitle': 'Complete Google Profile',
    'googleProfileDesc':
        'Your Google details have been auto-filled. You can review or edit them and set your 6-digit PIN.',
    'saveAndContinue': 'Save & Continue',
    'googleAccount': 'Google Account',
    'cancel': 'Cancel',
    'continueText': 'Continue',
    'pleaseSignUpFirst': 'Please register your account first.',
    'profileCompletedTitle': 'Profile Completed Successfully',
    'profileCompletedSubtitle': 'Welcome! Your Google account is ready to use.',
    'resetPinFailed': 'Failed to reset PIN. Please try again.',
    'saveProfileFailed': 'Failed to save profile. Please try again.',
    'successfullyLoggedIn': 'You have successfully logged in!',
    'googleVerifiedEnterPin': 'Google verified. Please enter your PIN.',
    'googleSignInFailed': 'Google sign-in failed',
    'phoneVerified': 'Phone Verified',
    'completeYourProfile': 'Complete Your Profile',
    'phoneProfileDesc':
        'Your phone has been verified. Now please complete your profile information.',
    'fullNameExample': 'e.g., John Doe',
    'emailRequired': 'Email is required.',
    'validEmailError': 'Please enter a valid email address.',
    'accountCreatedTitle': 'Account Created Successfully',
    'accountCreatedSubtitle': 'Welcome! Your account is ready to use.',
    'emailAlreadyRegistered':
        'This email is already registered. Please use a different email or sign in.',
    'accountExistsTitle': 'Account Already Exists',
    'accountExistsByPhone':
        'This email is already linked to an account registered via phone number {phone}. Please log in with your phone number first.',

    // ── Home screen ──────────────────────────────────────────────────────
    'greetingMorning': 'Good Morning',
    'greetingAfternoon': 'Good Afternoon',
    'greetingEvening': 'Good Evening',
    'greetingNight': 'Good Night',
    'searchHint': 'Search services or therapists…',
    'upcomingAppointment': 'Upcoming Appointment',
    'seeAll': 'See All',
    'ourServices': 'Our Services',
    'rehabProgress': 'Rehabilitation Progress',
    'detail': 'Detail',
    'popularSearch': 'Popular Searches',
    'noResultFor': 'No results for',
    'serviceCat': 'Service',
    'therapistCat': 'Therapist',
    'tipsCat': 'Tips',
    'homeCare': 'Home Care',
    'homeCareDesc': 'Therapy at your home',
    'klinik': 'Clinic',
    'klinikDesc': 'Visit our physiotherapy clinic',
    'rehab': 'Rehabilitation',
    'rehabDesc': 'Motion recovery program',
    'wellness': 'Wellness',
    'wellnessDesc': 'Wellness & relaxation care',
    'tipsStretch': 'Stretching Before Session',
    'tipsStretchBody': 'Do 10 minutes of stretching for optimal results',
    'tipsWater': 'Drink Enough Water',
    'tipsWaterBody': 'Hydration helps muscle recovery faster',
    'tipsRest': 'Regular Rest',
    'tipsRestBody': '7–8 hours of sleep speeds up rehabilitation',
    'appointmentLabel': 'Home Care · Marvin McKinney',
    'appointmentDate': 'Tuesday, Aug 18 · 11:00 – 12:00',
    'bookNow': 'Book Now',
    'weeklyProgress': 'Weekly Progress',
    'sessions': 'sessions',
    'tipsTitle': 'Tips for Today',

    // ── History screen ───────────────────────────────────────────────────
    'historyTitle': 'History',
    'historySubtitle': 'Your therapy schedule history',
    'filterAll': 'All',
    'filterUpcoming': 'Upcoming',
    'filterDone': 'Done',
    'filterCancelled': 'Cancelled',
    'sortLabel': 'Sort',
    'sortNewest': 'Newest',
    'sortOldest': 'Oldest',
    'sortByDate': 'By Date',
    'upcomingAppointmentSection': 'Upcoming Appointment',
    'previousHistory': 'Previous History',
    'statusUpcoming': 'Upcoming',
    'statusDone': 'Done',
    'statusExpired': 'Expired',
    'statusCancelled': 'Cancelled',
    'reschedule': 'Reschedule',
    'cancel2': 'Cancel',
    'noAppointments': 'No appointments',
    'filterDate': 'Date',

    // ── Settings screen ──────────────────────────────────────────────────
    'settingsTitle': 'Settings',
    'emailVerified': 'Email Verified',
    'emailNotVerified': 'Verify Email',
    'idCopied': 'ID copied',
    'groupAccount': 'Account',
    'groupPreferences': 'Preferences',
    'groupSupport': 'Support & About',
    'groupServices': 'Services',
    'groupInfo': 'Information',
    'groupOther': 'Other',
    'menuEditProfile': 'Account Information',
    'menuEditProfileSub': 'Name, photo, and personal info',
    'menuChangePin': 'Change PIN',
    'menuChangePinSub': 'Update your account security PIN',
    'menuNotification': 'Notifications',
    'menuNotificationSub': 'Manage notification preferences',
    'menuCS': 'Customer Service',
    'menuCSSub': 'Contact our support team',
    'menuAddress': 'My Address',
    'menuAddressSub': 'Manage delivery and service addresses',
    'menuFaq': 'FAQ',
    'menuFaqSub': 'Frequently asked questions',
    'menuTerms': 'Terms & Conditions',
    'menuTermsSub': 'Learn about service terms',
    'menuPrivacy': 'Privacy Policy',
    'menuPrivacySub': 'How we protect your data',
    'menuAbout': 'About App',
    'menuAboutSub': 'v1.0.0 · PT Kedota Health Indonesia',
    'menuLogout': 'Sign Out',
    'menuLogoutSub': 'Sign out of your account',
    'aboutAppDesc': 'Physiotherapy App',
    'aboutVersion': 'Version 1.0.0',
    'aboutDesc':
        'Trusted physiotherapy platform to support your recovery and wellness.',
    'aboutFeatureBooking': 'Easy\nBooking',
    'aboutFeatureMonitor': 'Health\nMonitor',
    'aboutFeatureHomeCare': 'Home\nCare',
    'aboutDeveloper': 'Developed by',
    'closeBtn': 'Close',
    'logoutTitle': 'Sign Out?',
    'logoutDesc': 'You will be signed out of your current account.',
    'logoutConfirm': 'Sign Out',
    'comingSoon': 'Coming soon',
    'languageToggle': 'Language',
    'languageToggleSub': 'Switch app language',
    'incompleteProfileTitle': 'Complete Your Account Info',
    'incompleteProfileDesc': 'ID number and address are not filled in yet.',
    'incompleteProfileBtn': 'Complete',

    // ── Tab navigation ───────────────────────────────────────────────────
    'tabBeranda': 'Home',
    'tabProgress': 'Progress',
    'tabReservasi': 'Reservation',
    'tabRiwayat': 'History',
    'tabPengaturan': 'Settings',

    // ── Missing keys that exist in ID ──────────────────────────────────
    'enterPhoneNumberTitle': 'Enter Phone Number',
    'emailAlreadyUsedTitle': 'Email Already Registered',
    'emailAlreadyUsedByPhone':
        'This email is already used by an account registered via phone number. Please log in with your phone number.',
    'loginWithPhone': 'Log In with Phone Number',

    // ── Notification preferences ────────────────────────────────────────
    'notifSectionPush': 'Push Notifications',
    'notifSectionEmail': 'Email Notifications',
    'notifPushTitle': 'Allow Notifications',
    'notifPushSubtitle': 'Receive pop-up notifications on your phone screen.',
    'notifReminderTitle': 'Therapy Schedule Reminder',
    'notifReminderSubtitle': 'Notifications 1 day and 2 hours before your physiotherapy session.',
    'notifPromoTitle': 'Promos & Offers',
    'notifPromoSubtitle': 'Discounts and the latest health service packages.',
    'notifEmailTitle': 'News via Email',
    'notifEmailSubtitle': 'We will send health articles to your email.',

    // ── Edit profile ─────────────────────────────────────────────────────
    'profileSavedSuccess': '✓ Profile saved successfully',
    'failedTitle': 'Failed',
    'camera': 'Camera',
    'gallery': 'Gallery',
    'deletePhoto': 'Delete Photo',
    'profilePhotoUpdated': '✓ Profile photo updated',
    'uploadPhotoFailed': 'Failed to upload photo. Try again.',
    'profilePhotoDeleted': 'Profile photo deleted',
    'personalInfoSection': 'Personal Information',
    'fullNameHint': 'Your full name',
    'contactSection': 'Contact',
    'securitySection': 'Security',
    'deleteAccountPermanent': 'Delete Account Permanently',
    'deleteAccountTitle': 'Delete Account',
    'deleteAccountDesc': 'Your account and all your data will be permanently deleted. This action cannot be undone.',
    'deleteBtn': 'Delete',
    'phoneNotFound': 'Phone number not found',
    'verifyPinTitle': 'Verify PIN',
    'enterPinToContinue': 'Enter your PIN to continue',
    'verifyBtn': 'Verify',
    'wrongPinShort': 'Wrong PIN',
    'deleteAccountFailed': 'Failed to delete account. Please try again.',
  },
  AppLanguage.id: {
    'language': 'Bahasa',
    'skip': 'Lewati',
    'back': 'Kembali',
    'next': 'Lanjut',
    'getStarted': 'Mulai',
    'welcomeTo': 'Pesan Jadwal',
    'kedotaPhysiotherapy': 'Tanpa Ribet!',
    'onboardingWelcomeDesc':
        'Atur jadwal konsultasi dengan gampang dan efisien!',
    'recoveryWith': 'Pantau Kesehatan',
    'guidance': 'Lebih Mudah',
    'onboardingRecoveryDesc': 'Monitor perkembangan vital-mu secara real-time.',
    'startYour': 'Perawatan Medis',
    'journey': 'Dirumah Anda',
    'onboardingJourneyDesc':
        'Atur jadwal untuk melakukan perawatan medis dirumah.',
    'tagline': 'Kenyamanan Anda, kepedulian kami',
    'splashTitle': 'Kedota',
    'splashSubtitle': 'Physiotherapy',
    'splashTagline': 'Kenyamanan Anda, kepedulian kami',
    'welcomeToSignIn': 'Selamat datang di\nAplikasi ',
    'physiotherapyApp': ' Physiotherapy',
    'signInSubtitle':
        'Ruang yang tenang untuk melanjutkan perjalanan pemulihan Anda bersama Kedota.',
    'phoneNumber': 'Nomor Telepon',
    'enterPin': 'Masukkan PIN 6 digit',
    'continuePhone': 'Lanjut dengan Nomor Telepon',
    'orContinueWith': 'atau lanjut dengan',
    'continueGoogle': 'Google',
    'continueApple': 'Apple',
    'dontHaveAccount': 'Belum punya akun? ',
    'signUp': 'Daftar',
    'signIn': 'Masuk',
    'tryAgainSeconds': 'Coba lagi dalam {seconds} detik',
    'accountLocked': 'Akun terkunci sementara',
    'enterPhoneError': 'Masukkan nomor telepon Anda',
    'validPhoneError': 'Masukkan nomor telepon Indonesia yang valid',
    'numberNotRegistered': 'Nomor ini belum terdaftar. Silakan daftar dulu.',
    'enterSixPinError': 'Masukkan PIN 6 digit',
    'tooManyAttempts': 'Terlalu banyak percobaan PIN gagal. {time}.',
    'lockedAlert':
        'Terlalu banyak percobaan PIN gagal. Akun Anda terkunci sementara selama 5 menit. Peringatan keamanan telah dikirim ke {phone}.',
    'wrongPin': 'PIN salah. Sisa {attempts} percobaan.',
    'createAccount': 'Buat Akun',
    'createAccountSubtitle':
        'Daftarkan akun Anda dengan satu langkah modern dan aman.',
    'phoneExample': 'Contoh: 81234567890',
    'continue': 'Lanjut',
    'or': 'ATAU',
    'alreadyHaveAccount': 'Sudah punya akun? ',
    'phoneRequiredPeriod': 'Masukkan nomor telepon Anda.',
    'invalidPhoneFormat': 'Format nomor telepon tidak valid.',
    'phoneAlreadyRegistered': 'Nomor telepon ini sudah terdaftar.',
    'phoneAlreadyRegisteredDesc':
        'Nomor ini sudah terhubung ke akun lain. Gunakan nomor lain atau masuk dengan akun yang sudah terdaftar.',
    'signInOrUseAnother': 'Silakan masuk ke akun Anda atau gunakan nomor lain.',
    'useAnotherNumber': 'Gunakan Nomor Lain',
    'socialSignInSuccess':
        '{provider} berhasil masuk. Silakan lengkapi profil Anda.',
    'fullNameRequired': 'Nama lengkap wajib diisi.',
    'invalidEmail': 'Format email tidak valid.',
    'birthDateRequired': 'Tanggal lahir wajib diisi.',
    'gender': 'Jenis Kelamin',
    'male': 'Laki-laki',
    'female': 'Perempuan',
    'otherGender': 'Lainnya',
    'genderRequired': 'Jenis kelamin wajib dipilih.',
    'pinEmpty': 'PIN tidak boleh kosong.',
    'pinNumbersOnly': 'PIN hanya boleh berisi angka.',
    'pinSixDigits': 'PIN harus 6 digit.',
    'pinMismatch': 'Konfirmasi PIN tidak cocok.',
    'registrationSuccessfulToast': 'Registrasi berhasil.',
    'completeProfile': 'Lengkapi Profil Anda',
    'completeProfilePhone': 'Lengkapi detail Anda sebelum melanjutkan.',
    'completeProfileSocial':
        'Detail Anda sudah terisi otomatis. Silakan periksa dan lanjutkan.',
    'completeProfileMessage': 'Silakan lengkapi profil Anda untuk melanjutkan.',
    'fullName': 'Nama Lengkap',
    'email': 'Email',
    'birthDate': 'Tanggal Lahir',
    'createPin': 'Buat PIN',
    'createPinDesc':
        'Buat PIN 6 digit untuk melindungi akun Anda. PIN ini akan digunakan sebagai lapisan keamanan tambahan.',
    'confirmPinDesc': 'Masukkan kembali 6 digit PIN yang baru saja Anda buat.',
    'pin': 'PIN',
    'confirmPin': 'Konfirmasi PIN',
    'savePin': 'Simpan PIN',
    'registrationSuccessful': 'Registrasi Berhasil',
    'registrationSuccessDesc':
        'Akun Anda telah dibuat. Anda akan diarahkan ke halaman Masuk.',
    'goToSignIn': 'Ke Halaman Masuk',
    'otpInvalid': 'OTP yang Anda masukkan tidak valid. Silakan coba lagi.',
    'pinCreated': 'PIN dibuat: {pin}',
    'verifyPhone': 'Verifikasi telepon Anda',
    'sentCode': 'Kami mengirim kode 4 digit ke {phone}.',
    'enterOtp': 'Masukkan OTP',
    'otpExpires': 'OTP kedaluwarsa dalam {seconds} detik',
    'otpExpired': 'OTP kedaluwarsa. Silakan kirim ulang OTP.',
    'verifyOtp': 'Verifikasi OTP',
    'enterOtpSentTo':
        'Masukkan 4 digit kode OTP yang telah dikirimkan ke nomor ',
    'resendIn': 'Kirim Ulang Dalam ',
    'otpSentTitle': 'Kode OTP Dikirim',
    'otpResent': 'OTP berhasil dikirim ulang.',
    'resendOtp': 'Kirim Ulang OTP',
    'sendOtp': 'Kirim OTP',
    'forgotPin': 'Lupa PIN',
    'enterPhoneNumberTitle': 'Masukkan No. Telepon',
    'forgotPinDesc':
        'Kami akan mengirimkan kode OTP ke nomor Anda untuk verifikasi sebelum membuat PIN baru.',
    'resetPin': 'Reset PIN',
    'pinResetSent': 'Petunjuk reset PIN telah dikirim ke telepon Anda.',
    'welcome': 'Selamat Datang',
    'unregisteredDialogContent':
        'Nomor telepon ini belum terdaftar. Apakah Anda ingin mendaftar sekarang?',
    'googleAccountNotRegistered':
        'Akun Google ini belum terdaftar. Silakan daftar dulu.',
    'googleUnregisteredDialogContent':
        'Akun Google ini belum terdaftar. Apakah Anda ingin mendaftar sekarang?',
    'continueSignUp': 'Lanjut Daftar',
    'phoneNotRegisteredOrIncomplete':
        'Nomor belum terdaftar atau belum melengkapi profil.',
    'wrongPinOrSignInFailed': 'PIN salah atau gagal masuk.',
    'enterPinDesc': 'Silakan masukkan PIN 6 digit Anda untuk masuk.',
    'signedInSuccessfully': 'Berhasil masuk',
    'noInternetTitle': 'Tidak Ada Koneksi Internet',
    'noInternetSubtitle': 'Tolong Periksa Koneksi Internet Anda',
    'otpLimitTitle': 'Batas Permintaan OTP!',
    'otpLimitSubtitle': 'Mohon tunggu 30 detik sebelum meminta kode OTP kembali.',
    'verificationLimitTitle': 'Batas Verifikasi',
    'verificationLimitSubtitle':
        'Mohon tunggu 30 detik sebelum mencoba verifikasi kembali.',
    'pinLimitTitle': 'Batas Memasukkan PIN.',
    'pinLimitSubtitle': 'Mohon tunggu 30 detik untuk memasukkan PIN.',
    'dormantAccountTitle': 'Akun Tidak Aktif > 60 Hari',
    'dormantAccountSubtitle':
        'Akun Anda telah tidak aktif lebih dari 60 hari. Demi keamanan, OTP akan dikirimkan ke email terdaftar Anda.',
    'sentEmailCode': 'Kami mengirim kode 4 digit ke email {email}.',
    'continueEmail': 'Lanjut ke OTP Email',
    'createNewPin': 'Buat PIN Baru',
    'createNewPinDesc': 'Masukkan 6 digit PIN baru untuk akun Anda.',
    'confirmNewPin': 'Konfirmasi PIN Baru',
    'pinUpdatedSuccessTitle': 'PIN Berhasil Diperbarui',
    'pinUpdatedSuccessDesc':
        'PIN Anda telah berhasil diperbarui. Silakan masuk menggunakan PIN baru Anda.',
    'wait30Seconds': 'Tunggu {seconds} detik...',
    'verifyBirthDateTitle': 'Verifikasi Tanggal Lahir',
    'verifyBirthDateDesc':
        'Silakan pilih tanggal lahir Anda untuk memverifikasi identitas akun.',
    'selectBirthDateHint': 'dd/mm/yyyy',
    'selectBirthDateError': 'Silakan pilih tanggal lahir Anda terlebih dahulu.',
    'birthDateMismatchError':
        'Tanggal lahir tidak sesuai. Silakan tunggu 3 detik untuk mencoba lagi.',
    'confirmPinMismatchError':
        'PIN konfirmasi tidak cocok. Silakan buat ulang.',
    'sameAsOldPinError': 'PIN baru tidak boleh sama dengan PIN lama.',
    'googleProfileTitle': 'Lengkapi Profil Google',
    'googleProfileDesc':
        'Data akun Google Anda terisi otomatis. Silakan periksa atau ubah, lalu buat PIN 6-digit Anda.',
    'saveAndContinue': 'Simpan & Masuk',
    'googleAccount': 'Akun Google',
    'cancel': 'Batal',
    'continueText': 'Lanjut',
    'pleaseSignUpFirst': 'Silakan melakukan pendaftaran terlebih dahulu.',
    'profileCompletedTitle': 'Profil Berhasil Dilengkapi',
    'profileCompletedSubtitle':
        'Selamat datang! Akun Google Anda telah siap digunakan.',
    'resetPinFailed': 'Gagal mereset PIN. Silakan coba lagi.',
    'saveProfileFailed': 'Gagal menyimpan profil. Silakan coba lagi.',
    'successfullyLoggedIn': 'Anda berhasil login!',
    'googleVerifiedEnterPin': 'Google terverifikasi. Masukkan PIN Anda.',
    'googleSignInFailed': 'Google sign-in gagal',
    'phoneVerified': 'Telepon Terverifikasi',
    'completeYourProfile': 'Lengkapi Profil Anda',
    'phoneProfileDesc':
        'Nomor telepon Anda telah terverifikasi. Sekarang lengkapi informasi profil Anda.',
    'fullNameExample': 'Contoh: Budi Santoso',
    'emailRequired': 'Email wajib diisi.',
    'validEmailError': 'Silakan masukkan alamat email yang valid.',
    'accountCreatedTitle': 'Akun Berhasil Dibuat',
    'accountCreatedSubtitle': 'Selamat datang! Akun Anda telah siap digunakan.',
    'emailAlreadyRegistered':
        'Email ini sudah terdaftar. Silakan gunakan email lain atau login.',
    'emailAlreadyUsedTitle': 'Email Sudah Terdaftar',
    'emailAlreadyUsedByPhone':
        'Email ini sudah digunakan untuk akun yang terdaftar via nomor telepon. Silakan login menggunakan nomor telepon Anda.',
    'loginWithPhone': 'Login dengan Nomor Telepon',
    'accountExistsTitle': 'Akun Sudah Ada',
    'accountExistsByPhone':
        'Email ini sudah terhubung dengan akun yang terdaftar via nomor telepon {phone}. Silakan login dengan nomor telepon Anda terlebih dahulu.',

    // ── Home screen ──────────────────────────────────────────────────────
    'greetingMorning': 'Selamat Pagi',
    'greetingAfternoon': 'Selamat Siang',
    'greetingEvening': 'Selamat Sore',
    'greetingNight': 'Selamat Malam',
    'searchHint': 'Cari layanan atau terapis…',
    'upcomingAppointment': 'Janji Temu Mendatang',
    'seeAll': 'Lihat semua',
    'ourServices': 'Layanan Kami',
    'rehabProgress': 'Progress Rehabilitasi',
    'detail': 'Detail',
    'popularSearch': 'Pencarian Populer',
    'noResultFor': 'Tidak ada hasil untuk',
    'serviceCat': 'Layanan',
    'therapistCat': 'Terapis',
    'tipsCat': 'Tips',
    'homeCare': 'Home Care',
    'homeCareDesc': 'Terapi di rumah Anda',
    'klinik': 'Klinik',
    'klinikDesc': 'Kunjungi klinik fisioterapi kami',
    'rehab': 'Rehabilitasi',
    'rehabDesc': 'Program pemulihan gerak tubuh',
    'wellness': 'Wellness',
    'wellnessDesc': 'Perawatan kebugaran & relaksasi',
    'tipsStretch': 'Peregangan Sebelum Sesi',
    'tipsStretchBody': 'Lakukan peregangan 10 menit untuk hasil optimal',
    'tipsWater': 'Minum Air yang Cukup',
    'tipsWaterBody': 'Hidrasi membantu pemulihan otot lebih cepat',
    'tipsRest': 'Istirahat Teratur',
    'tipsRestBody': 'Tidur 7–8 jam mempercepat proses rehabilitasi',
    'appointmentLabel': 'Home Care · Marvin McKinney',
    'appointmentDate': 'Selasa, 18 Agu · 11:00 – 12:00',
    'bookNow': 'Pesan Sekarang',
    'weeklyProgress': 'Progress Mingguan',
    'sessions': 'sesi',
    'tipsTitle': 'Tips Hari Ini',

    // ── History screen ───────────────────────────────────────────────────
    'historyTitle': 'Riwayat',
    'historySubtitle': 'Riwayat jadwal terapi Anda',
    'filterAll': 'Semua',
    'filterUpcoming': 'Mendatang',
    'filterDone': 'Selesai',
    'filterCancelled': 'Dibatalkan',
    'sortLabel': 'Urutkan',
    'sortNewest': 'Terbaru',
    'sortOldest': 'Terlama',
    'sortByDate': 'Per Tanggal',
    'upcomingAppointmentSection': 'Janji Temu Mendatang',
    'previousHistory': 'Riwayat Sebelumnya',
    'statusUpcoming': 'Mendatang',
    'statusDone': 'Selesai',
    'statusExpired': 'Batas Waktu',
    'statusCancelled': 'Dibatalkan',
    'reschedule': 'Jadwal Ulang',
    'cancel2': 'Batalkan',
    'noAppointments': 'Tidak ada janji temu',
    'filterDate': 'Tanggal',

    // ── Settings screen ──────────────────────────────────────────────────
    'settingsTitle': 'Pengaturan',
    'emailVerified': 'Email Terverifikasi',
    'emailNotVerified': 'Verifikasi Email',
    'idCopied': 'ID disalin',
    'groupAccount': 'Akun',
    'groupPreferences': 'Preferensi',
    'groupSupport': 'Dukungan & Tentang',
    'groupServices': 'Layanan',
    'groupInfo': 'Informasi',
    'groupOther': 'Lainnya',
    'menuEditProfile': 'Informasi Akun',
    'menuEditProfileSub': 'Nama, foto, dan informasi pribadi',
    'menuChangePin': 'Ubah PIN',
    'menuChangePinSub': 'Ganti PIN keamanan akun Anda',
    'menuNotification': 'Notifikasi',
    'menuNotificationSub': 'Atur preferensi notifikasi',
    'menuCS': 'Dukungan Pelanggan',
    'menuCSSub': 'Hubungi tim dukungan kami',
    'menuAddress': 'Alamat Saya',
    'menuAddressSub': 'Kelola alamat pengiriman dan layanan',
    'menuFaq': 'FAQ',
    'menuFaqSub': 'Pertanyaan yang sering ditanyakan',
    'menuTerms': 'Syarat & Ketentuan',
    'menuTermsSub': 'Pelajari syarat penggunaan layanan',
    'menuPrivacy': 'Kebijakan Privasi',
    'menuPrivacySub': 'Cara kami melindungi data Anda',
    'menuAbout': 'Tentang Aplikasi',
    'menuAboutSub': 'v1.0.0 · PT Trifa Axis Global',
    'menuLogout': 'Keluar',
    'menuLogoutSub': 'Keluar dari akun Anda',
    'aboutAppDesc': 'Aplikasi Fisioterapi',
    'aboutVersion': 'Versi 1.0.0',
    'aboutDesc':
        'Platform fisioterapi terpercaya untuk membantu pemulihan dan kesehatan Anda.',
    'aboutFeatureBooking': 'Booking\nMudah',
    'aboutFeatureMonitor': 'Monitor\nKesehatan',
    'aboutFeatureHomeCare': 'Home\nCare',
    'aboutDeveloper': 'Dikembangkan oleh',
    'closeBtn': 'Tutup',
    'logoutTitle': 'Keluar dari Akun?',
    'logoutDesc': 'Anda akan keluar dari akun Anda saat ini.',
    'logoutConfirm': 'Keluar',
    'comingSoon': 'Segera hadir',
    'languageToggle': 'Bahasa',
    'languageToggleSub': 'Ganti bahasa aplikasi',
    'incompleteProfileTitle': 'Lengkapi Informasi Akun',
    'incompleteProfileDesc': 'NIK dan alamat belum diisi.',
    'incompleteProfileBtn': 'Lengkapi',

    // ── Tab navigation ───────────────────────────────────────────────────
    'tabBeranda': 'Beranda',
    'tabProgress': 'Progres',
    'tabReservasi': 'Reservasi',
    'tabRiwayat': 'Riwayat',
    'tabPengaturan': 'Pengaturan',

    // ── Notification preferences ────────────────────────────────────────
    'notifSectionPush': 'Notifikasi Push',
    'notifSectionEmail': 'Notifikasi Email',
    'notifPushTitle': 'Izinkan Notifikasi',
    'notifPushSubtitle': 'Menerima pemberitahuan pop-up di layar HP Anda.',
    'notifReminderTitle': 'Pengingat Jadwal Terapi',
    'notifReminderSubtitle': 'Notifikasi H-1 dan 2 jam sebelum jadwal fisioterapi Anda.',
    'notifPromoTitle': 'Promo & Penawaran',
    'notifPromoSubtitle': 'Informasi diskon dan paket layanan kesehatan terbaru.',
    'notifEmailTitle': 'Update Berita via Email',
    'notifEmailSubtitle': 'Kami akan mengirimkan artikel kesehatan ke email Anda.',

    // ── Edit profile ─────────────────────────────────────────────────────
    'profileSavedSuccess': '✓ Profil berhasil disimpan',
    'failedTitle': 'Gagal',
    'camera': 'Kamera',
    'gallery': 'Galeri',
    'deletePhoto': 'Hapus Foto',
    'profilePhotoUpdated': '✓ Foto profil diperbarui',
    'uploadPhotoFailed': 'Gagal upload foto. Coba lagi.',
    'profilePhotoDeleted': 'Foto profil dihapus',
    'personalInfoSection': 'Informasi Pribadi',
    'fullNameHint': 'Nama lengkap Anda',
    'contactSection': 'Kontak',
    'securitySection': 'Keamanan',
    'deleteAccountPermanent': 'Hapus Akun Permanen',
    'deleteAccountTitle': 'Hapus Akun',
    'deleteAccountDesc': 'Akun dan semua data Anda akan dihapus secara permanen. Tindakan ini tidak dapat dibatalkan.',
    'deleteBtn': 'Hapus',
    'phoneNotFound': 'Nomor telepon tidak ditemukan',
    'verifyPinTitle': 'Verifikasi PIN',
    'enterPinToContinue': 'Masukkan PIN Anda untuk melanjutkan',
    'verifyBtn': 'Verifikasi',
    'wrongPinShort': 'PIN salah',
    'deleteAccountFailed': 'Gagal menghapus akun. Silakan coba lagi.',
  },
};
