"use client";

import { useState } from "react";
import {
  ShieldCheck,
  Plus,
  Zap,
  Clock,
  Bell,
  Mail,
  MessageSquare,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  ChevronRight,
  MoreHorizontal,
  Play,
  Pause,
  Settings,
  ArrowRight,
  User,
  MapPin,
  Calendar,
} from "lucide-react";
import { cn } from "@/lib/utils";

type RuleStatus = "active" | "paused" | "draft";
type TriggerType = "time" | "event" | "condition";
type ActionType = "notification" | "email" | "sms" | "task" | "alert";

interface AutomationRule {
  id: string;
  name: string;
  description: string;
  status: RuleStatus;
  trigger: {
    type: TriggerType;
    condition: string;
  };
  action: {
    type: ActionType;
    target: string;
  };
  lastTriggered?: string;
  triggerCount: number;
}

const automationRules: AutomationRule[] = [
  {
    id: "R001",
    name: "Missed Check-in Alert",
    description: "Alert supervisor when a guard misses scheduled check-in",
    status: "active",
    trigger: { type: "event", condition: "Guard misses check-in by 15 minutes" },
    action: { type: "notification", target: "Assigned Supervisor" },
    lastTriggered: "2 hours ago",
    triggerCount: 45,
  },
  {
    id: "R002",
    name: "Shift Reminder",
    description: "Send reminder 1 hour before shift starts",
    status: "active",
    trigger: { type: "time", condition: "1 hour before scheduled shift" },
    action: { type: "sms", target: "Assigned Guard" },
    lastTriggered: "30 minutes ago",
    triggerCount: 312,
  },
  {
    id: "R003",
    name: "Overtime Warning",
    description: "Alert HR when guard exceeds 10 hours in shift",
    status: "active",
    trigger: { type: "condition", condition: "Shift duration exceeds 10 hours" },
    action: { type: "email", target: "HR Department" },
    lastTriggered: "Yesterday",
    triggerCount: 18,
  },
  {
    id: "R004",
    name: "Emergency Response",
    description: "Notify all nearby guards when emergency button pressed",
    status: "active",
    trigger: { type: "event", condition: "Emergency button activated" },
    action: { type: "alert", target: "Guards within 500m radius" },
    lastTriggered: "3 days ago",
    triggerCount: 5,
  },
  {
    id: "R005",
    name: "Daily Report Generation",
    description: "Auto-generate and send daily activity report",
    status: "paused",
    trigger: { type: "time", condition: "Every day at 23:00" },
    action: { type: "email", target: "Management Team" },
    lastTriggered: "1 week ago",
    triggerCount: 89,
  },
  {
    id: "R006",
    name: "New Incident Task",
    description: "Create follow-up task when incident is reported",
    status: "active",
    trigger: { type: "event", condition: "New incident report submitted" },
    action: { type: "task", target: "Site Manager" },
    lastTriggered: "5 hours ago",
    triggerCount: 67,
  },
  {
    id: "R007",
    name: "Contract Expiry Notice",
    description: "Alert admin 30 days before client contract expires",
    status: "draft",
    trigger: { type: "condition", condition: "Contract expires in 30 days" },
    action: { type: "notification", target: "Account Manager" },
    triggerCount: 0,
  },
];

const statusConfig: Record<RuleStatus, { label: string; color: string; bg: string; icon: typeof CheckCircle2 }> = {
  active: { label: "Active", color: "text-emerald-700", bg: "bg-emerald-50", icon: CheckCircle2 },
  paused: { label: "Paused", color: "text-amber-700", bg: "bg-amber-50", icon: Pause },
  draft: { label: "Draft", color: "text-slate-600", bg: "bg-slate-100", icon: Settings },
};

const triggerConfig: Record<TriggerType, { label: string; icon: typeof Clock; color: string }> = {
  time: { label: "Time-based", icon: Clock, color: "text-blue-600" },
  event: { label: "Event-based", icon: Zap, color: "text-purple-600" },
  condition: { label: "Condition-based", icon: AlertTriangle, color: "text-amber-600" },
};

const actionConfig: Record<ActionType, { label: string; icon: typeof Bell; color: string }> = {
  notification: { label: "Push Notification", icon: Bell, color: "text-blue-600" },
  email: { label: "Email", icon: Mail, color: "text-emerald-600" },
  sms: { label: "SMS", icon: MessageSquare, color: "text-purple-600" },
  task: { label: "Create Task", icon: CheckCircle2, color: "text-amber-600" },
  alert: { label: "Emergency Alert", icon: AlertTriangle, color: "text-red-600" },
};

export default function AutomationPage() {
  const [statusFilter, setStatusFilter] = useState<RuleStatus | "all">("all");
  const [selectedRule, setSelectedRule] = useState<AutomationRule | null>(null);

  const filteredRules = automationRules.filter(
    (rule) => statusFilter === "all" || rule.status === statusFilter
  );

  const stats = {
    total: automationRules.length,
    active: automationRules.filter((r) => r.status === "active").length,
    paused: automationRules.filter((r) => r.status === "paused").length,
    draft: automationRules.filter((r) => r.status === "draft").length,
    totalTriggers: automationRules.reduce((acc, r) => acc + r.triggerCount, 0),
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Automation Rules</h1>
          <p className="text-slate-500 mt-1">Configure if-then logic for automated responses</p>
        </div>
        <button className="inline-flex items-center px-4 py-2 bg-primary text-white rounded-lg font-medium text-sm hover:bg-emerald-600 transition-colors shadow-sm">
          <Plus className="h-4 w-4 mr-2" />
          Create Rule
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-4">
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-slate-100 rounded-lg">
              <ShieldCheck className="h-5 w-5 text-slate-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.total}</p>
              <p className="text-sm text-slate-500">Total Rules</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-emerald-50 rounded-lg">
              <Play className="h-5 w-5 text-emerald-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.active}</p>
              <p className="text-sm text-slate-500">Active</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-amber-50 rounded-lg">
              <Pause className="h-5 w-5 text-amber-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.paused}</p>
              <p className="text-sm text-slate-500">Paused</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-slate-100 rounded-lg">
              <Settings className="h-5 w-5 text-slate-500" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.draft}</p>
              <p className="text-sm text-slate-500">Drafts</p>
            </div>
          </div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-purple-50 rounded-lg">
              <Zap className="h-5 w-5 text-purple-600" />
            </div>
            <div>
              <p className="text-2xl font-bold text-slate-900">{stats.totalTriggers}</p>
              <p className="text-sm text-slate-500">Total Triggers</p>
            </div>
          </div>
        </div>
      </div>

      {/* Filter */}
      <div className="bg-white rounded-xl border border-slate-200 p-4">
        <div className="flex items-center gap-2">
          <span className="text-sm text-slate-500">Status:</span>
          {(["all", "active", "paused", "draft"] as const).map((status) => (
            <button
              key={status}
              onClick={() => setStatusFilter(status)}
              className={cn(
                "px-3 py-1.5 rounded-lg text-sm font-medium capitalize transition-colors",
                statusFilter === status
                  ? "bg-primary text-white"
                  : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              )}
            >
              {status}
            </button>
          ))}
        </div>
      </div>

      {/* Rules List */}
      <div className="space-y-4">
        {filteredRules.map((rule) => {
          const status = statusConfig[rule.status];
          const trigger = triggerConfig[rule.trigger.type];
          const action = actionConfig[rule.action.type];

          return (
            <div
              key={rule.id}
              className="bg-white rounded-xl border border-slate-200 p-5 hover:shadow-md transition-shadow"
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <h3 className="text-base font-semibold text-slate-900">{rule.name}</h3>
                    <span className={cn("inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium", status.bg, status.color)}>
                      <status.icon className="h-3 w-3 mr-1" />
                      {status.label}
                    </span>
                  </div>
                  <p className="text-sm text-slate-500 mb-4">{rule.description}</p>

                  {/* If-Then Display */}
                  <div className="flex items-center gap-3 p-4 bg-slate-50 rounded-lg">
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-1">
                        <span className="text-xs font-semibold text-slate-500 uppercase">If</span>
                        <div className={cn("p-1 rounded", trigger.color.replace("text", "bg").replace("600", "100"))}>
                          <trigger.icon className={cn("h-3 w-3", trigger.color)} />
                        </div>
                        <span className="text-xs text-slate-400">{trigger.label}</span>
                      </div>
                      <p className="text-sm font-medium text-slate-700">{rule.trigger.condition}</p>
                    </div>

                    <ArrowRight className="h-5 w-5 text-slate-300 flex-shrink-0" />

                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-1">
                        <span className="text-xs font-semibold text-slate-500 uppercase">Then</span>
                        <div className={cn("p-1 rounded", action.color.replace("text", "bg").replace("600", "100"))}>
                          <action.icon className={cn("h-3 w-3", action.color)} />
                        </div>
                        <span className="text-xs text-slate-400">{action.label}</span>
                      </div>
                      <p className="text-sm font-medium text-slate-700">{rule.action.target}</p>
                    </div>
                  </div>

                  {/* Stats */}
                  <div className="flex items-center gap-6 mt-4 text-sm text-slate-500">
                    <div className="flex items-center gap-1">
                      <Zap className="h-4 w-4 text-slate-400" />
                      <span>{rule.triggerCount} triggers</span>
                    </div>
                    {rule.lastTriggered && (
                      <div className="flex items-center gap-1">
                        <Clock className="h-4 w-4 text-slate-400" />
                        <span>Last: {rule.lastTriggered}</span>
                      </div>
                    )}
                  </div>
                </div>

                <div className="flex items-center gap-2 ml-4">
                  {rule.status === "active" ? (
                    <button className="p-2 hover:bg-amber-50 rounded-lg transition-colors group">
                      <Pause className="h-4 w-4 text-slate-400 group-hover:text-amber-600" />
                    </button>
                  ) : rule.status === "paused" ? (
                    <button className="p-2 hover:bg-emerald-50 rounded-lg transition-colors group">
                      <Play className="h-4 w-4 text-slate-400 group-hover:text-emerald-600" />
                    </button>
                  ) : null}
                  <button className="p-2 hover:bg-slate-100 rounded-lg transition-colors">
                    <Settings className="h-4 w-4 text-slate-400" />
                  </button>
                  <button className="p-2 hover:bg-slate-100 rounded-lg transition-colors">
                    <MoreHorizontal className="h-4 w-4 text-slate-400" />
                  </button>
                </div>
              </div>
            </div>
          );
        })}

        {filteredRules.length === 0 && (
          <div className="bg-white rounded-xl border border-slate-200 py-12 text-center">
            <ShieldCheck className="h-12 w-12 text-slate-300 mx-auto mb-4" />
            <p className="text-slate-500 font-medium">No automation rules found</p>
            <p className="text-slate-400 text-sm mt-1">Create your first rule to get started</p>
          </div>
        )}
      </div>
    </div>
  );
}
