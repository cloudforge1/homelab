# Homelab AI/ML Tools Investigation

## Table of Contents

- [1. Executive Summary](#1-executive-summary)
- [2. Your 5 Requested Tools](#2-your-5-requested-tools)
- [3. Top Tools by Category](#3-top-tools-by-category)
  - [3.1 Document OCR & Understanding](#31-document-ocr--understanding)
  - [3.2 Speech-to-Text (Transcription)](#32-speech-to-text-transcription)
  - [3.3 Text-to-Speech (TTS)](#33-text-to-speech-tts)
  - [3.4 Audio Separation & Processing](#34-audio-separation--processing)
  - [3.5 Translation](#35-translation)
  - [3.6 Image Generation](#36-image-generation)
  - [3.7 Image Enhancement & Restoration](#37-image-enhancement--restoration)
  - [3.8 AI Code Assistant](#38-ai-code-assistant)
  - [3.9 LLM Inference](#39-llm-inference)
  - [3.10 LLM VRAM Optimization](#310-llm-vram-optimization)
  - [3.11 Model Manipulation](#311-model-manipulation)
  - [3.12 LLM Gateway & Routing](#312-llm-gateway--routing)
  - [3.13 Video Download & Processing](#313-video-download--processing)
  - [3.14 RAG & Document Chat](#314-rag--document-chat)
  - [3.15 Email Privacy](#315-email-privacy)
  - [3.16 Privacy & Anonymization](#316-privacy--anonymization)
  - [3.17 AI Memory & Cognitive](#317-ai-memory--cognitive)
  - [3.18 NSFW / 18+ Tools](#318-nsfw--18-tools)
- [4. Baidu Open-Source AI/ML Ecosystem](#4-baidu-open-source-aiml-ecosystem)
  - [4.1 PaddlePaddle Ecosystem](#41-paddlepaddle-ecosystem-githubcompaddlepaddle---107-repos)
  - [4.2 Baidu Corporate Repos](#42-baidu-corporate-repos-githubcombaidu---122-repos)
  - [4.3 Baidu Cloud-Only (Not Self-Hostable)](#43-baidu-cloud-only-not-self-hostable)
- [5. Homelab Recommendations](#5-homelab-recommendations)
  - [5.1 Priority Deployment](#51-priority-deployment)
  - [5.2 Worth Evaluating](#52-worth-evaluating)
  - [5.3 Cloud-Only / Not Applicable](#53-cloud-only--not-applicable)
- [6. Already Deployed on cf0](#6-already-deployed-on-cf0)
- [7. Hardware Profile](#7-hardware-profile)

---

## 1. Executive Summary

This document catalogs single-purpose, self-hostable AI/ML tools across 18+ categories. Each entry is filtered for: Docker-ready or easy deploy, low-maintenance, consumer-hardware compatible (specifically GTX 1060 6GB / i9-9900K / 107GB RAM). The investigation also covers Baidu's open-source AI ecosystem (PaddlePaddle org + corporate repos) for a Chinese-language project.

---

## 2. Your 5 Requested Tools

### GLM-OCR
- **Category:** Document OCR
- **Purpose:** High-accuracy OCR for text, formulas, tables, layout → JSON/Markdown
- **Stack:** Python, 0.9B GLM-V architecture (CogViT encoder + GLM-0.5B decoder), Multi-Token Prediction, PP-DocLayout-V3 layout engine
- **Backends:** vLLM, SGLang, Ollama, MLX
- **Docker:** Yes (official `vllm/vllm-openai:nightly` and `lmsysorg/sglang:dev` images)
- **Hardware:** Only 0.9B params — efficient for edge devices and high-concurrency. Layout model can offload to CPU. Fully optimized for Apple Silicon via mlx-vlm.
- **Homelab Fit:** ✅ GTX 1060 CPU-friendly

### Reclip
- **Category:** Video Download
- **Purpose:** Download video/audio from 1,000+ platforms (YouTube, TikTok, Twitter/X, Instagram) as MP4/MP3
- **Stack:** Python + Flask (~150 lines), vanilla HTML/CSS/JS, yt-dlp + ffmpeg
- **Docker:** Yes (`docker build -t reclip . && docker run -p 8899:8899 reclip`)
- **Hardware:** Minimal — runs on any machine that can handle Python + ffmpeg + yt-dlp
- **Homelab Fit:** ✅ ~150 lines of Python, negligible resources

### AnonAddy
- **Category:** Email Privacy
- **Purpose:** Anonymous email forwarding, disposable aliases, spam filtering, GPG/OpenPGP encryption, anonymous replies
- **Stack:** PHP 8.2+, Vue.js, Blade, Postfix, Redis 7.x+, MariaDB/MySQL, Nginx, Rspamd
- **Docker:** Yes (official `github.com/anonaddy/docker`)
- **Hardware:** No specific specs. Requires **port 25 unblocked** + DNS/MX/SSL configuration.
- **Homelab Fit:** ⚠️ Needs port 25 + DNS/MX setup

### AirLLM
- **Category:** LLM Inference Optimization
- **Purpose:** Run 70B–405B parameter models on as low as 4GB GPU by splitting and dynamically streaming model layers from disk/CPU to GPU
- **Stack:** Python, Jupyter, Hugging Face ecosystem, safetensors, bitsandbytes (optional 4/8-bit quantization), Apple MLX
- **Docker:** Not provided
- **Hardware:** As low as single 4GB GPU (70B models) or 8GB VRAM (405B). Supports CPU inference. Requires sufficient disk space for model layers.
- **Homelab Fit:** ✅ CPU mode works on your i9-9900K

### Heretic
- **Category:** Model Decensor
- **Purpose:** Auto-uncensor LLMs via abliteration + Optuna TPE optimizer to suppress refusals while minimizing KL divergence
- **Stack:** Python 3.10+, PyTorch 2.2+, Optuna, bitsandbytes (optional 4-bit quantization)
- **Docker:** Not provided
- **Hardware:** GPU required. ~45 min to decensor 8B model on RTX 3090. bitsandbytes 4-bit reduces VRAM needs.
- **Homelab Fit:** ⚠️ Needs GPU + PyTorch

---

## 3. Top Tools by Category

### 3.1 Document OCR & Understanding

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **GLM-OCR** | ~4k | 0.9B multimodal OCR: text, formulas, tables → JSON/Markdown. Layout-aware, beats GPT-4o on some benchmarks. | ✅ vLLM/SGLang/MLX |
| **PaddleOCR-VL** | 75k | Industry-standard OCR, 100+ languages, Apache 2.0. Tops 2026 benchmarks, beats GPT-5.4 on consumer GPU. | ✅ |
| **Marker** | ~20k | PDF → Markdown with high accuracy. Single CLI, no GPU needed, 80+ languages, structured output. | ✅ |

**Also notable:** Surya (7k), Docling (6k), Nougat (8k)

---

### 3.2 Speech-to-Text (Transcription)

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **Faster-Whisper** | ~18k | CTranslate2-optimized Whisper, 4x faster, 2x less VRAM. OpenAI-compatible API, production-grade. | ✅ |
| **WhisperX** | ~17k | Whisper + word-level timestamps + speaker diarization. Adds alignment on top of base Whisper. | ✅ |
| **FunASR (Alibaba)** | ~9k | Production ASR: speech-to-text, punctuation, diarization. Chinese-optimized, real-time streaming. | ✅ |

**Also notable:** whisper.cpp (35k, CPU-optimized), speechbrain (6k)

---

### 3.3 Text-to-Speech (TTS)

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **Piper** | ~21k | Fast local neural TTS, 900+ voices, edge-friendly. CPU-only, WASM support, <100ms latency. | ✅ |
| **Kokoro-FastAPI** | ~6k | High-quality TTS with OpenAI-compatible API. Fast, Docker-ready, 50+ languages. Drop-in OpenAI replacement. | ✅ |
| **PaddleSpeech (Baidu)** | 12.6k | All-in-one speech: TTS + ASR + speaker verification + translation. Best Chinese TTS, streaming. | ✅ |

**Also notable:** Coqui TTS (35k, no longer maintained), edge-tts (zero GPU)

---

### 3.4 Audio Separation & Processing

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **Demucs (Meta)** | ~19k | Music source separation: vocals, drums, bass, other. Industry standard stem splitter. | ✅ |
| **UVR5** | ~42k | Ultimate Vocal Remover — GUI for MDX, Demucs, VR Arch. Best-in-class quality, 20+ models. | ✅ |
| **AudioSep** | ~1.5k | Separate any audio source by text description. Describe what to isolate ("remove piano"). | ✅ |

**Also notable:** spleeter (25k, outdated), noisereduce (real-time noise suppression)

---

### 3.5 Translation

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **PDFMathTranslate** | 25k | PDF scientific paper translation preserving layout. EMNLP 2025, #1 GitHub trending for a week. | ✅ |
| **LibreTranslate** | ~10k | Self-hosted machine translation API, 30+ languages. OpenAI-compatible, offline-capable, simple setup. | ✅ |
| **Argos Translate** | ~6k | Offline neural machine translation, OpenNMT-based. Desktop + CLI, no internet needed. | ✅ |

**Also notable:** NLLB (Meta, 200 languages), HY-MT (Tencent Hunyuan, 7B)

---

### 3.6 Image Generation

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **ComfyUI** | 70k | Node-based Stable Diffusion backend, API-first. Most powerful SD ecosystem, 1M+ workflows. | ✅ |
| **Fooocus** | 50k | SDXL image generator with Midjourney-like UX. Zero config, auto-optimizes, beautiful output. | ✅ |
| **SwarmUI** | 10k | Multi-backend image gen over ComfyUI, multi-GPU. Professional features, batch processing. | ✅ |

**Also notable:** Automatic1111 (65k, legacy), InvokeAI (27k)

---

### 3.7 Image Enhancement & Restoration

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **Real-ESRGAN** | ~33k | General-purpose image/video 4x upscaler. 4x upscaling, anime + photo, CLI/Docker. | ✅ |
| **GFPGAN (Tencent)** | ~24k | Practical face restoration algorithm. Fixes old/damaged photos, one-line CLI. | ✅ |
| **Clarity Upscaler** | ~5k | Open-source Magnific alternative. UI-first, multiple models, easy Docker. | ✅ |

**Also notable:** CodeFormer (17k, face restoration), SwinIR (5k)

---

### 3.8 AI Code Assistant

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **Aider** | 43k | AI pair programming in your terminal. Git-aware, works with any OpenAI-compatible API. | ✅ |
| **Continue** | 31k | Open-source AI coding assistant (VSCode/JetBrains). Works with any LLM, extensible, local-first. | ✅ |
| **Tabby** | 23k | Self-hosted GitHub Copilot alternative. REST API, autocomplete, chat, Docker. | ✅ |

**Also notable:** Bloop (17k, code search), GPT-Code-Clippy (3k)

---

### 3.9 LLM Inference

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **Ollama** | 167k | Run/manage LLMs locally. Streamlined tool for serving models with model management. | ✅ |
| **llama.cpp** | 101k | Pure C/C++ LLM inference, GGUF format. Runs anywhere, CPU-optimized. | ✅ |
| **vLLM** | 75k | High-throughput LLM serving engine. PagedAttention, 24x throughput, industry standard. | ✅ |

**Also notable:** SGLang (12k), TensorRT-LLM (16k)

---

### 3.10 LLM VRAM Optimization

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **AirLLM** | ~13k | Run 70B–405B on 4GB GPU via layer streaming. No quantization needed, CPU mode works. | ❌ Python lib |
| **exllamav2** | ~12k | Optimized inference for 4-bit GGUF/EXL2 models. Extremely efficient for small VRAM. | ❌ Python lib |
| **bitsandbytes** | ~8k | 4/8-bit quantization for any HuggingFace model. Standard quantization library. | ❌ Python lib |

---

### 3.11 Model Manipulation

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **mergekit** | ~7k | Merge LLMs: SLERP, TIES, DARE, passthrough. The standard for model merging, CLI-first. | ❌ Python lib |
| **Heretic** | ~1k | Auto-uncensor LLMs via abliteration + TPE optimizer. One-click, no manual tuning, preserves model IQ. | ❌ Python lib |
| **abliteration** | ~500 | Uncensor LLMs without TransformerLens. Simpler alternative to Heretic. | ❌ Python lib |

---

### 3.12 LLM Gateway & Routing

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **LiteLLM** | 42k | Universal LLM proxy — 100+ providers, single API. Rate limiting, cost tracking, fallback routing. | ✅ |
| **Langfuse** | 24k | LLM observability, tracing, prompt management, dataset evaluation. Production-grade engineering platform. | ✅ |
| **Infinity** | ~8k | Embedding + reranker server, OpenAI-compatible API. Production-grade, CPU-friendly, multimodal. | ✅ |

**Also notable:** OpenRouter (self-hostable proxy), SmarterRouter (100, VRAM-aware routing)

---

### 3.13 Video Download & Processing

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **Cobalt** | 23k | Clean download UI, 1,000+ platforms. Modern, no-nonsense download interface. | ✅ |
| **MeTube** | ~8k | yt-dlp web UI with queue, playlists, format selection. Mature, one-click Docker, active development. | ✅ |
| **Reclip** | ~1k | Minimal yt-dlp Flask UI, ~150 lines. Bulk URLs, quality selection, dead simple. | ✅ |

**Also notable:** TubeArchivist (8k, video archiving + search), yt-dlp-web-ui Go (~2k, NAS-friendly)

---

### 3.14 RAG & Document Chat

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **PrivateGPT** | 60k | Chat with documents offline, zero data leaves machine. Single binary, local embeddings, 100% offline. | ✅ |
| **AnythingLLM** | 34k | All-in-one document chat with RAG, multi-user. Docker, supports any LLM backend, vector DBs. | ✅ |
| **PaperQA2** | ~3k | High-accuracy RAG on PDFs/research papers. Academic-grade, cites sources, no vector DB needed. | ✅ |

**Also notable:** Dify (87k, workflow builder), Langflow (55k, visual RAG)

---

### 3.15 Email Privacy

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **AnonAddy** | ~10k | Anonymous email forwarding, disposable aliases, GPG encryption. Powers addy.io, most features. | ✅ |
| **SimpleLogin** | ~7k | Email alias service with reply/send. Acquired by Proton, Docker-ready, polished UX. | ✅ |
| **Mailu** | ~3.5k | Full self-hosted mail server (Postfix/Dovecot/Rspamd). Complete mail stack, lightweight. | ✅ |

**Also notable:** Stalwart (3k, modern mail server), Postal (15k, transactional mail)

---

### 3.16 Privacy & Anonymization

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **Microsoft Presidio** | ~11k | PII/anonymization engine — detects and redacts sensitive data. 30+ PII types, Docker, API-first. | ✅ |
| **SecretScanner** | ~2k | Scan files/images/containers for secrets and hardcoded credentials. Finds API keys, tokens, passwords. | ✅ |
| **PII Detector** | ~500 | AI-powered PII detection in logs and text. LLM-based, self-hosted. | ✅ |

**Also notable:** OpenSanctions (org screening), Gophish (phishing testing)

---

### 3.17 AI Memory & Cognitive

| Tool | Stars | Description | Docker |
|------|-------|-------------|--------|
| **Mem0** | ~22k | AI memory layer — persistent memory for AI apps. OpenAI-compatible, works with any LLM. | ✅ |
| **Letta** | ~17k | Agent memory with persistent state management. Self-hosted, structured memory, agent-aware. | ✅ |
| **Cognee** | ~3k | AI memory/knowledge engine, graph-based. Already in your homelab: cf0:8000. | ✅ |

**Also notable:** Recallium (28), Zenii (16, 20MB memory brain)

---

### 3.18 NSFW / 18+ Tools

#### Uncensored LLMs & Model Fine-tunes

| Tool/Model | Source | Description | Popularity |
|------------|--------|-------------|------------|
| **Dolphin** (cognitivecomputations) | HuggingFace | Uncensored fine-tune series (Llama, Mistral, Mixtral). The gold standard for uncensored LLMs. | 500k+ downloads |
| **Hermes** (NousResearch) | HuggingFace | High-quality uncensored fine-tunes. Excellent reasoning + no refusals. | 1M+ downloads |
| **Heretic** | github.com/p-e-w/heretic | Auto-uncensor any open-weight LLM via abliteration. One-click, no manual tuning. | ~1k stars |
| **Abliteration** | github.com/spkgyk/abliteration | Uncensor without TransformerLens. Simpler alternative to Heretic. | ~500 stars |

#### Image Generation — Models & Tools

| Tool/Model | Source | Description | Popularity |
|------------|--------|-------------|------------|
| **Pony Diffusion V6 XL** | CivitAI | Best NSFW SDXL fine-tune, dominates the scene. SDXL-based, runs on 8GB VRAM. | #1 on CivitAI |
| **ComfyUI** | github.com/Comfy-Org | Node-based SD backend — most used for NSFW workflows. Supports any checkpoint/LoRA. | 70k stars |
| **Stable Diffusion WebUI** (AUTOMATIC1111) | github.com/AUTOMATIC1111 | Classic SD GUI, massive NSFW extension ecosystem. Legacy but still widely used. | 155k stars |
| **Fooocus** | github.com/lllyasviel | SDXL, Midjourney-like UX — supports Pony checkpoints. Zero-config NSFW. | 50k stars |
| **CivitAI** | civitai.com | Platform for downloading NSFW models, LoRAs, embeddings. The hub, not a tool itself. | — |

#### Deepfake / Face Manipulation

| Tool | Source | Description | Stars |
|------|--------|-------------|-------|
| **FaceFusion** | github.com/facefusion/facefusion | Next-gen face swap, face enhancement, lip sync. Most polished, Docker-ready. | ~30k |
| **Rope** | github.com/Hillobar/Rope | Real-time face swap GUI with live preview. Fast, RTX-optimized. | ~6k |
| **Roop** | github.com/s0md3v/roop (discontinued) | Original one-click face swap. Discontinued, forked into FaceFusion. | ~35k |
| **DeepFaceLive** | github.com/iperov/DeepFaceLive | Real-time deepfake for video calls. Streaming deepfake. | ~18k |

#### NSFW Video Generation

| Tool | Source | Description | Stars |
|------|--------|-------------|-------|
| **AnimateDiff** | github.com/guoyww/AnimateDiff | Turn SD images into short animated clips. Works with Pony/NSFW checkpoints. | ~14k |
| **Moore-AnimateAnyone** | github.com/MooreThreads | Pose-driven character animation. Person following pose sequences. | ~8k |
| **MagicAnimate** | github.com/magic-research | Densepose-guided human animation. Academic but functional. | ~3k |

#### NSFW Voice/Audio

| Tool | Source | Description | Stars |
|------|--------|-------------|-------|
| **RVC** (Retrieval-based Voice Conversion) | github.com/RVC-Project | AI voice cloning/conversion — huge NSFW community. Clone any voice from 1min audio. | ~30k |
| **Applio** | github.com/IAHispano/Applio | RVC fork with better UI, training, and inference. Most polished RVC fork. | ~5k |
| **Bark** | github.com/suno-ai/bark | Text-to-audio with non-speech sounds (laughs, sighs). OpenAI-style TTS with expressions. | ~35k |

#### Supporting Tools

| Tool | Source | Description | Stars |
|------|--------|-------------|-------|
| **kohya_ss** | github.com/bmaltais/kohya_ss | Train custom LoRAs and fine-tunes. The standard for NSFW model training. | ~19k |
| **AI Toolkit** | github.com/microsoft/ai-toolkit | Microsoft's LoRA training toolkit. Cleaner alternative to kohya. | ~5k |
| **Stability Matrix** | github.com/LykosAI/StabilityMatrix | Package manager for all SD UIs in one installer. Manages A1111, ComfyUI, Fooocus. | ~8k |

---

## 4. Baidu Open-Source AI/ML Ecosystem

Baidu operates under **two GitHub organizations**:
- **`github.com/PaddlePaddle`** — PaddlePaddle (飞桨) framework ecosystem — **107 repositories**
- **`github.com/baidu`** — Baidu corporate — **122 repositories**

### 4.1 PaddlePaddle Ecosystem (`github.com/PaddlePaddle`) — 107 Repos

| Tool | Stars | Category | Description |
|------|-------|----------|-------------|
| **PaddleOCR** | 75k | OCR | PDF/image → structured data for AI. 100+ languages. Industry-standard OCR toolkit. |
| **PaddlePaddle (飞桨)** | 23.8k | Framework | Core DL/ML framework — Baidu's PyTorch equivalent. Parallel distributed deep learning. |
| **PaddleFormers** | 13k | LLM Zoo | Pre-trained large language model library. Easy-to-use, like HuggingFace transformers. |
| **PaddleX** | 13k | Low-Code AI | End-to-end development tool: drag-and-drop model training for detection, OCR, classification. |
| **PaddleSpeech** | 12.6k | Speech AI | All-in-one speech: ASR (STT), TTS, speaker verification, speech translation, keyword spotting. |
| **PaddleDetection** | 9.5k | Vision | Object detection library. YOLO, Faster R-CNN, and more. |
| **PaddleClas** | 7.5k | Vision | Image classification with 24k+ pretrained models. |
| **ERNIE (文心)** | 7.7k | LLM Toolkit | ERNIE 4.5/5.0 industrial-grade development toolkit based on PaddlePaddle. |
| **PaddleSeg** | 5.5k | Vision | Image segmentation toolkit. |
| **PaddleGAN** | 5k | Vision | Generative adversarial networks: style transfer, super-resolution. |
| **PaddleNLP** | 4.5k | NLP | Chinese NLP toolkit: sentiment analysis, NER, QA, translation. |
| **FastDeploy** | 3.7k | Inference | High-performance inference/deployment for LLMs and VLMs based on PaddlePaddle. |
| **PaddleRec** | 3k | RecSys | Recommendation system framework. |
| **PaddleTS** | 2k | Time Series | Time series forecasting toolkit. |
| **PaddleCustomDevice** | 103 | Hardware | Custom third-party hardware backend integration for PaddlePaddle. |

### 4.2 Baidu Corporate Repos (`github.com/baidu`) — 122 Repos

| Tool | Stars | Category | Description |
|------|-------|----------|-------------|
| **amis** | 22k | Frontend | Low-code JSON-based frontend framework. Used internally at Baidu for rapid UI development. |
| **vLLM-Kunlun** | 389 | Inference | Community-maintained hardware plugin to run vLLM on Baidu's Kunlun XPU (their own AI chip). |

### 4.3 Baidu Cloud-Only (Not Self-Hostable)

| Tool | Description |
|------|-------------|
| **ERNIE 5.0 (文心)** | Baidu's flagship LLM — primarily cloud via Qianfan API. No easy self-host Docker. |
| **Qianfan (千帆)** | Baidu's AI cloud platform (like AWS Bedrock). Not open-source. |
| **Comate** | Baidu's Copilot — cloud coding assistant. Not open-source. |

---

## 5. Homelab Recommendations

Based on your hardware (GTX 1060 6GB, 107GB RAM, 16 threads) and what you already run.

### 5.1 Priority Deployment (🔥)

| Priority | Category | Tool | Port | Reason |
|----------|----------|------|------|--------|
| 🔥 | OCR | **PaddleOCR** | 5510 | Already have PaddlePaddle 3.0.0 in Conda envs — just add API server |
| 🔥 | TTS | **Piper** | 5500 | CPU-only, 900+ voices, instant response, <100ms latency |
| 🔥 | Transcription | **Faster-Whisper** | 5501 | GPU-optimized Whisper, 4x faster than stock, fits 6GB VRAM |
| 🔥 | Image Gen | **ComfyUI** | 7861 | GTX 1060 can run SD1.5/SDXL, most flexible SD backend |
| 🔥 | Doc Chat | **AnythingLLM** | 3001 | Uses your existing Ollama backend + vector DBs (Qdrant/Chroma) |

### 5.2 Worth Evaluating (✅)

| Priority | Category | Tool | Port | Reason |
|----------|----------|------|------|--------|
| ✅ | Translation | **LibreTranslate** | 5503 | 30+ languages, CPU-friendly, OpenAI-compatible API |
| ✅ | Code Assist | **Continue** | N/A | VSCode/JetBrains extension → your Ollama backend |
| ✅ | Image Upscale | **Real-ESRGAN** | 5504 | GTX 1060 handles 4x upscaling fine |
| ✅ | LLM Gateway | **LiteLLM** | 5505 | Single API endpoint for all your backends (Ollama, OpenSearch, etc.) |
| ✅ | Embeddings | **Infinity** | 5506 | CPU-friendly embedding + reranker, OpenAI-compatible |
| ✅ | Video DL | **Reclip** | 8899 | You already wanted it — minimal yt-dlp Flask UI |

### 5.3 Cloud-Only / Not Applicable (⚠️)

| Priority | Category | Tool | Port | Reason |
|----------|----------|------|------|--------|
| ⚠️ | Email Privacy | **AnonAddy** | 25/80 | Needs port 25 unblocked + DNS/MX/SSL setup |
| ⚠️ | Decensor | **Heretic** | N/A | Run as one-shot CLI on GPU — not a persistent service |
| ⚠️ | VRAM Opt | **AirLLM** | N/A | Python library, not a Docker service |
| ⚠️ | Code Assist | **Tabby** | 5504 | Heavy — needs 8GB+ VRAM ideally |

---

## 6. Already Deployed on cf0

| Service | Port | Project | Status |
|---------|------|---------|--------|
| Ollama | 11434 | cf-core | ✅ Running |
| Open WebUI | 8080 | cf-core | ✅ Running |
| SearXNG | 8081 | cf-core | ✅ Running |
| MindsDB | 47334/47335 | cf-core | ✅ Running |
| Cognee | 8000/5678 | cf-core | ✅ Running |
| ZeroClaw | 42617 | cf-core | ✅ Running |
| RedisInsight | 5540 | cf-core | ✅ Running |
| OpenSearch | 9200/9600 | cf-openrag | ✅ Running |
| OpenSearch Dashboards | 5601 | cf-openrag | ✅ Running |
| Langflow | 7860 | cf-openrag | ✅ Running |
| OpenRAG Frontend | 3000 | cf-openrag | ✅ Running |
| n8n | 5679 | cf-expand | ✅ Running |
| Nuclio | 8070 | cf-expand | ✅ Running |
| Qdrant | 6333/6334 | cf-expand | ✅ Running |
| TensorLake | 8900 | cf-expand | ✅ Running |
| Nautilus Trader | 8889 | cf-expand | ✅ Running |
| OpenBB | 6900 | cf-expand | ✅ Running |
| PostgreSQL (tools) | 4433 | cf-expand | ✅ Running |
| Scrutiny | 7786 | cf-scrutiny | ✅ Running |
| OpenSpace | 7788 | cf-openspace | ✅ Running |
| Serena MCP | 9121 | cf-serena | ✅ Running |
| Chroma | 8020 | cf-vectordbs | ✅ Running |
| Weaviate | 8090/50051 | cf-vectordbs | ✅ Running |
| Milvus | 19530/9091 | cf-vectordbs | ✅ Running |
| etcd (Milvus) | 2379 | cf-vectordbs | ✅ Running |
| MinIO (Milvus) | 9000 | cf-vectordbs | ✅ Running |

**Total:** 7 compose projects, 26+ containers, all running.

---

## 7. Hardware Profile

| Component | Details |
|-----------|---------|
| **Host** | cf0 (alias: `ubu1`) |
| **CPU** | Intel i9-9900K (16 threads, AVX2) |
| **RAM** | 107 GB |
| **GPU** | NVIDIA GTX 1060 6GB (Pascal, SM 6.1, compute capability 6.1) |
| **Storage** | 492 GB /home (RAID0) |
| **Network** | 100 Mbps ethernet, limited to 50 Mbps during setup |

**GPU limitations:** The GTX 1060 (Pascal, compute capability 6.1) is too old for modern GPU-accelerated inference libraries like vLLM which require SM 8.0+. GPU mode is hard-blocked for vLLM. CPU mode is used instead for most workloads.
