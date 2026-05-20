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
    return <p className="text-app-text-muted">Loading module data...</p>;
  }

  if (error) {
    return <p className="text-app-error">Error: {error}</p>;
  }

  if (!data) {
    return <p className="text-app-text-muted">Module not found.</p>;
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-app-text">{data.modulePath}</h1>
        <p className="text-sm text-app-text-muted mt-1">
          Source: <code className="bg-app-bg-alt px-1.5 py-0.5 rounded">modules/{data.modulePath}.nix</code>
          {" | "}
          <a
            href={`/${data.modulePath}.md`}
            className="text-app-accent hover:underline"
          >
            View as markdown
          </a>
        </p>
      </div>

      <h2 className="text-lg font-semibold text-app-text mb-3">
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
