"use client";

import { createContext, useContext, useEffect, useState } from "react";
import { translations, Locale, Translations } from "@/lib/i18n";

interface LanguageContextType {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  t: Translations;
}

const LanguageContext = createContext<LanguageContextType | undefined>(undefined);

export function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>("th");
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    queueMicrotask(() => setMounted(true));
    const savedLocale = localStorage.getItem("locale") as Locale | null;
    if (savedLocale && (savedLocale === "th" || savedLocale === "en")) {
      queueMicrotask(() => setLocaleState(savedLocale));
    }
  }, []);

  useEffect(() => {
    if (!mounted) return;
    localStorage.setItem("locale", locale);
    document.documentElement.lang = locale;
  }, [locale, mounted]);

  const setLocale = (newLocale: Locale) => {
    setLocaleState(newLocale);
  };

  const t = translations[locale];

  if (!mounted) {
    return <>{children}</>;
  }

  return (
    <LanguageContext.Provider value={{ locale, setLocale, t }}>
      {children}
    </LanguageContext.Provider>
  );
}

export function useLanguage() {
  const context = useContext(LanguageContext);
  if (!context) {
    // Return default values for static rendering
    return {
      locale: "th" as Locale,
      setLocale: () => {},
      t: translations.th,
    };
  }
  return context;
}
