// ABOUTME: TypeScript type definitions for API server
// ABOUTME: Defines message formats, tool interfaces, and agent result types

export interface Message {
  role: "user" | "assistant";
  content: string | ContentBlock[];
}

export interface ContentBlock {
  type: "text" | "tool_use" | "tool_result";
  text?: string;
  id?: string;
  name?: string;
  input?: Record<string, any>;
  tool_use_id?: string;
  content?: string;
  is_error?: boolean;
}

export interface ToolUse {
  id: string;
  name: string;
  input: Record<string, any>;
}

export interface LLMHistoryEntry {
  type:
    | "user_prompt"
    | "llm_response"
    | "tool_call"
    | "tool_result"
    | "tool_error";
  timestamp: string;
  content?: any;
  stop_reason?: string;
  tool_use_id?: string;
  tool_name?: string;
  arguments?: Record<string, any>;
  result?: string;
  error?: string;
}

export interface AgenticLoopResult {
  finalResponse: string;
  llmHistory: LLMHistoryEntry[];
  geoFeatures: GeoFeature[];
}

export interface GeoFeature {
  id: string;
  type: "marker";
  lat: number;
  lon: number;
  label?: string;
}

export interface StreamUpdate {
  type:
    | "user_prompt"
    | "tool_call"
    | "tool_result"
    | "tool_error"
    | "llm_response"
    | "geo_feature"
    | "remove_geo_feature";
  data: any;
}
