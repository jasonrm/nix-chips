import { Link, useParams } from "react-router";
import { useModuleIndex } from "../hooks/useModuleIndex";
import { useModuleData } from "../hooks/useModuleData";
import { OptionCard } from "../components/OptionCard";

export function ModuleCategory() {
  const params = useParams();
  const path = [params.group, params.subcategory].filter(Boolean).join("/");
  const { index, loading } = useModuleIndex();

  // Check if this path is a module (e.g., shared/arcanum) vs a category (e.g., chips/config)
  const isModule = index?.some((e) => e.modulePath === path) ?? false;
  const modules = index?.filter((e) => e.category === path) ?? [];

  if (loading) {
    return <p className="text-zinc-400">Loading...</p>;
  }

  // If this matches a module path, render as module page
  if (isModule) {
    return <ModuleView modulePath={path} />;
  }

  if (modules.length === 0) {
    return <p className="text-zinc-500">No modules found in {path}.</p>;
  }

  return (
    <div>
      <h1 className="text-2xl font-bold text-zinc-900 mb-4">{path}</h1>
      <div className="space-y-2">
        {modules.map((mod) => (
          <Link
            key={mod.modulePath}
            to={`/${mod.modulePath}`}
            className="block border border-zinc-200 rounded-lg p-4 hover:border-blue-300 hover:bg-blue-50 transition-colors"
          >
            <div className="flex items-center justify-between">
              <span className="font-medium text-zinc-900">{mod.name}</span>
              <span className="text-xs text-zinc-500">
                {mod.optionCount} options
              </span>
            </div>
            {mod.options.length > 0 && (
              <p className="text-sm text-zinc-500 mt-1 truncate">
                {mod.options
                  .slice(0, 3)
                  .map((o) => o.name)
                  .join(", ")}
                {mod.options.length > 3 && "..."}
              </p>
            )}
          </Link>
        ))}
      </div>
    </div>
  );
}

function ModuleView({ modulePath }: { modulePath: string }) {
  const { data, error, loading } = useModuleData(modulePath);

  if (loading) return <p className="text-zinc-400">Loading module data...</p>;
  if (error) return <p className="text-red-500">Error: {error}</p>;
  if (!data) return <p className="text-zinc-500">Module not found.</p>;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-zinc-900">{data.modulePath}</h1>
        <p className="text-sm text-zinc-500 mt-1">
          Source: <code className="bg-zinc-100 px-1.5 py-0.5 rounded">modules/{data.modulePath}.nix</code>
          {" | "}
          <a href={`/${data.modulePath}.md`} className="text-blue-600 hover:underline">
            View as markdown
          </a>
        </p>
      </div>
      <h2 className="text-lg font-semibold text-zinc-800 mb-3">
        Options ({data.options.length})
      </h2>
      <div>
        {data.options.map((opt) => (
          <OptionCard key={opt.name} option={opt} />
        ))}
      </div>
    </div>
  );
}
