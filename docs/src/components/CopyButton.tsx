import { useState } from "react";

type CopyButtonProps = {
  text: string;
  ariaLabel: string;
  label?: string;
  copiedLabel?: string;
  failedLabel?: string;
  title?: string;
  className?: string;
};

export function CopyButton({
  text,
  ariaLabel,
  label = "⧉",
  copiedLabel = "✓",
  failedLabel = "!",
  title,
  className = "",
}: CopyButtonProps) {
  const [copyState, setCopyState] = useState<"idle" | "copied" | "failed">(
    "idle",
  );

  async function copyText() {
    try {
      await writeToClipboard(text);
      setCopyState("copied");
    } catch {
      setCopyState("failed");
    }

    window.setTimeout(() => setCopyState("idle"), 1500);
  }

  return (
    <button
      type="button"
      onClick={copyText}
      className={[
        "inline-flex h-6 w-6 items-center justify-center rounded border border-zinc-200 text-xs font-medium text-zinc-500 hover:border-zinc-300 hover:bg-zinc-50 hover:text-zinc-900",
        className,
      ].join(" ")}
      aria-label={ariaLabel}
      title={title ?? ariaLabel}
    >
      {copyState === "copied"
        ? copiedLabel
        : copyState === "failed"
          ? failedLabel
          : label}
    </button>
  );
}

async function writeToClipboard(text: string) {
  if (navigator.clipboard) {
    try {
      await navigator.clipboard.writeText(text);
      return;
    } catch {
      // Fall through to the older copy command for browsers that expose the
      // clipboard API but reject it in the current page context.
    }
  }

  const textArea = document.createElement("textarea");
  textArea.value = text;
  textArea.style.position = "fixed";
  textArea.style.opacity = "0";
  document.body.append(textArea);
  textArea.select();

  try {
    if (!document.execCommand("copy")) {
      throw new Error("Copy command was not accepted");
    }
  } finally {
    textArea.remove();
  }
}
