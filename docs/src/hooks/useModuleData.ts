import { useState, useEffect } from "react";
import type { ModuleData } from "../lib/types";

const cache = new Map<string, ModuleData>();

export function useModuleData(modulePath: string | undefined) {
  const [data, setData] = useState<ModuleData | null>(
    modulePath ? cache.get(modulePath) ?? null : null
  );
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!modulePath) return;

    if (cache.has(modulePath)) {
      setData(cache.get(modulePath)!);
      return;
    }

    setData(null);
    setError(null);

    fetch(`/data/${modulePath}.json`)
      .then((res) => {
        if (!res.ok) throw new Error(`Module not found: ${modulePath}`);
        return res.json();
      })
      .then((mod: ModuleData) => {
        cache.set(modulePath, mod);
        setData(mod);
      })
      .catch((err) => setError(err.message));
  }, [modulePath]);

  return { data, error, loading: !data && !error && !!modulePath };
}
