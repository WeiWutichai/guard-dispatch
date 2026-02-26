"use client";

import { useState } from "react";
import {
  Activity,
  Smartphone,
  MessageSquare,
  Monitor,
  Tablet,
  MapPin,
  Clock,
  User,
  Shield,
  Search,
  Filter,
  ChevronDown,
  Eye,
  X,
  Globe,
  Laptop,
  LogIn,
  LogOut,
  RefreshCw,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";

type ActivityTab = "device" | "chat";

interface DeviceLog {
  id: string;
  userId: string;
  userName: string;
  userType: "guard" | "customer" | "admin";
  action: "login" | "logout" | "refresh";
  device: "mobile" | "desktop" | "tablet";
  browser: string;
  os: string;
  ip: string;
  location: string;
  timestamp: string;
}

interface ChatMessage {
  id: string;
  guardId: string;
  guardName: string;
  customerId: string;
  customerName: string;
  jobId: string;
  jobTitle: string;
  message: string;
  sender: "guard" | "customer";
  timestamp: string;
  read: boolean;
}

const initialDeviceLogs: DeviceLog[] = [
  { id: "D001", userId: "G001", userName: "สมชาย วงศ์ใหญ่", userType: "guard", action: "login", device: "mobile", browser: "Chrome Mobile", os: "Android 14", ip: "192.168.1.101", location: "กรุงเทพฯ", timestamp: "2024-01-16 14:30:25" },
  { id: "D002", userId: "C001", userName: "นายวิชัย มั่งคั่ง", userType: "customer", action: "login", device: "desktop", browser: "Chrome 120", os: "Windows 11", ip: "192.168.1.102", location: "กรุงเทพฯ", timestamp: "2024-01-16 14:25:10" },
  { id: "D003", userId: "G002", userName: "วันชัย สมใส", userType: "guard", action: "logout", device: "mobile", browser: "Safari", os: "iOS 17", ip: "192.168.1.103", location: "นนทบุรี", timestamp: "2024-01-16 14:20:45" },
  { id: "D004", userId: "A001", userName: "ผู้ดูแลระบบ A", userType: "admin", action: "login", device: "desktop", browser: "Firefox 121", os: "macOS 14", ip: "192.168.1.100", location: "กรุงเทพฯ", timestamp: "2024-01-16 14:15:30" },
  { id: "D005", userId: "C002", userName: "บริษัท ABC จำกัด", userType: "customer", action: "refresh", device: "tablet", browser: "Safari", os: "iPadOS 17", ip: "192.168.1.104", location: "ปทุมธานี", timestamp: "2024-01-16 14:10:15" },
  { id: "D006", userId: "G003", userName: "อนุชา สมบูรณ์", userType: "guard", action: "login", device: "mobile", browser: "Chrome Mobile", os: "Android 13", ip: "192.168.1.105", location: "สมุทรปราการ", timestamp: "2024-01-16 14:05:00" },
  { id: "D007", userId: "G001", userName: "สมชาย วงศ์ใหญ่", userType: "guard", action: "logout", device: "mobile", browser: "Chrome Mobile", os: "Android 14", ip: "192.168.1.101", location: "กรุงเทพฯ", timestamp: "2024-01-16 10:30:00" },
  { id: "D008", userId: "C003", userName: "นางสาวมาลี รักดี", userType: "customer", action: "login", device: "mobile", browser: "Safari", os: "iOS 17", ip: "192.168.1.106", location: "กรุงเทพฯ", timestamp: "2024-01-16 10:15:00" },
];

const initialChatMessages: ChatMessage[] = [
  { id: "M001", guardId: "G001", guardName: "สมชาย วงศ์ใหญ่", customerId: "C001", customerName: "นายวิชัย มั่งคั่ง", jobId: "J001", jobTitle: "รักษาความปลอดภัยคอนโด ABC", message: "สวัสดีครับ ผมมาถึงจุดงานแล้วครับ", sender: "guard", timestamp: "2024-01-16 08:00:15", read: true },
  { id: "M002", guardId: "G001", guardName: "สมชาย วงศ์ใหญ่", customerId: "C001", customerName: "นายวิชัย มั่งคั่ง", jobId: "J001", jobTitle: "รักษาความปลอดภัยคอนโด ABC", message: "ได้รับทราบครับ ขอบคุณที่แจ้งให้ทราบ", sender: "customer", timestamp: "2024-01-16 08:02:30", read: true },
  { id: "M003", guardId: "G002", guardName: "วันชัย สมใส", customerId: "C002", customerName: "บริษัท ABC จำกัด", jobId: "J002", jobTitle: "รักษาความปลอดภัยออฟฟิศ", message: "แจ้งให้ทราบครับ มีรถส่งของมาถึงแล้ว", sender: "guard", timestamp: "2024-01-16 10:30:00", read: true },
  { id: "M004", guardId: "G002", guardName: "วันชัย สมใส", customerId: "C002", customerName: "บริษัท ABC จำกัด", jobId: "J002", jobTitle: "รักษาความปลอดภัยออฟฟิศ", message: "ให้รอก่อนนะครับ กำลังลงไปรับ", sender: "customer", timestamp: "2024-01-16 10:32:15", read: true },
  { id: "M005", guardId: "G003", guardName: "อนุชา สมบูรณ์", customerId: "C003", customerName: "นางสาวมาลี รักดี", jobId: "J003", jobTitle: "บอดี้การ์ดงานอีเวนต์", message: "สวัสดีครับ ผมพร้อมปฏิบัติงานแล้วครับ", sender: "guard", timestamp: "2024-01-16 18:00:00", read: false },
  { id: "M006", guardId: "G001", guardName: "สมชาย วงศ์ใหญ่", customerId: "C001", customerName: "นายวิชัย มั่งคั่ง", jobId: "J001", jobTitle: "รักษาความปลอดภัยคอนโด ABC", message: "รายงานครับ การปฏิบัติงานเสร็จสิ้นเรียบร้อยแล้ว", sender: "guard", timestamp: "2024-01-16 20:00:00", read: false },
  { id: "M007", guardId: "G002", guardName: "วันชัย สมใส", customerId: "C002", customerName: "บริษัท ABC จำกัด", jobId: "J002", jobTitle: "รักษาความปลอดภัยออฟฟิศ", message: "มีบุคคลภายนอกต้องการเข้าพบ ชื่อ นายสมศักดิ์ ครับ", sender: "guard", timestamp: "2024-01-16 14:00:00", read: true },
  { id: "M008", guardId: "G002", guardName: "วันชัย สมใส", customerId: "C002", customerName: "บริษัท ABC จำกัด", jobId: "J002", jobTitle: "รักษาความปลอดภัยออฟฟิศ", message: "ให้เข้ามาได้เลยครับ นัดไว้แล้ว", sender: "customer", timestamp: "2024-01-16 14:02:00", read: true },
];

export default function ActivityPage() {
  const { locale } = useLanguage();
  const [activeTab, setActiveTab] = useState<ActivityTab>("device");
  const [deviceLogs] = useState<DeviceLog[]>(initialDeviceLogs);
  const [chatMessages] = useState<ChatMessage[]>(initialChatMessages);
  const [searchQuery, setSearchQuery] = useState("");
  const [userTypeFilter, setUserTypeFilter] = useState("all");
  const [deviceFilter, setDeviceFilter] = useState("all");
  const [chatDetailOpen, setChatDetailOpen] = useState(false);
  const [selectedConversation, setSelectedConversation] = useState<{guardName: string; customerName: string; jobTitle: string; messages: ChatMessage[]} | null>(null);

  const tabs: { id: ActivityTab; label: string; labelEn: string; icon: typeof Activity }[] = [
    { id: "device", label: "Log การเข้าถึงอุปกรณ์", labelEn: "Device Access Logs", icon: Smartphone },
    { id: "chat", label: "Log ข้อความสนทนา", labelEn: "Chat Message Logs", icon: MessageSquare },
  ];

  const filteredDeviceLogs = deviceLogs.filter((log) => {
    const matchesSearch = log.userName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      log.ip.includes(searchQuery) ||
      log.location.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesUserType = userTypeFilter === "all" || log.userType === userTypeFilter;
    const matchesDevice = deviceFilter === "all" || log.device === deviceFilter;
    return matchesSearch && matchesUserType && matchesDevice;
  });

  const filteredChatMessages = chatMessages.filter((msg) => {
    return msg.guardName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      msg.customerName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      msg.message.toLowerCase().includes(searchQuery.toLowerCase()) ||
      msg.jobTitle.toLowerCase().includes(searchQuery.toLowerCase());
  });

  // Group chat messages by conversation
  const groupedConversations = filteredChatMessages.reduce((acc, msg) => {
    const key = `${msg.guardId}-${msg.customerId}-${msg.jobId}`;
    if (!acc[key]) {
      acc[key] = {
        guardName: msg.guardName,
        customerName: msg.customerName,
        jobTitle: msg.jobTitle,
        messages: [],
        lastMessage: msg,
      };
    }
    acc[key].messages.push(msg);
    if (new Date(msg.timestamp) > new Date(acc[key].lastMessage.timestamp)) {
      acc[key].lastMessage = msg;
    }
    return acc;
  }, {} as Record<string, {guardName: string; customerName: string; jobTitle: string; messages: ChatMessage[]; lastMessage: ChatMessage}>);

  const conversations = Object.values(groupedConversations).sort(
    (a, b) => new Date(b.lastMessage.timestamp).getTime() - new Date(a.lastMessage.timestamp).getTime()
  );

  const getDeviceIcon = (device: string) => {
    switch (device) {
      case "mobile": return Smartphone;
      case "desktop": return Monitor;
      case "tablet": return Tablet;
      default: return Laptop;
    }
  };

  const getActionIcon = (action: string) => {
    switch (action) {
      case "login": return LogIn;
      case "logout": return LogOut;
      case "refresh": return RefreshCw;
      default: return Activity;
    }
  };

  const getUserTypeLabel = (type: string) => {
    switch (type) {
      case "guard": return locale === "th" ? "เจ้าหน้าที่" : "Guard";
      case "customer": return locale === "th" ? "ลูกค้า" : "Customer";
      case "admin": return locale === "th" ? "ผู้ดูแลระบบ" : "Admin";
      default: return type;
    }
  };

  const getUserTypeColor = (type: string) => {
    switch (type) {
      case "guard": return "bg-emerald-100 text-emerald-700";
      case "customer": return "bg-blue-100 text-blue-700";
      case "admin": return "bg-purple-100 text-purple-700";
      default: return "bg-slate-100 text-slate-700";
    }
  };

  const getActionLabel = (action: string) => {
    switch (action) {
      case "login": return locale === "th" ? "เข้าสู่ระบบ" : "Login";
      case "logout": return locale === "th" ? "ออกจากระบบ" : "Logout";
      case "refresh": return locale === "th" ? "รีเฟรช" : "Refresh";
      default: return action;
    }
  };

  const getActionColor = (action: string) => {
    switch (action) {
      case "login": return "text-emerald-600";
      case "logout": return "text-red-500";
      case "refresh": return "text-blue-500";
      default: return "text-slate-500";
    }
  };

  const handleViewConversation = (conv: {guardName: string; customerName: string; jobTitle: string; messages: ChatMessage[]}) => {
    setSelectedConversation(conv);
    setChatDetailOpen(true);
  };

  const stats = {
    totalLogins: deviceLogs.filter(l => l.action === "login").length,
    activeUsers: new Set(deviceLogs.filter(l => l.action === "login").map(l => l.userId)).size,
    totalMessages: chatMessages.length,
    unreadMessages: chatMessages.filter(m => !m.read).length,
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900">
          {locale === "th" ? "Activity Log" : "Activity Log"}
        </h1>
        <p className="text-slate-500 mt-1">
          {locale === "th"
            ? "ติดตามกิจกรรมการใช้งานของผู้ใช้ในระบบ"
            : "Track user activities in the system"}
        </p>
      </div>

      <div className="flex flex-col lg:flex-row gap-6">
        {/* Sidebar */}
        <div className="lg:w-64 flex-shrink-0">
          <div className="bg-white rounded-xl border border-slate-200 p-2">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={cn(
                  "w-full flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-colors",
                  activeTab === tab.id
                    ? "bg-emerald-50 text-emerald-700"
                    : "text-slate-600 hover:bg-slate-50"
                )}
              >
                <tab.icon className={cn("h-5 w-5", activeTab === tab.id ? "text-emerald-600" : "text-slate-400")} />
                {locale === "th" ? tab.label : tab.labelEn}
              </button>
            ))}
          </div>

          {/* Quick Stats */}
          <div className="bg-white rounded-xl border border-slate-200 p-4 mt-4 space-y-3">
            <h3 className="text-sm font-bold text-slate-700">
              {locale === "th" ? "สถิติวันนี้" : "Today's Stats"}
            </h3>
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-sm text-slate-500">{locale === "th" ? "การเข้าสู่ระบบ" : "Logins"}</span>
                <span className="text-sm font-bold text-emerald-600">{stats.totalLogins}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-slate-500">{locale === "th" ? "ผู้ใช้งาน" : "Active Users"}</span>
                <span className="text-sm font-bold text-blue-600">{stats.activeUsers}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-slate-500">{locale === "th" ? "ข้อความทั้งหมด" : "Total Messages"}</span>
                <span className="text-sm font-bold text-slate-700">{stats.totalMessages}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-slate-500">{locale === "th" ? "ยังไม่อ่าน" : "Unread"}</span>
                <span className="text-sm font-bold text-amber-600">{stats.unreadMessages}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 bg-white rounded-xl border border-slate-200 p-6">
          {/* Device Access Logs Tab */}
          {activeTab === "device" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">
                  {locale === "th" ? "Log การเข้าถึงอุปกรณ์" : "Device Access Logs"}
                </h2>
                <p className="text-sm text-slate-500 mt-1">
                  {locale === "th"
                    ? "ประวัติการเข้าสู่ระบบ ออกจากระบบ และอุปกรณ์ที่ใช้งาน"
                    : "Login, logout history and devices used"}
                </p>
              </div>

              {/* Filters */}
              <div className="flex flex-wrap gap-4">
                <div className="flex-1 min-w-[200px]">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
                    <input
                      type="text"
                      placeholder={locale === "th" ? "ค้นหาชื่อ, IP, สถานที่..." : "Search name, IP, location..."}
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2 pl-10 pr-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none"
                    />
                  </div>
                </div>
                <select
                  value={userTypeFilter}
                  onChange={(e) => setUserTypeFilter(e.target.value)}
                  className="bg-slate-50 border border-slate-200 rounded-lg py-2 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none"
                >
                  <option value="all">{locale === "th" ? "ผู้ใช้ทั้งหมด" : "All Users"}</option>
                  <option value="guard">{locale === "th" ? "เจ้าหน้าที่" : "Guards"}</option>
                  <option value="customer">{locale === "th" ? "ลูกค้า" : "Customers"}</option>
                  <option value="admin">{locale === "th" ? "ผู้ดูแลระบบ" : "Admins"}</option>
                </select>
                <select
                  value={deviceFilter}
                  onChange={(e) => setDeviceFilter(e.target.value)}
                  className="bg-slate-50 border border-slate-200 rounded-lg py-2 px-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none"
                >
                  <option value="all">{locale === "th" ? "อุปกรณ์ทั้งหมด" : "All Devices"}</option>
                  <option value="mobile">{locale === "th" ? "มือถือ" : "Mobile"}</option>
                  <option value="desktop">{locale === "th" ? "คอมพิวเตอร์" : "Desktop"}</option>
                  <option value="tablet">{locale === "th" ? "แท็บเล็ต" : "Tablet"}</option>
                </select>
              </div>

              {/* Logs List */}
              <div className="space-y-3">
                {filteredDeviceLogs.map((log) => {
                  const DeviceIcon = getDeviceIcon(log.device);
                  const ActionIcon = getActionIcon(log.action);
                  return (
                    <div key={log.id} className="p-4 bg-slate-50 rounded-lg">
                      <div className="flex items-start justify-between">
                        <div className="flex items-start gap-4">
                          <div className="p-2 bg-white rounded-lg">
                            <DeviceIcon className="h-5 w-5 text-slate-600" />
                          </div>
                          <div>
                            <div className="flex items-center gap-2">
                              <p className="font-medium text-slate-900">{log.userName}</p>
                              <span className={cn("px-2 py-0.5 rounded text-xs font-medium", getUserTypeColor(log.userType))}>
                                {getUserTypeLabel(log.userType)}
                              </span>
                              <span className={cn("flex items-center gap-1 text-xs font-medium", getActionColor(log.action))}>
                                <ActionIcon className="h-3 w-3" />
                                {getActionLabel(log.action)}
                              </span>
                            </div>
                            <div className="flex items-center gap-4 mt-1 text-sm text-slate-500">
                              <span className="flex items-center gap-1">
                                <Monitor className="h-3.5 w-3.5" />
                                {log.browser} • {log.os}
                              </span>
                              <span className="flex items-center gap-1">
                                <Globe className="h-3.5 w-3.5" />
                                {log.ip}
                              </span>
                              <span className="flex items-center gap-1">
                                <MapPin className="h-3.5 w-3.5" />
                                {log.location}
                              </span>
                            </div>
                          </div>
                        </div>
                        <div className="flex items-center gap-1 text-xs text-slate-400">
                          <Clock className="h-3.5 w-3.5" />
                          {log.timestamp}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>

              {filteredDeviceLogs.length === 0 && (
                <div className="py-12 text-center">
                  <Activity className="h-12 w-12 text-slate-300 mx-auto mb-3" />
                  <p className="text-slate-500">{locale === "th" ? "ไม่พบ Log" : "No logs found"}</p>
                </div>
              )}
            </div>
          )}

          {/* Chat Message Logs Tab */}
          {activeTab === "chat" && (
            <div className="space-y-6">
              <div>
                <h2 className="text-lg font-semibold text-slate-900">
                  {locale === "th" ? "Log ข้อความสนทนา" : "Chat Message Logs"}
                </h2>
                <p className="text-sm text-slate-500 mt-1">
                  {locale === "th"
                    ? "ประวัติการสนทนาระหว่างเจ้าหน้าที่กับผู้ว่าจ้าง"
                    : "Conversation history between guards and employers"}
                </p>
              </div>

              {/* Search */}
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
                <input
                  type="text"
                  placeholder={locale === "th" ? "ค้นหาชื่อ, ข้อความ, งาน..." : "Search name, message, job..."}
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full bg-slate-50 border border-slate-200 rounded-lg py-2 pl-10 pr-4 text-sm focus:ring-2 focus:ring-primary/20 focus:border-primary outline-none"
                />
              </div>

              {/* Conversations List */}
              <div className="space-y-3">
                {conversations.map((conv, idx) => (
                  <div key={idx} className="p-4 bg-slate-50 rounded-lg hover:bg-slate-100 transition-colors cursor-pointer" onClick={() => handleViewConversation(conv)}>
                    <div className="flex items-start justify-between">
                      <div className="flex items-start gap-4">
                        <div className="p-2 bg-white rounded-lg">
                          <MessageSquare className="h-5 w-5 text-primary" />
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="flex items-center gap-1 text-sm font-medium text-emerald-600">
                              <Shield className="h-3.5 w-3.5" />
                              {conv.guardName}
                            </span>
                            <span className="text-slate-400">↔</span>
                            <span className="flex items-center gap-1 text-sm font-medium text-blue-600">
                              <User className="h-3.5 w-3.5" />
                              {conv.customerName}
                            </span>
                          </div>
                          <p className="text-xs text-slate-500 mt-0.5">{conv.jobTitle}</p>
                          <p className="text-sm text-slate-600 mt-2 line-clamp-1">
                            <span className="text-slate-400">
                              {conv.lastMessage.sender === "guard" ? (locale === "th" ? "รปภ: " : "Guard: ") : (locale === "th" ? "ลูกค้า: " : "Customer: ")}
                            </span>
                            {conv.lastMessage.message}
                          </p>
                        </div>
                      </div>
                      <div className="flex flex-col items-end gap-2">
                        <span className="text-xs text-slate-400">{conv.lastMessage.timestamp.split(" ")[1]}</span>
                        <span className="px-2 py-0.5 bg-slate-200 text-slate-600 text-xs rounded-full">
                          {conv.messages.length} {locale === "th" ? "ข้อความ" : "messages"}
                        </span>
                        {conv.messages.some(m => !m.read) && (
                          <span className="w-2 h-2 bg-amber-500 rounded-full"></span>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              {conversations.length === 0 && (
                <div className="py-12 text-center">
                  <MessageSquare className="h-12 w-12 text-slate-300 mx-auto mb-3" />
                  <p className="text-slate-500">{locale === "th" ? "ไม่พบการสนทนา" : "No conversations found"}</p>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Chat Detail Modal */}
      {chatDetailOpen && selectedConversation && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-2xl shadow-2xl max-h-[80vh] flex flex-col">
            {/* Header */}
            <div className="flex items-center justify-between p-5 border-b border-slate-200">
              <div>
                <h2 className="text-lg font-bold text-slate-900">
                  {locale === "th" ? "รายละเอียดการสนทนา" : "Conversation Details"}
                </h2>
                <p className="text-sm text-slate-500">{selectedConversation.jobTitle}</p>
              </div>
              <button
                onClick={() => setChatDetailOpen(false)}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X className="h-5 w-5 text-slate-400" />
              </button>
            </div>

            {/* Participants */}
            <div className="px-5 py-3 bg-slate-50 border-b border-slate-200 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="flex items-center gap-1 text-sm font-medium text-emerald-600">
                  <Shield className="h-4 w-4" />
                  {selectedConversation.guardName}
                </div>
                <span className="text-slate-400">↔</span>
                <div className="flex items-center gap-1 text-sm font-medium text-blue-600">
                  <User className="h-4 w-4" />
                  {selectedConversation.customerName}
                </div>
              </div>
              <span className="text-xs text-slate-500">
                {selectedConversation.messages.length} {locale === "th" ? "ข้อความ" : "messages"}
              </span>
            </div>

            {/* Messages */}
            <div className="flex-1 overflow-y-auto p-5 space-y-4">
              {selectedConversation.messages.sort((a, b) => new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()).map((msg) => (
                <div key={msg.id} className={cn("flex", msg.sender === "guard" ? "justify-start" : "justify-end")}>
                  <div className={cn(
                    "max-w-[70%] p-3 rounded-2xl",
                    msg.sender === "guard"
                      ? "bg-emerald-100 text-emerald-900 rounded-tl-sm"
                      : "bg-blue-100 text-blue-900 rounded-tr-sm"
                  )}>
                    <p className="text-sm">{msg.message}</p>
                    <p className={cn(
                      "text-xs mt-1",
                      msg.sender === "guard" ? "text-emerald-600" : "text-blue-600"
                    )}>
                      {msg.timestamp}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
