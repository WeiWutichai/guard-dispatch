import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Guard Dispatch Docs',
  description: 'ระบบเรียก รปภ. — Developer Documentation',
  lang: 'th',

  themeConfig: {
    logo: '🛡️',
    siteTitle: 'Guard Dispatch',

    nav: [
      { text: 'Home', link: '/' },
      { text: 'Developer Guide', link: '/DEVELOPER_GUIDE' },
      {
        text: 'Web Admin',
        items: [
          { text: 'Dashboard', link: '/pages/dashboard' },
          { text: 'Applicants', link: '/pages/applicants' },
          { text: 'Guards', link: '/pages/guards' },
          { text: 'Customers', link: '/pages/customers' },
          { text: 'Tasks', link: '/pages/tasks' },
          { text: 'Map', link: '/pages/map' },
        ],
      },
      {
        text: 'Mobile',
        items: [
          { text: 'Common Screens', link: '/screens/phone-input' },
          { text: 'Guard Screens', link: '/screens/guard/dashboard' },
          { text: 'Hirer Screens', link: '/screens/hirer/dashboard' },
        ],
      },
    ],

    sidebar: {
      '/': [
        {
          text: 'Getting Started',
          items: [
            { text: 'Overview', link: '/' },
            { text: 'Developer Guide', link: '/DEVELOPER_GUIDE' },
          ],
        },
      ],

      '/pages/': [
        {
          text: 'Web Admin Pages',
          items: [
            { text: 'Dashboard', link: '/pages/dashboard' },
            { text: 'Login', link: '/pages/login' },
            { text: 'Applicants', link: '/pages/applicants' },
            { text: 'Guards', link: '/pages/guards' },
            { text: 'Customers', link: '/pages/customers' },
            { text: 'Map', link: '/pages/map' },
            { text: 'Tasks', link: '/pages/tasks' },
            { text: 'Reviews', link: '/pages/reviews' },
            { text: 'Wallet', link: '/pages/wallet' },
            { text: 'Pricing', link: '/pages/pricing' },
            { text: 'Recruitment', link: '/pages/recruitment' },
            { text: 'Reports', link: '/pages/reports' },
            { text: 'Automation', link: '/pages/automation' },
            { text: 'Activity Log', link: '/pages/activity' },
            { text: 'Settings', link: '/pages/settings' },
            { text: 'Profile', link: '/pages/profile' },
          ],
        },
      ],

      '/screens/': [
        {
          text: 'Common Screens',
          items: [
            { text: 'Phone Input', link: '/screens/phone-input' },
            { text: 'OTP Verification', link: '/screens/otp-verification' },
            { text: 'Role Selection', link: '/screens/role-selection' },
            { text: 'PIN Setup', link: '/screens/pin-setup' },
            { text: 'PIN Lock', link: '/screens/pin-lock' },
            { text: 'Notification', link: '/screens/notification' },
            { text: 'Chat List', link: '/screens/chat-list' },
            { text: 'Chat', link: '/screens/chat' },
            { text: 'Call', link: '/screens/call' },
          ],
        },
        {
          text: 'Guard Screens',
          items: [
            { text: 'Dashboard', link: '/screens/guard/dashboard' },
            { text: 'Home Tab', link: '/screens/guard/home-tab' },
            { text: 'Jobs Tab', link: '/screens/guard/jobs-tab' },
            { text: 'Income Tab', link: '/screens/guard/income-tab' },
            { text: 'Profile Tab', link: '/screens/guard/profile-tab' },
            { text: 'Registration', link: '/screens/guard/registration' },
            { text: 'Profile Settings', link: '/screens/guard/profile-settings' },
            { text: 'Ratings & Reviews', link: '/screens/guard/ratings-reviews' },
            { text: 'Work History', link: '/screens/guard/work-history' },
            { text: 'Application Status', link: '/screens/guard/application-status' },
            { text: 'Contact Support', link: '/screens/guard/contact-support' },
          ],
        },
        {
          text: 'Hirer Screens',
          items: [
            { text: 'Dashboard', link: '/screens/hirer/dashboard' },
            { text: 'Service Selection', link: '/screens/hirer/service-selection' },
            { text: 'Booking', link: '/screens/hirer/booking' },
            { text: 'Guard Selection', link: '/screens/hirer/guard-selection' },
            { text: 'Payment', link: '/screens/hirer/payment' },
            { text: 'History', link: '/screens/hirer/history' },
            { text: 'Profile', link: '/screens/hirer/profile' },
            { text: 'Profile Settings', link: '/screens/hirer/profile-settings' },
          ],
        },
        {
          text: 'Legacy',
          collapsed: true,
          items: [
            { text: 'Guard Login', link: '/screens/guard-login' },
            { text: 'Customer Login', link: '/screens/customer-login' },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com' },
    ],

    search: {
      provider: 'local',
    },

    footer: {
      message: 'Guard Dispatch — Security Guard Dispatch System',
      copyright: 'ระบบเรียก รปภ. แบบ Real-time',
    },
  },
})
