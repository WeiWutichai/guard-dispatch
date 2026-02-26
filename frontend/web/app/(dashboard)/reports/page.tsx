"use client";

import { useState } from "react";
import {
  FileText,
  Download,
  Calendar,
  TrendingUp,
  TrendingDown,
  Users,
  Briefcase,
  AlertTriangle,
  DollarSign,
  Clock,
  CheckCircle2,
  BarChart3,
  PieChart,
  ArrowUpRight,
  ArrowDownRight,
  Filter,
} from "lucide-react";
import { cn } from "@/lib/utils";

type ReportPeriod = "week" | "month" | "quarter" | "year";
type ReportType = "overview" | "personnel" | "incidents" | "appeals";

interface MetricCard {
  title: string;
  value: string;
  change: number;
  icon: typeof Users;
  color: string;
  bg: string;
}

const metrics: MetricCard[] = [
  { title: "Total Revenue", value: "฿1,680,000", change: 12.5, icon: DollarSign, color: "text-emerald-600", bg: "bg-emerald-50" },
  { title: "Active Guards", value: "124", change: 8.2, icon: Users, color: "text-blue-600", bg: "bg-blue-50" },
  { title: "Tasks Completed", value: "2,847", change: 15.3, icon: CheckCircle2, color: "text-purple-600", bg: "bg-purple-50" },
  { title: "Incident Reports", value: "23", change: -18.5, icon: AlertTriangle, color: "text-amber-600", bg: "bg-amber-50" },
];

const weeklyData = [
  { day: "Mon", tasks: 45, incidents: 2 },
  { day: "Tue", tasks: 52, incidents: 1 },
  { day: "Wed", tasks: 48, incidents: 3 },
  { day: "Thu", tasks: 61, incidents: 0 },
  { day: "Fri", tasks: 55, incidents: 2 },
  { day: "Sat", tasks: 38, incidents: 1 },
  { day: "Sun", tasks: 32, incidents: 0 },
];

const sitePerformance = [
  { name: "Central Plaza", tasks: 156, completion: 94, revenue: "฿280,000" },
  { name: "Siam Paragon", tasks: 142, completion: 97, revenue: "฿320,000" },
  { name: "ICONSIAM", tasks: 189, completion: 91, revenue: "฿410,000" },
  { name: "EmQuartier", tasks: 98, completion: 95, revenue: "฿180,000" },
  { name: "Terminal 21", tasks: 124, completion: 88, revenue: "฿220,000" },
];

const appealsSummary = [
  { type: "Attendance", count: 8, approved: 5, rejected: 3 },
  { type: "Conduct", count: 5, approved: 2, rejected: 3 },
  { type: "Performance", count: 3, approved: 2, rejected: 1 },
  { type: "Schedule", count: 12, approved: 10, rejected: 2 },
];

export default function ReportsPage() {
  const [period, setPeriod] = useState<ReportPeriod>("month");
  const [reportType, setReportType] = useState<ReportType>("overview");

  const maxTasks = Math.max(...weeklyData.map((d) => d.tasks));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Reports & Analytics</h1>
          <p className="text-slate-500 mt-1">Insights and performance metrics across operations</p>
        </div>
        <button className="inline-flex items-center px-4 py-2 bg-primary text-white rounded-lg font-medium text-sm hover:bg-emerald-600 transition-colors shadow-sm">
          <Download className="h-4 w-4 mr-2" />
          Export Report
        </button>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl border border-slate-200 p-4">
        <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="text-sm text-slate-500">Report Type:</span>
            {(["overview", "personnel", "incidents", "appeals"] as const).map((type) => (
              <button
                key={type}
                onClick={() => setReportType(type)}
                className={cn(
                  "px-3 py-1.5 rounded-lg text-sm font-medium capitalize transition-colors",
                  reportType === type
                    ? "bg-primary text-white"
                    : "bg-slate-100 text-slate-600 hover:bg-slate-200"
                )}
              >
                {type}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-2">
            <Calendar className="h-4 w-4 text-slate-400" />
            <span className="text-sm text-slate-500">Period:</span>
            {(["week", "month", "quarter", "year"] as const).map((p) => (
              <button
                key={p}
                onClick={() => setPeriod(p)}
                className={cn(
                  "px-3 py-1.5 rounded-lg text-sm font-medium capitalize transition-colors",
                  period === p
                    ? "bg-slate-900 text-white"
                    : "bg-slate-100 text-slate-600 hover:bg-slate-200"
                )}
              >
                {p}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Metrics Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {metrics.map((metric) => (
          <div key={metric.title} className="bg-white p-5 rounded-xl border border-slate-200">
            <div className="flex items-start justify-between">
              <div className={cn("p-2 rounded-lg", metric.bg)}>
                <metric.icon className={cn("h-5 w-5", metric.color)} />
              </div>
              <div className={cn(
                "flex items-center text-xs font-medium px-2 py-1 rounded-full",
                metric.change >= 0 ? "bg-emerald-50 text-emerald-600" : "bg-red-50 text-red-600"
              )}>
                {metric.change >= 0 ? (
                  <ArrowUpRight className="h-3 w-3 mr-0.5" />
                ) : (
                  <ArrowDownRight className="h-3 w-3 mr-0.5" />
                )}
                {Math.abs(metric.change)}%
              </div>
            </div>
            <p className="text-2xl font-bold text-slate-900 mt-3">{metric.value}</p>
            <p className="text-sm text-slate-500 mt-1">{metric.title}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Weekly Performance Chart */}
        <div className="lg:col-span-2 bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div className="p-5 border-b border-slate-200 flex items-center justify-between">
            <div>
              <h2 className="text-lg font-semibold text-slate-900">Weekly Performance</h2>
              <p className="text-sm text-slate-500 mt-0.5">Tasks completed vs incidents reported</p>
            </div>
            <div className="flex items-center gap-4 text-sm">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-emerald-500" />
                <span className="text-slate-600">Tasks</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-red-400" />
                <span className="text-slate-600">Incidents</span>
              </div>
            </div>
          </div>
          <div className="p-5">
            <div className="flex items-end justify-between gap-2 h-48">
              {weeklyData.map((data) => (
                <div key={data.day} className="flex-1 flex flex-col items-center gap-2">
                  <div className="w-full flex flex-col items-center gap-1 flex-1 justify-end">
                    <div
                      className="w-full max-w-[40px] bg-emerald-500 rounded-t transition-all"
                      style={{ height: `${(data.tasks / maxTasks) * 100}%` }}
                    />
                    {data.incidents > 0 && (
                      <div className="absolute -mt-2 w-5 h-5 bg-red-400 rounded-full flex items-center justify-center text-white text-xs font-medium">
                        {data.incidents}
                      </div>
                    )}
                  </div>
                  <span className="text-xs text-slate-500 font-medium">{data.day}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Monthly Appeal Summary */}
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <div className="p-5 border-b border-slate-200">
            <h2 className="text-lg font-semibold text-slate-900">Appeal Summary</h2>
            <p className="text-sm text-slate-500 mt-0.5">Monthly disciplinary appeals</p>
          </div>
          <div className="p-4 space-y-3">
            {appealsSummary.map((appeal) => (
              <div key={appeal.type} className="p-3 bg-slate-50 rounded-lg">
                <div className="flex items-center justify-between mb-2">
                  <span className="font-medium text-slate-900 text-sm">{appeal.type}</span>
                  <span className="text-xs text-slate-500">{appeal.count} total</span>
                </div>
                <div className="flex gap-1 h-2 rounded-full overflow-hidden bg-slate-200">
                  <div
                    className="bg-emerald-500 transition-all"
                    style={{ width: `${(appeal.approved / appeal.count) * 100}%` }}
                  />
                  <div
                    className="bg-red-400 transition-all"
                    style={{ width: `${(appeal.rejected / appeal.count) * 100}%` }}
                  />
                </div>
                <div className="flex justify-between mt-2 text-xs">
                  <span className="text-emerald-600">{appeal.approved} approved</span>
                  <span className="text-red-500">{appeal.rejected} rejected</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Site Performance Table */}
      <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
        <div className="p-5 border-b border-slate-200 flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold text-slate-900">Site Performance</h2>
            <p className="text-sm text-slate-500 mt-0.5">Performance breakdown by location</p>
          </div>
          <button className="text-sm text-primary font-medium hover:underline">
            View All Sites
          </button>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-slate-50">
                <th className="text-left py-3 px-5 text-xs font-semibold text-slate-500 uppercase">Site</th>
                <th className="text-left py-3 px-5 text-xs font-semibold text-slate-500 uppercase">Tasks</th>
                <th className="text-left py-3 px-5 text-xs font-semibold text-slate-500 uppercase">Completion Rate</th>
                <th className="text-right py-3 px-5 text-xs font-semibold text-slate-500 uppercase">Revenue</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {sitePerformance.map((site) => (
                <tr key={site.name} className="hover:bg-slate-50 transition-colors">
                  <td className="py-4 px-5">
                    <p className="font-medium text-slate-900">{site.name}</p>
                  </td>
                  <td className="py-4 px-5">
                    <div className="flex items-center gap-2">
                      <Briefcase className="h-4 w-4 text-slate-400" />
                      <span className="text-slate-600">{site.tasks}</span>
                    </div>
                  </td>
                  <td className="py-4 px-5">
                    <div className="flex items-center gap-3">
                      <div className="flex-1 max-w-[100px] h-2 bg-slate-100 rounded-full overflow-hidden">
                        <div
                          className={cn(
                            "h-full rounded-full transition-all",
                            site.completion >= 95 ? "bg-emerald-500" : site.completion >= 90 ? "bg-amber-500" : "bg-red-500"
                          )}
                          style={{ width: `${site.completion}%` }}
                        />
                      </div>
                      <span className={cn(
                        "text-sm font-medium",
                        site.completion >= 95 ? "text-emerald-600" : site.completion >= 90 ? "text-amber-600" : "text-red-600"
                      )}>
                        {site.completion}%
                      </span>
                    </div>
                  </td>
                  <td className="py-4 px-5 text-right">
                    <span className="font-semibold text-slate-900">{site.revenue}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
