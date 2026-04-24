import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
    return twMerge(clsx(inputs));
}

/** Escape a single CSV cell. Quotes the value whenever it contains a
 *  comma / quote / newline, or starts with `=+-@` (Excel formula prefix). */
function csvCell(value: unknown): string {
    if (value === null || value === undefined) return "";
    const s = typeof value === "string" ? value : String(value);
    const needsQuoting = /[",\n\r]/.test(s) || /^[=+\-@]/.test(s);
    return needsQuoting ? `"${s.replace(/"/g, '""')}"` : s;
}

/** Build a CSV string from an array of row objects. `columns` pairs a
 *  header label with either a key or an accessor function so column order
 *  stays deterministic and labels can differ from object keys. */
export function toCsv<T extends Record<string, unknown>>(
    rows: T[],
    columns: Array<[string, keyof T | ((row: T) => unknown)]>
): string {
    const header = columns.map(([label]) => csvCell(label)).join(",");
    const body = rows.map((row) =>
        columns
            .map(([, accessor]) => {
                const v = typeof accessor === "function" ? accessor(row) : row[accessor];
                return csvCell(v);
            })
            .join(",")
    );
    // BOM so Excel opens UTF-8 (Thai) correctly.
    return "\ufeff" + [header, ...body].join("\r\n");
}

/** Trigger a browser download for a CSV blob. Safe to call from click handlers. */
export function downloadCsv(filename: string, csv: string): void {
    if (typeof window === "undefined") return;
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    a.style.display = "none";
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}

/** `20260424-143005` — timestamp suffix for export filenames. */
export function exportTimestamp(d: Date = new Date()): string {
    const p = (n: number) => n.toString().padStart(2, "0");
    return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}
