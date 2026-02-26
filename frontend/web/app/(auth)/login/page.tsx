"use client";

import { useState } from "react";
import { ShieldCheck, Mail, Lock, Eye, EyeOff, ArrowRight } from "lucide-react";
import { useLanguage } from "@/components/LanguageProvider";
import { useAuth } from "@/components/AuthProvider";

export default function LoginPage() {
    const { login } = useAuth();
    const { locale, setLocale } = useLanguage();
    const [showPassword, setShowPassword] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
    const [formData, setFormData] = useState({
        email: "",
        password: "",
        remember: false,
    });
    const [error, setError] = useState("");

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError("");
        setIsLoading(true);

        try {
            await login(formData.email, formData.password);
            // AuthProvider handles redirect to "/"
        } catch (err: unknown) {
            const message = err instanceof Error ? err.message : "Unknown error";
            setError(
                locale === "th"
                    ? `เข้าสู่ระบบไม่สำเร็จ: ${message}`
                    : `Login failed: ${message}`
            );
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-emerald-900 flex items-center justify-center p-4">
            {/* Background Pattern */}
            <div className="absolute inset-0 opacity-10">
                <div className="w-full h-full bg-[radial-gradient(#10b981_1px,transparent_1px)] [background-size:40px_40px]" />
            </div>

            <div className="relative w-full max-w-md">
                {/* Language Switcher */}
                <div className="absolute -top-12 right-0 flex gap-2">
                    <button
                        onClick={() => setLocale("th")}
                        className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                            locale === "th"
                                ? "bg-emerald-500 text-white"
                                : "bg-white/10 text-white/70 hover:bg-white/20"
                        }`}
                    >
                        TH
                    </button>
                    <button
                        onClick={() => setLocale("en")}
                        className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                            locale === "en"
                                ? "bg-emerald-500 text-white"
                                : "bg-white/10 text-white/70 hover:bg-white/20"
                        }`}
                    >
                        EN
                    </button>
                </div>

                {/* Login Card */}
                <div className="bg-white rounded-2xl shadow-2xl p-8 border border-slate-200">
                    {/* Logo & Title */}
                    <div className="text-center mb-8">
                        <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-emerald-500 to-emerald-600 flex items-center justify-center mx-auto mb-4 shadow-lg shadow-emerald-500/30">
                            <ShieldCheck className="text-white w-8 h-8" />
                        </div>
                        <h1 className="text-2xl font-bold text-slate-900">Guard Dispatch</h1>
                        <p className="text-slate-500 mt-2">
                            {locale === "th" ? "เข้าสู่ระบบเพื่อจัดการความปลอดภัย" : "Sign in to manage security"}
                        </p>
                    </div>

                    {/* Error Message */}
                    {error && (
                        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
                            <p className="text-sm text-red-600 text-center">{error}</p>
                        </div>
                    )}

                    {/* Login Form */}
                    <form onSubmit={handleSubmit} className="space-y-5">
                        <div>
                            <label className="block text-sm font-medium text-slate-700 mb-2">
                                {locale === "th" ? "อีเมล" : "Email"}
                            </label>
                            <div className="relative">
                                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-400" />
                                <input
                                    type="email"
                                    value={formData.email}
                                    onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                                    placeholder="admin@example.com"
                                    required
                                    className="w-full pl-12 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all text-slate-900 placeholder:text-slate-400"
                                />
                            </div>
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-slate-700 mb-2">
                                {locale === "th" ? "รหัสผ่าน" : "Password"}
                            </label>
                            <div className="relative">
                                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-400" />
                                <input
                                    type={showPassword ? "text" : "password"}
                                    value={formData.password}
                                    onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                                    placeholder="--------"
                                    required
                                    className="w-full pl-12 pr-12 py-3 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 outline-none transition-all text-slate-900 placeholder:text-slate-400"
                                />
                                <button
                                    type="button"
                                    onClick={() => setShowPassword(!showPassword)}
                                    className="absolute right-4 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 transition-colors"
                                >
                                    {showPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
                                </button>
                            </div>
                        </div>

                        <div className="flex items-center justify-between">
                            <label className="flex items-center cursor-pointer">
                                <input
                                    type="checkbox"
                                    checked={formData.remember}
                                    onChange={(e) => setFormData({ ...formData, remember: e.target.checked })}
                                    className="w-4 h-4 rounded border-slate-300 text-emerald-500 focus:ring-emerald-500/20"
                                />
                                <span className="ml-2 text-sm text-slate-600">
                                    {locale === "th" ? "จดจำฉัน" : "Remember me"}
                                </span>
                            </label>
                            <button type="button" className="text-sm text-emerald-600 hover:text-emerald-700 font-medium">
                                {locale === "th" ? "ลืมรหัสผ่าน?" : "Forgot password?"}
                            </button>
                        </div>

                        <button
                            type="submit"
                            disabled={isLoading}
                            className="w-full py-3 px-4 bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700 text-white rounded-xl font-medium text-sm transition-all shadow-lg shadow-emerald-500/30 hover:shadow-emerald-500/40 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                        >
                            {isLoading ? (
                                <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                            ) : (
                                <>
                                    {locale === "th" ? "เข้าสู่ระบบ" : "Sign In"}
                                    <ArrowRight className="h-4 w-4" />
                                </>
                            )}
                        </button>
                    </form>
                </div>

                {/* Footer */}
                <p className="text-center text-sm text-white/50 mt-6">
                    &copy; 2025 Guard Dispatch. {locale === "th" ? "สงวนลิขสิทธิ์" : "All rights reserved."}
                </p>
            </div>
        </div>
    );
}
