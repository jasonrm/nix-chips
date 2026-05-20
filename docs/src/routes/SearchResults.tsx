import { Link, useSearchParams } from "react-router";
import { CopyButton } from "../components/CopyButton";
import { useSearch } from "../hooks/useSearch";

export function SearchResults() {
  const [searchParams] = useSearchParams();
  const query = searchParams.get("q") || "";
  const { results, ready } = useSearch(query);

  if (!query) {
    return <p className="text-app-text-muted">Enter a search query.</p>;
  }

  if (!ready) {
    return <p className="text-app-text-muted">Loading search index...</p>;
  }

  return (
    <div>
      <h1 className="text-2xl font-bold text-app-text mb-1">Search Results</h1>
      <p className="text-sm text-app-text-muted mb-4">
        {results.length} results for "{query}"
      </p>

      {results.length === 0 ? (
        <p className="text-app-text-muted">No results found.</p>
      ) : (
        <div className="space-y-2">
          {results.map(({ item }) => (
            <div
              key={`${item.modulePath}:${item.optionName}`}
              className="flex items-start gap-2 rounded-lg border border-app-border transition-colors hover:border-app-accent hover:bg-app-accent-bg"
            >
              <Link
                to={`/${item.modulePath}#${encodeURIComponent(item.optionName)}`}
                className="min-w-0 flex-1 p-3 pr-0"
              >
                <div className="select-text break-all font-mono text-sm font-medium text-app-text">
                  {item.optionName}
                </div>
                <div className="mt-1 flex items-center gap-2">
                  <span className="text-xs text-app-text-muted">
                    {item.modulePath}
                  </span>
                  <span className="text-xs text-app-text-muted">|</span>
                  <span className="text-xs font-mono text-app-text-muted">
                    {item.type}
                  </span>
                </div>
                {item.description && (
                  <p className="mt-1 truncate text-sm text-app-text-muted">
                    {item.description}
                  </p>
                )}
              </Link>
              <CopyButton
                text={item.optionName}
                ariaLabel={`Copy option name ${item.optionName}`}
                title="Copy option name"
                className="mt-3 mr-3 shrink-0"
              />
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
