import { Link, useSearchParams } from "react-router";
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
            <Link
              key={`${item.modulePath}:${item.optionName}`}
              to={`/${item.modulePath}#${item.optionName}`}
              className="block border border-zinc-200 rounded-lg p-3 hover:border-blue-300 hover:bg-blue-50 transition-colors"
            >
              <div className="font-mono text-sm font-medium text-zinc-900">
                {item.optionName}
              </div>
              <div className="flex items-center gap-2 mt-1">
                <span className="text-xs text-zinc-500">{item.modulePath}</span>
                <span className="text-xs text-zinc-400">|</span>
                <span className="text-xs font-mono text-zinc-500">
                  {item.type}
                </span>
              </div>
              {item.description && (
                <p className="text-sm text-zinc-500 mt-1 truncate">
                  {item.description}
                </p>
              )}
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
