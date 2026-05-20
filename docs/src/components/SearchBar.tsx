import { useState, useCallback } from "react";
import { useNavigate } from "react-router";

export function SearchBar() {
  const [value, setValue] = useState("");
  const navigate = useNavigate();

  const handleSubmit = useCallback(
    (e: React.FormEvent) => {
      e.preventDefault();
      if (value.trim()) {
        navigate(`/search?q=${encodeURIComponent(value.trim())}`);
      }
    },
    [value, navigate]
  );

  return (
    <form onSubmit={handleSubmit} className="relative">
      <input
        type="search"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="Search options..."
        className="w-full pl-3 pr-8 py-1.5 text-sm border border-app-border rounded-md bg-app-bg text-app-text focus:outline-none focus:ring-2 focus:ring-app-accent focus:border-app-accent placeholder:text-app-text-muted"
      />
      <kbd className="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-app-text-muted pointer-events-none">
        /
      </kbd>
    </form>
  );
}
