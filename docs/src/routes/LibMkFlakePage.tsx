import { useState, useEffect } from "react";
import type { MkFlakeOptions } from "../lib/types";

export function LibMkFlakePage() {
  const [params, setParams] = useState<MkFlakeOptions | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetch("/data/lib/mkFlake.json")
      .then((res) => {
        if (!res.ok) throw new Error("Failed to load lib.mkFlake data");
        return res.json();
      })
      .then(setParams)
      .catch((err) => setError(err.message));
  }, []);

  if (error) return <p className="text-app-error">Error: {error}</p>;
  if (!params) return <p className="text-app-text-muted">Loading...</p>;

  const sorted = Object.entries(params).sort(([, a], [, b]) => {
    if (a.hasDefault === b.hasDefault) return 0;
    return a.hasDefault ? 1 : -1;
  });

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-app-text">lib.mkFlake</h1>
        <p className="text-sm text-app-text-muted mt-1">
          The main entry point for nix-chips. Configure your project's flake
          outputs by passing typed options to <code>lib.mkFlake</code>.
        </p>
        <p className="text-sm text-app-text-muted mt-1">
          <a
            href="/lib/mkFlake.md"
            className="text-app-accent hover:underline"
          >
            View as markdown
          </a>
        </p>
      </div>

      <h2 className="text-lg font-semibold text-app-text mb-3">Options</h2>

      <div className="space-y-3">
        {sorted.map(([name, info]) => (
          <div
            key={name}
            className="border border-app-border rounded-lg p-4"
            id={name}
          >
            <h3 className="font-mono text-sm font-semibold text-app-text mb-2">
              <a href={`#${name}`} className="hover:text-app-accent">
                {name}
              </a>
              {!info.hasDefault && (
                <span className="ml-2 text-xs text-app-error font-normal">
                  required
                </span>
              )}
            </h3>

            <div className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-sm">
              <span className="text-app-text-muted font-medium">Type</span>
              <span className="font-mono text-app-text">{info.type}</span>

              {info.hasDefault && info.default !== undefined && (
                <>
                  <span className="text-app-text-muted font-medium">Default</span>
                  <code className="text-app-text bg-app-bg-alt px-1.5 py-0.5 rounded text-xs">
                    {info.default}
                  </code>
                </>
              )}
            </div>

            <p className="mt-2 text-sm text-app-text-muted">{info.description}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
