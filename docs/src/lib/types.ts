export interface ModuleOption {
  name: string;
  type: string;
  default?: string;
  description: string;
  example?: string;
  readOnly: boolean;
  declarations: string[];
}

export interface ModuleData {
  modulePath: string;
  category: string;
  name: string;
  options: ModuleOption[];
}

export interface IndexEntry {
  modulePath: string;
  category: string;
  name: string;
  optionCount: number;
  options: { name: string; type: string; description: string }[];
}

export interface UseParam {
  hasDefault: boolean;
  description: string;
  type: string;
  default?: string;
}

export type UseParams = Record<string, UseParam>;
