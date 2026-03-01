import { useState, useEffect } from "react";
import type { IndexEntry } from "../lib/types";

let cachedIndex: IndexEntry[] | null = null;

export function useModuleIndex() {
  const [index, setIndex] = useState<IndexEntry[] | null>(cachedIndex);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (cachedIndex) return;

    fetch("/data/_index.json")
      .then((res) => {
        if (!res.ok) throw new Error(`Failed to load index: ${res.status}`);
        return res.json();
      })
      .then((data: IndexEntry[]) => {
        cachedIndex = data;
        setIndex(data);
      })
      .catch((err) => setError(err.message));
  }, []);

  const categories = index
    ? [...new Set(index.map((e) => e.category))].sort()
    : [];

  return { index, categories, error, loading: !index && !error };
}
