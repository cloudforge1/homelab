# GitHub Copilot Agent File Architecture

> **Purpose**: This guide explains how GitHub Copilot processes agent files (`.github/agents/*.md`), what gets attention, what gets ignored, and how to structure content for optimal LLM comprehension.

---

## How Copilot Processes Agent Files

### File Discovery & Loading

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COPILOT CONTEXT ASSEMBLY                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   User Invokes @reviewer                                                    │
│            │                                                                │
│            ▼                                                                │
│   ┌─────────────────────────────────────────────────────────┐              │
│   │  1. AGENT DISCOVERY                                      │              │
│   │     Search: .github/agents/{agent-name}.md               │              │
│   │     Fallback: AGENTS.md, CLAUDE.md, GEMINI.md           │              │
│   └─────────────────────────────────────────────────────────┘              │
│            │                                                                │
│            ▼                                                                │
│   ┌─────────────────────────────────────────────────────────┐              │
│   │  2. CONTEXT LOADING (Priority Order)                     │              │
│   │     ┌────────────────────────────────────────────────┐  │              │
│   │     │ SYSTEM PROMPT (immutable, from Copilot)        │  │              │
│   │     ├────────────────────────────────────────────────┤  │              │
│   │     │ copilot-instructions.md (repo-wide rules)      │  │ ◄── Always  │
│   │     ├────────────────────────────────────────────────┤  │     loaded  │
│   │     │ .github/instructions/*.md (path-specific)      │  │ ◄── mVat    │
│   │     ├────────────────────────────────────────────────┤  │              │
│   │     │ Agent file content (role-specific)             │  │              │
│   │     ├────────────────────────────────────────────────┤  │              │
│   │     │ User's current message                         │  │              │
│   │     └────────────────────────────────────────────────┘  │              │
│   └─────────────────────────────────────────────────────────┘              │
│            │                                                                │
│            ▼                                                                │
│   ┌─────────────────────────────────────────────────────────┐              │
│   │  3. TOKEN ALLOCATION                                     │              │
│   │     ┌────────────────────────────────────────────────┐  │              │
│   │     │ System + Instructions ≈ 15-20% of context      │  │              │
│   │     │ Agent file          ≈ 10-15% of context        │  │              │
│   │     │ Conversation history ≈ 20-30% of context       │  │              │
│   │     │ User request + files ≈ 35-55% of context       │  │              │
│   │     └────────────────────────────────────────────────┘  │              │
│   └─────────────────────────────────────────────────────────┘              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### What Gets Attention

LLMs have **attention mechanisms** that determine which parts of input text influence the output most.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ATTENTION DISTRIBUTION                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Document Start                                                            │
│   ┌─────────────────────────────────────────────┐                          │
│   │ ███████████████████████████████████████████ │ ◄── PRIMACY ZONE        │
│   │ ███████████████████████████████████████████ │     High attention       │
│   │ ███████████████████████████████████████████ │     (~first 500 tokens)  │
│   ├─────────────────────────────────────────────┤                          │
│   │ ██████████████████████████████████████      │                          │
│   │ █████████████████████████████████           │ ◄── MID ZONE            │
│   │ ████████████████████████████                │     Moderate attention   │
│   │ ███████████████████████                     │     (reference material) │
│   │ ██████████████████                          │                          │
│   │ █████████████                               │                          │
│   │ ██████████                                  │ ◄── ATTENTION VALLEY    │
│   │ ████████                                    │     Lowest attention     │
│   │ ██████                                      │     (easily forgotten)   │
│   │ ████████                                    │                          │
│   │ ██████████                                  │                          │
│   │ █████████████████                           │                          │
│   │ ████████████████████████                    │                          │
│   │ ███████████████████████████████████████████ │ ◄── RECENCY ZONE        │
│   │ ███████████████████████████████████████████ │     High attention       │
│   │ ███████████████████████████████████████████ │     (~last 500 tokens)   │
│   └─────────────────────────────────────────────┘                          │
│   Document End                                                              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key Insight**: Place critical rules at the TOP (primacy) and BOTTOM (recency). Reference material goes in the middle.

---

## Agent File Structure Template

Based on LLM attention patterns, use this structure:

```markdown
---
# YAML FRONTMATTER (parsed by Copilot, not in context)
name: agent-name
description: One-line description shown in agent picker
model: Claude Opus 4.6
handoffs:
  - label: "Handoff Label"
    agent: target-agent
    prompt: "Context passed to target agent"
---

# 🏷️ Agent Title (emoji helps visual parsing)

> **EXECUTIVE SUMMARY**: 2-3 sentences with key facts. Who am I? 
> What do I do? Who do I work with? This gets HIGH attention.

---

## 🚫 Do NOT (Critical Constraints)        ◄── PRIMACY ZONE

- **Do NOT** {forbidden action 1}
- **Do NOT** {forbidden action 2}

---

## ✅ Do (Required Behaviors)              ◄── PRIMACY ZONE

### Introduction Protocol
### Core Process
### Tools Reference Table

---

## 📋 Specifications                       ◄── MID ZONE (reference)

### Mode/State Matrix
### Mode Details

---

## 📝 Output Templates                     ◄── MID ZONE (reference)

### Template structures for outputs

---

## 🔒 Checklists                           ◄── RECENCY ZONE

- [ ] Item 1
- [ ] Item 2

---

## 🎯 Coordination                         ◄── RECENCY ZONE

### Upstream/Downstream agents
```

---

## mVat Agent Ecosystem

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     mVat AGENT HANDOFF ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   copilot-instructions.md                                                   │
│   ├── Loaded for ALL agents (base context)                                 │
│   └── Defines: Prisma types, Fastify, Zustand, mVat patterns               │
│                                                                             │
│   .github/instructions/                    ◄── mVat-specific               │
│   ├── api-backend.instructions.md                                          │
│   ├── app-frontend.instructions.md                                         │
│   ├── jpk-implementation.instructions.md                                   │
│   └── ... (9 path-specific instruction files)                              │
│                                                                             │
│   .github/agents/                                                           │
│   ├── orchestrator.md    ◄── Entry point, manages workflow                 │
│   │                                                                         │
│   ├── architect-*.md     ◄── Design phase agents                           │
│   │   ├── architect-api.md                                                 │
│   │   ├── architect-data.md                                                │
│   │   └── architect-ui.md                                                  │
│   │                                                                         │
│   ├── impl-*.md          ◄── Implementation phase agents                   │
│   │   ├── impl-nestjs.md   ◄── NestJS + Fastify (NOT Express)             │
│   │   ├── impl-react.md    ◄── React 19 + Zustand                         │
│   │   ├── impl-prisma.md   ◄── Prisma schema + migrations                 │
│   │   ├── impl-jpk.md      ◄── mVat-specific: JPK/KSEF compliance         │
│   │   └── impl-auth.md                                                     │
│   │                                                                         │
│   └── qa-*.md            ◄── Quality assurance agents                      │
│       ├── reviewer.md                                                      │
│       ├── tester.md                                                        │
│       └── documentor.md                                                    │
│                                                                             │
│   Handoff Flow:                                                             │
│   ┌────────────┐   design   ┌─────────────┐   impl    ┌──────────┐        │
│   │orchestrator│ ─────────→ │ architect-* │ ────────→ │ impl-*   │        │
│   └────────────┘            └─────────────┘           └──────────┘        │
│         ▲                                                   │              │
│         │                                                   ▼              │
│         │              ┌──────────┐    approved    ┌──────────┐           │
│         └───────────── │ reviewer │ ◄──────────── │  tester  │           │
│                        └──────────┘               └──────────┘           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## High-Signal Keywords

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        HIGH-SIGNAL KEYWORDS                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   PROHIBITION PATTERNS (strongest constraint signal)                        │
│   ───────────────────────────────────────────────────                      │
│   • "Do NOT"           • "NEVER"           • "MUST NOT"                    │
│   • "FORBIDDEN"        • "PROHIBITED"      • "CRITICAL: avoid"             │
│                                                                             │
│   OBLIGATION PATTERNS (strong action signal)                                │
│   ───────────────────────────────────────────────────                      │
│   • "MUST"             • "ALWAYS"          • "REQUIRED"                    │
│   • "MANDATORY"        • "SHALL"           • "ENSURE"                      │
│                                                                             │
│   mVat-SPECIFIC PATTERNS (domain signals)                                   │
│   ───────────────────────────────────────────────────                      │
│   • "Prisma types"     • "Fastify"         • "NOT Express"                 │
│   • "Zustand"          • "NOT Context"     • "ShimmerMask"                 │
│   • "JPK"              • "KSEF"            • "Polish_CI_AS"                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Agent File Best Practices

### Do ✅

| Practice                                     | Rationale                                          |
|----------------------------------------------|----------------------------------------------------|
| Start with Executive Summary                 | Primacy effect ensures core identity is understood |
| Put "Do NOT" rules immediately after summary | Negative constraints are high-signal               |
| Use tables for structured data               | Better token efficiency than prose                 |
| Include templates with placeholders          | Gives concrete output structure                    |
| Place checklists at document end             | Recency effect for action items                    |
| Keep agent files under 5000 tokens           | Avoid context budget overflow                      |
| Reference `.github/instructions/`            | mVat path-specific rules                           |

### Do NOT ❌

| Anti-Pattern                      | Problem                               |
|-----------------------------------|---------------------------------------|
| Long prose paragraphs             | Low signal density, wastes tokens     |
| Critical rules in document middle | Attention valley = forgotten          |
| Deeply nested headers (H4+)       | Attention decay, structure lost       |
| Vague instructions ("be careful") | No actionable constraint              |
| Missing output templates          | Agent invents format each time        |
| Ignoring mVat patterns            | Violates Prisma/Fastify/Zustand rules |

---

## Processing Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      AGENT FILE PROCESSING PIPELINE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌───────────────┐                                                        │
│   │  Agent File   │                                                        │
│   │  (.md)        │                                                        │
│   └───────┬───────┘                                                        │
│           │                                                                 │
│           ▼                                                                 │
│   ┌───────────────────────────────────────────────────────────┐            │
│   │ STAGE 1: YAML FRONTMATTER EXTRACTION                       │            │
│   │ ─────────────────────────────────────────────────────────  │            │
│   │ • name → Agent picker display                              │            │
│   │ • description → Agent picker tooltip                       │            │
│   │ • model → Model selection                                  │            │
│   │ • handoffs → Handoff menu options                          │            │
│   │                                                            │            │
│   │ ⚠️ YAML is PARSED, not included in LLM context             │            │
│   └───────────────────────────────────────────────────────────┘            │
│           │                                                                 │
│           ▼                                                                 │
│   ┌───────────────────────────────────────────────────────────┐            │
│   │ STAGE 2: MARKDOWN BODY → CONTEXT INJECTION                 │            │
│   │ ─────────────────────────────────────────────────────────  │            │
│   │ • Everything after `---` closing tag                       │            │
│   │ • HTML comments ARE included (meta-instructions)           │            │
│   │ • Markdown rendered to plain text for tokenization         │            │
│   │                                                            │            │
│   │ ✓ This becomes part of the system prompt                   │            │
│   └───────────────────────────────────────────────────────────┘            │
│           │                                                                 │
│           ▼                                                                 │
│   ┌───────────────────────────────────────────────────────────┐            │
│   │ STAGE 3: ATTENTION COMPUTATION                             │            │
│   │ ─────────────────────────────────────────────────────────  │            │
│   │ • Primacy: First ~500 tokens → HIGH attention              │            │
│   │ • Recency: Last ~500 tokens → HIGH attention               │            │
│   │ • Middle: Variable attention (reference lookups)           │            │
│   │                                                            │            │
│   │ User message gets HIGHEST attention (most recent)          │            │
│   └───────────────────────────────────────────────────────────┘            │
│           │                                                                 │
│           ▼                                                                 │
│   ┌───────────────┐                                                        │
│   │  LLM Output   │                                                        │
│   └───────────────┘                                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Debugging Agent Behavior

If your agent isn't following instructions:

1. **Check primacy**: Is the rule in the first 500 tokens?
2. **Check recency**: Is it in the last 500 tokens?
3. **Check signal**: Is it using strong keywords (MUST, NEVER)?
4. **Check format**: Is it bold, in a list, or in a table?
5. **Check conflict**: Does `copilot-instructions.md` contradict?
6. **Check length**: Is the agent file too long (>5000 tokens)?
7. **Check mVat rules**: Are `.github/instructions/*.md` files loaded?

---

## See Also

- [.github/copilot-instructions.md](../../.github/copilot-instructions.md) — Main project rules
- [.github/instructions/](../../.github/instructions/) — Path-specific instructions
- [.github/agents/](../../.github/agents/) — All agent definitions
- [.github/prompts/](../../.github/prompts/) — Reusable prompts
- [docs/adr/](../adr/) — Architecture decisions (WHAT)
- [docs/roadmap/](../roadmap/) — Migration tasks (HOW)
