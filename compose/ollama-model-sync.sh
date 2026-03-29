#!/bin/sh
set -eu

timeout_secs="${MODEL_SYNC_TIMEOUT_SECS:-1800}"
elapsed=0
until ollama list >/dev/null 2>&1; do
  if [ "$elapsed" -ge "$timeout_secs" ]; then
    echo "Ollama API did not become ready within ${timeout_secs}s" >&2
    exit 1
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done

pull_if_enabled() {
  flag="$1"
  model="$2"
  value="$(printenv "$flag" 2>/dev/null || true)"
  if [ "${value:-false}" = "true" ]; then
    echo "==> pulling ${model}"
    ollama pull "$model"
  else
    echo "==> skipping ${model} (${flag}=${value:-false})"
  fi
}

pull_if_enabled ENABLE_MODEL_NEMOTRON_3_SUPER nemotron-3-super
pull_if_enabled ENABLE_MODEL_QWEN3_CODER_NEXT qwen3-coder-next
pull_if_enabled ENABLE_MODEL_DEVSTRAL_2 devstral-2
pull_if_enabled ENABLE_MODEL_NEMOTRON_CASCADE_2 nemotron-cascade-2
pull_if_enabled ENABLE_MODEL_NEMOTRON_3_NANO_30B nemotron-3-nano:30b
pull_if_enabled ENABLE_MODEL_QWEN3_VL_30B qwen3-vl:30b
pull_if_enabled ENABLE_MODEL_QWEN3_VL_8B qwen3-vl:8b
pull_if_enabled ENABLE_MODEL_LFM2_24B lfm2:24b
pull_if_enabled ENABLE_MODEL_GLM_4_7_FLASH glm-4.7-flash
pull_if_enabled ENABLE_MODEL_QWEN3_NEXT qwen3-next
pull_if_enabled ENABLE_MODEL_GPT_OSS_20B gpt-oss:20b
pull_if_enabled ENABLE_MODEL_OLMO_3_1_32B olmo-3.1:32b

pull_if_enabled ENABLE_MODEL_QWEN35_9B "qwen3.5:9b"
pull_if_enabled ENABLE_MODEL_QWEN35_122B "qwen3.5:122b"
echo "==> final model list"
ollama list
