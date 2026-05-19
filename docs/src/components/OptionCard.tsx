import type { ModuleOption } from "../lib/types";
import { CopyButton } from "./CopyButton";

export function OptionCard({ option }: { option: ModuleOption }) {
  const anchorHref = `#${encodeURIComponent(option.name)}`;
  const snippet = buildOptionSnippet(option);

  return (
    <div className="border border-zinc-200 rounded-lg p-4 mb-3" id={option.name}>
      <h3 className="mb-2 flex items-start gap-1.5">
        <a
          href={anchorHref}
          className="inline-flex h-6 w-6 shrink-0 items-center justify-center rounded border border-zinc-200 font-mono text-xs font-medium text-zinc-500 hover:border-zinc-300 hover:bg-zinc-50 hover:text-blue-600"
          aria-label={`Link to ${option.name}`}
          title="Link to option"
        >
          #
        </a>
        <CopyButton
          text={option.name}
          ariaLabel={`Copy option name ${option.name}`}
          title="Copy option name"
        />
        <span className="min-w-0 flex-1 select-text break-all pt-0.5 font-mono text-sm font-semibold text-zinc-900">
          {option.name}
        </span>
      </h3>

      <CopyableCode
        label="Assignment"
        value={snippet}
        copyAriaLabel={`Copy Nix snippet for ${option.name}`}
        emphasized
        hideLabel
      />

      <div className="mt-3 grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-sm">
        <span className="text-zinc-500 font-medium">Type</span>
        <span className="font-mono text-zinc-700">{option.type}</span>

        {option.readOnly && (
          <>
            <span className="text-zinc-500 font-medium">Access</span>
            <span className="text-amber-600 text-xs font-medium">Read only</span>
          </>
        )}
      </div>

      {option.description && (
        <p className="mt-2 text-sm text-zinc-600">{option.description}</p>
      )}

      {option.example !== undefined && (
        <CopyableCode label="Example" value={option.example} emphasized />
      )}

      {option.default !== undefined && (
        <CopyableCode label="Default" value={option.default} />
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

function buildOptionSnippet(option: ModuleOption) {
  return `${option.name} = ${option.example ?? option.default ?? "<value>"};`;
}

function CopyableCode({
  label,
  value,
  copyAriaLabel,
  emphasized = false,
  hideLabel = false,
}: {
  label: string;
  value: string;
  copyAriaLabel?: string;
  emphasized?: boolean;
  hideLabel?: boolean;
}) {
  const shouldUseBlock = value.includes("\n") || value.length > 72;
  const ariaLabel = copyAriaLabel ?? `Copy ${label.toLowerCase()} value`;

  return (
    <div className={emphasized ? "mt-4" : "mt-3"}>
      <div
        className={
          hideLabel
            ? "flex items-start gap-1.5"
            : "grid grid-cols-[auto_auto_1fr] items-start gap-x-2"
        }
      >
        {!hideLabel && (
          <span
            className={
              emphasized
                ? "pt-0.5 text-sm font-semibold text-zinc-700"
                : "pt-0.5 text-sm font-medium text-zinc-500"
            }
          >
            {label}
          </span>
        )}
        <CopyButton
          text={value}
          ariaLabel={ariaLabel}
          title={ariaLabel}
          className="shrink-0"
        />
        {shouldUseBlock ? (
          <pre className="min-w-0 max-h-56 flex-1 overflow-auto whitespace-pre-wrap break-words rounded bg-zinc-100 p-2 text-xs text-zinc-700">
            <code>{value}</code>
          </pre>
        ) : (
          <code className="min-w-0 flex-1 select-text break-all rounded bg-zinc-100 px-1.5 py-1 text-xs text-zinc-700">
            {value}
          </code>
        )}
      </div>
    </div>
  );
}
