import { useTheme, type Theme } from "../hooks/useTheme";

const options: { value: Theme; label: string; icon: string }[] = [
  { value: "system", label: "System", icon: "◐" },
  { value: "light", label: "Light", icon: "○" },
  { value: "dark", label: "Dark", icon: "●" },
];

export function ThemeSelector() {
  const { theme, setTheme } = useTheme();

  return (
    <div
      className="flex overflow-hidden rounded border border-app-border text-xs shrink-0"
      role="group"
      aria-label="Theme selector"
    >
      {options.map((opt) => {
        const isActive = theme === opt.value;
        return (
          <button
            key={opt.value}
            type="button"
            onClick={() => setTheme(opt.value)}
            className={[
              "px-2 py-1 flex items-center justify-center transition-colors",
              isActive
                ? "bg-app-accent text-[#ffffff]"
                : "text-app-text-muted hover:bg-app-bg-alt hover:text-app-text",
            ].join(" ")}
            title={`${opt.label} theme`}
            aria-label={`Switch to ${opt.label} theme`}
            aria-pressed={isActive}
          >
            <span className="text-sm leading-none">{opt.icon}</span>
          </button>
        );
      })}
    </div>
  );
}
