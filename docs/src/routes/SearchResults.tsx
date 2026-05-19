import { Link, useSearchParams } from "react-router";
import { CopyButton } from "../components/CopyButton";
import { useSearch } from "../hooks/useSearch";

export function SearchResults() {
  const [searchParams] = useSearchParams();
  const query = searchParams.get("q") || "";
  const { results, ready } = useSearch(query);

  if (!query) {
    return <p className="text-zinc-500">Enter a search query.</p>;
  }

  if (!ready) {
    return <p className="text-zinc-400">Loading search index...</p>;
  }

  return (
    <div>
      <h1 className="text-2xl font-bold text-zinc-900 mb-1">Search Results</h1>
      <p className="text-sm text-zinc-500 mb-4">
        {results.length} results for "{query}"
      </p>

      {results.length === 0 ? (
        <p className="text-zinc-500">No results found.</p>
      ) : (
        <div className="space-y-2">
          {results.map(({ item }) => (
            <div
              key={`${item.modulePath}:${item.optionName}`}
              className="flex items-start gap-2 rounded-lg border border-zinc-200 transition-colors hover:border-blue-300 hover:bg-blue-50"
            >
              <Link
                to={`/${item.modulePath}#${encodeURIComponent(item.optionName)}`}
                className="min-w-0 flex-1 p-3 pr-0"
              >
                <div className="select-text break-all font-mono text-sm font-medium text-zinc-900">
                  {item.optionName}
                </div>
                <div className="mt-1 flex items-center gap-2">
                  <span className="text-xs text-zinc-500">
                    {item.modulePath}
                  </span>
                  <span className="text-xs text-zinc-400">|</span>
                  <span className="text-xs font-mono text-zinc-500">
                    {item.type}
                  </span>
                </div>
                {item.description && (
                  <p className="mt-1 truncate text-sm text-zinc-500">
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
