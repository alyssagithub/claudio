export type Picture = {
  mediaType: string;
  data: string;
};

export type DecodedImage = {
  width: number;
  height: number;
  data: Uint8Array;
};

export type SentImage = {
  width: number;
  height: number;
  pixels: string;
};

export type ImageSource = {
  type: string;
  media_type: string;
  data: string;
};

export type ContentBlock = {
  type: string;
  text?: string;
  thinking?: string;
  id?: string;
  name?: string;
  input?: unknown;
  tool_use_id?: string;
  content?: ContentBlock[] | string;
  is_error?: boolean;
  source?: ImageSource;
};

export type Content = ContentBlock[] | string;

export type SdkUsage = {
  input_tokens?: number;
  output_tokens?: number;
  cache_read_input_tokens?: number;
  cache_creation_input_tokens?: number;
};

export type TranscriptLine = {
  type?: string;
  isMeta?: boolean;
  isSidechain?: boolean;
  timestamp?: string;
  requestId?: string;
  cwd?: string;
  message?: {
    id?: string;
    role?: string;
    content?: Content;
    usage?: SdkUsage;
    model?: string;
  };
};

export type Tokens = {
  input: number;
  output: number;
  cached: number;
};

export type Usage = {
  Input: number;
  Output: number;
  Cached: number;
};

export type LineCount = {
  added: number;
  removed: number;
};

export type Delegate = {
  name: string;
  model: string;
};

export type CallStatus = "preparing" | "running" | "done" | "error";

export type Call = {
  Id: string;
  Name: string;
  Input: string;
  Output: string;
  Status: CallStatus;
  StartedAt: number;
  Milliseconds: number;
  Steps?: string[];
  Delegate: Delegate | null;
  Lines?: LineCount | null;
  Image?: number | null;
};

export type SentCall = {
  name: string;
  input: string;
  output: string;
  status: string;
  steps: string[];
  milliseconds: number;
  delegate: Delegate | null;
  lines: LineCount | null;
  image: number | null;
};

export type StoredCall = {
  name: string;
  input: string;
  output: string;
  status: string;
  milliseconds: number;
  image: number | null;
};

export type Part = {
  kind: string;
  text?: string;
  id?: string;
  call?: number;
};

export type StoredMessage = {
  role: string;
  text: string;
  activity?: string[];
  parts?: Part[];
  calls?: StoredCall[];
  images: number[];
  at: number | null;
  tokens?: Tokens | null;
  cost?: number;
  estimated?: boolean;
};

export type Conversation = {
  id: string;
  title: string;
  project: string | null;
  workingDirectory: string | null;
  messages: StoredMessage[];
  total?: number;
  first?: number;
};

export type Summary = {
  id: string;
  title: string;
  project: string;
  folder: string | null;
  startedAt: number;
  endedAt: number;
  messages: number;
  starred: boolean;
  archived: boolean;
  mine: boolean;
};

export type Chapter = {
  index: number;
  title: string;
};

export type Limit = {
  label?: string;
  utilization?: number;
  resetsAt?: number;
};

export type Breakdown = {
  total: number;
  max: number;
  percentage: number;
  model: string | null;
  categories: unknown[];
};

export type Task = {
  Id: string;
  Description: string;
  Kind: string;
  Status: string;
  Background: boolean;
  Depth: number;
  Error?: string | null;
};

export type Asked = {
  Id: string;
  Questions: Question[];
  Resolve: (Answers: unknown) => void;
};

export type Question = {
  header: string;
  question: string;
  multiSelect: boolean;
  options: {
    label: string;
    description: string;
  }[];
};

export type Job = {
  id: string;
  kind: string;
  input: Record<string, unknown>;
  role?: string;
};

export type JobAnswer = Record<string, unknown> & {
  error?: string;
  text?: string;
};

export type ScriptEntry = {
  path: string;
  source: string;
};

export type TreeEntry = {
  path: string;
  className: string;
};

export type Warning = {
  line: number;
  kind: string;
  message: string;
};

export type ModelInfo = {
  value: string;
  label: string;
  description: string;
  version?: string;
};

export type Tier = {
  model: string;
  effort: string | null;
  delegate: string;
};

export type Mode = {
  value: string;
  label: string;
  detail: string;
};

export type Allowance = "once" | "always" | "no";

export type Permission = {
  Id: string;
  ToolName: string;
  Input: unknown;
  Resolve: (Answer: unknown) => void;
};

import type { Query } from "@anthropic-ai/claude-agent-sdk";

export type { Query };

export type Session = {
  Key: string;
  ConversationId: string | null;
  WorkingDirectory: string;
  Model: string;
  Mode: string;
  Delegate: string;
  Delegating: boolean;
  Planning: boolean;
  AskForTools: boolean;
  GuardTools: boolean;
  CapResults?: boolean;
  ExtraPrompt: boolean;
  FastMode: boolean;
  Effort: string | null;
  HasSpoken?: boolean;
  Ended?: boolean;
  LastUsedAt: number;
  Spent?: number;
  Place?: string | null;
  PendingPlace?: string | null;
  PendingContext?: string | null;
  Breakdown?: Breakdown | null;
  CurrentTurn: Turn | null;
  FilesBefore: Map<string, string>;
  LineCounts: Map<string, LineCount>;
  Query: Query | null;
  Send: (Message: unknown) => void;
  Close: () => void;
};

export type SdkMessage = {
  type: string;
  subtype?: string;
  session_id?: string;
  uuid?: string;
  parent_tool_use_id?: string | null;
  message?: {
    id?: string;
    role?: string;
    content?: Content;
    usage?: SdkUsage;
  };
  event?: {
    type: string;
    delta?: {
      type: string;
      text?: string;
      thinking?: string;
      partial_json?: string;
    };
    content_block?: ContentBlock;
  };
  duration_ms?: number;
  total_cost_usd?: number;
  usage?: SdkUsage;
  permission_denials?: {tool_name: string}[];
  result?: string;
  is_error?: boolean;
  modelUsage?: Record<string, unknown>;
};

export type Turn = {
  Id: string;
  ConversationId: string | null;
  SessionId: string | null;
  Prompt: string;
  Auto: boolean;
  CapResults: boolean;
  Planning: boolean;
  Delegating: boolean;
  Tasks: Task[];
  Model: string;
  Effort: string | null;
  Delegate: string;
  AskForTools: boolean;
  GuardTools: boolean;
  ExtraPrompt: boolean;
  FastMode: boolean;
  Bypass: boolean;
  Mode: string;
  WorkingDirectory: string;
  Status: string;
  CommittedText: string;
  PendingText: string;
  CommittedThinking: string;
  PendingThinking: string;
  Parts: Part[];
  Flushed: boolean;
  Streamed: number;
  OutputShown?: number;
  Activity: string[];
  Calls: Call[];
  Usage: Usage;
  StartedAt: number;
  OpenedAt?: number;
  FirstTextAt?: number;
  Cold?: boolean;
  Milliseconds: number;
  Cost: number;
  ContextWindow: number;
  ContextModel: string | null;
  Images: SentImage[];
  Delivered: Record<number, boolean>;
  Permissions: Permission[];
  PermissionCount: number;
  Question: Asked | null;
  Error: string | null;
  Version: number;
  Waiters: (() => void)[];
  Session?: Session | null;
};

export type TurnRequest = {
  Text: string;
  ConversationId: string | null;
  Images: Picture[];
  Model: string;
  Effort: string | null;
  AskForTools?: boolean;
  GuardTools?: boolean;
  Escalate?: boolean;
  ExtraPrompt?: boolean;
  FastMode?: boolean;
  Mode: string;
  Bypass?: boolean;
  Place?: {name?: string, placeId?: number, universeId?: number} | null;
  Folder?: string | null;
};