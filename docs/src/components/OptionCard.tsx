import type { ModuleOption } from "../lib/types";

export function OptionCard({ option }: { option: ModuleOption }) {
  return (
    <div className="border border-zinc-200 rounded-lg p-4 mb-3" id={option.name}>
      <h3 className="font-mono text-sm font-semibold text-zinc-900 mb-2">
        <a href={`#${option.name}`} className="hover:text-blue-600">
          {option.name}
        </a>
      </h3>

      <div className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-sm">
        <span className="text-zinc-500 font-medium">Type</span>
        <span className="font-mono text-zinc-700">{option.type}</span>

        {option.default !== undefined && (
          <>
            <span className="text-zinc-500 font-medium">Default</span>
            <code className="text-zinc-700 bg-zinc-100 px-1.5 py-0.5 rounded text-xs">
              {option.default}
            </code>
          </>
        )}

        {option.readOnly && (
          <>
            <span className="text-zinc-500 font-medium">Access</span>
            <span className="text-amber-600 text-xs font-medium">Read only</span>
          </>
        )}

        {option.example !== undefined && (
          <>
            <span className="text-zinc-500 font-medium">Example</span>
            <code className="text-zinc-700 bg-zinc-100 px-1.5 py-0.5 rounded text-xs">
              {option.example}
            </code>
          </>
        )}
      </div>

      {option.description && (
        <p className="mt-2 text-sm text-zinc-600">{option.description}</p>
      )}

      {option.declarations.length > 0 && (
        <div className="mt-2 text-xs text-zinc-400">
          Declared in:{" "}
          {option.declarations.map((d, i) => (
            <span key={d}>
              {i > 0 && ", "}
              <code>{d}</code>
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
