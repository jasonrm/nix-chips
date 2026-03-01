import { useParams } from "react-router";
import { useModuleData } from "../hooks/useModuleData";
import { OptionCard } from "../components/OptionCard";

export function ModulePage() {
  const params = useParams();

  // Build module path from URL params
  const modulePath = [params.group, params.subcategory, params.module]
    .filter(Boolean)
    .join("/");

  const { data, error, loading } = useModuleData(modulePath);

  if (loading) {
    return <p className="text-zinc-400">Loading module data...</p>;
  }

  if (error) {
    return <p className="text-red-500">Error: {error}</p>;
  }

  if (!data) {
    return <p className="text-zinc-500">Module not found.</p>;
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-zinc-900">{data.modulePath}</h1>
        <p className="text-sm text-zinc-500 mt-1">
          Source: <code className="bg-zinc-100 px-1.5 py-0.5 rounded">modules/{data.modulePath}.nix</code>
          {" | "}
          <a
            href={`/${data.modulePath}.md`}
            className="text-blue-600 hover:underline"
          >
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
