# OllamaBox

Run a local AI chatbot on your Windows PC. One command. No data leaves your machine.

## Quick Start

**Step 1:** Make sure WSL is enabled. Open **PowerShell as Administrator** and run:

```powershell
wsl --install
```

Restart your PC if prompted.

**Step 2:** Open **PowerShell** and run:

```powershell
irm https://raw.githubusercontent.com/cellexec/wsl-ollama-installer/main/install.ps1 | iex
```

**Step 3:** Follow the prompts. It will ask you to pick a model — just press **Enter** to use the recommended one.

**Step 4:** When it's done, open this link in your browser: **http://localhost:8080**

Create a local account (stays on your machine), and you're in. You can chat, upload PDFs, and get summaries.

## Start It Again Later

```powershell
wsl -d OllamaBox -- bash -c "~/start-ollama.sh"
```

Then open **http://localhost:8080**.

## Remove It

This only removes OllamaBox. Your normal Windows and WSL setup is not affected.

```powershell
wsl --unregister OllamaBox
Remove-Item -Recurse "$env:USERPROFILE\WSL\OllamaBox"
```

---

## How It Works

The installer creates a **separate Linux environment** on your PC called "OllamaBox" using WSL (Windows Subsystem for Linux). This runs alongside Windows and doesn't touch anything else on your system.

Inside that environment, it installs two things:

1. **Ollama** — runs AI models locally on your hardware
2. **Open WebUI** — a web-based chat interface you open in your browser

Before downloading a model, the script scans your system (RAM, CPU, GPU) and recommends the best model your hardware can handle. You pick from a list or accept the default.

Once running, you interact through your browser at `localhost:8080`. The chat interface supports uploading PDFs and other documents directly — you can ask the AI to summarize, compare, or answer questions about them.

Everything runs locally. No API keys, no cloud services, no subscriptions.

### What Gets Installed

| Component | What It Does | Docs |
|---|---|---|
| [WSL 2](https://learn.microsoft.com/en-us/windows/wsl/) | Runs a lightweight Linux (Ubuntu 24.04) inside Windows | [Microsoft WSL Docs](https://learn.microsoft.com/en-us/windows/wsl/about) |
| [Ollama](https://ollama.com/) | Local LLM runtime — downloads and runs open source AI models on your CPU/GPU | [Ollama GitHub](https://github.com/ollama/ollama) |
| [Open WebUI](https://openwebui.com/) | Browser-based chat UI with PDF upload, conversation history, and multi-model support | [Open WebUI GitHub](https://github.com/open-webui/open-webui) |

### Available Models

The installer offers these models based on your RAM:

| Model | Parameters | RAM Needed | Best For |
|---|---|---|---|
| [TinyLlama](https://ollama.com/library/tinyllama) | 1.1B | 2 GB+ | Low-end hardware, basic tasks |
| [Phi-3 Mini](https://ollama.com/library/phi3) | 3.8B | 4 GB+ | Light systems, surprisingly capable |
| [Llama 3.1](https://ollama.com/library/llama3.1) | 8B | 8 GB+ | Best balance of quality and speed |
| [Gemma 2](https://ollama.com/library/gemma2) | 9B | 10 GB+ | Strong reasoning and summarization |
| [Mistral Nemo](https://ollama.com/library/mistral-nemo) | 12B | 12 GB+ | Excellent multilingual support |
| [Qwen 2.5](https://ollama.com/library/qwen2.5) | 14B | 16 GB+ | Great for detailed analysis |
| [Llama 3.1 70B](https://ollama.com/library/llama3.1) | 70B | 48 GB+ | Near-commercial quality, needs serious hardware |

### GPU vs CPU

By default Ollama runs on your CPU. You can check what's being used:

```powershell
wsl -d OllamaBox -- bash -c "ollama ps"
```

Example output:

```
NAME                   ID              SIZE      PROCESSOR    CONTEXT    UNTIL
mistral-nemo:latest    e7e06d107c6c    7.4 GB    100% CPU     4096       3 minutes from now
```

If it says `100% CPU`, you can speed things up significantly with an NVIDIA GPU.

**Enable GPU acceleration (one command):**

```powershell
powershell -Command "Start-Process -Verb RunAs powershell '-Command iwr -useb https://raw.githubusercontent.com/cellexec/wsl-ollama-installer/main/enable-gpu.ps1 | iex'"
```

This installs the [NVIDIA CUDA drivers for WSL](https://developer.nvidia.com/cuda/wsl) and restarts OllamaBox. After that, `ollama ps` should show `100% GPU` instead.

**Requirements for GPU:**
- An NVIDIA GPU (GTX 1060 or newer recommended)
- Latest [NVIDIA driver](https://www.nvidia.com/Download/index.aspx) installed on Windows

### System Requirements

- Windows 10 (version 2004+) or Windows 11
- 8 GB RAM recommended (4 GB minimum)
- 15 GB free disk space
- NVIDIA GPU optional but speeds things up significantly
