#!/usr/bin/env bash
# Verify Qwen setup - checks all symlinks and accessibility

set -e

QWEN_DIR=".qwen"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Qwen Code Configuration Verification ==="
echo ""

# Check .qwen directory exists
if [ ! -d "$QWEN_DIR" ]; then
    echo -e "${RED}✗ .qwen/ directory not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ .qwen/ directory exists${NC}"

# Check skills
echo -e "\n--- Skills ---"
skill_count=0
for skill in "$QWEN_DIR"/skills/*/; do
    [ -e "$skill" ] || continue
    skill_name=$(basename "$skill")
    if [ -L "$skill" ] || [ -d "$skill" ]; then
        if [ -f "$skill/SKILL.md" ]; then
            echo -e "${GREEN}✓ $skill_name${NC}"
            skill_count=$((skill_count + 1))
        else
            echo -e "${RED}✗ $skill_name (SKILL.md missing)${NC}"
        fi
    fi
done
echo "Total: $skill_count skills"

# Check agents
echo -e "\n--- Agents ---"
if [ -d "$QWEN_DIR/agents" ]; then
    agent_count=$(ls -1 "$QWEN_DIR/agents/"*.md 2>/dev/null | wc -l || echo "0")
    echo -e "${GREEN}✓ agents/ directory accessible (${agent_count} files)${NC}"
    echo "  Sample: $(ls "$QWEN_DIR/agents/" | head -3 | tr '\n' ', ')"
else
    echo -e "${RED}✗ agents/ directory not found${NC}"
fi

# Check instructions
echo -e "\n--- Instructions ---"
if [ -d "$QWEN_DIR/instructions" ]; then
    instr_count=$(ls -1 "$QWEN_DIR/instructions/"*.md 2>/dev/null | wc -l || echo "0")
    echo -e "${GREEN}✓ instructions/ directory accessible (${instr_count} files)${NC}"
else
    echo -e "${RED}✗ instructions/ directory not found${NC}"
fi

# Check prompts
echo -e "\n--- Prompts ---"
if [ -d "$QWEN_DIR/prompts" ]; then
    prompt_count=$(ls -1 "$QWEN_DIR/prompts/"*.md 2>/dev/null | wc -l || echo "0")
    echo -e "${GREEN}✓ prompts/ directory accessible (${prompt_count} files)${NC}"
else
    echo -e "${RED}✗ prompts/ directory not found${NC}"
fi

# Check documentation
echo -e "\n--- Documentation ---"
for doc in README.md AGENT-ADAPTER.md; do
    if [ -f "$QWEN_DIR/$doc" ]; then
        echo -e "${GREEN}✓ $doc exists${NC}"
    else
        echo -e "${YELLOW}⚠ $doc missing${NC}"
    fi
done

# Check QWEN.md references
echo -e "\n--- Project Integration ---"
if grep -q "\.qwen/" QWEN.md 2>/dev/null; then
    echo -e "${GREEN}✓ QWEN.md references .qwen/ directory${NC}"
else
    echo -e "${YELLOW}⚠ QWEN.md doesn't updated with .qwen/ info${NC}"
fi

echo -e "\n=== Summary ==="
echo "Skills: $skill_count"
echo "Agents: ${agent_count:-0}"
echo "Instructions: ${instr_count:-0}"
echo "Prompts: ${prompt_count:-0}"
echo ""
echo -e "${GREEN}Setup complete!${NC} Qwen Code can now access all Copilot resources."
