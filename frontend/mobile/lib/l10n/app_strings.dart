// ──────────────────────────────────────────────
// 1. PinSetupStrings — pin_setup_screen
// ──────────────────────────────────────────────
class PinSetupStrings {
  final String createTitle;
  final String createSubtitle;
  final String confirmTitle;
  final String confirmSubtitle;
  final String biometricTitle;
  final String biometricSubtitle;
  final String pinMismatch;
  final String touchSensor;
  final String skip;
  final String enable;

  PinSetupStrings({required bool isThai})
    : createTitle = isThai ? 'ตั้งรหัส PIN' : 'Set PIN',
      createSubtitle = isThai
          ? 'กรอกรหัส PIN 6 หลักเพื่อรักษาความปลอดภัย'
          : 'Enter a 6-digit PIN for security',
      confirmTitle = isThai ? 'ยืนยันรหัส PIN' : 'Confirm PIN',
      confirmSubtitle = isThai
          ? 'กรอกรหัส PIN อีกครั้งเพื่อยืนยัน'
          : 'Enter PIN again to confirm',
      biometricTitle = isThai ? 'เปิดใช้ลายนิ้วมือ?' : 'Enable Fingerprint?',
      biometricSubtitle = isThai
          ? 'ใช้ลายนิ้วมือเพื่อปลดล็อกแอปได้เร็วขึ้น'
          : 'Use fingerprint for faster unlock',
      pinMismatch = isThai
          ? 'รหัส PIN ไม่ตรงกัน ลองใหม่อีกครั้ง'
          : 'PIN does not match. Try again',
      touchSensor = isThai
          ? 'แตะเซ็นเซอร์เพื่อเปิดใช้งาน'
          : 'Touch sensor to enable',
      skip = isThai ? 'ข้าม' : 'Skip',
      enable = isThai ? 'เปิดใช้งาน' : 'Enable';
}

// ──────────────────────────────────────────────
// 2. PinLockStrings — pin_lock_screen
// ──────────────────────────────────────────────
class PinLockStrings {
  final String enterPin;
  final String enterPinSubtitle;
  final String pinIncorrect;
  final String biometricSuccess;

  PinLockStrings({required bool isThai})
    : enterPin = isThai ? 'กรอกรหัส PIN' : 'Enter PIN',
      enterPinSubtitle = isThai
          ? 'กรอกรหัส PIN 6 หลักเพื่อเข้าใช้งาน'
          : 'Enter 6-digit PIN to unlock',
      pinIncorrect = isThai
          ? 'รหัส PIN ไม่ถูกต้อง ลองใหม่อีกครั้ง'
          : 'Incorrect PIN. Try again',
      biometricSuccess = isThai
          ? 'ยืนยันลายนิ้วมือสำเร็จ'
          : 'Fingerprint verified';
}

// ──────────────────────────────────────────────
// 3. RoleSelectionStrings — role_selection_screen
// ──────────────────────────────────────────────
class RoleSelectionStrings {
  final String roleTitle;
  final String roleSubtitle;
  final String hireTitle;
  final String hireDesc;
  final String hireCta;
  final String guardTitle;
  final String guardDesc;
  final String guardCta;
  final String footerTitle;
  final String footerTerms;

  final String settingsTitle;
  final String changePin;
  final String notifications;
  final String helpSupport;
  final String language;

  RoleSelectionStrings({required bool isThai})
    : roleTitle = isThai ? 'เลือกบทบาทของคุณ' : 'Choose Your Role',
      roleSubtitle = isThai
          ? 'Choose Your Role'
          : 'Select how you want to use P-Guard',
      hireTitle = isThai ? 'ฉันต้องการจ้าง รปภ.' : 'I Want to Hire a Guard',
      hireDesc = isThai
          ? 'จ้างเจ้าหน้าที่รักษาความปลอดภัยระดับมืออาชีพ'
          : 'Hire professional security personnel',
      hireCta = isThai ? 'เริ่มจ้างงาน' : 'Hire Now',
      guardTitle = isThai ? 'ฉันคือเจ้าหน้าที่ รปภ.' : "I'm a Security Guard",
      guardDesc = isThai
          ? 'ลงชื่อเข้าใช้งานระบบ เพื่อเริ่มรับงาน'
          : 'Sign in to start receiving jobs',
      guardCta = isThai ? 'เข้าสู่ระบบ' : 'Login',
      footerTitle = isThai
          ? 'บริการรักษาความปลอดภัยมืออาชีพ'
          : 'PROFESSIONAL SECURITY SOLUTIONS',
      footerTerms = isThai
          ? 'ดำเนินการต่อ หมายถึง คุณยอมรับข้อกำหนดและนโยบายความเป็นส่วนตัว'
          : 'By continuing, you agree to our Terms and Privacy Policy',
      settingsTitle = isThai ? 'ตั้งค่า' : 'Settings',
      changePin = isThai ? 'เปลี่ยนรหัส PIN' : 'Change PIN',
      notifications = isThai ? 'การแจ้งเตือน' : 'Notifications',
      helpSupport = isThai ? 'ช่วยเหลือและสนับสนุน' : 'Help & Support',
      language = isThai ? 'ภาษา' : 'Language';
}

// ──────────────────────────────────────────────
// 4. PhoneInputStrings — phone_input_screen
// ──────────────────────────────────────────────
class PhoneInputStrings {
  final String customerLabel;
  final String guardLabel;
  final String registerTitle;
  final String registerSubtitle;
  final String phoneLabel;
  final String otpInfo;
  final String requestOtp;

  PhoneInputStrings({required bool isThai})
    : customerLabel = isThai ? 'ลูกค้า' : 'Customer',
      guardLabel = isThai ? 'เจ้าหน้าที่ รปภ.' : 'Security Guard',
      registerTitle = isThai ? 'ลงทะเบียน' : 'Register',
      registerSubtitle = isThai
          ? 'กรอกเบอร์โทรศัพท์เพื่อรับรหัส OTP'
          : 'Enter phone number to receive OTP',
      phoneLabel = isThai ? 'เบอร์โทรศัพท์' : 'Phone Number',
      otpInfo = isThai
          ? 'เราจะส่งรหัส OTP 6 หลักไปยังเบอร์นี้'
          : 'We will send a 6-digit OTP to this number',
      requestOtp = isThai ? 'ขอรหัส OTP' : 'Request OTP';
}

// ──────────────────────────────────────────────
// 5. OtpStrings — otp_verification_screen
// ──────────────────────────────────────────────
class OtpStrings {
  final String verifyTitle;
  final String codeSentTo;
  final String otpIncorrect;
  final String resendIn;
  final String seconds;
  final String resendOtp;
  final String prototypeHint;
  final String registerSuccess;

  OtpStrings({required bool isThai})
    : verifyTitle = isThai ? 'ยืนยันรหัส OTP' : 'Verify OTP',
      codeSentTo = isThai
          ? 'รหัส 6 หลักถูกส่งไปที่ '
          : 'A 6-digit code was sent to ',
      otpIncorrect = isThai
          ? 'รหัส OTP ไม่ถูกต้อง ลองใหม่อีกครั้ง'
          : 'Invalid OTP. Try again',
      resendIn = isThai ? 'ส่งรหัสอีกครั้งใน' : 'Resend code in',
      seconds = isThai ? 'วินาที' : 'seconds',
      resendOtp = isThai ? 'ส่งรหัส OTP อีกครั้ง' : 'Resend OTP',
      prototypeHint = isThai
          ? 'Prototype: ใช้รหัส 123456'
          : 'Prototype: Use code 123456',
      registerSuccess = isThai
          ? 'ลงทะเบียนสำเร็จ!'
          : 'Registration successful!';
}



// ──────────────────────────────────────────────
// 5b-old. RegistrationRoleStrings — registration_role_screen
// ──────────────────────────────────────────────
class RegistrationRoleStrings {
  final String title;
  final String subtitle;
  final String customerTitle;
  final String customerDesc;
  final String customerCta;
  final String guardTitle;
  final String guardDesc;
  final String guardCta;
  final String registering;

  RegistrationRoleStrings({required bool isThai})
    : title = isThai ? 'เลือกบทบาทของคุณ' : 'Choose Your Role',
      subtitle = isThai
          ? 'คุณต้องการใช้งานในบทบาทใด?'
          : 'How would you like to use P-Guard?',
      customerTitle = isThai ? 'ผู้เรียกใช้บริการ' : 'Hire a Guard',
      customerDesc = isThai
          ? 'จ้างเจ้าหน้าที่รักษาความปลอดภัยมืออาชีพ'
          : 'Hire professional security personnel',
      customerCta = isThai ? 'สมัครเป็นผู้เรียก' : 'Register as Customer',
      guardTitle = isThai ? 'เจ้าหน้าที่ รปภ.' : 'Security Guard',
      guardDesc = isThai
          ? 'สมัครเป็นเจ้าหน้าที่รักษาความปลอดภัย'
          : 'Register as a security guard',
      guardCta = isThai ? 'สมัครเป็น รปภ.' : 'Register as Guard',
      registering = isThai ? 'กำลังสมัครสมาชิก...' : 'Registering...';
}

// ──────────────────────────────────────────────
// 5c. SetPasswordStrings — set_password_screen
// ──────────────────────────────────────────────
class SetPasswordStrings {
  final String title;
  final String subtitle;
  final String fullNameLabel;
  final String fullNameHint;
  final String emailLabel;
  final String emailHint;
  final String passwordLabel;
  final String passwordHint;
  final String confirmPasswordLabel;
  final String confirmPasswordHint;
  final String passwordRequirement;
  final String passwordMismatch;
  final String createAccount;
  final String registering;
  final String registerSuccess;

  SetPasswordStrings({required bool isThai})
    : title = isThai ? 'ตั้งรหัสผ่าน' : 'Set Password',
      subtitle = isThai
          ? 'กรอกข้อมูลเพื่อสร้างบัญชีของคุณ'
          : 'Fill in your details to create your account',
      fullNameLabel = isThai ? 'ชื่อ-นามสกุล' : 'Full Name',
      fullNameHint = isThai ? 'กรอกชื่อ-นามสกุล' : 'Enter your full name',
      emailLabel = isThai ? 'อีเมล' : 'Email',
      emailHint = isThai ? 'กรอกอีเมล' : 'Enter your email',
      passwordLabel = isThai ? 'รหัสผ่าน' : 'Password',
      passwordHint = isThai ? 'กรอกรหัสผ่าน' : 'Enter password',
      confirmPasswordLabel = isThai ? 'ยืนยันรหัสผ่าน' : 'Confirm Password',
      confirmPasswordHint = isThai ? 'กรอกรหัสผ่านอีกครั้ง' : 'Enter password again',
      passwordRequirement = isThai
          ? 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร'
          : 'Password must be at least 8 characters',
      passwordMismatch = isThai
          ? 'รหัสผ่านไม่ตรงกัน'
          : 'Passwords do not match',
      createAccount = isThai ? 'สร้างบัญชี' : 'Create Account',
      registering = isThai ? 'กำลังสร้างบัญชี...' : 'Creating account...',
      registerSuccess = isThai
          ? 'สร้างบัญชีสำเร็จ!'
          : 'Account created successfully!';
}

// ──────────────────────────────────────────────
// 5d. RegistrationPendingStrings — registration_pending_screen
// ──────────────────────────────────────────────
class RegistrationPendingStrings {
  final String title;
  final String subtitle;
  final String detail;
  final String backToLogin;
  final String appDataTitle;
  final String fieldName;
  final String fieldGender;
  final String fieldExperience;
  final String fieldWorkplace;
  final String fieldBank;
  final String fieldAccountNumber;
  final String fieldAccountName;
  final String years;
  final String notSpecified;
  final String documentsTitle;
  final String docIdCard;
  final String docSecurityLicense;
  final String docTrainingCert;
  final String docCriminalCheck;
  final String docDriverLicense;
  final String docPassbook;
  final String docAttached;
  final String docNotAttached;
  final String bankTitle;
  final String editButton;
  final String editDialogTitle;
  final String editDialogMessage;
  final String editDialogConfirm;
  final String editDialogCancel;
  final String checkStatus;
  final String notYetApproved;
  final String checkStatusError;
  // Customer-specific fields
  final String customerInfoTitle;
  final String fieldCompanyName;
  final String fieldAddress;
  final String fieldEmail;
  final String fieldContactPhone;

  RegistrationPendingStrings({required bool isThai})
    : title = isThai ? 'รอการอนุมัติ' : 'Awaiting Approval',
      subtitle = isThai
          ? 'บัญชีของคุณอยู่ระหว่างการตรวจสอบ'
          : 'Your account is under review',
      detail = isThai
          ? 'ทีมงานกำลังตรวจสอบข้อมูลของคุณ\nคุณจะได้รับการแจ้งเตือนเมื่อบัญชีได้รับการอนุมัติ'
          : 'Our team is reviewing your information.\nYou will be notified once your account is approved.',
      backToLogin = isThai ? 'กลับสู่หน้าหลัก' : 'Back to Home',
      appDataTitle = isThai ? 'ข้อมูลส่วนตัว' : 'Personal Info',
      fieldName = isThai ? 'ชื่อ-นามสกุล' : 'Full Name',
      fieldGender = isThai ? 'เพศ' : 'Gender',
      fieldExperience = isThai ? 'ประสบการณ์' : 'Experience',
      fieldWorkplace = isThai ? 'ที่ทำงานเดิม' : 'Previous Workplace',
      fieldBank = isThai ? 'ธนาคาร' : 'Bank',
      fieldAccountNumber = isThai ? 'เลขบัญชี' : 'Account No.',
      fieldAccountName = isThai ? 'ชื่อบัญชี' : 'Account Name',
      years = isThai ? 'ปี' : 'yr',
      notSpecified = isThai ? 'ไม่ได้ระบุ' : 'Not specified',
      documentsTitle = isThai ? 'เอกสารแนบ' : 'Documents',
      docIdCard = isThai ? 'บัตรประชาชน' : 'ID Card',
      docSecurityLicense = isThai ? 'ใบอนุญาต รปภ.' : 'Security License',
      docTrainingCert = isThai ? 'ใบรับรองการฝึก' : 'Training Cert',
      docCriminalCheck = isThai ? 'ใบตรวจอาชญากรรม' : 'Criminal Check',
      docDriverLicense = isThai ? 'ใบขับขี่' : 'Driver License',
      docPassbook = isThai ? 'สมุดบัญชี' : 'Passbook',
      docAttached = isThai ? 'แนบแล้ว' : 'Attached',
      docNotAttached = isThai ? 'ยังไม่แนบ' : 'Not attached',
      bankTitle = isThai ? 'ข้อมูลธนาคาร' : 'Bank Account',
      editButton = isThai ? 'แก้ข้อมูล' : 'Edit Profile',
      editDialogTitle = isThai ? 'แก้ข้อมูลการสมัคร' : 'Edit Registration',
      editDialogMessage = isThai
          ? 'คุณสามารถแก้ไขข้อมูลและส่งใหม่ได้\nเอกสารที่แนบแล้วจะยังคงอยู่หากไม่แนบใหม่'
          : 'You can edit and resubmit.\nPreviously attached documents will be preserved unless re-uploaded.',
      editDialogConfirm = isThai ? 'แก้ข้อมูล' : 'Edit',
      editDialogCancel = isThai ? 'ยกเลิก' : 'Cancel',
      checkStatus = isThai ? 'ตรวจสอบสถานะ' : 'Check Status',
      notYetApproved = isThai ? 'ยังไม่ได้รับการอนุมัติ กรุณารอสักครู่' : 'Not yet approved. Please wait.',
      checkStatusError = isThai ? 'ไม่สามารถตรวจสอบได้ กรุณาลงทะเบียนใหม่' : 'Unable to check. Please re-register.',
      customerInfoTitle = isThai ? 'ข้อมูลลูกค้า' : 'Customer Info',
      fieldCompanyName = isThai ? 'ชื่อบริษัท' : 'Company',
      fieldAddress = isThai ? 'ที่อยู่' : 'Address',
      fieldEmail = isThai ? 'อีเมล' : 'Email',
      fieldContactPhone = isThai ? 'เบอร์ติดต่อ' : 'Contact Phone';
}

// ──────────────────────────────────────────────
// 6. CustomerLoginStrings — customer_login_screen
// ──────────────────────────────────────────────
class CustomerLoginStrings {
  final String appBarTitle;
  final String customer;
  final String customerEn;
  final String underDevelopment;
  final String underDevelopmentEn;

  CustomerLoginStrings({required bool isThai})
    : appBarTitle = isThai ? 'จ้างรปภ.' : 'Hire a Guard',
      customer = isThai ? 'ลูกค้า' : 'Customer',
      customerEn = 'Customer',
      underDevelopment = isThai ? 'อยู่ระหว่างพัฒนา' : 'Under Development',
      underDevelopmentEn = isThai ? 'Under Development' : 'Coming Soon';
}

// ──────────────────────────────────────────────
// 7. DashboardStrings — dashboard_screen
// ──────────────────────────────────────────────
class DashboardStrings {
  final String headerTitle;
  final String headerSubtitle;
  final String totalRevenue;
  final String pending;
  final String totalFees;
  final String netProfit;
  final String statusCompleted;
  final String kpiSubItems;
  final String kpiSubPending;
  final String kpiSubFees;
  final String kpiSubVerified;
  final String chartTitle;
  final String chartRevenue;
  final String chartWithdrawals;
  final String bankSummaryTitle;
  final String bankKBank;
  final String bankSCB;
  final String withdrawalListTitle;
  final String viewAll;
  final String statusPending;
  final String statusProcessing;
  final String sampleKpiSubFees;
  final String sampleKpiSubItems;
  final String sampleKpiSubPending;
  final String sampleKpiSubVerified;
  final String sampleDate1;

  DashboardStrings({required bool isThai})
    : headerTitle = isThai ? 'จัดการการเงิน' : 'Financial Management',
      headerSubtitle = isThai
          ? 'ระบบบริหารจัดการรายได้'
          : 'Revenue Management System',
      totalRevenue = isThai ? 'รายได้ทั้งหมด' : 'Total Revenue',
      pending = isThai ? 'รอรวมดำเนินการ' : 'Pending',
      totalFees = isThai ? 'ค่าธรรมเนียมรวม' : 'Total Fees',
      netProfit = isThai ? 'กำไรสุทธิ' : 'Net Profit',
      kpiSubItems = isThai ? 'รายรายการ' : 'items',
      kpiSubPending = isThai ? 'จากยอดรวม' : 'of total',
      kpiSubFees = '+12.5%',
      kpiSubVerified = isThai ? 'ตรวจสอบแล้ว' : 'Verified',
      sampleKpiSubFees = '+12.5%',
      sampleKpiSubItems = isThai ? '12 รายการ' : '12 items',
      sampleKpiSubPending = isThai ? '3% จากยอดรวม' : '3% of total',
      sampleKpiSubVerified = isThai ? 'ตรวจสอบแล้ว' : 'Verified',
      sampleDate1 = isThai ? '1 ม.ค.' : '1 Jan',
      chartTitle = isThai
          ? 'รายได้เทียมยอดออก (30 วัน)'
          : 'Revenue vs Withdrawals (30 days)',
      chartRevenue = isThai ? 'รายได้' : 'Revenue',
      chartWithdrawals = isThai ? 'ยอดถอน' : 'Withdrawals',
      bankSummaryTitle = isThai
          ? 'สรุปยอดเงินแยกตามธนาคาร'
          : 'Bank Summary by Account',
      bankKBank = isThai ? 'กสิกรไทย' : 'KBank',
      bankSCB = isThai ? 'ไทยพาณิชย์' : 'SCB',
      withdrawalListTitle = isThai
          ? 'รายการรอรับการถอนเงิน'
          : 'Pending Withdrawal Requests',
      viewAll = isThai ? 'ดูทั้งหมด' : 'View All',
      statusPending = isThai ? 'รออนุมัติ' : 'Pending',
      statusProcessing = isThai ? 'กำลังดำเนินการ' : 'Processing',
      statusCompleted = isThai ? 'เสร็จสิ้น' : 'Completed';
}

// ──────────────────────────────────────────────
// 9. WithdrawalStrings — withdrawal_approval_screen
// ──────────────────────────────────────────────
class WithdrawalStrings {
  final String appBarTitle;
  final String employeeId;
  final String memberSince;
  final String totalEarnings;
  final String withdrawn;
  final String currentBalance;
  final String detailsTitle;
  final String amount;
  final String bank;
  final String accountName;
  final String accountNumber;
  final String checklistTitle;
  final String identityVerified;
  final String noDisputes;
  final String rejectionHint;
  final String employeePhoto;
  final String idCardCopy;
  final String reject;
  final String approveTransfer;
  final String sampleName;
  final String sampleEmployeeId;
  final String sampleMemberSince;
  final String sampleBankName;

  WithdrawalStrings({required bool isThai})
    : appBarTitle = isThai ? 'อนุมัติรายการถอนเงิน' : 'Approve Withdrawal',
      employeeId = isThai ? 'รหัสพนักงาน:' : 'Employee ID:',
      memberSince = isThai ? 'เป็นสมาชิกตั้งแต่' : 'Member since',
      totalEarnings = isThai ? 'รายได้สะสม' : 'Total Earnings',
      withdrawn = isThai ? 'ถอนไปแล้ว' : 'Withdrawn',
      currentBalance = isThai ? 'ยอดเป็นปัจจุบัน' : 'Current Balance',
      detailsTitle = isThai ? 'รายละเอียดการถอนเงิน' : 'Withdrawal Details',
      amount = isThai ? 'จำนวนเงินที่ถอน' : 'Amount',
      bank = isThai ? 'ธนาคาร' : 'Bank',
      accountName = isThai ? 'ชื่อบัญชี' : 'Account Name',
      accountNumber = isThai ? 'เลขบัญชี' : 'Account Number',
      checklistTitle = isThai
          ? 'รายการตรวจสอบความถูกต้อง'
          : 'Verification Checklist',
      identityVerified = isThai
          ? 'ยืนยันตัวตนเรียบร้อยแล้ว (Identity Verified)'
          : 'Identity Verified',
      noDisputes = isThai
          ? 'ไม่มีข้อพิพาทที่ยังดำเนินการอยู่ (No Disputes)'
          : 'No Active Disputes',
      rejectionHint = isThai
          ? 'เหตุผลการปฏิเสธ (ถ้ามี)...'
          : 'Rejection reason (if any)...',
      employeePhoto = isThai ? 'ภาพถ่ายหน้าตรงของพนักงาน' : 'Employee Photo',
      idCardCopy = isThai ? 'สำเนาบัตรประชาชน' : 'ID Card Copy',
      reject = isThai ? 'ปฏิเสธรายการ' : 'Reject',
      approveTransfer = isThai ? 'อนุมัติและโอนเงิน' : 'Approve & Transfer',
      sampleName = isThai ? 'นายสมชาย รักชาติ' : 'Mr. Somchai Rakchart',
      sampleEmployeeId = 'SG-88294',
      sampleMemberSince = isThai ? '12 ม.ค. 2565' : '12 Jan 2022',
      sampleBankName = isThai ? 'กสิกรไทย (KBank)' : 'KBank';
}

// ──────────────────────────────────────────────
// 10. GuardDashboardStrings — guard_dashboard_screen
// ──────────────────────────────────────────────
class GuardDashboardStrings {
  final String navHome;
  final String navJobs;
  final String navChat;
  final String navIncome;
  final String navMore;

  GuardDashboardStrings({required bool isThai})
    : navHome = isThai ? 'หน้าหลัก' : 'Home',
      navJobs = isThai ? 'งาน' : 'Jobs',
      navChat = isThai ? 'แชท' : 'Chat',
      navIncome = isThai ? 'รายได้' : 'Income',
      navMore = isThai ? 'อื่นๆ' : 'More';
}

// ──────────────────────────────────────────────
// 11. GuardRegistrationStrings — guard_registration_screen
// ──────────────────────────────────────────────
class GuardRegistrationStrings {
  final String appBarTitle;
  final String stepPersonal;
  final String stepDocuments;
  final String stepBank;
  final String fillInfo;
  final String personalDetails;
  final String fullName;
  final String fullNameHint;
  final String gender;
  final String selectGender;
  final List<String> genderOptions;
  final String dateOfBirth;
  final String workExperience;
  final String yearsOfExp;
  final String previousWorkplace;
  final String companyHint;
  final String next;
  final String back;
  final String submitApplication;

  // Step 2 - Documents
  final String uploadDocuments;
  final String uploadDocumentsDesc;
  final String idCard;
  final String securityLicense;
  final String trainingCert;
  final String criminalCheck;
  final String driverLicense;
  final String notAttached;
  final String uploadFile;
  final String expiryDate;
  final String selectExpiryDate;

  // Step 3 - Bank Account
  final String bankDetails;
  final String bankName;
  final String selectBank;
  final List<String> bankOptions;
  final String accountNumber;
  final String accountNumberHint;
  final String accountName;
  final String accountNameHint;
  final String accountNameMustMatch;
  final String passbookPhoto;

  // Step 4 - Review / Submitted
  final String applicationReview;
  final String applicationReviewDesc;
  final String submittedOn;
  final String submittedData;
  final String nameLabel;
  final String experienceLabel;
  final String documentsLabel;
  final String bankLabel;
  final String yearsUnit;
  final String documentsCount;

  GuardRegistrationStrings({required bool isThai})
    : appBarTitle = isThai
          ? 'สมัครเพื่อเริ่มรับงาน'
          : 'Register to Start Working',
      stepPersonal = isThai ? 'ข้อมูลส่วนตัว' : 'Personal',
      stepDocuments = isThai ? 'เอกสาร' : 'Documents',
      stepBank = isThai ? 'บัญชีธนาคาร' : 'Bank Account',
      fillInfo = isThai ? 'กรอกข้อมูลให้ครบถ้วน' : 'Fill in all information',
      personalDetails = isThai ? 'ข้อมูลส่วนบุคคล' : 'Personal Details',
      fullName = isThai ? 'ชื่อ-นามสกุล *' : 'Full Name *',
      fullNameHint = isThai ? 'กรอกชื่อ-นามสกุล' : 'Enter full name',
      gender = isThai ? 'เพศ *' : 'Gender *',
      selectGender = isThai ? 'เลือกเพศ' : 'Select gender',
      genderOptions = isThai
          ? ['ชาย', 'หญิง', 'อื่นๆ']
          : ['Male', 'Female', 'Other'],
      dateOfBirth = isThai ? 'วันเกิด *' : 'Date of Birth *',
      workExperience = isThai ? 'ประวัติการทำงาน' : 'Work Experience',
      yearsOfExp = isThai ? 'อายุงาน (ปี) *' : 'Years of Experience *',
      previousWorkplace = isThai
          ? 'สถานที่ทำงานก่อนหน้า *'
          : 'Previous Workplace *',
      companyHint = isThai ? 'ชื่อบริษัท/สถานที่' : 'Company / Location',
      next = isThai ? 'ถัดไป' : 'Next',
      back = isThai ? 'ย้อนกลับ' : 'Back',
      submitApplication = isThai ? 'ส่งใบสมัคร' : 'Submit Application',

      // Step 2 - Documents
      uploadDocuments = isThai ? 'อัพโหลดเอกสาร' : 'Upload Documents',
      uploadDocumentsDesc = isThai
          ? 'ข้อมูลของคุณจะถูกใช้เพื่อการตรวจสอบการทำงานเท่านั้น และจัดเก็บอย่างปลอดภัย'
          : 'Your information will be used for verification purposes only and stored securely',
      idCard = isThai ? 'บัตรประจำตัวประชาชน *' : 'National ID Card *',
      securityLicense = isThai
          ? 'ใบอนุญาตรักษาความปลอดภัย *'
          : 'Security License *',
      trainingCert = isThai ? 'ใบฝึกอบรม *' : 'Training Certificate *',
      criminalCheck = isThai
          ? 'ใบผ่านการตรวจสอบประวัติอาชญากรรม *'
          : 'Criminal Background Check *',
      driverLicense = isThai ? 'ใบขับขี่ *' : "Driver's License *",
      notAttached = isThai ? 'ยังไม่แนบ' : 'Not attached',
      uploadFile = isThai ? 'อัพโหลดไฟล์' : 'Upload File',
      expiryDate = isThai ? 'หมดอายุ' : 'Expires',
      selectExpiryDate = isThai ? 'เลือกวันหมดอายุเอกสาร' : 'Select document expiry date',

      // Step 3 - Bank Account
      bankDetails = isThai ? 'ข้อมูลบัญชีธนาคาร' : 'Bank Account Details',
      bankName = isThai ? 'ธนาคาร *' : 'Bank *',
      selectBank = isThai ? 'เลือกธนาคาร' : 'Select bank',
      bankOptions = isThai
          ? [
              'ธนาคารกรุงเทพ',
              'ธนาคารกสิกรไทย',
              'ธนาคารกรุงไทย',
              'ธนาคารไทยพาณิชย์',
              'ธนาคารกรุงศรีอยุธยา',
              'ธนาคารทหารไทยธนชาต',
            ]
          : [
              'Bangkok Bank',
              'Kasikorn Bank',
              'Krungthai Bank',
              'SCB',
              'Bank of Ayudhya',
              'TMBThanachart',
            ],
      accountNumber = isThai ? 'เลขบัญชี *' : 'Account Number *',
      accountNumberHint = isThai ? 'กรอกเลขบัญชี' : 'Enter account number',
      accountName = isThai ? 'ชื่อบัญชี *' : 'Account Name *',
      accountNameHint = isThai ? 'กรอกชื่อบัญชี' : 'Enter account name',
      accountNameMustMatch = isThai
          ? 'ชื่อบัญชีต้องตรงกับชื่อ-นามสกุลที่กรอกในขั้นตอนแรก'
          : 'Account name must match the full name entered in step 1',
      passbookPhoto = isThai ? 'รูปสมุดบัญชีธนาคาร *' : 'Bank Passbook Photo *',

      // Step 4 - Review / Submitted
      applicationReview = isThai
          ? 'ใบสมัครของคุณอยู่ระหว่างการตรวจสอบโดยแอดมิน'
          : 'Your application is being reviewed by admin',
      applicationReviewDesc = isThai
          ? 'เราจะแจ้งผลให้คุณทราบเมื่อการตรวจสอบเสร็จสิ้น'
          : 'We will notify you once the review is complete',
      submittedOn = isThai ? 'ส่งเมื่อ:' : 'Submitted on:',
      submittedData = isThai ? 'ข้อมูลที่ส่ง' : 'Submitted Data',
      nameLabel = isThai ? 'ชื่อ-นามสกุล' : 'Full Name',
      experienceLabel = isThai ? 'ประสบการณ์' : 'Experience',
      documentsLabel = isThai ? 'เอกสาร' : 'Documents',
      bankLabel = isThai ? 'ธนาคาร' : 'Bank',
      yearsUnit = isThai ? 'ปี' : 'years',
      documentsCount = isThai ? 'รายการ' : 'items';
}

// ──────────────────────────────────────────────
// 11b. CustomerRegistrationStrings
// ──────────────────────────────────────────────
class CustomerRegistrationStrings {
  final String appBarTitle;
  final String fillInfo;
  final String fullName;
  final String fullNameHint;
  final String contactPhone;
  final String contactPhoneHint;
  final String contactPhoneInvalid;
  final String email;
  final String emailHint;
  final String emailInvalid;
  final String companyName;
  final String companyHint;
  final String address;
  final String addressHint;
  final String addressRequired;
  final String submitApplication;
  final String submitting;
  final String successMessage;

  CustomerRegistrationStrings({required bool isThai})
    : appBarTitle = isThai ? 'สมัครเพื่อเริ่มใช้บริการ' : 'Register as Customer',
      fillInfo = isThai ? 'กรุณากรอกข้อมูลของคุณ' : 'Please fill in your information',
      fullName = isThai ? 'ชื่อ-นามสกุล *' : 'Full Name *',
      fullNameHint = isThai ? 'กรอกชื่อ-นามสกุล' : 'Enter your full name',
      contactPhone = isThai ? 'เบอร์ติดต่อ *' : 'Contact Phone *',
      contactPhoneHint = isThai
          ? 'เบอร์ติดต่อ (ไม่ใช่เบอร์ login)'
          : 'Contact number (not login number)',
      contactPhoneInvalid = isThai
          ? 'เบอร์โทรต้องเป็นตัวเลข 10 หลักขึ้นต้นด้วย 0'
          : 'Phone must be 10 digits starting with 0',
      email = isThai ? 'อีเมล (ไม่บังคับ)' : 'Email (optional)',
      emailHint = 'example@mail.com',
      emailInvalid = isThai ? 'รูปแบบอีเมลไม่ถูกต้อง' : 'Invalid email format',
      companyName = isThai ? 'ชื่อบริษัท *' : 'Company Name *',
      companyHint = isThai ? 'กรอกชื่อบริษัท (ถ้ามี)' : 'Enter company name (if any)',
      address = isThai ? 'ที่อยู่ (ไม่บังคับ)' : 'Address (optional)',
      addressHint = isThai
          ? 'กรอกที่อยู่ เช่น บ้านเลขที่ ถนน แขวง เขต จังหวัด'
          : 'Enter your full address',
      addressRequired = isThai
          ? 'กรุณากรอกที่อยู่อย่างน้อย 10 ตัวอักษร'
          : 'Address must be at least 10 characters',
      submitApplication = isThai ? 'ส่งใบสมัคร' : 'Submit Application',
      submitting = isThai ? 'กำลังส่ง...' : 'Submitting...',
      successMessage = isThai ? 'ส่งใบสมัครสำเร็จ!' : 'Application submitted!';
}

// ──────────────────────────────────────────────
// 12. GuardHomeStrings — guard_home_tab
// ──────────────────────────────────────────────
class GuardHomeStrings {
  final String greeting;
  final String ready;
  final String notReady;
  final String today;
  final String thisWeek;
  final String completedJobsLabel;
  final String noChangeLabel;
  final String incomingJobs;
  final String unavailable;
  final String noNewJobsMsg;
  final String setAvailableMsg;
  final String viewNewJobs;
  final String sampleGuardName;

  // Not registered state
  final String notRegistered;
  final String registerToStart;
  final String registerNow;

  // GPS tracking
  final String connecting;
  final String locationPermissionDenied;
  final String gpsAccuracy;

  // Busy state
  final String busy;

  GuardHomeStrings({required bool isThai})
    : greeting = isThai ? 'สวัสดีตอนเย็น' : 'Good Evening',
      ready = isThai ? 'พร้อมให้บริการ' : 'Available',
      notReady = isThai ? 'ไม่พร้อมให้บริการ' : 'Unavailable',
      today = isThai ? 'วันนี้' : 'Today',
      thisWeek = isThai ? 'สัปดาห์นี้' : 'This Week',
      completedJobsLabel = isThai ? 'งานสำเร็จ' : 'Completed',
      noChangeLabel = isThai ? 'ไม่เปลี่ยนแปลง' : 'No change',
      incomingJobs = isThai ? 'งานที่เข้ามา' : 'Incoming Jobs',
      unavailable = isThai ? 'ไม่พร้อมให้บริการ' : 'Unavailable',
      noNewJobsMsg = isThai
          ? 'ยังไม่มีงานใหม่'
          : 'No new jobs available.',
      setAvailableMsg = isThai
          ? 'เปิดสถานะ "พร้อมให้บริการ" เพื่อรับงานใหม่'
          : 'Set status to "Available" to receive new jobs',
      viewNewJobs = isThai ? 'ดูงานใหม่' : 'View New Jobs',
      sampleGuardName = isThai ? 'คุณสมชาย รักษาดี' : 'Mr. Somchai Raksadee',
      notRegistered = isThai ? 'ยังไม่ได้สมัคร' : 'Not Registered',
      registerToStart = isThai
          ? 'กรุณาสมัครเพื่อเริ่มรับงาน'
          : 'Please register to start receiving jobs',
      registerNow = isThai ? 'สมัครเลย' : 'Register Now',
      connecting = isThai ? 'กำลังเชื่อมต่อ...' : 'Connecting...',
      locationPermissionDenied = isThai
          ? 'กรุณาอนุญาตการเข้าถึงตำแหน่ง'
          : 'Please allow location access',
      gpsAccuracy = isThai ? 'ความแม่นยำ GPS' : 'GPS Accuracy',
      busy = isThai ? 'ไม่ว่าง — กำลังปฏิบัติงาน' : 'Busy — On Duty',
      _isThai = isThai;

  final bool _isThai;

  String completedJobsCount(int count) =>
      _isThai ? '$count งานสำเร็จ' : '$count completed';

  String newJobsCount(int count) =>
      _isThai ? 'มี $count งานใหม่ โปรดตรวจสอบ' : '$count new jobs available. Please check.';

  String weekChangePercent(double percent) {
    if (percent == 0) return noChangeLabel;
    final sign = percent > 0 ? '+' : '';
    return _isThai
        ? '${percent > 0 ? "เพิ่มขึ้น" : "ลดลง"} $sign${percent.toStringAsFixed(0)}%'
        : '${percent > 0 ? "Up" : "Down"} $sign${percent.toStringAsFixed(0)}%';
  }
}

// ──────────────────────────────────────────────
// 13. GuardJobsStrings — guard_jobs_tab
// ──────────────────────────────────────────────
class GuardJobsStrings {
  final String appBarTitle;
  final String currentTabLabel;
  final String completedTabLabel;
  final String statusWorking;
  final String callClient;
  final String chat;
  final String checkIn;
  final String checkInRange;
  final String additionalDetails;
  final String securityEquipment;
  final String detailPet;
  final String detailPetContent;
  final String detailPlants;
  final String detailPlantsContent;
  final String detailUtilities;
  final String detailUtilitiesContent;
  final String jobDesc;
  final String sampleClient;
  final String sampleLocation;
  final String sampleEquipment;
  final String sampleBonusLabel;
  final String sampleDate2;
  final String sampleDate3;

  GuardJobsStrings({required bool isThai})
    : appBarTitle = isThai ? 'รายการงาน' : 'Job List',
      currentTabLabel = isThai ? 'งานปัจจุบัน' : 'Current',
      completedTabLabel = isThai ? 'งานที่เสร็จแล้ว' : 'Completed',
      statusWorking = isThai ? 'กำลังทำงาน' : 'Working',
      callClient = isThai ? 'โทรหาลูกค้า' : 'Call Client',
      chat = isThai ? 'แชท' : 'Chat',
      checkIn = isThai ? 'เช็คอิน' : 'Check In',
      checkInRange = isThai
          ? 'ต้องอยู่ใกล้สถานที่ทำงาน (100 เมตร)'
          : 'Must be within 100m of workplace',
      additionalDetails = isThai
          ? '📋 รายละเอียดเพิ่มเติมจากลูกค้า'
          : '📋 Additional Details from Client',
      securityEquipment = isThai
          ? '🛡️ อุปกรณ์รักษาความปลอดภัย:'
          : '🛡️ Security Equipment:',
      detailPet = isThai ? 'ดูแลสัตว์เลี้ยง:' : 'Pet Care:',
      detailPetContent = isThai
          ? 'มีหมาตัวชื่อ "บัดดี้" ให้อาหารตอน 16:00 น. อย่าให้ขนมหวาน'
          : 'Dog named "Buddy" - feed at 4 PM, no sweets',
      detailPlants = isThai ? 'ดูแลต้นไม้:' : 'Plant Care:',
      detailPlantsContent = isThai
          ? 'รดน้ำต้นไม้หน้าบ้าน 3 ต้น ช่วงเย็นเท่านั้น'
          : 'Water 3 front plants in the evening only',
      detailUtilities = isThai ? 'ปิด/เปิดน้ำ-ไฟฟ้า:' : 'Utilities:',
      detailUtilitiesContent = isThai
          ? 'ปิดไฟหน้าบ้านตอน 22:00 น. เปิดระบบปั่นน้ำตอน 06:00 น.'
          : 'Turn off front lights at 10 PM. Turn on water pump at 6 AM',
      jobDesc = isThai
          ? 'เฝ้าประตูหน้าอาคารในช่วงงานเลี้ยงบริษัท'
          : 'Guard front gate during company event',
      sampleClient = isThai ? 'คุณสมชาย ใจดี' : 'Mr. Somchai Jaidee',
      sampleLocation = isThai
          ? 'อาคารสยามทาวเวอร์ ชั้น 15'
          : 'Siam Tower, 15th Fl',
      sampleEquipment = isThai
          ? 'ไฟฉาย, ชุดเครื่องแบบ รปภ.+เสื้อโปโล'
          : 'Flashlight, Guard Uniform + Polo Shirt',
      sampleBonusLabel = isThai ? 'โบนัส:' : 'Bonus:',
      sampleDate2 = isThai ? '15 ธ.ค.' : '15 Dec',
      sampleDate3 = isThai ? '14 ธ.ค.' : '14 Dec';
}

// ──────────────────────────────────────────────
// 14. GuardIncomeStrings — guard_income_tab
// ──────────────────────────────────────────────
class GuardIncomeStrings {
  final String appBarTitle;
  final String tabIncomeGoals;
  final String tabBonusPoints;
  final String tabWallet;
  final String trackIncome;
  final String monthlyGoal;
  final String onTrack;
  final String completedThisMonth;
  final String daysLeft;
  final String thisWeek;
  final String avgPerJob;
  final String jobCount;
  final String dailyIncome;
  final String pointsProgress;
  final String pointsAccumulated;
  final String nearBonus;
  final String performanceStats;
  final String performance;
  final String completedJobs;
  final String acceptRate;
  final String workHours;
  final String walletTitle;
  final String withdrawable;
  final String pendingApproval;
  final String withdrawAfter;
  final String withdrawTitle;
  final String withdrawMin;
  final String withdrawBtn;
  final String withdrawFreeInfo;
  final String accountMustMatch;
  final String withdrawHistory;
  final String success;
  final String failed;
  final String sampleDate1;
  final String sampleDate2;
  final String sampleDate3;
  final String sampleJobCount;
  final String sampleBankInfo;

  GuardIncomeStrings({required bool isThai})
    : appBarTitle = isThai ? 'รายได้' : 'Income',
      tabIncomeGoals = isThai ? 'รายได้และเป้าหมาย' : 'Income & Goals',
      tabBonusPoints = isThai ? 'โบนัสและแต้ม' : 'Bonus & Points',
      tabWallet = isThai ? 'กระเป๋าเงิน' : 'Wallet',
      trackIncome = isThai ? 'ติดตามรายได้และเป้าหมาย' : 'Track Income & Goals',
      monthlyGoal = isThai ? 'เป้าหมายประจำเดือน' : 'Monthly Goal',
      onTrack = isThai ? '📈 ตามเป้า' : '📈 On Track',
      completedThisMonth = isThai
          ? 'งานที่สำเร็จในเดือนนี้: 18/25 งาน'
          : 'Jobs completed this month: 18/25',
      daysLeft = isThai ? 'เหลืออีก 14 วัน' : '14 days left',
      thisWeek = isThai ? 'สัปดาห์นี้' : 'This Week',
      avgPerJob = isThai ? 'เฉลี่ย/งาน' : 'Avg/Job',
      jobCount = isThai ? 'จำนวนงาน' : 'Jobs',
      dailyIncome = isThai ? 'รายได้รายวัน' : 'Daily Income',
      pointsProgress = isThai
          ? '🔰 ความคืบหน้าในการสะสมแต้ม'
          : '🔰 Points Progress',
      pointsAccumulated = isThai ? 'แต้มที่สะสมได้' : 'Points Accumulated',
      nearBonus = isThai
          ? 'ใกล้ถึงโบนัส ฿300! อีก 80 แต้ม'
          : 'Near ฿300 bonus! 80 points to go',
      performanceStats = isThai ? 'สถิติประสิทธิภาพ' : 'Performance Stats',
      performance = isThai ? 'ประสิทธิภาพ' : 'Performance',
      completedJobs = isThai ? 'งานที่สำเร็จ' : 'Completed',
      acceptRate = isThai ? 'อัตราการรับงาน' : 'Accept Rate',
      workHours = isThai ? 'ชั่วโมงทำงาน' : 'Work Hours',
      walletTitle = isThai ? 'กระเป๋าเงิน' : 'Wallet',
      withdrawable = isThai ? 'ยอดถอนได้' : 'Available Balance',
      pendingApproval = isThai
          ? 'รอการอนุมัติ: ฿1,450'
          : 'Pending approval: ฿1,450',
      withdrawAfter = isThai
          ? 'จะสามารถถอนได้หลังจาก 24 ชั่วโมง'
          : 'Withdrawable after 24 hours',
      withdrawTitle = isThai ? 'ถอนเงิน' : 'Withdraw',
      withdrawMin = isThai ? 'จำนวนเงิน (ขั้นต่ำ ฿100)' : 'Amount (min ฿100)',
      withdrawBtn = isThai
          ? 'ถอนเงิน (ต้องใส่ PIN)'
          : 'Withdraw (PIN required)',
      withdrawFreeInfo = isThai
          ? '💡 การถอนฟรี: 1/1 ครั้งต่อวัน\nการถอนเพิ่มเติม: ค่าธรรมเนียม ฿10/ครั้ง'
          : '💡 Free withdrawal: 1/1 per day\nAdditional: ฿10 fee per transaction',
      accountMustMatch = isThai
          ? 'บัญชีต้องตรงกับชื่อที่ลงทะเบียน'
          : 'Account must match registered name',
      withdrawHistory = isThai ? 'ประวัติการถอน' : 'Withdrawal History',
      success = isThai ? 'สำเร็จ' : 'Success',
      failed = isThai ? 'ล้มเหลว' : 'Failed',
      sampleDate1 = isThai ? '16 ธ.ค.' : '16 Dec',
      sampleDate2 = isThai ? '15 ธ.ค.' : '15 Dec',
      sampleDate3 = isThai ? '14 ธ.ค.' : '14 Dec',
      sampleJobCount = isThai ? '12 งาน' : '12 Jobs',
      sampleBankInfo = isThai ? 'ธนาคารกสิกรไทย ***1234' : 'KBank ***1234';
}

// ──────────────────────────────────────────────
// 15. GuardProfileStrings — guard_profile_tab
// ──────────────────────────────────────────────
class GuardProfileStrings {
  final String profileHeader;
  final String verified;
  final String notRegistered;
  final String rating;
  final String totalJobs;
  final String months;
  final String contactInfo;
  final String joinedDate;
  final String menuTitle;
  final String menuAppStatus;
  final String menuSettings;
  final String menuReviews;
  final String menuHistory;
  final String menuSupport;
  final String menuLogout;
  final String sampleGuardCode;
  final String sampleLocation;
  final String sampleGuardName;

  GuardProfileStrings({required bool isThai})
    : profileHeader = isThai ? 'โปรไฟล์เจ้าหน้าที่' : 'Security Guard Profile',
      verified = isThai ? '✓ ยืนยันแล้ว' : '✓ Verified',
      notRegistered = isThai ? 'ยังไม่ได้สมัคร' : 'Not Registered',
      rating = isThai ? 'คะแนน' : 'Rating',
      totalJobs = isThai ? 'งานทั้งหมด' : 'Total Jobs',
      months = isThai ? 'เดือน' : 'Months',
      contactInfo = isThai ? 'ข้อมูลติดต่อ' : 'Contact Info',
      joinedDate = isThai ? 'เข้าร่วมเมื่อ มีนาคม 2023' : 'Joined March 2023',
      menuTitle = isThai ? 'เมนู' : 'Menu',
      menuAppStatus = isThai ? 'สถานะใบสมัคร' : 'Application Status',
      menuSettings = isThai ? 'ตั้งค่าโปรไฟล์' : 'Profile Settings',
      menuReviews = isThai ? 'คะแนนและรีวิว' : 'Ratings & Reviews',
      menuHistory = isThai ? 'ประวัติการทำงาน' : 'Work History',
      menuSupport = isThai ? 'ติดต่อฝ่ายสนับสนุน' : 'Contact Support',
      menuLogout = isThai ? 'ออกจากระบบ' : 'Logout',
      sampleGuardCode = isThai ? 'รหัส: RG001234' : 'ID: RG001234',
      sampleLocation = isThai ? 'กรุงเทพมหานคร' : 'Bangkok',
      sampleGuardName = isThai ? 'สมชาย รักษาดี' : 'Somchai Raksadee';
}

// ──────────────────────────────────────────────
// 16. AppStatusStrings — application_status_screen
// ──────────────────────────────────────────────
class AppStatusStrings {
  final String appBarTitle;
  final String statusPending;
  final String statusApproved;
  final String statusRejected;
  final String pendingDesc;
  final String approvedDesc;
  final String rejectedDesc;
  final String submittedOn;
  final String personalInfo;
  final String fullName;
  final String gender;
  final String dateOfBirth;
  final String experience;
  final String previousWorkplace;
  final String documents;
  final String bankAccount;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String yearsUnit;
  final String uploaded;
  final String notUploaded;
  final String idCard;
  final String securityLicense;
  final String trainingCert;
  final String criminalCheck;
  final String driverLicense;
  final String passbookPhoto;
  final String editApplication;

  AppStatusStrings({required bool isThai})
    : appBarTitle = isThai ? 'สถานะใบสมัคร' : 'Application Status',
      statusPending = isThai ? 'รอการตรวจสอบ' : 'Pending Review',
      statusApproved = isThai ? 'อนุมัติแล้ว' : 'Approved',
      statusRejected = isThai ? 'ถูกปฏิเสธ' : 'Rejected',
      pendingDesc = isThai
          ? 'ใบสมัครของคุณอยู่ระหว่างการตรวจสอบโดยแอดมิน'
          : 'Your application is being reviewed by admin',
      approvedDesc = isThai
          ? 'ใบสมัครของคุณได้รับการอนุมัติแล้ว'
          : 'Your application has been approved',
      rejectedDesc = isThai
          ? 'ใบสมัครของคุณถูกปฏิเสธ กรุณาติดต่อฝ่ายสนับสนุน'
          : 'Your application was rejected. Please contact support',
      submittedOn = isThai ? 'ส่งเมื่อ:' : 'Submitted on:',
      personalInfo = isThai ? 'ข้อมูลส่วนตัว' : 'Personal Info',
      fullName = isThai ? 'ชื่อ-นามสกุล' : 'Full Name',
      gender = isThai ? 'เพศ' : 'Gender',
      dateOfBirth = isThai ? 'วันเกิด' : 'Date of Birth',
      experience = isThai ? 'ประสบการณ์' : 'Experience',
      previousWorkplace = isThai
          ? 'สถานที่ทำงานก่อนหน้า'
          : 'Previous Workplace',
      documents = isThai ? 'เอกสาร' : 'Documents',
      bankAccount = isThai ? 'บัญชีธนาคาร' : 'Bank Account',
      bankName = isThai ? 'ธนาคาร' : 'Bank',
      accountNumber = isThai ? 'เลขบัญชี' : 'Account Number',
      accountName = isThai ? 'ชื่อบัญชี' : 'Account Name',
      yearsUnit = isThai ? 'ปี' : 'years',
      uploaded = isThai ? 'อัพโหลดแล้ว' : 'Uploaded',
      notUploaded = isThai ? 'ยังไม่แนบ' : 'Not attached',
      idCard = isThai ? 'บัตรประจำตัวประชาชน' : 'National ID Card',
      securityLicense = isThai
          ? 'ใบอนุญาตรักษาความปลอดภัย'
          : 'Security License',
      trainingCert = isThai ? 'ใบฝึกอบรม' : 'Training Certificate',
      criminalCheck = isThai
          ? 'ใบผ่านการตรวจสอบประวัติอาชญากรรม'
          : 'Criminal Background Check',
      driverLicense = isThai ? 'ใบขับขี่' : "Driver's License",
      passbookPhoto = isThai ? 'รูปสมุดบัญชีธนาคาร' : 'Bank Passbook Photo',
      editApplication = isThai ? 'แก้ไขใบสมัคร' : 'Edit Application';
}

// ──────────────────────────────────────────────
// 17. ProfileSettingsStrings — profile_settings_screen
// ──────────────────────────────────────────────
class ProfileSettingsStrings {
  final String appBarTitle;
  final String profilePhoto;
  final String changePhoto;
  final String personalInfo;
  final String fullName;
  final String phone;
  final String email;
  final String emailHint;
  final String address;
  final String addressHint;
  // Guard-specific fields
  final String guardInfo;
  final String gender;
  final String dateOfBirth;
  final String yearsOfExperience;
  final String previousWorkplace;
  final String emergencyContact;
  final String contactName;
  final String contactNameHint;
  final String contactPhone;
  final String contactPhoneHint;
  final String relationship;
  final String relationshipHint;
  final String notifications;
  final String pushNotif;
  final String pushNotifDesc;
  final String smsNotif;
  final String smsNotifDesc;
  final String jobAlerts;
  final String jobAlertsDesc;
  final String saveChanges;

  ProfileSettingsStrings({required bool isThai})
    : appBarTitle = isThai ? 'ตั้งค่าโปรไฟล์' : 'Profile Settings',
      profilePhoto = isThai ? 'รูปโปรไฟล์' : 'Profile Photo',
      changePhoto = isThai ? 'เปลี่ยนรูปภาพ' : 'Change Photo',
      personalInfo = isThai ? 'ข้อมูลส่วนตัว' : 'Personal Info',
      fullName = isThai ? 'ชื่อ-นามสกุล' : 'Full Name',
      phone = isThai ? 'เบอร์โทรศัพท์' : 'Phone Number',
      email = isThai ? 'อีเมล' : 'Email',
      emailHint = isThai ? 'กรอกอีเมล' : 'Enter email',
      address = isThai ? 'ที่อยู่' : 'Address',
      addressHint = isThai ? 'กรอกที่อยู่' : 'Enter address',
      guardInfo = isThai ? 'ข้อมูลเจ้าหน้าที่' : 'Guard Info',
      gender = isThai ? 'เพศ' : 'Gender',
      dateOfBirth = isThai ? 'วันเกิด' : 'Date of Birth',
      yearsOfExperience = isThai ? 'ประสบการณ์ (ปี)' : 'Experience (years)',
      previousWorkplace = isThai ? 'สถานที่ทำงานก่อนหน้า' : 'Previous Workplace',
      emergencyContact = isThai ? 'ผู้ติดต่อฉุกเฉิน' : 'Emergency Contact',
      contactName = isThai ? 'ชื่อผู้ติดต่อ' : 'Contact Name',
      contactNameHint = isThai ? 'กรอกชื่อ' : 'Enter name',
      contactPhone = isThai ? 'เบอร์โทรศัพท์' : 'Phone Number',
      contactPhoneHint = isThai ? 'กรอกเบอร์โทร' : 'Enter phone',
      relationship = isThai ? 'ความสัมพันธ์' : 'Relationship',
      relationshipHint = isThai
          ? 'เช่น พ่อ แม่ คู่สมรส'
          : 'e.g. Parent, Spouse',
      notifications = isThai ? 'การแจ้งเตือน' : 'Notifications',
      pushNotif = isThai ? 'การแจ้งเตือนแอป' : 'Push Notifications',
      pushNotifDesc = isThai
          ? 'รับการแจ้งเตือนเมื่อมีงานใหม่'
          : 'Receive alerts for new jobs',
      smsNotif = isThai ? 'แจ้งเตือนทาง SMS' : 'SMS Notifications',
      smsNotifDesc = isThai
          ? 'รับ SMS เมื่อมีเรื่องสำคัญ'
          : 'Receive SMS for important updates',
      jobAlerts = isThai ? 'แจ้งเตือนงานใกล้เคียง' : 'Nearby Job Alerts',
      jobAlertsDesc = isThai
          ? 'แจ้งเตือนเมื่อมีงานในรัศมี 10 กม.'
          : 'Alert when jobs are within 10 km',
      saveChanges = isThai ? 'บันทึกการเปลี่ยนแปลง' : 'Save Changes';
}

// ──────────────────────────────────────────────
// 18. RatingsReviewsStrings — ratings_reviews_screen
// ──────────────────────────────────────────────
class RatingsReviewsStrings {
  final String appBarTitle;
  final String overallRating;
  final String basedOnReviews;
  final String ratingBreakdown;
  final String punctuality;
  final String professionalism;
  final String communication;
  final String appearance;
  final String recentReviews;
  final String sampleReview1Name;
  final String sampleReview1Text;
  final String sampleReview1Date;
  final String sampleReview2Name;
  final String sampleReview2Text;
  final String sampleReview2Date;
  final String sampleReview3Name;
  final String sampleReview3Text;
  final String sampleReview3Date;
  final String noReviews;

  RatingsReviewsStrings({required bool isThai})
    : appBarTitle = isThai ? 'คะแนนและรีวิว' : 'Ratings & Reviews',
      overallRating = isThai ? 'คะแนนรวม' : 'Overall Rating',
      basedOnReviews = isThai ? 'จาก 48 รีวิว' : 'Based on 48 reviews',
      ratingBreakdown = isThai ? 'คะแนนแยกหมวด' : 'Rating Breakdown',
      punctuality = isThai ? 'ตรงต่อเวลา' : 'Punctuality',
      professionalism = isThai ? 'ความเป็นมืออาชีพ' : 'Professionalism',
      communication = isThai ? 'การสื่อสาร' : 'Communication',
      appearance = isThai ? 'บุคลิกภาพ' : 'Appearance',
      recentReviews = isThai ? 'รีวิวล่าสุด' : 'Recent Reviews',
      sampleReview1Name = isThai ? 'คุณสมศรี ใจดี' : 'Mrs. Somsri Jaidee',
      sampleReview1Text = isThai
          ? 'ทำงานดีมาก ตรงเวลา สุภาพเรียบร้อย แนะนำเลยค่ะ'
          : 'Excellent work, punctual and polite. Highly recommended!',
      sampleReview1Date = isThai ? '10 ก.พ. 2569' : '10 Feb 2026',
      sampleReview2Name = isThai ? 'คุณวิชัย มั่นคง' : 'Mr. Wichai Mankong',
      sampleReview2Text = isThai
          ? 'ดูแลอาคารได้ดี มีความรับผิดชอบสูง'
          : 'Great building security, very responsible',
      sampleReview2Date = isThai ? '5 ก.พ. 2569' : '5 Feb 2026',
      sampleReview3Name = isThai ? 'คุณนภา สว่างใจ' : 'Ms. Napa Sawangjai',
      sampleReview3Text = isThai
          ? 'สุภาพ แต่งตัวเรียบร้อย ทำตามหน้าที่ครบถ้วน'
          : 'Polite, well-dressed, completed all duties properly',
      sampleReview3Date = isThai ? '28 ม.ค. 2569' : '28 Jan 2026',
      noReviews = isThai ? 'ยังไม่มีรีวิว' : 'No reviews yet';
}

// ──────────────────────────────────────────────
// 19. WorkHistoryStrings — work_history_screen
// ──────────────────────────────────────────────
class WorkHistoryStrings {
  final String appBarTitle;
  final String summary;
  final String totalJobs;
  final String totalHours;
  final String totalEarnings;
  final String avgRating;
  final String jobHistory;
  final String completed;
  final String sampleJob1Client;
  final String sampleJob1Location;
  final String sampleJob1Date;
  final String sampleJob1Duration;
  final String sampleJob2Client;
  final String sampleJob2Location;
  final String sampleJob2Date;
  final String sampleJob2Duration;
  final String sampleJob3Client;
  final String sampleJob3Location;
  final String sampleJob3Date;
  final String sampleJob3Duration;
  final String sampleJob4Client;
  final String sampleJob4Location;
  final String sampleJob4Date;
  final String sampleJob4Duration;
  final String noHistory;

  WorkHistoryStrings({required bool isThai})
    : appBarTitle = isThai ? 'ประวัติการทำงาน' : 'Work History',
      summary = isThai ? 'สรุปภาพรวม' : 'Summary',
      totalJobs = isThai ? 'งานทั้งหมด' : 'Total Jobs',
      totalHours = isThai ? 'ชั่วโมงทำงาน' : 'Total Hours',
      totalEarnings = isThai ? 'รายได้รวม' : 'Total Earnings',
      avgRating = isThai ? 'คะแนนเฉลี่ย' : 'Avg Rating',
      jobHistory = isThai ? 'ประวัติงาน' : 'Job History',
      completed = isThai ? 'เสร็จสิ้น' : 'Completed',
      sampleJob1Client = isThai ? 'คุณสมศรี ใจดี' : 'Mrs. Somsri Jaidee',
      sampleJob1Location = isThai
          ? 'อาคารสยามทาวเวอร์ ชั้น 15'
          : 'Siam Tower, 15th Fl',
      sampleJob1Date = isThai ? '10 ก.พ. 2569' : '10 Feb 2026',
      sampleJob1Duration = isThai ? '4 ชั่วโมง' : '4 hours',
      sampleJob2Client = isThai ? 'คุณวิชัย มั่นคง' : 'Mr. Wichai Mankong',
      sampleJob2Location = isThai
          ? 'หมู่บ้านเพอร์เฟค พาร์ค'
          : 'Perfect Park Village',
      sampleJob2Date = isThai ? '8 ก.พ. 2569' : '8 Feb 2026',
      sampleJob2Duration = isThai ? '8 ชั่วโมง' : '8 hours',
      sampleJob3Client = isThai ? 'บริษัท ไทยเทค จำกัด' : 'ThaiTech Co., Ltd.',
      sampleJob3Location = isThai
          ? 'อาคารไทยเทค ถ.สาทร'
          : 'ThaiTech Bldg, Sathorn Rd',
      sampleJob3Date = isThai ? '5 ก.พ. 2569' : '5 Feb 2026',
      sampleJob3Duration = isThai ? '6 ชั่วโมง' : '6 hours',
      sampleJob4Client = isThai ? 'คุณนภา สว่างใจ' : 'Ms. Napa Sawangjai',
      sampleJob4Location = isThai
          ? 'คอนโด เดอะ ไลน์ สุขุมวิท'
          : 'The Line Sukhumvit Condo',
      sampleJob4Date = isThai ? '1 ก.พ. 2569' : '1 Feb 2026',
      sampleJob4Duration = isThai ? '5 ชั่วโมง' : '5 hours',
      noHistory = isThai ? 'ยังไม่มีประวัติการทำงาน' : 'No work history yet';
}

// ──────────────────────────────────────────────
// 20. ContactSupportStrings — contact_support_screen
// ──────────────────────────────────────────────
class ContactSupportStrings {
  final String appBarTitle;
  final String headerTitle;
  final String headerDesc;
  final String callCenter;
  final String callCenterNumber;
  final String callCenterHours;
  final String lineChat;
  final String lineChatId;
  final String lineChatDesc;
  final String emailSupport;
  final String emailAddress;
  final String emailDesc;
  final String faq;
  final String faq1Question;
  final String faq1Answer;
  final String faq2Question;
  final String faq2Answer;
  final String faq3Question;
  final String faq3Answer;
  final String reportIssue;
  final String reportDesc;
  final String reportButton;

  ContactSupportStrings({required bool isThai})
    : appBarTitle = isThai ? 'ติดต่อฝ่ายสนับสนุน' : 'Contact Support',
      headerTitle = isThai ? 'เราพร้อมช่วยเหลือคุณ' : "We're Here to Help",
      headerDesc = isThai
          ? 'เลือกช่องทางที่สะดวกเพื่อติดต่อทีมงาน'
          : 'Choose a convenient channel to reach our team',
      callCenter = isThai ? 'ศูนย์บริการลูกค้า' : 'Call Center',
      callCenterNumber = '02-123-4567',
      callCenterHours = isThai
          ? 'เปิดให้บริการ จ.-ศ. 08:00-20:00'
          : 'Available Mon-Fri 08:00-20:00',
      lineChat = isThai ? 'แชท LINE' : 'LINE Chat',
      lineChatId = '@p-guard',
      lineChatDesc = isThai
          ? 'ตอบกลับภายใน 30 นาที ในเวลาทำการ'
          : 'Replies within 30 min during business hours',
      emailSupport = isThai ? 'อีเมล' : 'Email',
      emailAddress = 'support@p-guard.co.th',
      emailDesc = isThai
          ? 'ตอบกลับภายใน 24 ชั่วโมง'
          : 'Response within 24 hours',
      faq = isThai ? 'คำถามที่พบบ่อย' : 'FAQ',
      faq1Question = isThai
          ? 'ทำไมใบสมัครของฉันยังไม่ได้รับการอนุมัติ?'
          : 'Why is my application still pending?',
      faq1Answer = isThai
          ? 'การตรวจสอบใบสมัครใช้เวลา 1-3 วันทำการ หากเกิน 3 วัน กรุณาติดต่อฝ่ายสนับสนุน'
          : 'Application review takes 1-3 business days. If it exceeds 3 days, please contact support',
      faq2Question = isThai
          ? 'ฉันจะถอนเงินได้อย่างไร?'
          : 'How do I withdraw my earnings?',
      faq2Answer = isThai
          ? 'ไปที่แท็บรายได้ > กระเป๋าเงิน > กรอกจำนวนเงินและยืนยันด้วย PIN'
          : 'Go to Income tab > Wallet > Enter amount and confirm with PIN',
      faq3Question = isThai
          ? 'ฉันสามารถเปลี่ยนข้อมูลธนาคารได้ไหม?'
          : 'Can I change my bank information?',
      faq3Answer = isThai
          ? 'ได้ครับ กรุณาติดต่อฝ่ายสนับสนุนเพื่อเปลี่ยนข้อมูลธนาคาร'
          : 'Yes, please contact support to update your bank details',
      reportIssue = isThai ? 'แจ้งปัญหา' : 'Report an Issue',
      reportDesc = isThai
          ? 'พบปัญหาในการใช้งาน? แจ้งให้เราทราบ'
          : 'Having trouble? Let us know',
      reportButton = isThai ? 'แจ้งปัญหา' : 'Report Issue';
}

// ──────────────────────────────────────────────
// 21. NotificationStrings — notification_screen
// ──────────────────────────────────────────────
class NotificationStrings {
  final String appBarTitle;
  final String readAll;
  final String emptyTitle;
  final String emptySubtitle;
  final String justNow;
  final String minutesAgo;
  final String hoursAgo;
  final String daysAgo;
  final String weeksAgo;
  final String loadError;

  NotificationStrings({required bool isThai})
    : appBarTitle = isThai ? 'การแจ้งเตือน' : 'Notifications',
      readAll = isThai ? 'อ่านทั้งหมด' : 'Read all',
      emptyTitle = isThai ? 'ไม่มีการแจ้งเตือน' : 'No notifications',
      emptySubtitle = isThai
          ? 'เมื่อมีการแจ้งเตือนใหม่จะแสดงที่นี่'
          : 'New notifications will appear here',
      justNow = isThai ? 'เมื่อสักครู่' : 'Just now',
      minutesAgo = isThai ? 'นาทีที่แล้ว' : 'm ago',
      hoursAgo = isThai ? 'ชั่วโมงที่แล้ว' : 'h ago',
      daysAgo = isThai ? 'วันที่แล้ว' : 'd ago',
      weeksAgo = isThai ? 'สัปดาห์ที่แล้ว' : 'w ago',
      loadError = isThai ? 'ไม่สามารถโหลดการแจ้งเตือนได้' : 'Failed to load notifications';
}

// ──────────────────────────────────────────────
// 22. ChatStrings — chat_list_screen & chat_screen
// ──────────────────────────────────────────────
class ChatStrings {
  final String chatListTitle;
  final String chatListSubtitle;
  final String online;
  final String offline;
  final String lastSeen;
  final String typeMessage;
  final String systemEventCheckIn;
  final String hourlyReport;
  final String reportNormal;
  final String viewLocation;
  final String photoReport;
  final String call;
  final String yesterday;

  ChatStrings({required bool isThai})
    : chatListTitle = isThai ? 'แชทกับเจ้าหน้าที่' : 'Chat with Guard',
      chatListSubtitle = isThai
          ? 'ติดต่อกับเจ้าหน้าที่รักษาความปลอดภัยของคุณ'
          : 'Contact your security personnel',
      online = isThai ? 'ออนไลน์' : 'Online',
      offline = isThai ? 'ออฟไลน์' : 'Offline',
      lastSeen = isThai ? 'เมื่อวาน' : 'Yesterday',
      typeMessage = isThai ? 'พิมพ์ข้อความ...' : 'Type a message...',
      systemEventCheckIn = isThai ? 'การแจ้งเตือนระบบ' : 'System Notification',
      hourlyReport = isThai ? 'รายงานประจำชั่วโมง' : 'Hourly Report',
      reportNormal = isThai
          ? 'ปกติ พื้นที่ปลอดภัย ไม่มีเหตุการณ์ผิดปกติ'
          : 'Normal, area secure, no incidents.',
      viewLocation = isThai
          ? 'ตำแหน่งที่ยืนยันด้วย GPS'
          : 'GPS Verified Location',
      photoReport = isThai ? 'ภาพถ่ายรายงาน' : 'Report Photo',
      call = isThai ? 'โทร' : 'Call',
      yesterday = isThai ? 'เมื่อวาน' : 'Yesterday';
}

// ──────────────────────────────────────────────
// 23. HirerHistoryStrings — hirer_history_screen
// ──────────────────────────────────────────────
class HirerHistoryStrings {
  final String appBarTitle;
  final String noHistory;
  final String total;
  final String statusCompleted;
  final String statusCancelled;
  final String statusInProgress;
  final String securityGuard;
  final String bodyguard;

  HirerHistoryStrings({required bool isThai})
    : appBarTitle = isThai ? 'ประวัติการจอง' : 'Booking History',
      noHistory = isThai
          ? 'คุณยังไม่มีประวัติการจอง'
          : 'No booking history yet',
      total = isThai ? 'ยอดรวม' : 'Total',
      statusCompleted = isThai ? 'สำเร็จ' : 'Completed',
      statusCancelled = isThai ? 'ยกเลิก' : 'Cancelled',
      statusInProgress = isThai ? 'กำลังดำเนินการ' : 'In Progress',
      securityGuard = isThai ? 'เจ้าหน้าที่รปภ.' : 'Security Guard',
      bodyguard = isThai ? 'บอดี้การ์ด' : 'Bodyguard';
}

// ──────────────────────────────────────────────
// 24. HirerProfileStrings — hirer_profile_screen
// ──────────────────────────────────────────────
class HirerProfileStrings {
  final String hirer;
  final String profileHeader;
  final String sampleHirerName;
  final String sampleCompany;
  final String editProfile;
  final String savedLocations;
  final String paymentMethods;
  final String changePin;
  final String notifications;
  final String support;
  final String logout;
  // Stats
  final String totalBookings;
  final String activeGuards;
  final String memberSince;
  // Contact info
  final String contactInfo;
  final String samplePhone;
  final String sampleEmail;
  // Menu
  final String menuTitle;
  // Header extras
  final String sampleHirerCode;
  final String verified;

  HirerProfileStrings({required bool isThai})
    : hirer = isThai ? 'ผู้ว่าจ้าง' : 'Hirer',
      profileHeader = isThai ? 'โปรไฟล์ของฉัน' : 'My Profile',
      sampleHirerName = isThai ? 'คุณมานะ มีบุญ' : 'Mr. Mana Meebun',
      sampleCompany = isThai
          ? 'บริษัท เซเว่นการ์ด จำกัด'
          : 'SevenGuard Co., Ltd.',
      editProfile = isThai ? 'แก้ไขโปรไฟล์' : 'Edit Profile',
      savedLocations = isThai ? 'สถานที่ที่บันทึกไว้' : 'Saved Locations',
      paymentMethods = isThai ? 'วิธีการชำระเงิน' : 'Payment Methods',
      changePin = isThai ? 'เปลี่ยนรหัส PIN' : 'Change PIN',
      notifications = isThai ? 'การแจ้งเตือน' : 'Notifications',
      support = isThai ? 'ช่วยเหลือและสนับสนุน' : 'Help & Support',
      logout = isThai ? 'ออกจากระบบ' : 'Logout',
      totalBookings = isThai ? 'จองทั้งหมด' : 'Bookings',
      activeGuards = isThai ? 'กำลังทำงาน' : 'Active',
      memberSince = isThai ? 'เดือน' : 'Months',
      contactInfo = isThai ? 'ข้อมูลติดต่อ' : 'Contact Info',
      samplePhone = '081-234-5678',
      sampleEmail = 'mana@p-guard.co.th',
      menuTitle = isThai ? 'เมนู' : 'Menu',
      sampleHirerCode = isThai ? 'รหัส: HR005678' : 'ID: HR005678',
      verified = isThai ? 'ยืนยันแล้ว' : 'Verified';
}

// ──────────────────────────────────────────────
// 25. HirerProfileSettingsStrings — hirer_profile_settings_screen
// ──────────────────────────────────────────────
class HirerProfileSettingsStrings {
  final String appBarTitle;
  final String changePhoto;
  final String personalInfo;
  final String fullName;
  final String phone;
  final String email;
  final String emailHint;
  final String company;
  final String companyHint;
  final String address;
  final String addressHint;
  final String notifications;
  final String pushNotif;
  final String pushNotifDesc;
  final String smsNotif;
  final String smsNotifDesc;
  final String bookingAlerts;
  final String bookingAlertsDesc;
  final String saveChanges;

  HirerProfileSettingsStrings({required bool isThai})
    : appBarTitle = isThai ? 'แก้ไขโปรไฟล์' : 'Edit Profile',
      changePhoto = isThai ? 'เปลี่ยนรูปภาพ' : 'Change Photo',
      personalInfo = isThai ? 'ข้อมูลส่วนตัว' : 'Personal Info',
      fullName = isThai ? 'ชื่อ-นามสกุล' : 'Full Name',
      phone = isThai ? 'เบอร์โทรศัพท์' : 'Phone Number',
      email = isThai ? 'อีเมล' : 'Email',
      emailHint = isThai ? 'กรอกอีเมล' : 'Enter email',
      company = isThai ? 'ชื่อบริษัท / องค์กร' : 'Company / Organization',
      companyHint = isThai
          ? 'กรอกชื่อบริษัท (ถ้ามี)'
          : 'Enter company name (optional)',
      address = isThai ? 'ที่อยู่' : 'Address',
      addressHint = isThai ? 'กรอกที่อยู่' : 'Enter address',
      notifications = isThai ? 'การแจ้งเตือน' : 'Notifications',
      pushNotif = isThai ? 'การแจ้งเตือนแอป' : 'Push Notifications',
      pushNotifDesc = isThai
          ? 'รับการแจ้งเตือนเมื่อมีอัปเดตการจอง'
          : 'Receive alerts for booking updates',
      smsNotif = isThai ? 'แจ้งเตือนทาง SMS' : 'SMS Notifications',
      smsNotifDesc = isThai
          ? 'รับ SMS เมื่อมีเรื่องสำคัญ'
          : 'Receive SMS for important updates',
      bookingAlerts = isThai ? 'แจ้งเตือนการจอง' : 'Booking Alerts',
      bookingAlertsDesc = isThai
          ? 'แจ้งเตือนเมื่อสถานะการจองเปลี่ยน'
          : 'Alert when booking status changes',
      saveChanges = isThai ? 'บันทึกการเปลี่ยนแปลง' : 'Save Changes';
}

// ──────────────────────────────────────────────
// 27. LiveMapStrings — live_map_screen
// ──────────────────────────────────────────────
class LiveMapStrings {
  final String title;
  final String subtitle;
  final String totalOnMap;
  final String active;
  final String idle;
  final String alerts;
  final String filterAll;
  final String filterActive;
  final String filterIdle;
  final String filterAlert;
  final String personnelList;
  final String guardsOnMap;
  final String legend;
  final String justNow;
  final String minAgo;
  final String hourAgo;
  final String noGuards;
  final String refresh;
  final String myLocation;

  LiveMapStrings({required bool isThai})
    : title = isThai ? 'แผนที่ติดตามสด' : 'Live Map Tracking',
      subtitle = isThai
          ? 'ติดตามตำแหน่งเจ้าหน้าที่แบบเรียลไทม์'
          : 'Real-time location monitoring',
      totalOnMap = isThai ? 'ทั้งหมดบนแผนที่' : 'Total On Map',
      active = isThai ? 'ปฏิบัติงาน' : 'Active',
      idle = isThai ? 'ว่าง' : 'Idle',
      alerts = isThai ? 'แจ้งเตือน' : 'Alerts',
      filterAll = isThai ? 'ทั้งหมด' : 'All',
      filterActive = isThai ? 'ปฏิบัติงาน' : 'Active',
      filterIdle = isThai ? 'ว่าง' : 'Idle',
      filterAlert = isThai ? 'แจ้งเตือน' : 'Alert',
      personnelList = isThai ? 'เจ้าหน้าที่ปฏิบัติงาน' : 'Active Personnel',
      guardsOnMap = isThai ? 'คนบนแผนที่' : 'guards on map',
      legend = isThai ? 'สัญลักษณ์' : 'Legend',
      justNow = isThai ? 'เมื่อสักครู่' : 'Just now',
      minAgo = isThai ? 'นาทีที่แล้ว' : 'min ago',
      hourAgo = isThai ? 'ชม. ที่แล้ว' : 'h ago',
      noGuards = isThai
          ? 'ไม่พบเจ้าหน้าที่ในตัวกรองนี้'
          : 'No guards found for this filter',
      refresh = isThai ? 'รีเฟรช' : 'Refresh',
      myLocation = isThai ? 'ตำแหน่งของฉัน' : 'My Location';
}

// ──────────────────────────────────────────────
// PinLoginStrings — pin_login_screen
// ──────────────────────────────────────────────
class PinLoginStrings {
  final String accountApproved;
  final String title;
  final String subtitle;
  final String pinIncorrect;

  PinLoginStrings({required bool isThai})
    : accountApproved = isThai ? 'บัญชีได้รับอนุมัติแล้ว' : 'Account Approved',
      title = isThai ? 'เข้าสู่ระบบ' : 'Login',
      subtitle = isThai
          ? 'กรุณาใส่ PIN 6 หลักที่ตั้งไว้ตอนลงทะเบียน'
          : 'Enter the 6-digit PIN you set during registration',
      pinIncorrect = isThai
          ? 'PIN ไม่ถูกต้อง ลองใหม่อีกครั้ง'
          : 'Incorrect PIN. Try again';
}

// ──────────────────────────────────────────────
// GuardNavigationStrings — guard_navigation_screen
// ──────────────────────────────────────────────
class GuardNavigationStrings {
  final String title;
  final String subtitle;
  final String arrived;

  GuardNavigationStrings({required bool isThai})
    : title = isThai ? 'กำลังเดินทาง' : 'En Route',
      subtitle = isThai ? 'นำทางไปยังจุดหมาย' : 'Navigating to destination',
      arrived = isThai ? 'ถึงแล้ว' : 'Arrived';
}

// ──────────────────────────────────────────────
// CustomerTrackingStrings — customer_tracking_screen
// ──────────────────────────────────────────────
class CustomerTrackingStrings {
  final String title;
  final String guardEnRoute;
  final String guardArrived;
  final String hasArrived;
  final String waitingForLocation;
  final String ok;
  final String trackGuard;

  CustomerTrackingStrings({required bool isThai})
    : title = isThai ? 'ติดตามเจ้าหน้าที่' : 'Track Guard',
      guardEnRoute = isThai ? 'กำลังเดินทางมาหาคุณ' : 'On the way to you',
      guardArrived = isThai ? 'เจ้าหน้าที่ถึงแล้ว' : 'Guard Arrived',
      hasArrived = isThai ? 'ถึงจุดหมายของคุณแล้ว' : 'has arrived at your location',
      waitingForLocation = isThai ? 'กำลังรอตำแหน่งเจ้าหน้าที่...' : 'Waiting for guard location...',
      ok = isThai ? 'ตกลง' : 'OK',
      trackGuard = isThai ? 'ติดตามเจ้าหน้าที่' : 'Track Guard';
}

// ──────────────────────────────────────────────
// CustomerActiveJobStrings — customer_active_job_screen
// ──────────────────────────────────────────────
class CustomerActiveJobStrings {
  final String title;
  final String subtitle;
  final String remaining;
  final String guard;
  final String location;
  final String bookedHours;
  final String hours;
  final String minutes;
  final String guardWorking;
  final String jobCompleted;
  final String jobCompletedMsg;
  final String backToHome;
  final String timeUp;
  final String timeUpMsg;
  final String reviewTitle;
  final String reviewSubtitle;
  final String startTime;
  final String endTime;
  final String workedDuration;
  final String bookedDuration;
  final String approveCompletion;
  final String hold;
  final String pendingReview;

  CustomerActiveJobStrings({required bool isThai})
    : title = isThai ? 'เจ้าหน้าที่กำลังปฏิบัติงาน' : 'Guard On Duty',
      subtitle = isThai ? 'นับถอยหลังเวลาทำงาน' : 'Job countdown timer',
      remaining = isThai ? 'เวลาที่เหลือ' : 'Remaining',
      guard = isThai ? 'เจ้าหน้าที่' : 'Guard',
      location = isThai ? 'สถานที่' : 'Location',
      bookedHours = isThai ? 'ระยะเวลาจอง' : 'Booked Duration',
      hours = isThai ? 'ชั่วโมง' : 'hours',
      minutes = isThai ? 'นาที' : 'min',
      guardWorking = isThai ? 'กำลังปฏิบัติหน้าที่' : 'Currently on duty',
      jobCompleted = isThai ? 'งานเสร็จสิ้น!' : 'Job Completed!',
      jobCompletedMsg = isThai ? 'เจ้าหน้าที่ปฏิบัติงานเสร็จสิ้นแล้ว' : 'The guard has completed the job',
      backToHome = isThai ? 'กลับหน้าหลัก' : 'Back to Home',
      timeUp = isThai ? 'หมดเวลาแล้ว' : 'Time\'s Up',
      timeUpMsg = isThai ? 'ระยะเวลาที่จองหมดแล้ว รอเจ้าหน้าที่จบงาน' : 'Booked duration ended. Waiting for guard to complete.',
      reviewTitle = isThai ? 'ตรวจสอบปิดงาน' : 'Review Completion',
      reviewSubtitle = isThai ? 'กรุณาตรวจสอบข้อมูลก่อนอนุมัติ' : 'Please review details before approving',
      startTime = isThai ? 'เวลาเริ่มงาน' : 'Start Time',
      endTime = isThai ? 'เวลาสิ้นสุด' : 'End Time',
      workedDuration = isThai ? 'ระยะเวลาทำงาน' : 'Worked Duration',
      bookedDuration = isThai ? 'ระยะเวลาจอง' : 'Booked Duration',
      approveCompletion = isThai ? 'อนุมัติปิดงาน' : 'Approve Completion',
      hold = 'Hold',
      pendingReview = isThai ? 'เจ้าหน้าที่ขอปิดงาน รอตรวจสอบ' : 'Guard requested completion';
}

class ReviewRatingStrings {
  final String title;
  final String subtitle;
  final String overallRating;
  final String punctuality;
  final String professionalism;
  final String communication;
  final String appearance;
  final String reviewPlaceholder;
  final String submitReview;
  final String skip;
  final String thankYou;
  final String reviewSubmitted;
  final String reviewSubmittedMsg;
  final String guard;

  ReviewRatingStrings({required bool isThai})
    : title = isThai ? 'ให้คะแนนเจ้าหน้าที่' : 'Rate Guard',
      subtitle = isThai ? 'กรุณาให้คะแนนการบริการ' : 'Please rate the service',
      overallRating = isThai ? 'คะแนนรวม' : 'Overall Rating',
      punctuality = isThai ? 'ตรงต่อเวลา' : 'Punctuality',
      professionalism = isThai ? 'ความเป็นมืออาชีพ' : 'Professionalism',
      communication = isThai ? 'การสื่อสาร' : 'Communication',
      appearance = isThai ? 'บุคลิกภาพ' : 'Appearance',
      reviewPlaceholder = isThai ? 'แสดงความคิดเห็น (ไม่บังคับ)' : 'Write a review (optional)',
      submitReview = isThai ? 'ส่งรีวิว' : 'Submit Review',
      skip = isThai ? 'ข้าม' : 'Skip',
      thankYou = isThai ? 'ขอบคุณ!' : 'Thank You!',
      reviewSubmitted = isThai ? 'ส่งรีวิวเรียบร้อย' : 'Review Submitted',
      reviewSubmittedMsg = isThai ? 'ขอบคุณสำหรับการให้คะแนน' : 'Thank you for your feedback',
      guard = isThai ? 'เจ้าหน้าที่' : 'Guard';
}

class ProgressReportStrings {
  final String title;
  final String hourLabel;
  final String messagePlaceholder;
  final String takePhoto;
  final String chooseGallery;
  final String recordVideo;
  final String submit;
  final String skip;
  final String submitSuccess;
  final String submitError;
  final String progressReports;
  final String noReports;
  final String submitting;
  final String maxFilesReached;
  final String filesSelected;
  final String compressing;
  final String removeFile;

  ProgressReportStrings({
    required bool isThai,
  })  : title = isThai ? 'รายงานความคืบหน้า' : 'Progress Report',
        hourLabel = isThai ? 'ชั่วโมงที่' : 'Hour',
        messagePlaceholder = isThai ? 'พิมพ์ข้อความรายงาน (ไม่บังคับ)' : 'Type report message (optional)',
        takePhoto = isThai ? 'ถ่ายรูป' : 'Take Photo',
        chooseGallery = isThai ? 'เลือกจากแกลเลอรี' : 'Choose from Gallery',
        recordVideo = isThai ? 'วิดีโอ' : 'Video',
        submit = isThai ? 'ส่งรายงาน' : 'Submit Report',
        skip = isThai ? 'ข้ามไปก่อน' : 'Skip for Now',
        submitSuccess = isThai ? 'ส่งรายงานสำเร็จ' : 'Report submitted',
        submitError = isThai ? 'ส่งรายงานไม่สำเร็จ' : 'Failed to submit report',
        progressReports = isThai ? 'รายงานความคืบหน้า' : 'Progress Reports',
        noReports = isThai ? 'ยังไม่มีรายงาน' : 'No reports yet',
        submitting = isThai ? 'กำลังส่ง...' : 'Submitting...',
        maxFilesReached = isThai ? 'ไฟล์ครบจำนวนสูงสุด' : 'Maximum files reached',
        filesSelected = isThai ? 'ไฟล์ที่เลือก' : 'files selected',
        compressing = isThai ? 'กำลังบีบอัดรูป...' : 'Compressing...',
        removeFile = isThai ? 'ลบไฟล์' : 'Remove file';
}
