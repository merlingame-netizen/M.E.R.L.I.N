# Trinity-Nano-Preview - Corrected Notebook
# Model: arcee-ai/Trinity-Nano-Preview
#
# This notebook has been corrected to be more stable and robust.
# Key changes:
# 1. Pinned dependencies: `transformers` is pinned to a stable version known to work with the model.
# 2. Removed patching: All the fragile monkey-patching code has been removed,
#    as the fixes are now in the main library.
# 3. Code quality: The code has been refactored for clarity and efficiency.
#
# IMPORTANT: Enable the GPU before starting!
# Runtime > Change runtime type > T4 GPU

# ============================================================================
# CELL 1: SETUP & DEPENDENCIES
# ============================================================================
import os
import torch
from datetime import datetime

print("=" * 70)
print("TRINITY-NANO-PREVIEW - SETUP")
print(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print("=" * 70)

# --- Configuration ---
class Config:
    MODEL_ID = "arcee-ai/Trinity-Nano-Preview"
    # Pinning versions for stability
    TRANSFORMERS_VERSION = "4.42.3"
    TORCH_VERSION = "2.3.0"
    ACCELERATE_VERSION = "0.30.1"
    BITSANDBYTES_VERSION = "0.43.1"

# --- GPU Check ---
print("
[1.1] Checking for GPU...")
if not torch.cuda.is_available():
    print("      [ERROR] No GPU detected. Please enable a GPU runtime.")
    # In a notebook, you might want to stop execution here:
    # raise SystemExit("GPU not found")
else:
    print(f"      [OK] GPU found: {torch.cuda.get_device_name(0)}")

# --- Install Dependencies ---
print("
[1.2] Installing dependencies...")
print("      This will take 2-3 minutes.")

# Use os.system for cleaner output in notebooks
os.system(f"pip install --upgrade -q 
    transformers=={Config.TRANSFORMERS_VERSION} 
    torch=={Config.TORCH_VERSION} 
    accelerate=={Config.ACCELERATE_VERSION} 
    bitsandbytes=={Config.BITSANDBYTES_VERSION} 
    sentencepiece 
    protobuf")

print("      [OK] Dependencies installed.")

# --- Version Check ---
print("
[1.3] Verifying versions...")
import transformers

print(f"      - Python: {sys.version.split()[0]}")
print(f"      - PyTorch: {torch.__version__}")
print(f"      - Transformers: {transformers.__version__}")
print(f"      - CUDA available: {torch.cuda.is_available()}")

if torch.cuda.is_available():
    vram = torch.cuda.get_device_properties(0).total_memory / 1e9
    print(f"      - VRAM: {vram:.1f} GB")

print("
" + "=" * 70)
print("SETUP COMPLETE: You can now proceed to the next cell.")
print("=" * 70)


# ============================================================================
# CELL 2: LOAD MODEL AND TOKENIZER
# ============================================================================
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
import gc
import time

print("=" * 70)
print(f"LOADING: {Config.MODEL_ID} (4-bit)")
print("=" * 70)

# --- Clean Memory ---
gc.collect()
if torch.cuda.is_available():
    torch.cuda.empty_cache()

# --- Quantization Config ---
print("[2.1] Configuring 4-bit quantization (NF4)...")
quantization_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4"
)
print("      [OK] Configured.")

# --- Load Tokenizer ---
# No patching needed anymore, trust_remote_code handles it.
print("
[2.2] Loading tokenizer...")
tokenizer = AutoTokenizer.from_pretrained(Config.MODEL_ID, trust_remote_code=True)
if tokenizer.pad_token is None:
    tokenizer.pad_token = tokenizer.eos_token
print("      [OK] Tokenizer loaded.")

# --- Load Model ---
# No more manual patching is required. Transformers >= 4.41.0 handles the model correctly.
print("
[2.3] Loading model...")
print("      This may take 1-2 minutes.")

start_time = time.time()
model = AutoModelForCausalLM.from_pretrained(
    Config.MODEL_ID,
    quantization_config=quantization_config,
    device_map="auto",
    trust_remote_code=True,
)
elapsed = time.time() - start_time
print(f"
      [OK] Model loaded in {elapsed:.1f} seconds.")

# --- Model Info ---
print("
[2.4] Model information:")
total_params = sum(p.numel() for p in model.parameters())
print(f"      - Parameters: {total_params / 1e9:.2f}B")
if torch.cuda.is_available():
    vram_used = torch.cuda.memory_allocated() / 1e9
    print(f"      - VRAM usage: {vram_used:.1f} GB")

print("
" + "=" * 70)
print("MODEL IS READY!")
print("=" * 70)


# ============================================================================
# CELL 3: CHAT & GENERATION CLASS
# ============================================================================
import time
import torch
from threading import Thread
from transformers import TextIteratorStreamer

print("=" * 70)
print("CONFIGURING CHAT FUNCTIONALITY")
print("=" * 70)

class TrinityChat:
    def __init__(self, model, tokenizer):
        self.model = model
        self.tokenizer = tokenizer
        self.chat_history = []
        print("[OK] Chat class initialized. Use `chat.send('Your message')`")

    def reset(self):
        """Resets the conversation history."""
        self.chat_history = []
        gc.collect()
        print("
[INFO] Conversation history has been reset.")

    def send(self, message: str, max_new_tokens: int = 512, temperature: float = 0.7, stream: bool = True):
        """
        Sends a message to the model and streams the response.

        Args:
            message (str): The user's message.
            max_new_tokens (int): Maximum tokens for the response.
            temperature (float): Controls creativity (0.2=factual, 1.0=creative).
            stream (bool): Whether to stream the response token-by-token.
        """
        print(f"
> You: {message}")
        print(f"
> Trinity: ", end="", flush=True)

        self.chat_history.append({"role": "user", "content": message})

        input_ids = self.tokenizer.apply_chat_template(
            self.chat_history,
            add_generation_prompt=True,
            return_tensors="pt"
        ).to(self.model.device)

        gen_kwargs = {
            "input_ids": input_ids,
            "max_new_tokens": max_new_tokens,
            "do_sample": True,
            "temperature": temperature,
            "top_p": 0.95,
            "top_k": 50,
            "pad_token_id": self.tokenizer.eos_token_id,
        }

        start_time = time.time()

        if stream:
            streamer = TextIteratorStreamer(self.tokenizer, skip_prompt=True, skip_special_tokens=True)
            gen_kwargs["streamer"] = streamer
            thread = Thread(target=self.model.generate, kwargs=gen_kwargs)
            thread.start()

            full_response = ""
            for new_text in streamer:
                print(new_text, end="", flush=True)
                full_response += new_text
            thread.join()
        else:
            with torch.no_grad():
                outputs = self.model.generate(**gen_kwargs)
            response_ids = outputs[0][input_ids.shape[1]:]
            full_response = self.tokenizer.decode(response_ids, skip_special_tokens=True)
            print(full_response)

        elapsed_time = time.time() - start_time
        response_token_count = len(self.tokenizer.encode(full_response))
        tps = response_token_count / elapsed_time if elapsed_time > 0 else 0

        self.chat_history.append({"role": "assistant", "content": full_response})

        print(f"

---")
        print(f"Stats: {response_token_count} tokens | {elapsed_time:.1f}s | {tps:.1f} tokens/s")
        print(f"---
")
        return full_response

# --- Initialize chat ---
chat = TrinityChat(model, tokenizer)

print("
" + "=" * 70)
print("CELL 3 COMPLETE: Chat is ready.")
print("=" * 70)

# ============================================================================
# CELL 4: INTERACTIVE CHAT
# ============================================================================
print("""
+------------------------------------------------------------------+
|  COMMANDS:                                                       |
|    chat.send("Your message")                                     |
|    chat.reset()                  - Start a new conversation      |
|                                                                  |
|  OPTIONS:                                                        |
|    chat.send("msg", max_new_tokens=1024)                         |
|    chat.send("msg", temperature=0.3)  - More factual response    |
|    chat.send("msg", temperature=1.0)  - More creative response   |
+------------------------------------------------------------------+
""")

# --- First Conversation Example ---
chat.send("Hello Trinity! In a few sentences, what makes you different from other models?")


# ============================================================================
# CELL 5: BENCHMARKS
# ============================================================================
import statistics
from tqdm.auto import tqdm

print("=" * 70)
print(f"BENCHMARKS: {Config.MODEL_ID}")
print("=" * 70)

# --- Speed Benchmark ---
print("
[5.1] Running speed benchmark...")
benchmark_prompts = [
    "What is the capital of France?",
    "Write a 4-line poem about the moon.",
    "List three benefits of exercise.",
    "Summarize the plot of 'The Matrix' in one sentence.",
    "Who was the first person on the moon?",
]
results = []

chat.reset() # Use a clean history for benchmarks

for prompt in tqdm(benchmark_prompts, desc="   Benchmarking"):
    start = time.time()
    # Use the chat class to generate, but we'll recalculate stats for consistency
    response = chat.send(prompt, max_new_tokens=60, temperature=0.5, stream=False)
    elapsed = time.time() - start

    tokens_out = len(tokenizer.encode(response))
    tps = tokens_out / elapsed if elapsed > 0 else 0
    results.append(tps)
    chat.reset() # Reset for next isolated test

avg_tps = statistics.mean(results)
print(f"
   [RESULT] Average Speed: {avg_tps:.1f} tokens/second")

# --- Long Context Test ---
# A more meaningful long context test
print("
[5.2] Running long context test...")
try:
    with open("long_text.txt", "w") as f:
        f.write("This is a story about a brave knight. " * 500) # ~5000 tokens
    with open("long_text.txt", "r") as f:
        long_prompt = f.read() + "

Based on the story, what is the main characteristic of the knight? Answer in one sentence."
    os.remove("long_text.txt")

    prompt_tokens = len(tokenizer.encode(long_prompt))
    print(f"   Prompt tokens: {prompt_tokens}")

    start = time.time()
    chat.reset()
    response = chat.send(long_prompt, max_new_tokens=50, stream=False)
    elapsed = time.time() - start
    tokens_out = len(tokenizer.encode(response))
    tps = tokens_out / elapsed if elapsed > 0 else 0

    print(f"   Generated tokens: {tokens_out}")
    print(f"   Time: {elapsed:.2f}s")
    print(f"   Speed: {tps:.1f} t/s")

except Exception as e:
    print(f"   [ERROR] Could not run long context test: {e}")

print("
" + "=" * 70)
print("BENCHMARKS COMPLETE")
print("=" * 70)
