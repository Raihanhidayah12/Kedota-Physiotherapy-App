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
    appLanguageNotifier.value = saved == 'en' ? AppLanguage.en : AppLanguage.id;
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
    'cameraPermissionTitle': 'Camera Permission Required',
    'cameraPermissionDesc': 'Allow camera access to take a profile photo.',
    'cameraPermissionSettingsDesc':
        'Camera access is blocked. Enable it in your phone settings.',
    'openSettings': 'Open Settings',
    'onboardingTitle1': 'Book Appointments Easily!',
    'onboardingDesc1': 'Schedule your consultations\nwith ease and efficiency!',
    'onboardingTitle2': 'Track Your Health More Easily',
    'onboardingDesc2': 'Monitor your vital progress\nin real time',
    'onboardingTitle3': 'Medical Care at Your Home',
    'onboardingDesc3': 'Schedule medical care\nat home',
    'notificationTherapyTitle': 'Physiotherapy Appointment Tomorrow',
    'notificationTherapyBody':
        'Do not forget your therapy session tomorrow at 10:00 AM at Central Clinic.',
    'notificationJustNow': 'Just now',
    'notificationProfileTitle': 'Profile Updated Successfully',
    'notificationReservationTitle': 'Appointment Reserved',
    'notificationReservationBody':
        '{service} appointment reserved for {date} at {time}.',
    'welcomeNotificationTitle': 'Welcome to Kedota',
    'welcomeNotificationBody':
        'Welcome! New patients get 10% off Klinik reservations in Malang.',
    'notificationScreenTitle': 'Notifications',
    'markNotificationsRead': 'Mark as read',
    'notificationsMarkedRead': 'All notifications have been marked as read',
    'noNotifications': 'No notifications yet.',
    'notificationProfileBody':
        'Your profile data has been successfully updated.',
    'notificationHoursAgo': '{hours} hours ago',
    'notificationPromoTitle': '20% Special Offer',
    'notificationPromoBody':
        'Get 20% off a back therapy package. Valid until the end of the month!',
    'notificationYesterday': 'Yesterday',
    'notificationTestTitle': 'Hello from Kedota!',
    'notificationTestBody': 'This is a sample notification from your app.',
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
    'signInFailedTitle': 'Sign-in Failed',
    'appleSignInFailed': 'Apple Sign-In failed',
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
    'forgotPinTitle': 'Forgot PIN',
    'otpVerificationTitle': 'OTP Verification',
    'infoTitle': 'Information',
    'successTitle': 'Success',
    'termsRequired': 'Please agree to the applicable terms and conditions.',
    'confirmNewPin': 'Confirm New PIN',
    'pinUpdatedSuccessTitle': 'PIN Updated Successfully',
    'pinUpdatedSuccessDesc':
        'Your PIN has been updated. Please sign in using your new PIN.',
    'wait30Seconds': 'Wait {seconds} seconds...',
    'changePinAvailableIn': 'Available again in {seconds} seconds',
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
    'sameAsOldPinAttemptError':
        'New PIN cannot be the same as your old PIN. {attempts} attempts remaining.',
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
    'accountCreatedCountdown':
        'Get ready, in %s seconds you will enter your new adventure!',
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
    'welcomeGreeting': 'Welcome!',
    'independentTasks': 'Independent Tasks',
    'taskStretch': 'Back Muscle Stretching',
    'taskLatihanOtot': 'Back Muscle Exercise',
    'taskPanggul': 'Pelvic Tilt Exercise',
    'taskJalan': 'Relaxed Walking',
    'detail': 'Detail',
    'popularSearch': 'Popular Searches',
    'noResultFor': 'No results for',
    'serviceCat': 'Service',
    'therapistCat': 'Therapist',
    'tipsCat': 'Tips',
    'homeCare': 'Home Care',
    'homeCareDesc': 'Therapy at your home',
    'promoNewPatientTag': 'NEW PATIENT PROMO',
    'promoNewPatientTitle': '10% Off for\nNew Patients',
    'promoNewPatientSubtitle': 'Malang City',
    'promoWhatsAppTag': 'FREE SERVICE',
    'promoWhatsAppTitle': 'Free Consultation via\nWhatsApp',
    'promoWhatsAppSubtitle': 'All Branches',
    'promoClaim': 'Claim',
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
    'refreshHistory': 'Refresh appointment history',
    'filterAll': 'All',
    'filterUpcoming': 'Upcoming',
    'filterDone': 'Done',
    'filterCancelled': 'Cancelled',
    'filterNoShow': 'No Show',
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
    'buatJanjiTemu': 'Make Appointment',
    'terapisLabel': 'Therapist:',
    'lihatDetail': 'View Detail',
    'noHistoryLabel': 'No appointment history.',
    'reservationTitle': 'Kedota Reservation',
    'reservationStagePatient': 'Patient Data',
    'reservationStageSchedule': 'Choose Schedule and Service',
    'reservationStageSession': 'Choose Session',
    'reservationStagePayment': 'Payment Method',
    'reservationForWho': 'Who is this reservation for?',
    'reservationForSelf': 'Reserve for Myself',
    'reservationForOther': 'Reserve for Someone Else',
    'reservationPatientData': 'Patient Data',
    'reservationPatientDataDesc': 'Review or edit the patient details.',
    'reservationNik': 'National ID number',
    'reservationMedicalCode': 'Medical Code',
    'reservationFullName': 'Full Name',
    'reservationGender': 'Gender',
    'reservationBirthDate': 'Date of Birth',
    'reservationPhone': 'Phone Number',
    'reservationComplaint': 'Patient Complaint',
    'reservationComplaintHint': 'Describe the complaint',
    'reservationComplaintMinLength':
        'Please describe your complaint in at least 10 characters.',
    'reservationClinic': 'Choose Clinic',
    'therapistDefault': 'Kedota Therapist',
    'openClinicMap': 'Get directions to clinic',
    'reservationService': 'Choose Service',
    'reservationDate': 'Choose Date',
    'reservationTimeUnavailable':
        'This appointment time was just booked. Please choose another time.',
    'reservationTime': 'Choose Time',
    'reservationAddress': 'Address',
    'reservationAddressHint': 'Auto-detected address',
    'reservationHomeCareAddressHint': 'Enter or select the Home Care address',
    'reservationHomeCareLocation': 'Choose Home Care Location',
    'reservationSundayClosed': 'Appointments are not available on Sundays.',
    'reservationMapTitle': 'Choose Location on Map',
    'reservationMapHint': 'Pan and zoom the map to inspect the location.',
    'reservationMapExpand': 'Expand map',
    'reservationCopyAccount': 'Copy account number',
    'reservationAccountCopied': 'Account number copied',
    'reservationQrisStep1':
        'Open your banking or e-wallet app and choose Scan QR.',
    'reservationQrisStep2':
        'Scan the QR code shown above and check the payment amount.',
    'reservationQrisStep3':
        'Confirm the payment and keep the successful transaction receipt.',
    'reservationWalletStep1': 'Open the selected e-wallet application.',
    'reservationWalletStep2':
        'Choose Pay or Transfer and enter the amount shown above.',
    'reservationWalletStep3':
        'Confirm with your PIN and keep the payment receipt.',
    'reservationBankMbca': 'How to pay via mBCA',
    'reservationBankIbanking': 'How to pay via Internet Banking',
    'reservationBankAtm': 'How to pay via ATM',
    'reservationBankStep1':
        'Choose Transfer, then select the bank account or virtual account menu.',
    'reservationBankStep2':
        'Enter the account number above and confirm the payment amount.',
    'reservationBankStep3':
        'Confirm the transaction and save the payment receipt.',
    'reservationCardStep1': 'Enter your card number, expiry date, and CVV.',
    'reservationCardStep2':
        'Check the payment amount and submit the transaction.',
    'reservationCardStep3': 'Complete the verification code from your bank.',
    'reservationScheduleHint':
        'Choose the closest clinic and available service.',
    'reservationUseCurrentLocation': 'Use Current Location',
    'reservationTherapistAvailability':
        'Agree to availability of female and male therapists',
    'reservationAvailabilityRequired':
        'Please confirm therapist availability before continuing.',
    'locationServiceDisabled': 'Please enable location services first.',
    'locationPermissionDenied': 'Location permission is required to use GPS.',
    'locationUnavailable': 'Current location is unavailable.',
    'reservationTherapistGender': 'Therapist Gender Preference',
    'reservationAnyGender': 'Any',
    'reservationFemale': 'Female',
    'reservationMale': 'Male',
    'reservationNext': 'Continue',
    'reservationBack': 'Back',
    'reservationChooseSession': 'Choose Session',
    'reservationSessionUnit': 'Sessions',
    'reservationSessionHint': 'Choose the therapy package you want.',
    'reservationPaymentPlan': 'Payment Type',
    'reservationPaymentPlanFull': 'Full Payment',
    'reservationPaymentPlanDeposit': 'Deposit',
    'paymentPending': 'Unpaid',
    'remainingPayment': 'Remaining Payment',
    'settlePayment': 'Pay Balance',
    'paymentComingSoon': 'Balance payment flow will be available soon.',
    'choosePaymentMethod': 'Choose Payment Method',
    'bankTransfer': 'Bank Transfer',
    'cashPayment': 'Cash Payment at Clinic',
    'confirmPayment': 'Confirm Payment',
    'reservationOrderSummary': 'Order Summary',
    'reservationPaymentSummary': 'Payment Summary',
    'reservationBasePrice': 'Base Price',
    'reservationTravelFee': 'Travel Fee',
    'reservationTotal': 'Total Payment',
    'reservationDiscount': 'New patient discount',
    'reservationDiscountAmount': 'Discount amount',
    'reservationAmountDue': 'Amount due now',
    'reservationPaymentDeadline':
        '*Payment must be completed within 10 minutes after choosing the payment method.',
    'reservationChoosePayment': 'Choose Payment Method',
    'reservationPaymentCash': 'Cash',
    'reservationPaymentQris': 'QRIS',
    'reservationPaymentWallet': 'E-Wallet',
    'reservationPaymentBank': 'Bank Transfer',
    'reservationPaymentCard': 'Credit Card',
    'reservationPaymentAvailable': 'Available payment methods',
    'reservationPaymentQrisWallet': 'QRIS & E-Wallet',
    'reservationPaymentBankTransfer': 'Bank Transfer',
    'reservationPaymentCardDebit': 'Credit / Debit Card',
    'reservationPaymentInstructionQris': 'QRIS Payment Instructions',
    'reservationPaymentInstructionWallet': 'E-Wallet Payment',
    'reservationPaymentInstructionBank': 'Bank Transfer Payment',
    'reservationPaymentInstructionCard': 'Credit Card Payment',
    'reservationPayNow': 'Pay Now',
    'reservationVirtualAccount': 'Virtual Account Number',
    'reservationCardholder': 'Cardholder Name',
    'reservationCardNumber': 'Card Number',
    'reservationCardExpiry': 'Valid Until',
    'reservationCardCvv': 'CVV',
    'reservationPaymentHowTo': 'Payment Instructions',
    'reservationSuccess': 'Reservation Created',
    'reservationSuccessDesc':
        'Your appointment has been saved and is waiting for payment.',
    'reservationSaved': 'Reservation saved',
    'paymentSuccessTitle': 'Payment Successful',
    'paymentSuccessDesc':
        'Your reservation on {date} at {clinic} has been confirmed.',
    'paymentReturningHome':
        'You will be redirected to History in {seconds} seconds',
    'historyDetailTitle': 'History Detail',
    'addToCalendar': 'Add to Calendar',
    'therapyAppointmentCalendarTitle': 'Therapy Appointment',
    'calendarAppointmentDetails': 'Kedota physiotherapy appointment',
    'calendarDateInvalid': 'The appointment date or time is invalid.',
    'calendarOpenFailed': 'Could not open the calendar.',
    'calendarPermissionRequired': 'Calendar permission is required.',
    'calendarUnavailable': 'No writable calendar was found.',
    'calendarAdded': 'Added to calendar. Reminder set for 1 hour before.',
    'patientData': 'Patient Data',
    'detailSection': 'Detail',
    'patientName': 'Kedota Patient',
    'emrCopied': 'EMR copied',
    'bookingCode': 'Booking code',
    'bookingCodeCopied': 'Booking code copied',
    'paymentPendingNotificationTitle': 'Deposit Payment Pending',
    'paymentPendingNotificationBody':
        'Please complete your deposit payment for the appointment on',
    'notificationScheduleUpdatedTitle': 'Schedule Updated',
    'notificationScheduleUpdatedBody':
        'Your appointment schedule has been updated to',
    'patientIdLabel': 'Patient ID',
    'copyPatientId': 'Copy patient ID',
    'patientIdCopied': 'Patient ID copied',
    'patientComplaint': 'Patient Complaint',
    'clinicalNotesAfterSession': 'Post-Session Clinical Notes',
    'quantitativeAssessmentScore': 'Quantitative Assessment Score',
    'notesAfterTherapistInput': '*Will appear after the therapist enters notes',
    'progressMonitoringIndicator': 'Progress Monitoring Indicator',
    'progressAfterTherapistInput':
        '*Will appear after the therapist enters progress',
    'expiredAppointmentTitle': 'Appointment Not Fulfilled',
    'expiredAppointmentBody':
        'This session passed its time limit without the patient attending.',
    'upcomingAppointmentButton': 'Reschedule Appointment',
    'rescheduleAppointmentButton': 'Reschedule',
    'contactCustomerService': 'Contact Support',
    'customerServiceWhatsAppMessage':
        'Hello Kedota, I need help with appointment {bookingCode} on {date} at {time}.',
    'sessionCount': '4 Sessions',
    'patientComplaintBody':
        'I would like to report persistent back pain that continues to interfere with my daily activities. It feels very uncomfortable and makes it difficult for me to move.',
    'therapistLicense': 'License: 19820481/FT-JBT/2021',
    'painScale': 'Pain Scale (VAS)',
    'muscleStrength': 'Muscle Strength (MMT)',
    'improving': 'Improving',
    'recommendationBody':
        'We strongly recommend continuing your therapist\'s advice on light stretching and maintaining good posture. This is important to reduce your back pain. Please return in two weeks for further evaluation.',
    'patientAddress': 'Jl. Melati No. 45, Merjosari, Malang, East Java',
    'wib': 'WIB',
    'sessionCountShort': '4 Sessions',
    'sessionUnit': 'Sessions',
    'clinicalNoteCompleted':
        'The patient showed improved lumbar mobility. Pain decreased from a scale of 7 to 4. Three more sessions are recommended.',
    'clinicalNoteExpired':
        'The patient did not attend the scheduled appointment. The session was forfeited. The patient is advised to reschedule based on therapist availability.',
    'romLabel': 'ROM',
    'odiLabel': 'ODI',
    'scoreUnitTen': '/ 10',
    'scoreUnitOneTwenty': '/ 120',
    'scoreUnitFive': '/ 5',
    'scoreUnitFifty': '/ 50',
    'improvingPercent': 'Improving (%s)',

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
    'address': 'Address',
    'addressHint': 'Enter your full address',
    'nik': 'ID Number',
    'nikHint': 'Enter your 16-digit ID number',
    'nikLengthError': 'ID number must be 16 digits',

    // ── Tab navigation ───────────────────────────────────────────────────
    'tabBeranda': 'Home',
    'tabProgress': 'Progress',
    'tabJanjiTemu': 'Appointment',
    'tabProfil': 'Profile',

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
    'notifReminderSubtitle':
        'Notifications 1 day and 2 hours before your physiotherapy session.',
    'appointmentReminderTitle': 'Therapy Appointment Reminder',
    'appointmentReminderBody': 'Your therapy appointment starts at {time}.',
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
    'biometricLogin': 'Biometric verification',
    'biometricLoginDesc': 'Use fingerprint or Face ID to verify your PIN.',
    'biometricUnavailable':
        'Biometric verification is not available on this device.',
    'biometricSetupFailed': 'Biometric verification was not enabled.',
    'biometricReason': 'Verify your identity to enable biometric verification.',
    'biometricPermissionTitle': 'Enable Biometric',
    'biometricPermissionMessage':
        'This app will request permission to use your biometric authentication (fingerprint or face recognition) for secure login.',
    'biometricNotSupportedTitle': 'Not Supported',
    'biometricNotSupportedMessage':
        'Your device does not support biometric authentication.',
    'biometricNotEnrolledTitle': 'Biometric Not Set Up',
    'biometricNotEnrolledMessage':
        'You need to set up fingerprint or face recognition on your device first. Go to your phone Settings to add biometric authentication.',
    'allowBtn': 'Allow',
    'openSettingsBtn': 'Open Settings',
    'deleteAccountPermanent': 'Delete Account Permanently',
    'deleteAccountTitle': 'Delete Account',
    'deleteAccountDesc':
        'Your account and all your data will be permanently deleted. This action cannot be undone.',
    'deleteBtn': 'Delete',
    'phoneNotFound': 'Phone number not found',
    'sessionExpiredUsePIN': 'Session expired. Please login with your PIN.',
    'appLockedTitle': 'App Locked',
    'appLockedDesc': 'Please re-authenticate to continue',
    'loadErrorTitle': 'Failed to Load Data',
    'loadErrorSubtitle': 'Please refresh the page',
    'verifyPinTitle': 'Verify PIN',
    'enterPinToContinue': 'Enter your PIN to continue',
    'verifyBtn': 'Verify',
    'wrongPinShort': 'Wrong PIN',
    'deleteAccountFailed': 'Failed to delete account. Please try again.',
    'faqIntro': 'Find answers to common questions about Kedota.',
    'faqQuestion1': 'Is my NIK safe if I enter it in the application?',
    'faqAnswer1':
        'Your NIK is displayed in masked form on the profile page and can only be viewed in full through the "Show" button. It is used for administration and electronic medical records (EMR), and is not shared with third parties beyond service needs.',
    'faqQuestion2':
        'Can I make a reservation for a family member or someone else?',
    'faqAnswer2':
        'Yes. When making a reservation, select "For Someone Else" and enter the patient data manually.',
    'faqQuestion3': 'Is there an additional fee for Home Care services?',
    'faqAnswer3':
        'Yes. Home Care services have an additional fee based on the distance between your address and the nearest clinic. The fee is shown in detail before payment.',
    'faqQuestion4': 'What happens if I do not attend without rescheduling?',
    'faqAnswer4':
        'The reservation will be marked No-show and the down payment that has been paid will be forfeited.',

    // ── Progress screen ──────────────────────────────────────────────────
    'progressTitle': 'Progress',
    'progressSubtitle': 'Track your rehabilitation progress',
    'progressTotalSessions': 'Total Sessions',
    'progressPainScore': 'Pain Score',
    'progressAverage': 'Average',
    'progressWeekThis': 'This Week',
    'progressWeekLast': 'Last Week',
    'progressWeek2Ago': '2 Weeks Ago',
    'progressPainChartTitle': 'Pain Score',
    'progressPainChartDesc': 'Scale 0–10 (lower is better)',
    'progressPainTrend': '−4.0 pts',
    'progressStatCompleted': 'Completed Sessions',
    'progressStatUpcoming': 'Upcoming Sessions',
    'progressStatSatisfaction': 'Satisfaction',
    'progressStatRemaining': 'Sessions Left',
    'progressPackageTitle': 'Therapy Package Progress',
    'progressSessionCount': '{completed} of {total} sessions completed',
    'progressSessionsRemaining': '{count} sessions remaining',
    'progressChartTitle': 'Session Completion',
    'progressChartDesc': 'Your completed sessions in this therapy package',
    'progressChartCompleted': 'Completed',
    'progressChartRemaining': 'Remaining',
    'progressNoSessions': 'No therapy sessions yet.',
    'rescheduleSave': 'Save New Schedule',
    'progressSessionHistoryTitle': 'Session History',
    'progressSessionLabel': 'Session',
    'progressSessionDone': 'Done',
    'progressServiceHomeCare': 'Home Care',
    'progressServiceKlinik': 'Clinic',
    'progressDayMon': 'Mon',
    'progressDayTue': 'Tue',
    'progressDayWed': 'Wed',
    'progressDayThu': 'Thu',
    'progressDayFri': 'Fri',
    'progressDaySat': 'Sat',
    'progressDaySun': 'Sun',

    'termsHeading': 'Terms and Conditions',
    'termsUpdated': 'Last updated: 01/09/2026',
    'termsIntro':
        'These Terms and Conditions govern your use of the Kedota application ("Application") provided by [Kedota Business Entity] ("Kedota", "we", or "us"). By creating an account and using the Application, you ("User") are considered to have read, understood, and agreed to all of the following terms.',
    'termsSection1': 'Using Kedota',
    'termsBody1':
        'Kedota helps you discover and manage physiotherapy services. Please provide accurate account information and use the service responsibly.',
    'termsSection2': 'Appointments',
    'termsBody2':
        'Appointments depend on therapist availability. Please arrive on time and contact support if you need to make a change.',
    'termsSection3': 'Account security',
    'termsBody3':
        'Keep your PIN private. You are responsible for activity performed through your account.',
    'termsSection4': '1.4 Payment Policy',
    'termsBody4':
        'Down payments must be made before a reservation is confirmed. Remaining payments may be completed at the clinic or through available digital payment methods. Applicable payment fees are the User\'s responsibility and are shown before confirmation. Transactions are processed by licensed third-party payment providers.',
    'termsSection5': '1.5 Rescheduling and Cancellation Policy',
    'termsBody5':
        'Rescheduling may be requested no later than one day (24 hours) before the session. Confirmed reservations are non-refundable unless cancelled by Kedota. A missed appointment without timely rescheduling forfeits the down payment. Kedota may cancel or change a schedule in certain circumstances and will provide a full refund or free rescheduling.',
    'termsSection6': '1.6 Limitation of Liability',
    'termsBody6':
        'Kedota provides a platform connecting Patients with Therapist Partners and is not the definitive medical service provider. Therapy results may vary. Kedota is not responsible for losses caused by inaccurate or incomplete User information. In a medical emergency, contact the nearest emergency service and do not rely on the Application for emergency care.',
    'termsSection7': '1.7 Changes to the Terms',
    'termsBody7':
        'Kedota may change these Terms and Conditions at any time. Significant changes will be announced through the Application, and Users may be asked to agree to the updated terms before continuing to use the Application.',
    'termsSection8': '1.8 Governing Law',
    'termsBody8':
        'These Terms and Conditions are governed by the laws of the Republic of Indonesia. Disputes will first be resolved through discussion and, if no agreement is reached, according to applicable Indonesian law.',
    'privacyHeading': 'Privacy Policy',
    'privacyUpdated': 'Last updated: 01/09/2026',
    'privacyIntro':
        'This Privacy Policy explains how Kedota collects, uses, stores, and protects User personal data in accordance with Law Number 27 of 2022 on Personal Data Protection (PDP Law).',
    'privacySection1': '1.1 Data we collect',
    'privacyBody1': '''Identity Data
Full name, National Identity Number (NIK), date of birth, gender, phone number, and email address.

Health Data
Patient complaints, selected service categories, and notes and assessment results from Therapist Partners, including assessment scores and therapy history. This is specific personal data under the PDP Law and receives special protection.

Location Data
Address and location coordinates selected by the User for Home Care services.

Transaction Data
Reservation history, payment methods, and payment status. Payment card and bank account data are not stored by Kedota and are processed directly by our third-party payment provider.

Technical Data
Device information, application activity logs, and usage data for security and service improvement.''',
    'privacySection2': '1.2 Legal basis and purposes',
    'privacyBody2':
        '''We process your personal data based on your consent when registering and using the Application, and to perform the service contract between you and Kedota. Data is used to:

1. Process reservations, payments, and therapy services.
2. Store and display your therapy history and progress.
3. Send notifications about schedules, payments, and session results.
4. Improve service quality and Application security.
5. Fulfill legal obligations, including medical record keeping.''',
    'privacySection3': '1.3 Data storage and security',
    'privacyBody3':
        '''1. NIK and other sensitive data are masked by default in the Application interface and shown in full only at the User's explicit request.
2. We apply encryption and layered access controls to protect personal data from unauthorized access, alteration, or disclosure.
3. Access to Patient health data is limited to the Therapist Partner handling that Patient and authorized administrative personnel.
4. Data is stored while the User account is active and for a certain period after deactivation as required for legal and operational purposes, before permanent deletion or anonymization.''',
    'privacySection4': '1.4 Sharing data with third parties',
    'privacyBody4':
        'We do not sell your personal data. Data may be shared on a limited basis with payment providers to process transactions, Therapist Partners handling your therapy session to the extent relevant to the service, and authorized authorities when required by law.',
    'privacySection5': '1.5 Your rights as a data subject',
    'privacyBody5':
        'Under the PDP Law, you have the right to access and obtain a copy of your personal data, update or correct inaccurate data through the Application, request deletion or deactivation of your account, withdraw consent for certain processing, and submit objections or complaints about processing of your personal data.',
    'privacySection6': '1.6 Contact',
    'privacyBody6':
        'For questions, data access requests, or privacy complaints, contact us at the responsible data protection email address [to be completed] or through the Customer Support page in the Kedota Application.',
    'privacySection7': '1.7 Changes to this Privacy Policy',
    'privacyBody7':
        'We may update this Privacy Policy from time to time to reflect changes to our services or applicable regulations. Significant changes will be announced through the Application, and you may be asked to provide consent again before continuing to use the service. This document is a working draft and requires finalization with the legal team before official publication.',
    'supportHeading': 'Questions or complaints?',
    'supportDesc':
        'Contact us for service questions, data access requests, or privacy complaints.',
    'supportService': 'Service questions',
    'supportServiceDesc': 'Questions about reservations and therapy services',
    'supportDataAccess': 'Data access requests',
    'supportDataAccessDesc': 'Request access to the personal data we store',
    'supportPrivacy': 'Privacy complaints',
    'supportPrivacyDesc': 'Report concerns about personal data processing',
    'supportEmail': 'Data protection email',
    'supportEmailPlaceholder': '[Email address to be completed]',
    'operatingHours': 'Operating hours',
    'weekdayHours': 'Monday - Friday',
    'saturdayHours': 'Saturday',
    'sundayHours': 'Sunday',
    'closed': 'Closed',
    'contact': 'Contact',
    'whatsapp': 'WhatsApp',
    'whatsappOpenFailed': 'Unable to open WhatsApp.',
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
    'cameraPermissionTitle': 'Izin Kamera Diperlukan',
    'cameraPermissionDesc': 'Izinkan akses kamera untuk mengambil foto profil.',
    'cameraPermissionSettingsDesc':
        'Akses kamera diblokir. Aktifkan melalui pengaturan HP Anda.',
    'openSettings': 'Buka Pengaturan',
    'onboardingTitle1': 'Pesan Jadwal Tanpa Ribet!',
    'onboardingDesc1': 'Atur Jadwal Konsultasi dengan\nGampang dan Efisien!',
    'onboardingTitle2': 'Pantau Kesehatan Lebih Mudah',
    'onboardingDesc2': 'Monitor Perkembangan Vital-mu\nSecara Real-time',
    'onboardingTitle3': 'Perawatan Medis Di Rumah Anda',
    'onboardingDesc3': 'Atur Jadwal Untuk Melakukan\nPerawatan Medis Di Rumah',
    'notificationTherapyTitle': 'Jadwal Fisioterapi Besok',
    'notificationTherapyBody':
        'Jangan lupa jadwal sesi terapi Anda besok jam 10:00 WIB di Klinik Pusat.',
    'notificationJustNow': 'Baru saja',
    'notificationProfileTitle': 'Update Profil Berhasil',
    'notificationReservationTitle': 'Janji Temu Berhasil Dipesan',
    'notificationReservationBody':
        'Janji temu {service} pada {date} pukul {time} berhasil dipesan.',
    'welcomeNotificationTitle': 'Selamat Datang di Kedota',
    'welcomeNotificationBody':
        'Selamat datang! Pasien baru mendapat diskon 10% untuk reservasi Klinik di Malang.',
    'notificationScreenTitle': 'Notifikasi',
    'markNotificationsRead': 'Tandai sudah dibaca',
    'notificationsMarkedRead': 'Semua notifikasi sudah dibaca',
    'noNotifications': 'Belum ada notifikasi.',
    'notificationProfileBody':
        'Data profil Anda telah berhasil diperbarui ke sistem kami.',
    'notificationHoursAgo': '{hours} jam yang lalu',
    'notificationPromoTitle': 'Promo Spesial 20%',
    'notificationPromoBody':
        'Dapatkan diskon 20% untuk paket terapi punggung. Berlaku hingga akhir bulan!',
    'notificationYesterday': 'Kemarin',
    'notificationTestTitle': 'Halo dari Kedota!',
    'notificationTestBody':
        'Ini adalah contoh notifikasi langsung dari aplikasi Anda.',
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
    'signInFailedTitle': 'Gagal Masuk',
    'appleSignInFailed': 'Apple Sign-In gagal',
    'enterPinDesc': 'Silakan masukkan PIN 6 digit Anda untuk masuk.',
    'signedInSuccessfully': 'Berhasil masuk',
    'noInternetTitle': 'Tidak Ada Koneksi Internet',
    'noInternetSubtitle': 'Tolong Periksa Koneksi Internet Anda',
    'otpLimitTitle': 'Batas Permintaan OTP!',
    'otpLimitSubtitle':
        'Mohon tunggu 30 detik sebelum meminta kode OTP kembali.',
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
    'forgotPinTitle': 'Lupa PIN',
    'otpVerificationTitle': 'Verifikasi OTP',
    'infoTitle': 'Informasi',
    'successTitle': 'Berhasil',
    'termsRequired': 'Silakan menyetujui syarat dan ketentuan yang berlaku.',
    'confirmNewPin': 'Konfirmasi PIN Baru',
    'pinUpdatedSuccessTitle': 'PIN Berhasil Diperbarui',
    'pinUpdatedSuccessDesc':
        'PIN Anda telah berhasil diperbarui. Silakan masuk menggunakan PIN baru Anda.',
    'wait30Seconds': 'Tunggu {seconds} detik...',
    'changePinAvailableIn': 'Tersedia lagi dalam {seconds} detik',
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
    'sameAsOldPinAttemptError':
        'PIN tidak boleh sama dengan PIN lama. Sisa {attempts} percobaan.',
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
    'accountCreatedCountdown':
        'Bersiaplah, dalam %s detik Anda akan menuju halaman utama petualangan baru!',
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
    'welcomeGreeting': 'Selamat Datang!',
    'independentTasks': 'Target & Tugas Mandiri',
    'taskStretch': 'Peregangan Otot Punggung',
    'taskLatihanOtot': 'Latihan Otot Inti',
    'taskPanggul': 'Latihan Kemiringan Panggul',
    'taskJalan': 'Jalan Kaki Santai',
    'detail': 'Detail',
    'popularSearch': 'Pencarian Populer',
    'noResultFor': 'Tidak ada hasil untuk',
    'serviceCat': 'Layanan',
    'therapistCat': 'Terapis',
    'tipsCat': 'Tips',
    'homeCare': 'Home Care',
    'homeCareDesc': 'Terapi di rumah Anda',
    'promoNewPatientTag': 'PROMO PASIEN BARU',
    'promoNewPatientTitle': 'Diskon 10% untuk\nPasien Baru',
    'promoNewPatientSubtitle': 'Kota Malang',
    'promoWhatsAppTag': 'LAYANAN GRATIS',
    'promoWhatsAppTitle': 'Konsultasi Gratis via\nWhatsApp',
    'promoWhatsAppSubtitle': 'Semua Cabang',
    'promoClaim': 'Klaim',
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
    'refreshHistory': 'Muat ulang riwayat janji temu',
    'filterAll': 'Semua',
    'filterUpcoming': 'Mendatang',
    'filterDone': 'Selesai',
    'filterCancelled': 'Dibatalkan',
    'filterNoShow': 'Tidak Hadir',
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
    'buatJanjiTemu': 'Buat Janji Temu',
    'terapisLabel': 'Terapis:',
    'lihatDetail': 'Lihat Detail',
    'noHistoryLabel': 'Tidak ada riwayat janji temu.',
    'reservationTitle': 'Reservasi Kedota',
    'reservationStagePatient': 'Data Diri Pasien',
    'reservationStageSchedule': 'Pilih Jadwal dan Layanan',
    'reservationStageSession': 'Pilih Sesi',
    'reservationStagePayment': 'Metode Pembayaran',
    'reservationForWho': 'Reservasi ini untuk siapa?',
    'reservationForSelf': 'Reservasi Mandiri',
    'reservationForOther': 'Reservasi Orang Lain',
    'reservationPatientData': 'Data Diri Pasien',
    'reservationPatientDataDesc': 'Periksa atau ubah data pasien.',
    'reservationNik': 'Nomor NIK',
    'reservationMedicalCode': 'Kode Nomor Medis',
    'reservationFullName': 'Nama Lengkap',
    'reservationGender': 'Jenis Kelamin',
    'reservationBirthDate': 'Tanggal Lahir',
    'reservationPhone': 'Nomor Telepon',
    'reservationComplaint': 'Keluhan Pasien',
    'reservationComplaintHint': 'Masukkan detail keluhan',
    'reservationComplaintMinLength': 'Jelaskan keluhan minimal 10 karakter.',
    'reservationClinic': 'Pilih Klinik',
    'therapistDefault': 'Terapis Kedota',
    'openClinicMap': 'Arahkan ke Google Maps',
    'reservationService': 'Pilih Layanan',
    'reservationDate': 'Pilih Jadwal',
    'reservationTimeUnavailable':
        'Jam janji temu ini baru saja diambil. Silakan pilih jam lain.',
    'reservationTime': 'Pilih Jam',
    'reservationAddress': 'Alamat',
    'reservationAddressHint': 'Otomatis dari data alamat',
    'reservationHomeCareAddressHint': 'Masukkan atau pilih alamat Home Care',
    'reservationHomeCareLocation': 'Pilih Lokasi Home Care',
    'reservationSundayClosed': 'Reservasi tidak tersedia pada hari Minggu.',
    'reservationMapTitle': 'Pilih Lokasi di Peta',
    'reservationMapHint': 'Geser dan perbesar peta untuk melihat lokasi.',
    'reservationMapExpand': 'Perbesar peta',
    'reservationCopyAccount': 'Salin nomor rekening',
    'reservationAccountCopied': 'Nomor rekening berhasil disalin',
    'reservationQrisStep1':
        'Buka aplikasi bank atau e-wallet, lalu pilih Scan QR.',
    'reservationQrisStep2': 'Pindai QR di atas dan periksa nominal pembayaran.',
    'reservationQrisStep3':
        'Konfirmasi pembayaran dan simpan bukti transaksi berhasil.',
    'reservationWalletStep1': 'Buka aplikasi e-wallet yang dipilih.',
    'reservationWalletStep2':
        'Pilih Bayar atau Transfer, lalu masukkan nominal di atas.',
    'reservationWalletStep3':
        'Konfirmasi dengan PIN dan simpan bukti pembayaran.',
    'reservationBankMbca': 'Cara pembayaran via mBCA',
    'reservationBankIbanking': 'Cara pembayaran via Internet Banking',
    'reservationBankAtm': 'Cara pembayaran via ATM',
    'reservationBankStep1':
        'Pilih Transfer, lalu buka menu rekening bank atau virtual account.',
    'reservationBankStep2':
        'Masukkan nomor rekening di atas dan periksa nominal pembayaran.',
    'reservationBankStep3': 'Konfirmasi transaksi dan simpan bukti pembayaran.',
    'reservationCardStep1':
        'Masukkan nomor kartu, tanggal kedaluwarsa, dan CVV.',
    'reservationCardStep2': 'Periksa nominal pembayaran lalu kirim transaksi.',
    'reservationCardStep3': 'Selesaikan kode verifikasi dari bank Anda.',
    'reservationScheduleHint':
        'Pilih klinik terdekat dan layanan yang tersedia.',
    'reservationUseCurrentLocation': 'Gunakan Lokasi Terkini',
    'reservationTherapistAvailability':
        'Bersedia Ketersediaan Terapis Wanita Maupun Pria',
    'reservationAvailabilityRequired':
        'Centang ketersediaan terapis sebelum melanjutkan.',
    'locationServiceDisabled': 'Aktifkan layanan lokasi terlebih dahulu.',
    'locationPermissionDenied': 'Izin lokasi diperlukan untuk menggunakan GPS.',
    'locationUnavailable': 'Lokasi terkini tidak tersedia.',
    'reservationTherapistGender': 'Preferensi Jenis Kelamin Terapis',
    'reservationAnyGender': 'Bebas',
    'reservationFemale': 'Perempuan',
    'reservationMale': 'Laki-Laki',
    'reservationNext': 'Lanjut',
    'reservationBack': 'Kembali',
    'reservationChooseSession': 'Pilih Sesi',
    'reservationSessionUnit': 'Sesi',
    'reservationSessionHint': 'Pilih paket layanan terapi yang kamu mau.',
    'reservationPaymentPlan': 'Jenis Pembayaran',
    'reservationPaymentPlanFull': 'Lunas',
    'reservationPaymentPlanDeposit': 'DP',
    'paymentPending': 'Belum Lunas',
    'remainingPayment': 'Sisa Pembayaran',
    'settlePayment': 'Lunasi Pembayaran',
    'paymentComingSoon': 'Fitur pelunasan akan segera tersedia.',
    'choosePaymentMethod': 'Pilih Metode Pembayaran',
    'bankTransfer': 'Transfer Bank',
    'cashPayment': 'Pembayaran Tunai di Klinik',
    'confirmPayment': 'Konfirmasi Pembayaran',
    'reservationOrderSummary': 'Rincian Pesanan',
    'reservationPaymentSummary': 'Rincian Pembayaran',
    'reservationBasePrice': 'Biaya Sesi',
    'reservationTravelFee': 'Biaya Jarak',
    'reservationTotal': 'Total Biaya',
    'reservationDiscount': 'Diskon pasien baru',
    'reservationDiscountAmount': 'Nominal diskon',
    'reservationAmountDue': 'Total tagihan saat ini',
    'reservationPaymentDeadline':
        '*Maksimal pembayaran dilakukan 10 menit setelah memilih metode pembayaran.',
    'reservationChoosePayment': 'Pilih Metode Pembayaran',
    'reservationPaymentCash': 'Lunas',
    'reservationPaymentQris': 'QRIS',
    'reservationPaymentWallet': 'E-Wallet',
    'reservationPaymentBank': 'Transfer Bank',
    'reservationPaymentCard': 'Kartu Kredit',
    'reservationPaymentAvailable': 'Pilih metode pembayaran yang tersedia',
    'reservationPaymentQrisWallet': 'QRIS & E-Wallet',
    'reservationPaymentBankTransfer': 'Transfer Bank',
    'reservationPaymentCardDebit': 'Kartu Kredit / Debit',
    'reservationPaymentInstructionQris': 'Cara Pembayaran QRIS',
    'reservationPaymentInstructionWallet': 'Pembayaran E-Wallet',
    'reservationPaymentInstructionBank': 'Pembayaran Transfer Bank',
    'reservationPaymentInstructionCard': 'Pembayaran Kartu Kredit',
    'reservationPayNow': 'Bayar Sekarang',
    'reservationVirtualAccount': 'Nomor Rekening Virtual',
    'reservationCardholder': 'Nama Pemilik Kartu',
    'reservationCardNumber': 'Nomor Kartu',
    'reservationCardExpiry': 'Berlaku Hingga',
    'reservationCardCvv': 'CVV',
    'reservationPaymentHowTo': 'Cara Pembayaran',
    'reservationSuccess': 'Reservasi Berhasil Dibuat',
    'reservationSuccessDesc': 'Janji temu tersimpan dan menunggu pembayaran.',
    'reservationSaved': 'Reservasi tersimpan',
    'paymentSuccessTitle': 'Pembayaran Berhasil',
    'paymentSuccessDesc':
        'Reservasi Anda pada {date} di {clinic} sudah terkonfirmasi.',
    'paymentReturningHome':
        'Anda akan diarahkan ke Riwayat dalam {seconds} detik',
    'historyDetailTitle': 'Detail Riwayat',
    'addToCalendar': 'Tambah ke Kalender',
    'therapyAppointmentCalendarTitle': 'Janji Temu Terapi',
    'calendarAppointmentDetails': 'Janji temu fisioterapi Kedota',
    'calendarDateInvalid': 'Tanggal atau waktu janji temu tidak valid.',
    'calendarOpenFailed': 'Kalender tidak dapat dibuka.',
    'calendarPermissionRequired': 'Izin kalender diperlukan.',
    'calendarUnavailable': 'Tidak ada kalender yang dapat ditulis.',
    'calendarAdded':
        'Janji temu ditambahkan. Pengingat diatur 1 jam sebelumnya.',
    'patientData': 'Data Pasien',
    'detailSection': 'Detail',
    'patientName': 'Pasien Kedota',
    'emrCopied': 'EMR disalin',
    'bookingCode': 'Kode pemesanan',
    'bookingCodeCopied': 'Kode pemesanan disalin',
    'paymentPendingNotificationTitle': 'Pembayaran DP Belum Lunas',
    'paymentPendingNotificationBody': 'Silakan lunasi DP untuk janji temu pada',
    'notificationScheduleUpdatedTitle': 'Jadwal Berhasil Diperbarui',
    'notificationScheduleUpdatedBody':
        'Jadwal janji temu Anda telah diperbarui menjadi',
    'patientIdLabel': 'ID Pasien',
    'copyPatientId': 'Salin ID pasien',
    'patientIdCopied': 'ID pasien disalin',
    'patientComplaint': 'Keluhan Pasien',
    'clinicalNotesAfterSession': 'Catatan Klinis Pasca Sesi',
    'quantitativeAssessmentScore': 'Skor Assessment Kuantitatif',
    'notesAfterTherapistInput':
        '*Akan muncul setelah terapis menginput catatan',
    'progressMonitoringIndicator': 'Indikator Pemantauan Progres',
    'progressAfterTherapistInput':
        '*Akan muncul setelah terapis menginput progres',
    'expiredAppointmentTitle': 'Janji Temu Tidak Terpenuhi',
    'expiredAppointmentBody':
        'Sesi ini telah melewati batas waktu tanpa kehadiran pasien.',
    'upcomingAppointmentButton': 'Ubah Jadwal Janji Temu',
    'rescheduleAppointmentButton': 'Jadwal Ulang',
    'contactCustomerService': 'Hubungi CS',
    'customerServiceWhatsAppMessage':
        'Halo Kedota, saya ingin bantuan untuk janji temu {bookingCode} pada {date} pukul {time}.',
    'sessionCount': '4 Sesi',
    'patientComplaintBody':
        'Saya ingin mengeluhkan nyeri punggung yang terus-menerus mengganggu aktivitas sehari-hari saya. Rasanya sangat tidak nyaman dan membuat saya sulit bergerak.',
    'therapistLicense': 'SIPF: 19820481/FT-JBT/2021',
    'painScale': 'Skala Nyeri (VAS)',
    'muscleStrength': 'Kekuatan Otot (MMT)',
    'improving': 'Membaik',
    'recommendationBody':
        'Kami sangat menyarankan Anda untuk terus mengikuti saran dari terapis mengenai peregangan ringan dan menjaga postur tubuh yang baik. Ini penting untuk mengurangi nyeri punggung Anda. Silakan kembali dalam dua minggu untuk evaluasi lebih lanjut.',
    'patientAddress': 'Jl. Melati No. 45, Merjosari, Malang, Jawa Timur',
    'wib': 'WIB',
    'sessionCountShort': '4 Sesi',
    'sessionUnit': 'Sesi',
    'clinicalNoteCompleted':
        'Pasien menunjukkan perbaikan mobilitas lumbar. Nyeri berkurang dari skala 7 menjadi 4. Direkomendasikan lanjut 3 sesi berikutnya.',
    'clinicalNoteExpired':
        'Pasien tidak hadir pada jadwal yang telah ditentukan. Sesi dinyatakan hangus. Pasien disarankan untuk menjadwalkan ulang sesuai ketersediaan terapis.',
    'romLabel': 'ROM',
    'odiLabel': 'ODI',
    'scoreUnitTen': '/ 10',
    'scoreUnitOneTwenty': '/ 120',
    'scoreUnitFive': '/ 5',
    'scoreUnitFifty': '/ 50',
    'improvingPercent': 'Membaik (%s)',

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
    'address': 'Alamat',
    'addressHint': 'Masukkan alamat lengkap',
    'nik': 'NIK',
    'nikHint': 'Masukkan 16 digit NIK',
    'nikLengthError': 'NIK harus 16 digit',

    // ── Tab navigation ───────────────────────────────────────────────────
    'tabBeranda': 'Beranda',
    'tabProgress': 'Progres',
    'tabJanjiTemu': 'Janji Temu',
    'tabProfil': 'Profil',

    // ── Notification preferences ────────────────────────────────────────
    'notifSectionPush': 'Notifikasi Push',
    'notifSectionEmail': 'Notifikasi Email',
    'notifPushTitle': 'Izinkan Notifikasi',
    'notifPushSubtitle': 'Menerima pemberitahuan pop-up di layar HP Anda.',
    'notifReminderTitle': 'Pengingat Jadwal Terapi',
    'notifReminderSubtitle':
        'Notifikasi H-1 dan 2 jam sebelum jadwal fisioterapi Anda.',
    'appointmentReminderTitle': 'Pengingat Janji Temu Terapi',
    'appointmentReminderBody': 'Janji temu terapi Anda dimulai pukul {time}.',
    'notifPromoTitle': 'Promo & Penawaran',
    'notifPromoSubtitle':
        'Informasi diskon dan paket layanan kesehatan terbaru.',
    'notifEmailTitle': 'Update Berita via Email',
    'notifEmailSubtitle':
        'Kami akan mengirimkan artikel kesehatan ke email Anda.',

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
    'biometricLogin': 'Verifikasi biometrik',
    'biometricLoginDesc':
        'Gunakan sidik jari atau Face ID untuk verifikasi PIN.',
    'biometricUnavailable':
        'Verifikasi biometrik tidak tersedia di perangkat ini.',
    'biometricSetupFailed': 'Verifikasi biometrik tidak berhasil diaktifkan.',
    'biometricReason':
        'Verifikasi identitas untuk mengaktifkan verifikasi biometrik.',
    'biometricPermissionTitle': 'Aktifkan Biometrik',
    'biometricPermissionMessage':
        'Aplikasi akan meminta izin untuk menggunakan autentikasi biometrik (sidik jari atau pengenalan wajah) untuk login yang aman.',
    'biometricNotSupportedTitle': 'Tidak Didukung',
    'biometricNotSupportedMessage':
        'Perangkat Anda tidak mendukung autentikasi biometrik.',
    'biometricNotEnrolledTitle': 'Biometrik Belum Diatur',
    'biometricNotEnrolledMessage':
        'Anda perlu mengatur sidik jari atau pengenalan wajah di perangkat Anda terlebih dahulu. Buka Pengaturan HP untuk menambahkan autentikasi biometrik.',
    'allowBtn': 'Izinkan',
    'openSettingsBtn': 'Buka Pengaturan',
    'deleteAccountPermanent': 'Hapus Akun Permanen',
    'deleteAccountTitle': 'Hapus Akun',
    'deleteAccountDesc':
        'Akun dan semua data Anda akan dihapus secara permanen. Tindakan ini tidak dapat dibatalkan.',
    'deleteBtn': 'Hapus',
    'phoneNotFound': 'Nomor telepon tidak ditemukan',
    'sessionExpiredUsePIN': 'Sesi habis. Silakan login dengan PIN Anda.',
    'appLockedTitle': 'Aplikasi Terkunci',
    'appLockedDesc': 'Silakan autentikasi kembali untuk melanjutkan',
    'loadErrorTitle': 'Gagal Memuat Data',
    'loadErrorSubtitle': 'Silahkan refresh halaman',
    'verifyPinTitle': 'Verifikasi PIN',
    'enterPinToContinue': 'Masukkan PIN Anda untuk melanjutkan',
    'verifyBtn': 'Verifikasi',
    'wrongPinShort': 'PIN salah',
    'deleteAccountFailed': 'Gagal menghapus akun. Silakan coba lagi.',
    'faqIntro': 'Temukan jawaban untuk pertanyaan umum tentang Kedota.',
    'faqQuestion1': 'Apakah NIK saya aman jika saya masukkan ke aplikasi?',
    'faqAnswer1':
        'NIK Anda ditampilkan dalam bentuk tersamar (masking) di halaman profil dan hanya dapat dilihat lengkap melalui tombol "Tampilkan". Data ini digunakan untuk keperluan administrasi dan rekam medis (EMR), dan tidak dibagikan kepada pihak ketiga di luar kebutuhan layanan.',
    'faqQuestion2':
        'Bisakah saya membuat reservasi untuk anggota keluarga atau orang lain?',
    'faqAnswer2':
        'Bisa. Saat membuat reservasi, Anda dapat memilih "Untuk Orang Lain" dan mengisi data pasien secara manual.',
    'faqQuestion3': 'Apakah ada biaya tambahan untuk layanan Home Care?',
    'faqAnswer3':
        'Ya. Layanan Home Care dikenakan biaya tambahan berdasarkan jarak antara alamat Anda dan klinik terdekat, yang akan ditampilkan secara rinci sebelum Anda melakukan pembayaran.',
    'faqQuestion4':
        'Bagaimana jika saya tidak hadir tanpa melakukan reschedule?',
    'faqAnswer4':
        'Reservasi akan berstatus Tidak Hadir (No-show) dan DP yang telah dibayarkan dianggap hangus.',

    // ── Progress screen ──────────────────────────────────────────────────
    'progressTitle': 'Progres',
    'progressSubtitle': 'Pantau perkembangan rehabilitasi Anda',
    'progressTotalSessions': 'Total Sesi',
    'progressPainScore': 'Pain Score',
    'progressAverage': 'Rata-rata',
    'progressWeekThis': 'Minggu Ini',
    'progressWeekLast': 'Minggu Lalu',
    'progressWeek2Ago': '2 Minggu Lalu',
    'progressPainChartTitle': 'Pain Score',
    'progressPainChartDesc': 'Skala 0–10 (lebih rendah lebih baik)',
    'progressPainTrend': '−4.0 pts',
    'progressStatCompleted': 'Sesi Selesai',
    'progressStatUpcoming': 'Sesi Mendatang',
    'progressStatSatisfaction': 'Kepuasan',
    'progressStatRemaining': 'Sisa Sesi',
    'progressPackageTitle': 'Progress Paket Terapi',
    'progressSessionCount': '{completed} dari {total} sesi selesai',
    'progressSessionsRemaining': 'Tersisa {count} sesi',
    'progressChartTitle': 'Penyelesaian Sesi',
    'progressChartDesc': 'Sesi yang sudah diselesaikan dalam paket terapi',
    'progressChartCompleted': 'Selesai',
    'progressChartRemaining': 'Tersisa',
    'progressNoSessions': 'Belum ada sesi terapi.',
    'rescheduleSave': 'Simpan Jadwal Baru',
    'progressSessionHistoryTitle': 'Riwayat Sesi',
    'progressSessionLabel': 'Sesi',
    'progressSessionDone': 'Selesai',
    'progressServiceHomeCare': 'Home Care',
    'progressServiceKlinik': 'Klinik',
    'progressDayMon': 'Sen',
    'progressDayTue': 'Sel',
    'progressDayWed': 'Rab',
    'progressDayThu': 'Kam',
    'progressDayFri': 'Jum',
    'progressDaySat': 'Sab',
    'progressDaySun': 'Min',

    'termsHeading': 'Syarat dan Ketentuan',
    'termsUpdated': 'Terakhir diperbarui: 01/09/2026',
    'termsIntro':
        'Syarat dan Ketentuan ini mengatur penggunaan aplikasi Kedota ("Aplikasi") yang disediakan oleh [Nama Badan Usaha Kedota] ("Kedota", "kami"). Dengan membuat akun dan menggunakan Aplikasi, Anda ("Pengguna") dianggap telah membaca, memahami, dan menyetujui seluruh ketentuan berikut.',
    'termsSection1': '1.1 Definisi',
    'termsBody1':
        '''1. "Pasien" adalah individu yang menerima layanan terapi, baik pemilik akun maupun pihak yang direservasikan oleh pemilik akun.
2. "Pemesan" adalah pemilik akun yang melakukan reservasi dan bertanggung jawab atas pembayaran.
3. "Layanan" mencakup layanan terapi di klinik (Offline) maupun kunjungan ke lokasi Pasien (Home Care).
4. "Mitra Terapis" adalah tenaga fisioterapi yang bekerja sama dengan Kedota untuk memberikan Layanan.''',
    'termsSection2': '1.2 Akun Pengguna',
    'termsBody2':
        '''1. Pengguna wajib memberikan data pendaftaran yang benar dan terkini, termasuk NIK untuk keperluan verifikasi dan rekam medis.
2. Pengguna bertanggung jawab menjaga kerahasiaan PIN dan kredensial akunnya. Segala aktivitas yang dilakukan melalui akun Pengguna menjadi tanggung jawab Pengguna, kecuali terbukti terjadi karena kelalaian sistem Kedota.
3. Kedota berhak menangguhkan atau menonaktifkan akun yang terindikasi melakukan penyalahgunaan, termasuk namun tidak terbatas pada percobaan akses tidak sah atau pemberian data identitas palsu.''',
    'termsSection3': '1.3 Reservasi dan Pelaksanaan Layanan',
    'termsBody3':
        '''1. Reservasi dinyatakan sah setelah Pemesan menyelesaikan pembayaran uang muka (DP) sesuai nominal yang ditentukan pada saat reservasi.
2. Slot jadwal yang telah dipilih akan ditahan sementara untuk jangka waktu tertentu guna menyelesaikan pembayaran; apabila melewati batas waktu tersebut tanpa pembayaran, slot akan dilepaskan secara otomatis.
3. Kedota berupaya menyesuaikan preferensi Mitra Terapis (termasuk preferensi gender) sesuai permintaan Pasien, namun tidak menjamin ketersediaan preferensi tersebut pada setiap jadwal.
4. Untuk layanan Home Care, Pasien wajib memastikan ketersediaan dan keamanan lokasi kunjungan bagi Mitra Terapis.''',
    'termsSection4': '1.4 Kebijakan Pembayaran',
    'termsBody4':
        '''1. Pembayaran DP wajib dilakukan sebelum reservasi dinyatakan terkonfirmasi.
2. Sisa pembayaran (pelunasan) dapat diselesaikan secara tunai di lokasi klinik (khusus layanan Offline) atau melalui metode pembayaran digital yang tersedia di Aplikasi.
3. Biaya administrasi atas metode pembayaran tertentu (Virtual Account, kartu kredit) menjadi tanggung jawab Pengguna dan akan ditampilkan secara transparan sebelum konfirmasi pembayaran.
4. Seluruh transaksi pembayaran diproses melalui penyedia jasa pembayaran pihak ketiga yang telah berizin dan diawasi oleh otoritas terkait di Indonesia.''',
    'termsSection5': '1.5 Kebijakan Reschedule dan Pembatalan',
    'termsBody5':
        '''1. Permintaan penjadwalan ulang (reschedule) hanya dapat diajukan paling lambat H-1 (24 jam) sebelum waktu pelaksanaan sesi.
2. Reservasi yang telah dikonfirmasi tidak dapat dibatalkan oleh Pengguna dengan pengembalian dana, kecuali pembatalan dilakukan oleh pihak Kedota.
3. Apabila Pasien tidak hadir pada jadwal yang telah dikonfirmasi tanpa pengajuan reschedule sesuai ketentuan waktu di atas, DP yang telah dibayarkan dinyatakan hangus.
4. Kedota berhak melakukan pembatalan atau perubahan jadwal sepihak dalam keadaan tertentu (misalnya ketidaktersediaan Mitra Terapis), dengan memberikan kompensasi berupa pengembalian dana penuh atau penjadwalan ulang tanpa biaya tambahan kepada Pasien.''',
    'termsSection6': '1.6 Batasan Tanggung Jawab',
    'termsBody6':
        '''1. Kedota menyediakan platform untuk mempertemukan Pasien dengan Mitra Terapis dan tidak bertindak sebagai penyedia layanan medis definitif; hasil terapi dapat bervariasi tergantung kondisi masing-masing Pasien.
2. Kedota tidak bertanggung jawab atas kerugian yang timbul akibat informasi yang tidak akurat atau tidak lengkap yang diberikan oleh Pengguna.
3. Dalam keadaan darurat medis, Pengguna disarankan untuk segera menghubungi layanan gawat darurat terdekat dan tidak mengandalkan Aplikasi sebagai sarana penanganan darurat.''',
    'termsSection7': '1.7 Perubahan Ketentuan',
    'termsBody7':
        'Kedota berhak mengubah Syarat dan Ketentuan ini sewaktu-waktu. Perubahan signifikan akan diinformasikan melalui Aplikasi, dan Pengguna akan diminta menyetujui kembali ketentuan terbaru sebelum melanjutkan penggunaan Aplikasi.',
    'termsSection8': '1.8 Hukum yang Berlaku',
    'termsBody8':
        'Syarat dan Ketentuan ini diatur dan ditafsirkan berdasarkan hukum Republik Indonesia. Segala perselisihan yang timbul akan diselesaikan melalui musyawarah, dan apabila tidak tercapai kesepakatan, akan diselesaikan sesuai ketentuan hukum yang berlaku di Indonesia.',
    'privacyHeading': 'Kebijakan Privasi',
    'privacyUpdated': 'Terakhir diperbarui: 01/09/2026',
    'privacyIntro':
        'Kebijakan Privasi ini menjelaskan bagaimana Kedota mengumpulkan, menggunakan, menyimpan, dan melindungi data pribadi Pengguna sesuai dengan Undang-Undang Nomor 27 Tahun 2022 tentang Pelindungan Data Pribadi (UU PDP).',
    'privacySection1': '1.1 Data yang Kami Kumpulkan',
    'privacyBody1': '''Data Identitas
Nama lengkap, Nomor Induk Kependudukan (NIK), tanggal lahir, jenis kelamin, nomor telepon, dan alamat email.

Data Kesehatan
Keluhan pasien, kategori layanan yang dipilih, serta catatan dan hasil asesmen dari Mitra Terapis, termasuk skor asesmen dan riwayat terapi. Data ini tergolong data pribadi yang bersifat spesifik sebagaimana diatur dalam UU PDP dan diberikan perlindungan khusus.

Data Lokasi
Alamat dan koordinat lokasi yang dipilih Pengguna untuk keperluan layanan Home Care.

Data Transaksi
Riwayat reservasi, metode dan status pembayaran. Data kartu pembayaran dan rekening tidak disimpan oleh Kedota, melainkan diproses langsung oleh penyedia jasa pembayaran pihak ketiga.

Data Teknis
Informasi perangkat, log aktivitas aplikasi, dan data penggunaan untuk keperluan keamanan dan perbaikan layanan.''',
    'privacySection2': '1.2 Dasar Hukum dan Tujuan Penggunaan Data',
    'privacyBody2':
        '''Kami memproses data pribadi Anda berdasarkan persetujuan yang Anda berikan saat mendaftar dan menggunakan Aplikasi, serta untuk pelaksanaan kontrak layanan antara Anda dan Kedota. Data digunakan untuk:

1. Memproses reservasi, pembayaran, dan pelaksanaan layanan terapi.
2. Menyimpan dan menampilkan riwayat serta progres terapi Anda.
3. Mengirimkan notifikasi terkait jadwal, pembayaran, dan hasil sesi.
4. Meningkatkan kualitas layanan dan keamanan Aplikasi.
5. Memenuhi kewajiban hukum yang berlaku, termasuk pencatatan rekam medis.''',
    'privacySection3': '1.3 Penyimpanan dan Keamanan Data',
    'privacyBody3':
        '''1. Data NIK dan data sensitif lainnya ditampilkan dalam bentuk tersamar (masking) secara default pada antarmuka Aplikasi, dan hanya ditampilkan penuh atas permintaan eksplisit Pengguna.
2. Kami menerapkan enkripsi dan kontrol akses berlapis untuk melindungi data pribadi dari akses, perubahan, atau pengungkapan yang tidak sah.
3. Akses terhadap data kesehatan Pasien dibatasi hanya untuk Mitra Terapis yang menangani Pasien tersebut serta personel administrasi yang berwenang.
4. Data akan disimpan selama akun Pengguna aktif dan dalam jangka waktu tertentu setelah akun dinonaktifkan sesuai kebutuhan hukum dan operasional, sebelum dihapus atau dianonimkan secara permanen.''',
    'privacySection4': '1.4 Pembagian Data kepada Pihak Ketiga',
    'privacyBody4':
        'Kami tidak menjual data pribadi Anda kepada pihak manapun. Data dapat dibagikan secara terbatas kepada penyedia jasa pembayaran untuk memproses transaksi, Mitra Terapis yang menangani sesi terapi Anda sebatas data yang relevan, dan otoritas yang berwenang apabila diwajibkan oleh peraturan perundang-undangan.',
    'privacySection5': '1.5 Hak Anda sebagai Subjek Data',
    'privacyBody5':
        'Sesuai UU PDP, Anda memiliki hak untuk mengakses dan memperoleh salinan data pribadi, memperbarui atau mengoreksi data yang tidak akurat melalui Aplikasi, meminta penghapusan atau penonaktifan akun, menarik persetujuan atas pemrosesan data tertentu, serta mengajukan keberatan atau pengaduan terkait pemrosesan data pribadi Anda.',
    'privacySection6': '1.6 Kontak',
    'privacyBody6':
        'Untuk pertanyaan, permintaan akses data, atau pengaduan terkait privasi, Anda dapat menghubungi kami melalui email penanggung jawab perlindungan data [alamat email akan diisi] atau halaman Dukungan Pelanggan pada Aplikasi Kedota.',
    'privacySection7': '1.7 Perubahan Kebijakan Privasi',
    'privacyBody7':
        'Kami dapat memperbarui Kebijakan Privasi ini dari waktu ke waktu mengikuti perubahan layanan atau peraturan yang berlaku. Perubahan signifikan akan diinformasikan melalui Aplikasi, dan Anda mungkin diminta memberikan persetujuan ulang sebelum melanjutkan penggunaan layanan. Dokumen ini adalah draf kerja dan memerlukan finalisasi bersama tim legal sebelum dipublikasikan secara resmi kepada pengguna.',
    'supportHeading': 'Ada pertanyaan atau pengaduan?',
    'supportDesc':
        'Hubungi kami untuk pertanyaan layanan, permintaan akses data, atau pengaduan privasi.',
    'supportService': 'Pertanyaan layanan',
    'supportServiceDesc': 'Pertanyaan tentang reservasi dan layanan terapi',
    'supportDataAccess': 'Permintaan akses data',
    'supportDataAccessDesc': 'Minta akses ke data pribadi yang kami simpan',
    'supportPrivacy': 'Pengaduan privasi',
    'supportPrivacyDesc': 'Laporkan masalah terkait pemrosesan data pribadi',
    'supportEmail': 'Email perlindungan data',
    'supportEmailPlaceholder': '[Alamat email akan diisi]',
    'operatingHours': 'Jam Operasional',
    'weekdayHours': 'Senin - Jumat',
    'saturdayHours': 'Sabtu',
    'sundayHours': 'Minggu',
    'closed': 'Tutup',
    'contact': 'Kontak',
    'whatsapp': 'WhatsApp',
    'whatsappOpenFailed': 'Tidak dapat membuka WhatsApp.',
  },
};
