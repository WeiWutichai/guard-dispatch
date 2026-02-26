"use client";

import { useState } from "react";
import {
  UserPlus,
  Search,
  Filter,
  Star,
  Phone,
  Mail,
  Calendar,
  ChevronRight,
  FileText,
  CheckCircle2,
  Clock,
  XCircle,
  User,
  MessageSquare,
  Brain,
  Lightbulb,
} from "lucide-react";
import { cn } from "@/lib/utils";

type PipelineStage = "applied" | "screening" | "interview" | "evaluation" | "offer" | "hired" | "rejected";

interface Candidate {
  id: string;
  name: string;
  email: string;
  phone: string;
  appliedDate: string;
  stage: PipelineStage;
  position: string;
  experience: string;
  scores?: {
    personality: number;
    communication: number;
    knowledge: number;
    problemSolving: number;
  };
}

const candidates: Candidate[] = [
  { id: "C001", name: "Prasit Chaiyasit", email: "prasit.c@email.com", phone: "+66 91 234 5678", appliedDate: "2024-01-10", stage: "interview", position: "Security Guard", experience: "3 years" },
  { id: "C002", name: "Surasak Meesuk", email: "surasak.m@email.com", phone: "+66 92 345 6789", appliedDate: "2024-01-08", stage: "evaluation", position: "Senior Guard", experience: "5 years", scores: { personality: 4, communication: 5, knowledge: 4, problemSolving: 3 } },
  { id: "C003", name: "Waraporn Sombat", email: "waraporn.s@email.com", phone: "+66 93 456 7890", appliedDate: "2024-01-12", stage: "screening", position: "Security Guard", experience: "1 year" },
  { id: "C004", name: "Chaiwat Ruangrit", email: "chaiwat.r@email.com", phone: "+66 94 567 8901", appliedDate: "2024-01-05", stage: "offer", position: "Team Lead", experience: "7 years", scores: { personality: 5, communication: 4, knowledge: 5, problemSolving: 5 } },
  { id: "C005", name: "Nattapong Klinhom", email: "nattapong.k@email.com", phone: "+66 95 678 9012", appliedDate: "2024-01-14", stage: "applied", position: "Security Guard", experience: "2 years" },
  { id: "C006", name: "Siriporn Thongsai", email: "siriporn.t@email.com", phone: "+66 96 789 0123", appliedDate: "2024-01-03", stage: "hired", position: "Security Guard", experience: "4 years", scores: { personality: 4, communication: 4, knowledge: 5, problemSolving: 4 } },
  { id: "C007", name: "Danai Phanphet", email: "danai.p@email.com", phone: "+66 97 890 1234", appliedDate: "2024-01-11", stage: "rejected", position: "Security Guard", experience: "6 months" },
  { id: "C008", name: "Kamolwan Saetang", email: "kamolwan.s@email.com", phone: "+66 98 901 2345", appliedDate: "2024-01-13", stage: "applied", position: "Night Guard", experience: "2 years" },
];

const stageConfig: Record<PipelineStage, { label: string; color: string; bg: string; icon: typeof Clock }> = {
  applied: { label: "Applied", color: "text-slate-600", bg: "bg-slate-100", icon: FileText },
  screening: { label: "Screening", color: "text-blue-600", bg: "bg-blue-50", icon: Search },
  interview: { label: "Interview", color: "text-purple-600", bg: "bg-purple-50", icon: MessageSquare },
  evaluation: { label: "Evaluation", color: "text-amber-600", bg: "bg-amber-50", icon: Star },
  offer: { label: "Offer", color: "text-emerald-600", bg: "bg-emerald-50", icon: FileText },
  hired: { label: "Hired", color: "text-emerald-700", bg: "bg-emerald-100", icon: CheckCircle2 },
  rejected: { label: "Rejected", color: "text-red-600", bg: "bg-red-50", icon: XCircle },
};

const pipelineStages: PipelineStage[] = ["applied", "screening", "interview", "evaluation", "offer", "hired"];

function StarRating({ rating, size = "sm" }: { rating: number; size?: "sm" | "md" }) {
  const sizeClass = size === "sm" ? "h-3 w-3" : "h-4 w-4";
  return (
    <div className="flex items-center gap-0.5">
      {[1, 2, 3, 4, 5].map((star) => (
        <Star
          key={star}
          className={cn(
            sizeClass,
            star <= rating ? "text-amber-400 fill-amber-400" : "text-slate-200"
          )}
        />
      ))}
    </div>
  );
}

export default function RecruitmentPage() {
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedCandidate, setSelectedCandidate] = useState<Candidate | null>(null);
  const [viewMode, setViewMode] = useState<"pipeline" | "list">("pipeline");

  const filteredCandidates = candidates.filter((candidate) =>
    candidate.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    candidate.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
    candidate.position.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const getCandidatesByStage = (stage: PipelineStage) =>
    filteredCandidates.filter((c) => c.stage === stage);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Recruitment Pipeline</h1>
          <p className="text-slate-500 mt-1">Track and manage candidate applications</p>
        </div>
        <button className="inline-flex items-center px-4 py-2 bg-primary text-white rounded-lg font-medium text-sm hover:bg-emerald-600 transition-colors shadow-sm">
          <UserPlus className="h-4 w-4 mr-2" />
          Add Candidate
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-3">
        {pipelineStages.map((stage) => {
          const config = stageConfig[stage];
          const count = getCandidatesByStage(stage).length;
          return (
            <div key={stage} className="bg-white p-3 rounded-xl border border-slate-200">
              <div className="flex items-center gap-2 mb-1">
                <config.icon className={cn("h-4 w-4", config.color)} />
                <span className="text-xs font-medium text-slate-500">{config.label}</span>
              </div>
              <p className="text-xl font-bold text-slate-900">{count}</p>
            </div>
          );
        })}
        <div className="bg-red-50 p-3 rounded-xl border border-red-100">
          <div className="flex items-center gap-2 mb-1">
            <XCircle className="h-4 w-4 text-red-600" />
            <span className="text-xs font-medium text-red-600">Rejected</span>
          </div>
          <p className="text-xl font-bold text-red-700">{getCandidatesByStage("rejected").length}</p>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white rounded-xl border border-slate-200 p-4">
        <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
          <div className="relative flex-1 max-w-md">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
            <input
              type="text"
              placeholder="Search candidates..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full bg-slate-50 border-none rounded-lg py-2 pl-10 pr-4 text-sm focus:ring-2 focus:ring-primary/20 focus:bg-white transition-all outline-none"
            />
          </div>
          <div className="flex items-center gap-2">
            <span className="text-sm text-slate-500">View:</span>
            <button
              onClick={() => setViewMode("pipeline")}
              className={cn(
                "px-3 py-1.5 rounded-lg text-sm font-medium transition-colors",
                viewMode === "pipeline" ? "bg-primary text-white" : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              )}
            >
              Pipeline
            </button>
            <button
              onClick={() => setViewMode("list")}
              className={cn(
                "px-3 py-1.5 rounded-lg text-sm font-medium transition-colors",
                viewMode === "list" ? "bg-primary text-white" : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              )}
            >
              List
            </button>
          </div>
        </div>
      </div>

      {viewMode === "pipeline" ? (
        /* Kanban Pipeline View */
        <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-4 overflow-x-auto pb-4">
          {pipelineStages.map((stage) => {
            const config = stageConfig[stage];
            const stageCandidates = getCandidatesByStage(stage);
            return (
              <div key={stage} className="min-w-[250px]">
                <div className={cn("px-3 py-2 rounded-t-lg", config.bg)}>
                  <div className="flex items-center justify-between">
                    <span className={cn("text-sm font-semibold", config.color)}>{config.label}</span>
                    <span className={cn("text-xs font-medium px-2 py-0.5 rounded-full bg-white", config.color)}>
                      {stageCandidates.length}
                    </span>
                  </div>
                </div>
                <div className="bg-slate-50 rounded-b-lg p-2 space-y-2 min-h-[300px]">
                  {stageCandidates.map((candidate) => (
                    <button
                      key={candidate.id}
                      onClick={() => setSelectedCandidate(candidate)}
                      className="w-full bg-white p-3 rounded-lg border border-slate-200 hover:shadow-md transition-all text-left"
                    >
                      <div className="flex items-start justify-between mb-2">
                        <div className="flex items-center gap-2">
                          <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                            <User className="h-4 w-4 text-primary" />
                          </div>
                          <div>
                            <p className="font-medium text-slate-900 text-sm">{candidate.name}</p>
                            <p className="text-xs text-slate-500">{candidate.position}</p>
                          </div>
                        </div>
                      </div>
                      {candidate.scores && (
                        <div className="mt-2 pt-2 border-t border-slate-100">
                          <div className="flex items-center justify-between">
                            <span className="text-xs text-slate-500">Avg Score</span>
                            <StarRating
                              rating={Math.round(
                                (candidate.scores.personality +
                                  candidate.scores.communication +
                                  candidate.scores.knowledge +
                                  candidate.scores.problemSolving) / 4
                              )}
                            />
                          </div>
                        </div>
                      )}
                      <div className="flex items-center gap-2 mt-2 text-xs text-slate-400">
                        <Calendar className="h-3 w-3" />
                        {candidate.appliedDate}
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        /* List View */
        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="bg-slate-50 border-b border-slate-200">
                <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase">Candidate</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase">Position</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase">Stage</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase">Applied</th>
                <th className="text-left py-3 px-4 text-xs font-semibold text-slate-500 uppercase">Evaluation</th>
                <th className="text-right py-3 px-4 text-xs font-semibold text-slate-500 uppercase">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredCandidates.map((candidate) => {
                const config = stageConfig[candidate.stage];
                return (
                  <tr key={candidate.id} className="hover:bg-slate-50 transition-colors">
                    <td className="py-4 px-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                          <User className="h-5 w-5 text-primary" />
                        </div>
                        <div>
                          <p className="font-medium text-slate-900">{candidate.name}</p>
                          <p className="text-sm text-slate-500">{candidate.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <p className="text-sm text-slate-900">{candidate.position}</p>
                      <p className="text-xs text-slate-500">{candidate.experience}</p>
                    </td>
                    <td className="py-4 px-4">
                      <span className={cn("inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium", config.bg, config.color)}>
                        <config.icon className="h-3 w-3 mr-1" />
                        {config.label}
                      </span>
                    </td>
                    <td className="py-4 px-4 text-sm text-slate-600">{candidate.appliedDate}</td>
                    <td className="py-4 px-4">
                      {candidate.scores ? (
                        <StarRating
                          rating={Math.round(
                            (candidate.scores.personality +
                              candidate.scores.communication +
                              candidate.scores.knowledge +
                              candidate.scores.problemSolving) / 4
                          )}
                          size="md"
                        />
                      ) : (
                        <span className="text-xs text-slate-400">Not evaluated</span>
                      )}
                    </td>
                    <td className="py-4 px-4 text-right">
                      <button
                        onClick={() => setSelectedCandidate(candidate)}
                        className="text-primary hover:text-emerald-700 text-sm font-medium"
                      >
                        View Details
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* Candidate Detail Modal */}
      {selectedCandidate && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-slate-200">
              <div className="flex items-start justify-between">
                <div className="flex items-center gap-4">
                  <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center">
                    <User className="h-8 w-8 text-primary" />
                  </div>
                  <div>
                    <h2 className="text-xl font-bold text-slate-900">{selectedCandidate.name}</h2>
                    <p className="text-slate-500">{selectedCandidate.position}</p>
                    <span className={cn("inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium mt-2", stageConfig[selectedCandidate.stage].bg, stageConfig[selectedCandidate.stage].color)}>
                      {stageConfig[selectedCandidate.stage].label}
                    </span>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedCandidate(null)}
                  className="p-2 hover:bg-slate-100 rounded-lg transition-colors"
                >
                  <XCircle className="h-5 w-5 text-slate-400" />
                </button>
              </div>
            </div>

            <div className="p-6 space-y-6">
              {/* Contact Info */}
              <div className="grid grid-cols-2 gap-4">
                <div className="flex items-center gap-3 p-3 bg-slate-50 rounded-lg">
                  <Mail className="h-5 w-5 text-slate-400" />
                  <div>
                    <p className="text-xs text-slate-500">Email</p>
                    <p className="text-sm font-medium text-slate-900">{selectedCandidate.email}</p>
                  </div>
                </div>
                <div className="flex items-center gap-3 p-3 bg-slate-50 rounded-lg">
                  <Phone className="h-5 w-5 text-slate-400" />
                  <div>
                    <p className="text-xs text-slate-500">Phone</p>
                    <p className="text-sm font-medium text-slate-900">{selectedCandidate.phone}</p>
                  </div>
                </div>
              </div>

              {/* Evaluation Scores */}
              <div>
                <h3 className="text-sm font-semibold text-slate-900 mb-4">Interview Evaluation</h3>
                {selectedCandidate.scores ? (
                  <div className="space-y-4">
                    <div className="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
                      <div className="flex items-center gap-3">
                        <User className="h-5 w-5 text-purple-500" />
                        <span className="text-sm font-medium text-slate-700">Personality</span>
                      </div>
                      <StarRating rating={selectedCandidate.scores.personality} size="md" />
                    </div>
                    <div className="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
                      <div className="flex items-center gap-3">
                        <MessageSquare className="h-5 w-5 text-blue-500" />
                        <span className="text-sm font-medium text-slate-700">Communication</span>
                      </div>
                      <StarRating rating={selectedCandidate.scores.communication} size="md" />
                    </div>
                    <div className="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
                      <div className="flex items-center gap-3">
                        <Brain className="h-5 w-5 text-emerald-500" />
                        <span className="text-sm font-medium text-slate-700">Knowledge</span>
                      </div>
                      <StarRating rating={selectedCandidate.scores.knowledge} size="md" />
                    </div>
                    <div className="flex items-center justify-between p-3 bg-slate-50 rounded-lg">
                      <div className="flex items-center gap-3">
                        <Lightbulb className="h-5 w-5 text-amber-500" />
                        <span className="text-sm font-medium text-slate-700">Problem Solving</span>
                      </div>
                      <StarRating rating={selectedCandidate.scores.problemSolving} size="md" />
                    </div>
                  </div>
                ) : (
                  <div className="text-center py-8 bg-slate-50 rounded-lg">
                    <Star className="h-8 w-8 text-slate-300 mx-auto mb-2" />
                    <p className="text-slate-500 text-sm">No evaluation scores yet</p>
                    <button className="mt-3 text-primary text-sm font-medium hover:underline">
                      Add Evaluation
                    </button>
                  </div>
                )}
              </div>

              {/* Actions */}
              <div className="flex gap-3 pt-4 border-t border-slate-200">
                <button className="flex-1 py-2.5 px-4 bg-primary text-white rounded-lg font-medium text-sm hover:bg-emerald-600 transition-colors">
                  Move to Next Stage
                </button>
                <button className="py-2.5 px-4 border border-slate-200 text-slate-600 rounded-lg font-medium text-sm hover:bg-slate-50 transition-colors">
                  Schedule Interview
                </button>
                <button className="py-2.5 px-4 border border-red-200 text-red-600 rounded-lg font-medium text-sm hover:bg-red-50 transition-colors">
                  Reject
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
