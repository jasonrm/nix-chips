import { Link, useLocation } from "react-router";
import { useModuleIndex } from "../hooks/useModuleIndex";

export function Sidebar() {
  const { index, categories, loading } = useModuleIndex();
  const location = useLocation();

  if (loading) {
    return (
      <nav className="w-64 shrink-0 border-r border-app-border bg-app-bg-alt p-4 overflow-y-auto">
        <p className="text-sm text-app-text-muted">Loading...</p>
      </nav>
    );
  }

  // Group modules by category
  const grouped = new Map<string, { name: string; path: string }[]>();
  for (const cat of categories) {
    grouped.set(cat, []);
  }
  if (index) {
    for (const entry of index) {
      grouped.get(entry.category)?.push({
        name: entry.name,
        path: `/${entry.modulePath}`,
      });
    }
  }

  return (
    <nav className="w-64 shrink-0 border-r border-app-border bg-app-bg-alt overflow-y-auto">
      <div className="p-4">
        <Link to="/" className="block text-lg font-bold text-app-text mb-4">
          nix-chips
        </Link>

        {[...grouped.entries()].map(([category, modules]) => (
          <div key={category} className="mb-4">
            <Link
              to={`/${category}`}
              className="block text-xs font-semibold uppercase tracking-wider text-app-text-muted mb-1 hover:text-app-text"
            >
              {category}
            </Link>
            <ul className="space-y-0.5">
              {modules.map((mod) => (
                <li key={mod.path}>
                  <Link
                    to={mod.path}
                    className={`block px-2 py-1 text-sm rounded ${
                      location.pathname === mod.path
                        ? "bg-app-accent-bg text-app-accent-text font-medium"
                        : "text-app-text hover:bg-app-bg-alt"
                    }`}
                  >
                    {mod.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}

        <div className="mb-4">
          <span className="block text-xs font-semibold uppercase tracking-wider text-app-text-muted mb-1">
            lib
          </span>
          <ul>
            <li>
              <Link
                to="/lib/mkFlake"
                className={`block px-2 py-1 text-sm rounded ${
                  location.pathname === "/lib/mkFlake"
                    ? "bg-app-accent-bg text-app-accent-text font-medium"
                    : "text-app-text hover:bg-app-bg-alt"
                }`}
              >
                mkFlake
              </Link>
            </li>
          </ul>
        </div>
      </div>
    </nav>
  );
}
