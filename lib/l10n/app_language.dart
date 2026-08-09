import 'package:flutter/material.dart';

enum AppLanguage { en, id }

final appLanguageNotifier = ValueNotifier<AppLanguage>(AppLanguage.id);

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

  static void toggle(BuildContext context) {
    final notifier = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>()
        ?.notifier;
    if (notifier == null) return;
    notifier.value = notifier.value == AppLanguage.en
        ? AppLanguage.id
        : AppLanguage.en;
  }
}

String t(BuildContext context, String key) {
  final language = AppLanguageScope.current(context);
  return _translations[language]?[key] ??
      _translations[AppLanguage.id]![key] ??
      key;
}

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
    'sentCode': 'We sent a 6-digit code to {phone}.',
    'enterOtp': 'Enter OTP',
    'otpExpires': 'OTP expires in {seconds} seconds',
    'otpExpired': 'OTP expired. Please resend OTP.',
    'verifyOtp': 'Verify OTP',
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
    'otpLimitSubtitle': 'Wait 1 hour before sending another OTP code!',
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
    'selectBirthDateHint': 'Select Birth Date (DD/MM/YYYY)',
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
    'sentCode': 'Kami mengirim kode 6 digit ke {phone}.',
    'enterOtp': 'Masukkan OTP',
    'otpExpires': 'OTP kedaluwarsa dalam {seconds} detik',
    'otpExpired': 'OTP kedaluwarsa. Silakan kirim ulang OTP.',
    'verifyOtp': 'Verifikasi OTP',
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
    'otpLimitSubtitle': 'Mohon tunggu 1 jam sebelum meminta kode OTP kembali.',
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
    'selectBirthDateHint': 'Pilih Tanggal Lahir (DD/MM/YYYY)',
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
  },
};
