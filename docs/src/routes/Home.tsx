import { Link } from "react-router";
import { useModuleIndex } from "../hooks/useModuleIndex";

export function Home() {
  const { index, categories, loading } = useModuleIndex();

  return (
    <div>
      <h1 className="text-3xl font-bold text-zinc-900 mb-2">nix-chips</h1>
      <p className="text-zinc-600 mb-6">
        A Nix flake library with reusable modules for development environments,
        services, and system configurations.
      </p>

      {loading ? (
        <p className="text-zinc-400">Loading module index...</p>
      ) : (
        <div className="space-y-6">
          {categories.map((cat) => {
            const modules = index?.filter((e) => e.category === cat) ?? [];
            return (
              <section key={cat}>
                <h2 className="text-lg font-semibold text-zinc-800 mb-2">
                  <Link to={`/${cat}`} className="hover:text-blue-600">
                    {cat}
                  </Link>
                </h2>
                <div className="grid grid-cols-2 gap-2">
                  {modules.map((mod) => (
                    <Link
                      key={mod.modulePath}
                      to={`/${mod.modulePath}`}
                      className="block border border-zinc-200 rounded-lg p-3 hover:border-blue-300 hover:bg-blue-50 transition-colors"
                    >
                      <span className="font-medium text-zinc-900">
                        {mod.name}
                      </span>
                      <span className="text-xs text-zinc-500 ml-2">
                        {mod.optionCount} options
                      </span>
                    </Link>
                  ))}
                </div>
              </section>
            );
          })}

          <section>
            <h2 className="text-lg font-semibold text-zinc-800 mb-2">lib</h2>
            <Link
              to="/lib/use"
              className="block border border-zinc-200 rounded-lg p-3 hover:border-blue-300 hover:bg-blue-50 transition-colors w-fit"
            >
              <span className="font-medium text-zinc-900">lib.use</span>
              <span className="text-xs text-zinc-500 ml-2">
                Flake entry point
              </span>
            </Link>
          </section>
        </div>
      )}
    </div>
  );
}
