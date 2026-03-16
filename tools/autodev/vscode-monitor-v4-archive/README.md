# M.E.R.L.I.N. Remote Trainer

Cette extension est maintenant en mode **panel unique**:
- `GPU Train + Chat`

Fonctions:
- orchestration Kaggle GPU (doctor/setup/submit/status/download),
- chat de test modele (endpoint distant OpenAI-compatible ou fallback Ollama local).
- presets cloud inference directement dans le panel: `Together`, `Groq`, `RunPod`.

## Settings

- `autodev-v4.remoteTrain.pythonPath`
- `autodev-v4.remoteTrain.kaggleUsername`
- `autodev-v4.remoteTrain.kernelSlug`
- `autodev-v4.remoteTrain.kernelTitle`
- `autodev-v4.remoteTrain.testModel`
- `autodev-v4.remoteTrain.testEndpoint`
- `autodev-v4.remoteTrain.testApiKey`

## Commandes

- `autodev-v4.remoteTrain.refresh`
- `autodev-v4.remoteTrain.configure`

## Presets cloud

- `Preset Together` configure:
  - endpoint: `https://api.together.xyz/v1/chat/completions`
  - model: `meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo`
- `Preset Groq` configure:
  - endpoint: `https://api.groq.com/openai/v1/chat/completions`
  - model: `llama-3.1-8b-instant`
- `Preset RunPod` demande un endpoint ID/URL puis construit l endpoint OpenAI-compatible.
- API key: soit `testApiKey`, soit variable d environnement:
  - Together: `TOGETHER_API_KEY`
  - Groq: `GROQ_API_KEY`
  - RunPod: `RUNPOD_API_KEY`
  - fallback generic: `OPENAI_API_KEY`

## Packaging VSIX

```powershell
cd tools/autodev/vscode-monitor-v4
npx @vscode/vsce package
```

## Docs

- `docs/10_llm/REMOTE_GPU_TRAINING_VSCODE_KAGGLE.md`
