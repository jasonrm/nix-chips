import { Link, useLocation } from "react-router";
import { useModuleIndex } from "../hooks/useModuleIndex";

export function Sidebar() {
  const { index, categories, loading } = useModuleIndex();
  const location = useLocation();

  if (loading) {
    return (
      <nav className="w-64 shrink-0 border-r border-zinc-200 bg-zinc-50 p-4 overflow-y-auto">
        <p className="text-sm text-zinc-400">Loading...</p>
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
    <nav className="w-64 shrink-0 border-r border-zinc-200 bg-zinc-50 overflow-y-auto">
      <div className="p-4">
        <Link to="/" className="block text-lg font-bold text-zinc-900 mb-4">
          nix-chips
        </Link>

        {[...grouped.entries()].map(([category, modules]) => (
          <div key={category} className="mb-4">
            <Link
              to={`/${category}`}
              className="block text-xs font-semibold uppercase tracking-wider text-zinc-500 mb-1 hover:text-zinc-700"
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
                        ? "bg-blue-100 text-blue-800 font-medium"
                        : "text-zinc-700 hover:bg-zinc-100"
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
          <span className="block text-xs font-semibold uppercase tracking-wider text-zinc-500 mb-1">
            lib
          </span>
          <ul>
            <li>
              <Link
                to="/lib/use"
                className={`block px-2 py-1 text-sm rounded ${
                  location.pathname === "/lib/use"
                    ? "bg-blue-100 text-blue-800 font-medium"
                    : "text-zinc-700 hover:bg-zinc-100"
                }`}
              >
                use
              </Link>
            </li>
          </ul>
        </div>
      </div>
    </nav>
  );
}
