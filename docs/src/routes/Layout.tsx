import { Outlet } from "react-router";
import { Sidebar } from "../components/Sidebar";
import { SearchBar } from "../components/SearchBar";
import { Breadcrumbs } from "../components/Breadcrumbs";

export function Layout() {
  return (
    <div className="flex h-screen">
      <Sidebar />
      <div className="flex-1 overflow-y-auto">
        <header className="sticky top-0 z-10 bg-white border-b border-zinc-200 px-6 py-3">
          <div className="max-w-3xl">
            <SearchBar />
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
