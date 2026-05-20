import { Link } from "react-router";
import { useModuleIndex } from "../hooks/useModuleIndex";

export function Home() {
  const { index, categories, loading } = useModuleIndex();

  return (
    <div>
      <h1 className="text-3xl font-bold text-app-text mb-2">nix-chips</h1>
      <p className="text-app-text-muted mb-6">
        A Nix flake library with reusable modules for development environments,
        services, and system configurations.
      </p>

      {loading ? (
        <p className="text-app-text-muted">Loading module index...</p>
      ) : (
        <div className="space-y-6">
          {categories.map((cat) => {
            const modules = index?.filter((e) => e.category === cat) ?? [];
            return (
              <section key={cat}>
                <h2 className="text-lg font-semibold text-app-text mb-2">
                  <Link to={`/${cat}`} className="hover:text-app-accent">
                    {cat}
                  </Link>
                </h2>
                <div className="grid grid-cols-2 gap-2">
                  {modules.map((mod) => (
                    <Link
                      key={mod.modulePath}
                      to={`/${mod.modulePath}`}
                      className="block border border-app-border rounded-lg p-3 hover:border-app-accent hover:bg-app-accent-bg transition-colors"
                    >
                      <span className="font-medium text-app-text">
                        {mod.name}
                      </span>
                      <span className="text-xs text-app-text-muted ml-2">
                        {mod.optionCount} options
                      </span>
                    </Link>
                  ))}
                </div>
              </section>
            );
          })}

          <section>
            <h2 className="text-lg font-semibold text-app-text mb-2">lib</h2>
            <Link
              to="/lib/mkFlake"
              className="block border border-app-border rounded-lg p-3 hover:border-app-accent hover:bg-app-accent-bg transition-colors w-fit"
            >
              <span className="font-medium text-app-text">lib.mkFlake</span>
              <span className="text-xs text-app-text-muted ml-2">
                Flake entry point
              </span>
            </Link>
          </section>
        </div>
      )}
    </div>
  );
}
