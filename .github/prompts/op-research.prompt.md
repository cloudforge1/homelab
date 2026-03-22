---
description: "Investigate a FastDeploy custom operator: find its CUDA source, registration signature, Python binding, and existing tests. Use when researching an op before writing tests or implementations."
agent: "agent"
argument-hint: "Op name, e.g. 'append_attention' or 'moe_wna16_marlin_gemm'"
---
# Research a Custom Operator

Investigate a FastDeploy custom op to understand its signature, behavior, and test requirements.

## Investigation Steps

1. **Find registration** in `custom_ops/gpu_ops/cpp_extensions.cc`:
   ```bash
   grep -n '{OP_NAME}' FastDeploy/custom_ops/gpu_ops/cpp_extensions.cc
   ```
   Look for `m.def(...)` — this gives the function signature, input/output types, and whether it's inplace (`SetInplaceMap`).

2. **Find CUDA source**: Check `custom_ops/gpu_ops/` directory tree:
   ```bash
   find FastDeploy/custom_ops/gpu_ops -name '*.cu' -o -name '*.cuh' | xargs grep -l '{OP_NAME}'
   ```

3. **Find Python binding** in `fastdeploy/model_executor/ops/gpu/`:
   ```bash
   grep -rn '{OP_NAME}' FastDeploy/fastdeploy/model_executor/ops/gpu/
   ```

4. **Check existing tests**:
   ```bash
   ls FastDeploy/tests/operators/test_*{OP_NAME}* 2>/dev/null
   ```

5. **Check if inplace**: Look for `SetInplaceMap` in the `.cu` file — if present, the op modifies inputs and returns None.

6. **Check task checkpoint**: `cat .checkpoints/task-NNN/checkpoint.md` for any prior research notes.

## Output Format

Report:
- **Op name**: full registered name
- **Signature**: input types, output types, parameters
- **Inplace?**: yes/no
- **CUDA source**: file path + key line numbers
- **Python binding**: file path
- **Existing tests**: any existing test files
- **Key behavior**: what the op does (1-2 sentences)
- **Test strategy**: recommended approach for unit testing
