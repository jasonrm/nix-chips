import { useMemo, useState, useEffect } from "react";
import Fuse from "fuse.js";
import { useModuleIndex } from "./useModuleIndex";

interface SearchItem {
  modulePath: string;
  category: string;
  moduleName: string;
  optionName: string;
  type: string;
  description: string;
}

export function useSearch(query: string) {
  const { index } = useModuleIndex();
  const [items, setItems] = useState<SearchItem[]>([]);

  useEffect(() => {
    if (!index) return;

    const flat: SearchItem[] = [];
    for (const entry of index) {
      for (const opt of entry.options) {
        flat.push({
          modulePath: entry.modulePath,
          category: entry.category,
          moduleName: entry.name,
          optionName: opt.name,
          type: opt.type,
          description: opt.description,
        });
      }
    }
    setItems(flat);
  }, [index]);

  const fuse = useMemo(
    () =>
      new Fuse(items, {
        keys: [
          { name: "optionName", weight: 2 },
          { name: "moduleName", weight: 1.5 },
          { name: "description", weight: 1 },
          { name: "type", weight: 0.5 },
        ],
        threshold: 0.4,
        includeScore: true,
      }),
    [items]
  );

  const results = useMemo(() => {
    if (!query || query.length < 2) return [];
    return fuse.search(query, { limit: 50 });
  }, [fuse, query]);

  return { results, ready: items.length > 0 };
}
