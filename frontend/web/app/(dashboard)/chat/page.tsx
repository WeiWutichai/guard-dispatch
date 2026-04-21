"use client";

import { useCallback, useEffect, useState } from "react";
import {
  MessageSquare,
  Search,
  Shield,
  User as UserIcon,
  Loader2,
  AlertCircle,
  X,
  Paperclip,
  ChevronLeft,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/components/LanguageProvider";
import {
  chatModerationApi,
  type AdminConversationItem,
  type ChatMessage,
} from "@/lib/api";

function formatDateTime(iso: string | null): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleString([], {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function requestStatusTone(status: string | null): { bg: string; text: string } {
  switch (status) {
    case "completed":
      return { bg: "bg-emerald-50", text: "text-emerald-700" };
    case "cancelled":
      return { bg: "bg-red-50", text: "text-red-700" };
    case "in_progress":
    case "assigned":
      return { bg: "bg-blue-50", text: "text-blue-700" };
    case "pending":
      return { bg: "bg-slate-100", text: "text-slate-600" };
    default:
      return { bg: "bg-slate-100", text: "text-slate-500" };
  }
}

export default function ChatModerationPage() {
  const { locale } = useLanguage();
  const isThai = locale === "th";

  const [items, setItems] = useState<AdminConversationItem[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [searchInput, setSearchInput] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");

  const [selected, setSelected] = useState<AdminConversationItem | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [messagesLoading, setMessagesLoading] = useState(false);
  const [messagesError, setMessagesError] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  useEffect(() => {
    const h = setTimeout(() => setDebouncedSearch(searchInput.trim()), 300);
    return () => clearTimeout(h);
  }, [searchInput]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const page = await chatModerationApi.listConversations({
        search: debouncedSearch || undefined,
        limit: 100,
      });
      setItems(page.data);
      setTotal(page.total);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, [debouncedSearch]);

  useEffect(() => {
    load();
  }, [load]);

  const openConversation = useCallback(async (c: AdminConversationItem) => {
    setSelected(c);
    setMessages([]);
    setMessagesError(null);
    setMessagesLoading(true);
    try {
      const list = await chatModerationApi.listMessages(c.id, { limit: 200 });
      // Server returns newest-first — flip so chat-like display reads top-to-bottom oldest-to-newest.
      setMessages([...list].reverse());
    } catch (e) {
      setMessagesError(e instanceof Error ? e.message : String(e));
    } finally {
      setMessagesLoading(false);
    }
  }, []);

  const closeConversation = useCallback(() => {
    setSelected(null);
    setMessages([]);
    setMessagesError(null);
    setPreviewUrl(null);
  }, []);

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <header className="mb-6">
        <div className="flex items-center gap-3 mb-1">
          <div className="p-2 bg-indigo-50 rounded-lg">
            <MessageSquare className="h-5 w-5 text-indigo-600" />
          </div>
          <h1 className="text-2xl font-bold text-slate-900">
            {isThai ? "ตรวจสอบแชท" : "Chat Moderation"}
          </h1>
        </div>
        <p className="text-sm text-slate-500 ml-11">
          {isThai
            ? "อ่านบทสนทนาระหว่างลูกค้าและเจ้าหน้าที่ — ใช้สำหรับตรวจสอบข้อพิพาทและคำร้องขอเข้าถึงข้อมูลส่วนบุคคล"
            : "Read customer ↔ guard conversations — for dispute resolution and PDPA subject-access requests."}
        </p>
      </header>

      <div className="bg-white rounded-xl border border-slate-200 p-4 mb-4">
        <div className="flex gap-3 items-center flex-wrap">
          <div className="relative flex-1 min-w-[240px]">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400 pointer-events-none" />
            <input
              type="text"
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
              placeholder={isThai ? "ค้นหาชื่อลูกค้าหรือเจ้าหน้าที่" : "Search customer or guard name"}
              className="w-full pl-9 pr-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-200 focus:border-indigo-400"
            />
          </div>
          <div className="text-sm text-slate-500">
            {isThai ? "ทั้งหมด" : "Total"}:{" "}
            <span className="ml-1.5 font-semibold text-slate-900">{total}</span>
          </div>
        </div>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm mb-4">
          <div className="flex items-start gap-2">
            <AlertCircle className="h-4 w-4 mt-0.5 flex-shrink-0" />
            <div className="flex-1">
              {error}
              <button onClick={load} className="ml-3 underline hover:no-underline">
                {isThai ? "ลองใหม่" : "Retry"}
              </button>
            </div>
          </div>
        </div>
      )}

      {loading && items.length === 0 && (
        <div className="p-12 flex justify-center">
          <Loader2 className="h-6 w-6 animate-spin text-indigo-600" />
        </div>
      )}

      {!loading && items.length === 0 && !error && (
        <div className="p-12 bg-white rounded-xl border border-slate-200 text-center text-slate-500">
          <MessageSquare className="h-10 w-10 mx-auto mb-3 text-slate-300" />
          <p className="font-medium">
            {isThai ? "ไม่พบบทสนทนา" : "No conversations"}
          </p>
        </div>
      )}

      {items.length > 0 && (
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-slate-50">
                <tr className="border-b border-slate-200">
                  <Th>{isThai ? "ลูกค้า" : "Customer"}</Th>
                  <Th>{isThai ? "เจ้าหน้าที่" : "Guard"}</Th>
                  <Th>{isThai ? "สถานะงาน" : "Job Status"}</Th>
                  <Th className="text-center">{isThai ? "ข้อความ" : "Msgs"}</Th>
                  <Th>{isThai ? "ล่าสุด" : "Last"}</Th>
                  <Th>{isThai ? "ข้อความล่าสุด" : "Preview"}</Th>
                </tr>
              </thead>
              <tbody>
                {items.map((c) => {
                  const tone = requestStatusTone(c.request_status);
                  return (
                    <tr
                      key={c.id}
                      onClick={() => openConversation(c)}
                      className="border-b border-slate-100 hover:bg-slate-50 cursor-pointer"
                    >
                      <Td>
                        <div className="font-medium text-slate-900">
                          {c.customer_name ?? (
                            <span className="italic text-slate-400">—</span>
                          )}
                        </div>
                      </Td>
                      <Td>
                        <div className="font-medium text-slate-900">
                          {c.guard_name ?? (
                            <span className="italic text-slate-400">—</span>
                          )}
                        </div>
                      </Td>
                      <Td>
                        {c.request_status && (
                          <span
                            className={cn(
                              "inline-flex px-2 py-0.5 rounded-full text-xs font-semibold",
                              tone.bg,
                              tone.text
                            )}
                          >
                            {c.request_status}
                          </span>
                        )}
                      </Td>
                      <Td className="text-center">
                        <span className="inline-flex items-center gap-1 text-sm font-semibold text-slate-700">
                          {c.message_count}
                          {c.has_attachments && (
                            <Paperclip className="h-3 w-3 text-slate-400" />
                          )}
                        </span>
                      </Td>
                      <Td className="whitespace-nowrap text-xs font-mono text-slate-600">
                        {formatDateTime(c.last_message_at)}
                      </Td>
                      <Td className="max-w-[280px]">
                        <span className="text-sm text-slate-500 line-clamp-1">
                          {c.last_message ?? (
                            <span className="italic text-slate-400">
                              {isThai ? "ยังไม่มีข้อความ" : "no messages"}
                            </span>
                          )}
                        </span>
                      </Td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Messages drawer — opens on row click */}
      {selected && (
        <>
          <div
            onClick={closeConversation}
            className="fixed inset-0 bg-black/40 z-40 animate-in fade-in"
          />
          <aside className="fixed right-0 top-0 bottom-0 w-full max-w-2xl bg-white z-50 flex flex-col shadow-2xl animate-in slide-in-from-right">
            <div className="px-6 py-4 border-b border-slate-200 flex items-center justify-between sticky top-0 bg-white z-10">
              <div className="flex items-center gap-3 min-w-0">
                <button
                  onClick={closeConversation}
                  className="p-1.5 hover:bg-slate-100 rounded-lg transition-colors md:hidden"
                  title={isThai ? "กลับ" : "Back"}
                >
                  <ChevronLeft className="h-5 w-5 text-slate-500" />
                </button>
                <div className="min-w-0">
                  <h2 className="text-lg font-bold text-slate-900 truncate">
                    {selected.customer_name ?? "—"}
                    <span className="text-slate-400 mx-2">↔</span>
                    {selected.guard_name ?? "—"}
                  </h2>
                  <p className="text-xs text-slate-500 truncate">
                    {isThai ? "บทสนทนา" : "Conversation"} ·{" "}
                    <span className="font-mono">{selected.id.slice(0, 8)}…</span>
                  </p>
                </div>
              </div>
              <button
                onClick={closeConversation}
                className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
              >
                <X className="h-5 w-5 text-slate-500" />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-4 bg-slate-50">
              {messagesError && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-start gap-2">
                  <AlertCircle className="h-4 w-4 mt-0.5 flex-shrink-0" />
                  <span>{messagesError}</span>
                </div>
              )}

              {messagesLoading ? (
                <div className="flex items-center justify-center py-12">
                  <Loader2 className="h-6 w-6 animate-spin text-indigo-600" />
                </div>
              ) : messages.length === 0 && !messagesError ? (
                <div className="py-12 text-center text-sm text-slate-500">
                  {isThai ? "ยังไม่มีข้อความ" : "No messages yet"}
                </div>
              ) : (
                <ul className="space-y-3">
                  {messages.map((m) => {
                    const isGuard = m.sender_role === "guard";
                    const isCustomer = m.sender_role === "customer";
                    const isSystem = m.message_type === "system";
                    if (isSystem) {
                      return (
                        <li key={m.id} className="flex justify-center">
                          <div className="text-xs text-slate-400 italic px-3 py-1 rounded-full bg-slate-100">
                            {m.content}
                          </div>
                        </li>
                      );
                    }
                    return (
                      <li
                        key={m.id}
                        className={cn(
                          "flex gap-2",
                          isGuard && "justify-start",
                          isCustomer && "justify-end"
                        )}
                      >
                        {isGuard && (
                          <div className="w-8 h-8 rounded-full bg-amber-100 text-amber-700 flex items-center justify-center flex-shrink-0">
                            <Shield className="h-4 w-4" />
                          </div>
                        )}
                        <div
                          className={cn(
                            "max-w-[70%] rounded-2xl px-4 py-2 shadow-sm",
                            isGuard && "bg-white border border-slate-200",
                            isCustomer && "bg-blue-600 text-white",
                            !isGuard && !isCustomer && "bg-slate-200 text-slate-600"
                          )}
                        >
                          {m.content && (
                            <p className="text-sm whitespace-pre-wrap break-words">
                              {m.content}
                            </p>
                          )}
                          {m.file_url && (
                            <button
                              type="button"
                              onClick={() => setPreviewUrl(m.file_url!)}
                              className="mt-2 block rounded-lg overflow-hidden border border-white/30 hover:opacity-90"
                            >
                              {/* eslint-disable-next-line @next/next/no-img-element */}
                              <img
                                src={m.file_url}
                                alt="attachment"
                                className="max-w-[240px] max-h-[240px] object-cover"
                              />
                            </button>
                          )}
                          <p
                            className={cn(
                              "text-[10px] mt-1 font-mono",
                              isCustomer ? "text-blue-100" : "text-slate-400"
                            )}
                          >
                            {formatDateTime(m.created_at)}
                            {m.sender_role && (
                              <span className="ml-1 uppercase">
                                · {m.sender_role}
                              </span>
                            )}
                          </p>
                        </div>
                        {isCustomer && (
                          <div className="w-8 h-8 rounded-full bg-blue-100 text-blue-700 flex items-center justify-center flex-shrink-0">
                            <UserIcon className="h-4 w-4" />
                          </div>
                        )}
                      </li>
                    );
                  })}
                </ul>
              )}
            </div>

            <div className="px-6 py-3 border-t border-slate-200 bg-white text-xs text-slate-400 flex items-center gap-2">
              <Shield className="h-3.5 w-3.5" />
              {isThai
                ? "อ่านอย่างเดียว — ผู้ดูแลระบบไม่สามารถส่งหรือแก้ไขข้อความได้"
                : "Read-only — admins cannot post or edit messages"}
            </div>
          </aside>
        </>
      )}

      {previewUrl && (
        <div
          className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4"
          onClick={() => setPreviewUrl(null)}
        >
          <div
            className="relative max-w-4xl w-full flex flex-col items-center"
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => setPreviewUrl(null)}
              className="absolute top-2 right-2 p-2 bg-white/10 hover:bg-white/20 rounded-lg text-white backdrop-blur-sm"
            >
              <X className="h-5 w-5" />
            </button>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={previewUrl}
              alt="attachment"
              className="max-h-[90vh] rounded-lg object-contain"
            />
          </div>
        </div>
      )}
    </div>
  );
}

function Th(props: { children?: React.ReactNode; className?: string }) {
  return (
    <th
      className={cn(
        "py-3 px-4 text-xs font-semibold text-slate-500 uppercase text-left",
        props.className
      )}
    >
      {props.children}
    </th>
  );
}

function Td(props: { children?: React.ReactNode; className?: string }) {
  return (
    <td className={cn("py-3 px-4 text-sm text-slate-700", props.className)}>
      {props.children}
    </td>
  );
}
