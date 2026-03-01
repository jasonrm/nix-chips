import { BrowserRouter, Routes, Route } from "react-router";
import { Layout } from "./routes/Layout";
import { Home } from "./routes/Home";
import { ModuleCategory } from "./routes/ModuleCategory";
import { ModulePage } from "./routes/ModulePage";
import { LibUsePage } from "./routes/LibUsePage";
import { SearchResults } from "./routes/SearchResults";

export function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<Home />} />
          <Route path="search" element={<SearchResults />} />
          <Route path="lib/use" element={<LibUsePage />} />

          {/* Category pages: chips/config, chips/programs, chips/services */}
          <Route path=":group/:subcategory" element={<ModuleCategory />} />

          {/* Module pages: chips/config/shell, chips/services/mysql, etc. */}
          <Route path=":group/:subcategory/:module" element={<ModulePage />} />

          {/* Top-level categories: shared, nixos, home-manager */}
          <Route path=":group" element={<ModuleCategory />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
