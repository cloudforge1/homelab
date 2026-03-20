---
applyTo: '**'
description: 'Tools, MCP servers, and AI model selection guidance for mVat development'
---

# Copilot Tools, MCP & Model Selection Instructions

**Last Updated**: 2025-12-24  
**Scope**: AI tool selection, MCP server usage, and model recommendations for mVat development

## 🔧 Available MCP Tools by Category

### 1. Context7 - Library Documentation (ESSENTIAL)

**When to use**: Any library/framework questions (React, NestJS, Prisma, Zod, etc.)

```
ALWAYS use this flow:
1. mcp_context7_resolve-library-id → Get library ID
2. mcp_context7_get-library-docs → Fetch documentation

Example libraries for this project:
- "/prisma/docs" - Prisma ORM
- "/vercel/next.js" - Reference patterns
- "/TanStack/query" - TanStack Query
- "/pmndrs/zustand" - Zustand state
- "/colinhacks/zod" - Zod validation
- "/nestjs/nest" - NestJS framework
- "/fastify/fastify" - Fastify
- "/microsoft/playwright" - E2E testing
```

### 2. GitHub Tools (Repository Operations)

**When to use**: PR reviews, issue management, code search

| Task | Tool | Notes |
|------|------|-------|
| Create PR | `activate_repository_management_tools` | Use PR templates from `.github/` |
| Review PR | `mcp_io_github_git_request_copilot_review` | Auto-review before human |
| Search code | `activate_search_and_discovery_tools` | Cross-repo code search |
| Branch ops | `activate_branch_and_commit_tools` | List branches, commits |

### 3. Browser/Playwright Tools (UI Testing)

**When to use**: E2E testing, accessibility audits, performance checks

```
Navigation: activate_browser_navigation_tools
Screenshots: activate_snapshot_capture_tools
Forms: activate_form_input_tools
Performance: activate_performance_monitoring_tools
Console: activate_console_logging_tools
```

### 4. Docker/Container Tools

**When to use**: MSSQL database management, Azurite emulator

```
Containers: activate_container_management_tools
Images: activate_image_management_tools
Inspect: activate_container_inspection_tools
List: activate_listing_tools
Cleanup: mcp_copilot_conta_prune
```

### 5. Database Tools (MSSQL)

**When to use**: Direct database queries, schema exploration

```
Connect: mssql_connect (serverName from mssql_list_servers)
Change DB: mssql_change_database
Explore: activate_mssql_database_exploration_tools
```

**mVat Database Names**:
- Global: `mvat_global`
- Entity: `mvat_entity_{entityId}`

### 6. Python Tools (Scripts/Analysis)

**When to use**: Data analysis, migration scripts, code generation

```
Environment: configure_python_environment (CALL FIRST!)
Execute: activate_python_code_validation_and_execution
Analysis: activate_import_analysis_and_dependency_management
```

### 7. Prisma Tools (Migrations)

**When to use**: Schema changes, database migrations

```
Migrations: activate_prisma_migration_tools
Database: activate_prisma_database_management_tools
```

### 8. Lighthouse/Performance Tools

**When to use**: Web performance, SEO, accessibility audits

```
Performance: activate_website_performance_and_accessibility_tools
Resources: activate_website_resource_optimization_tools
Security: activate_website_security_and_audit_tools
```

### 9. Serena/Code Analysis Tools

**When to use**: Complex code refactoring, symbol management

```
File search: activate_file_search_and_listing_tools
Symbols: activate_symbol_management_tools
Insertion: activate_symbol_insertion_tools
Memory: activate_memory_management_tools
Task check: mcp_oraios_serena_think_about_task_adherence
```

### 10. Pylance/Python Refactoring

**When to use**: Python code refactoring, import organization

```
mcp_pylance_mcp_s_pylanceInvokeRefactoring:
- source.unusedImports - Remove unused imports
- source.convertImportFormat - Fix import format
- source.addTypeAnnotation - Add type hints
```

---

## 🤖 AI Model Selection Guide

### Model Capabilities by Task

| Task Category | Recommended Model | Reason |
|---------------|-------------------|--------|
| **Architecture** | Claude Opus/Sonnet | Deep reasoning, long context |
| **Code Generation** | Claude Opus/Sonnet | Precise TypeScript, patterns |
| **Code Review** | Any capable model | Pattern matching |
| **Documentation** | Claude Opus/Sonnet | Clear technical writing |
| **Debugging** | Claude Opus/Sonnet | Stack trace analysis |
| **Quick Fixes** | Any capable model | Simple transformations |
| **Refactoring** | Claude Opus/Sonnet | Preserve behavior |

### When to Use `aitk-get_ai_model_guidance`

Call this tool when:
- User asks about model choice
- Switching between model providers
- Comparing model capabilities
- Model-related errors occur

### When to Use `aitk-get_agent_code_gen_best_practices`

Call this tool BEFORE:
- Creating AI/agent applications
- Implementing agentic workflows
- Connecting to external AI tools

---

## 📋 MCP Tool Selection Decision Tree

```
User Request
    │
    ├─► Need library docs? ──────────► Context7 (resolve → get-docs)
    │
    ├─► GitHub operations? ──────────► GitHub MCP tools
    │
    ├─► Database query? ─────────────► MSSQL tools (connect → query)
    │
    ├─► UI/E2E testing? ─────────────► Playwright/Browser tools
    │
    ├─► Performance audit? ──────────► Lighthouse tools
    │
    ├─► Container ops? ──────────────► Docker tools
    │
    ├─► Code refactoring? ───────────► Serena/Pylance tools
    │
    ├─► Python scripts? ─────────────► Python tools (configure first!)
    │
    └─► Schema changes? ─────────────► Prisma migration tools
```

---

## 🎯 Project-Specific Tool Patterns

### 1. Adding New Prisma Model

```
1. Edit schema in src/prisma/dbs/{entity|global}/schemas/
2. activate_prisma_migration_tools → prisma-migrate-dev
3. Run: pnpm prisma generate
4. Update @mvat/shared types
```

### 2. Debugging Sync Issues

```
1. mssql_connect to entity database
2. Query sync-related tables
3. activate_container_inspection_tools for Docker logs
4. Check IndexedDB via browser tools
```

### 3. Performance Optimization

```
1. activate_website_performance_and_accessibility_tools
2. mcp_lighthouse_get_core_web_vitals
3. mcp_lighthouse_get_lcp_opportunities
4. activate_website_resource_optimization_tools
```

### 4. Code Review Workflow

```
1. activate_pull_request_management_tools → list PRs
2. mcp_io_github_git_request_copilot_review → auto-review
3. activate_pull_request_review_tools → add comments
4. Submit review
```

---

## ⚠️ Tool Usage Warnings

### DO NOT

- Call `mssql_*` without `mssql_connect` first
- Use Python tools without `configure_python_environment` first
- Run Prisma migrations on production without backup
- Skip Context7 when asking about library APIs

### ALWAYS

- Use absolute paths for file operations
- Check terminal output after `run_in_terminal`
- Validate database connections before queries
- Use `mcp_oraios_serena_think_about_task_adherence` for complex tasks

---

## 🔍 Quick Reference: Common Operations

| Operation | Tools/Commands |
|-----------|----------------|
| Check React docs | Context7: `/facebook/react` |
| Check Prisma docs | Context7: `/prisma/docs` |
| List containers | `activate_listing_tools` |
| Connect to DB | `mssql_connect` |
| Run E2E test | Browser navigation + snapshot tools |
| Audit performance | Lighthouse tools |
| Review PR | GitHub MCP tools |
| Python script | `configure_python_environment` first |
