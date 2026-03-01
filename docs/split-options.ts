#!/usr/bin/env bun

import { mkdirSync, writeFileSync, readFileSync, existsSync } from "fs";
import { dirname, join } from "path";

const [optionsJsonPath, outputDir] = Bun.argv.slice(2);

if (!optionsJsonPath || !outputDir) {
  console.error("Usage: split-options.ts <options.json> <output-dir>");
  process.exit(1);
}

// Types
interface NixOption {
  declarations: string[];
  description?: string;
  type?: string;
  default?: { text?: string; _type?: string } | string | number | boolean;
  example?: { text?: string; _type?: string } | string | number | boolean;
  readOnly?: boolean;
  loc?: string[];
}

interface ModuleOption {
  name: string;
  type: string;
  default?: string;
  description: string;
  example?: string;
  readOnly: boolean;
  declarations: string[];
}

interface ModuleData {
  modulePath: string;
  category: string;
  name: string;
  options: ModuleOption[];
}

interface IndexEntry {
  modulePath: string;
  category: string;
  name: string;
  optionCount: number;
  options: { name: string; type: string; description: string }[];
}

// Parse input
const rawOptions: Record<string, NixOption> = JSON.parse(
  readFileSync(optionsJsonPath, "utf-8")
);

// Map from declaration file path to module path
function declarationToModulePath(decl: string): string | null {
  // Match patterns like modules/chips/services/mysql.nix → chips/services/mysql
  const match = decl.match(/^modules\/(chips|shared|nixos|home-manager)\/(.+)\.nix$/);
  if (match) {
    return `${match[1]}/${match[2]}`;
  }
  return null;
}

function extractCategory(modulePath: string): string {
  const parts = modulePath.split("/");
  if (parts[0] === "chips" && parts.length >= 2) {
    return `chips/${parts[1]}`; // e.g., chips/services, chips/config
  }
  return parts[0]; // e.g., shared, nixos, home-manager
}

function extractModuleName(modulePath: string): string {
  const parts = modulePath.split("/");
  return parts[parts.length - 1];
}

function formatDefault(val: unknown): string | undefined {
  if (val === undefined || val === null) return undefined;
  if (typeof val === "object" && val !== null && "_type" in val) {
    const typed = val as { _type: string; text?: string };
    if (typed._type === "literalExpression" && typed.text) return typed.text;
    if (typed._type === "literalMD" && typed.text) return typed.text;
  }
  if (typeof val === "boolean" || typeof val === "number") return String(val);
  if (typeof val === "string") return val;
  try {
    return JSON.stringify(val);
  } catch {
    return undefined;
  }
}

function cleanDescription(desc?: string): string {
  if (!desc) return "";
  // Strip XML/docbook tags and clean up markdown
  return desc
    .replace(/<[^>]+>/g, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

// Group options by declaring module
const moduleMap = new Map<string, ModuleOption[]>();

for (const [optionName, optionData] of Object.entries(rawOptions)) {
  // Find which module declared this option by looking at declarations
  let targetModule: string | null = null;

  for (const decl of optionData.declarations) {
    const modPath = declarationToModulePath(decl);
    if (modPath) {
      targetModule = modPath;
      break;
    }
  }

  // Skip options from nixos-shims or unknown sources
  if (!targetModule) continue;

  const option: ModuleOption = {
    name: optionName,
    type: optionData.type || "unknown",
    default: formatDefault(optionData.default),
    description: cleanDescription(optionData.description),
    example: formatDefault(optionData.example),
    readOnly: optionData.readOnly || false,
    declarations: optionData.declarations,
  };

  if (!moduleMap.has(targetModule)) {
    moduleMap.set(targetModule, []);
  }
  moduleMap.get(targetModule)!.push(option);
}

// Sort options within each module
for (const options of moduleMap.values()) {
  options.sort((a, b) => a.name.localeCompare(b.name));
}

// Write per-module JSON and markdown files
const indexEntries: IndexEntry[] = [];

for (const [modulePath, options] of moduleMap.entries()) {
  const category = extractCategory(modulePath);
  const name = extractModuleName(modulePath);

  const moduleData: ModuleData = {
    modulePath,
    category,
    name,
    options,
  };

  // Write JSON
  const jsonPath = join(outputDir, `${modulePath}.json`);
  mkdirSync(dirname(jsonPath), { recursive: true });
  writeFileSync(jsonPath, JSON.stringify(moduleData, null, 2));

  // Write Markdown
  const mdPath = join(outputDir, `${modulePath}.md`);
  writeFileSync(mdPath, generateMarkdown(moduleData));

  // Add to index
  indexEntries.push({
    modulePath,
    category,
    name,
    optionCount: options.length,
    options: options.map((o) => ({
      name: o.name,
      type: o.type,
      description: o.description.slice(0, 200),
    })),
  });
}

// Generate lib/use markdown
const useJsonPath = join(outputDir, "lib/use.json");
if (existsSync(useJsonPath)) {
  const useParams = JSON.parse(readFileSync(useJsonPath, "utf-8"));
  const useMd = generateUseMarkdown(useParams);
  writeFileSync(join(outputDir, "lib/use.md"), useMd);
}

// Sort index
indexEntries.sort((a, b) => a.modulePath.localeCompare(b.modulePath));

// Write index
writeFileSync(join(outputDir, "_index.json"), JSON.stringify(indexEntries, null, 2));

// Write index markdown
writeFileSync(join(outputDir, "_index.md"), generateIndexMarkdown(indexEntries));

console.log(`Generated ${indexEntries.length} module docs`);

// --- Generators ---

function generateMarkdown(mod: ModuleData): string {
  const lines: string[] = [];
  lines.push(`# ${mod.modulePath}`);
  lines.push("");
  lines.push(`**Category:** ${mod.category} | **Source:** \`modules/${mod.modulePath}.nix\``);
  lines.push("");
  lines.push("## Options");
  lines.push("");

  for (const opt of mod.options) {
    lines.push(`### \`${opt.name}\``);
    lines.push("");
    lines.push(`- **Type:** ${opt.type}`);
    if (opt.default !== undefined) {
      lines.push(`- **Default:** \`${opt.default}\``);
    }
    if (opt.readOnly) {
      lines.push(`- **Read only**`);
    }
    if (opt.description) {
      lines.push(`- **Description:** ${opt.description}`);
    }
    if (opt.example !== undefined) {
      lines.push(`- **Example:** \`${opt.example}\``);
    }
    lines.push("");
  }

  return lines.join("\n");
}

function generateUseMarkdown(params: Record<string, { hasDefault: boolean; description: string; type: string; default?: string }>): string {
  const lines: string[] = [];
  lines.push("# lib.use");
  lines.push("");
  lines.push("The `lib.use` function is the main entry point for nix-chips. It takes a set of parameters configuring your project's flake outputs.");
  lines.push("");
  lines.push("## Parameters");
  lines.push("");

  // Sort: required first, then optional
  const sorted = Object.entries(params).sort(([, a], [, b]) => {
    if (a.hasDefault === b.hasDefault) return 0;
    return a.hasDefault ? 1 : -1;
  });

  for (const [name, info] of sorted) {
    lines.push(`### \`${name}\``);
    lines.push("");
    lines.push(`- **Type:** ${info.type}`);
    if (info.hasDefault && info.default !== undefined) {
      lines.push(`- **Default:** \`${info.default}\``);
    }
    if (!info.hasDefault) {
      lines.push(`- **Required**`);
    }
    lines.push(`- **Description:** ${info.description}`);
    lines.push("");
  }

  return lines.join("\n");
}

function generateIndexMarkdown(entries: IndexEntry[]): string {
  const lines: string[] = [];
  lines.push("# nix-chips Module Reference");
  lines.push("");
  lines.push("Auto-generated documentation for all nix-chips modules.");
  lines.push("");

  // Group by category
  const categories = new Map<string, IndexEntry[]>();
  for (const entry of entries) {
    if (!categories.has(entry.category)) {
      categories.set(entry.category, []);
    }
    categories.get(entry.category)!.push(entry);
  }

  for (const [category, mods] of categories.entries()) {
    lines.push(`## ${category}`);
    lines.push("");
    for (const mod of mods) {
      lines.push(`- [${mod.name}](${mod.modulePath}.md) (${mod.optionCount} options)`);
    }
    lines.push("");
  }

  lines.push("");
  lines.push("## lib");
  lines.push("");
  lines.push("- [lib.use](lib/use.md) - Main flake entry point");
  lines.push("");

  return lines.join("\n");
}
