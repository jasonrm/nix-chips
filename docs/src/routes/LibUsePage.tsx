import { useState, useEffect } from "react";
import type { UseParams } from "../lib/types";

export function LibUsePage() {
  const [params, setParams] = useState<UseParams | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch("/data/lib/use.json")
      .then((res) => {
        if (!res.ok) throw new Error("Failed to load lib.use data");
        return res.json();
      })
      .then(setParams)
      .catch((err) => setError(err.message));
  }, []);

  if (error) return <p className="text-red-500">Error: {error}</p>;
  if (!params) return <p className="text-zinc-400">Loading...</p>;

  const sorted = Object.entries(params).sort(([, a], [, b]) => {
    if (a.hasDefault === b.hasDefault) return 0;
    return a.hasDefault ? 1 : -1;
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-zinc-900">lib.use</h1>
        <p className="text-sm text-zinc-600 mt-1">
          The main entry point for nix-chips. Configure your project's flake
          outputs by passing parameters to <code>lib.use</code>.
        </p>
        <p className="text-sm text-zinc-500 mt-1">
          <a
            href="/lib/use.md"
            className="text-blue-600 hover:underline"
          >
            View as markdown
          </a>
        </p>
      </div>

      <h2 className="text-lg font-semibold text-zinc-800 mb-3">Parameters</h2>

      <div className="space-y-3">
        {sorted.map(([name, info]) => (
          <div
            key={name}
            className="border border-zinc-200 rounded-lg p-4"
            id={name}
          >
            <h3 className="font-mono text-sm font-semibold text-zinc-900 mb-2">
              <a href={`#${name}`} className="hover:text-blue-600">
                {name}
              </a>
              {!info.hasDefault && (
                <span className="ml-2 text-xs text-red-600 font-normal">
                  required
                </span>
              )}
            </h3>

            <div className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-sm">
              <span className="text-zinc-500 font-medium">Type</span>
              <span className="font-mono text-zinc-700">{info.type}</span>

              {info.hasDefault && info.default !== undefined && (
                <>
                  <span className="text-zinc-500 font-medium">Default</span>
                  <code className="text-zinc-700 bg-zinc-100 px-1.5 py-0.5 rounded text-xs">
                    {info.default}
                  </code>
                </>
              )}
            </div>

            <p className="mt-2 text-sm text-zinc-600">{info.description}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
