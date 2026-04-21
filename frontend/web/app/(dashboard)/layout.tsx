import { Sidebar } from "@/components/Sidebar";
import { Header } from "@/components/Header";
import { AdminOnly } from "@/components/AdminOnly";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <div className="flex-1 flex flex-col min-w-0">
        <Header />
        <main className="flex-1 overflow-y-auto p-8 bg-slate-50">
          <AdminOnly>{children}</AdminOnly>
        </main>
      </div>
    </div>
  );
}
