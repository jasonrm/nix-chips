import { Outlet } from "react-router";
import { Sidebar } from "../components/Sidebar";
import { SearchBar } from "../components/SearchBar";
import { Breadcrumbs } from "../components/Breadcrumbs";
import { ThemeSelector } from "../components/ThemeSelector";

export function Layout() {
  return (
    <div className="flex h-screen bg-app-bg text-app-text">
      <Sidebar />
      <div className="flex-1 overflow-y-auto">
        <header className="sticky top-0 z-10 bg-app-bg border-b border-app-border px-6 py-3">
          <div className="max-w-3xl flex items-center gap-3">
            <div className="flex-1 min-w-0">
              <SearchBar />
            </div>
            <ThemeSelector />
          </div>
        </header>
        <main className="px-6 py-6 max-w-3xl">
          <Breadcrumbs />
          <Outlet />
        </main>
      </div>
    </div>
  );
}
