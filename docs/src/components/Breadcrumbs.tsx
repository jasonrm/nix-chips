import { Link, useLocation } from "react-router";

export function Breadcrumbs() {
  const location = useLocation();
  const parts = location.pathname.split("/").filter(Boolean);

  if (parts.length === 0) return null;

  const crumbs = parts.map((part, i) => ({
    label: part,
    path: "/" + parts.slice(0, i + 1).join("/"),
    isLast: i === parts.length - 1,
  }));

  return (
    <nav className="flex items-center gap-1.5 text-sm text-zinc-500 mb-4">
      <Link to="/" className="hover:text-zinc-700">
        Home
      </Link>
      {crumbs.map((crumb) => (
        <span key={crumb.path} className="flex items-center gap-1.5">
          <span>/</span>
          {crumb.isLast ? (
            <span className="text-zinc-900 font-medium">{crumb.label}</span>
          ) : (
            <Link to={crumb.path} className="hover:text-zinc-700">
              {crumb.label}
            </Link>
          )}
        </span>
      ))}
    </nav>
  );
}
