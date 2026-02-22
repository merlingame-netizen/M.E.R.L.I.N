#!/usr/bin/env python3
"""Quick test of LoRA adapter in FP16 (half the RAM of FP32)."""
import argparse, json, os, re, sys, time, gc

# Force offline mode — model already cached locally
os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["TRANSFORMERS_OFFLINE"] = "1"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adapter", default="tmp/merlin-lora-cpu/final-adapter",
                        help="Path to adapter directory")
    parser.add_argument("--max-tokens", type=int, default=300,
                        help="Max new tokens to generate")
    parser.add_argument("--num-tests", type=int, default=5,
                        help="Number of test prompts")
    args = parser.parse_args()

    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer
    from peft import PeftModel

    print(f"PyTorch {torch.__version__} | CPU threads: {torch.get_num_threads()}")

    MODEL_NAME = "Qwen/Qwen2.5-1.5B-Instruct"
    adapter_path = args.adapter
    if not os.path.isabs(adapter_path):
        adapter_path = os.path.join(os.path.dirname(__file__), "..", "..", adapter_path)
    adapter_path = os.path.abspath(adapter_path)

    print(f"\nChargement {MODEL_NAME} en FP16...")
    t0 = time.time()
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME,
        torch_dtype=torch.float16,
        device_map="cpu",
        trust_remote_code=True,
    )
    print(f"  Base model: {time.time()-t0:.0f}s | ~3.1 GB RAM")

    print(f"  Loading adapter: {adapter_path}")
    model = PeftModel.from_pretrained(model, adapter_path)
    model.eval()
    print(f"  Ready in {time.time()-t0:.0f}s")

    # Test prompts — increasing variety
    test_prompts = [
        {
            "system": "Tu es Merlin l'Enchanteur, druide ancestral de Broceliande. Tu contes au present, a la deuxieme personne (tu). FORMAT: 4-6 phrases sensorielles puis EXACTEMENT 3 choix:\nA) VERBE \u2014 Description d'action en 1 phrase\nB) VERBE \u2014 Description d'action en 1 phrase\nC) VERBE \u2014 Description d'action en 1 phrase",
            "user": "Carte 1. Lieu: foret_broceliande. Theme: source sacree. Acte I.",
        },
        {
            "system": "Tu es Merlin l'Enchanteur. FORMAT: VERBE \u2014 description concrete. Vocabulaire celtique.",
            "user": "Carte 5. Lieu: marais_korrigans. Theme: nuit de Samhain. Corps=bas Ame=equilibre Monde=haut.",
        },
        {
            "system": "Tu es Merlin l'Enchanteur. FORMAT: VERBE \u2014 description. URGENCE: peril.",
            "user": "Carte 12. Lieu: collines_dolmens. Theme: combat rituel. Acte III. Corps=bas Ame=bas.",
        },
        {
            "system": "Tu es Merlin l'Enchanteur, druide ancestral de Broceliande. Tu contes au present, a la deuxieme personne (tu). FORMAT: VERBE \u2014 description.",
            "user": "Carte 8. Lieu: cercle_menhirs. Theme: eclipse de lune. Acte II. Corps=equilibre Ame=haut Monde=bas.",
        },
        {
            "system": "Tu es Merlin l'Enchanteur. FORMAT: VERBE \u2014 description. Style sensoriel.",
            "user": "Carte 15. Lieu: grotte_cristal. Theme: riviere souterraine. Epilogue. Corps=haut Ame=equilibre Monde=equilibre.",
        },
    ]

    prompts_to_use = test_prompts[:args.num_tests]
    total_verb_lines = 0
    total_expected = args.num_tests * 3

    for i, prompt in enumerate(prompts_to_use):
        chatml = (
            f"<|im_start|>system\n{prompt['system']}<|im_end|>\n"
            f"<|im_start|>user\n{prompt['user']}<|im_end|>\n"
            f"<|im_start|>assistant\n"
        )
        inputs = tokenizer(chatml, return_tensors="pt")
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=args.max_tokens,
                temperature=0.7,
                top_p=0.9,
                repetition_penalty=1.3,
                do_sample=True,
            )
        del inputs; gc.collect()
        result = tokenizer.decode(outputs[0], skip_special_tokens=False)
        del outputs; gc.collect()
        answer = result.split("<|im_start|>assistant\n")[-1].split("<|im_end|>")[0]

        print(f"\n{'=' * 70}")
        print(f"  TEST {i + 1}: {prompt['user'][:65]}")
        print(f"{'=' * 70}")
        # Safe print for Windows console
        safe_answer = answer.strip()
        try:
            print(safe_answer)
        except UnicodeEncodeError:
            print(safe_answer.encode('ascii', errors='replace').decode('ascii'))

        # Flexible regex: A)/1) + UPPERCASE_VERB + em-dash/double-hyphen/hyphen + description
        verb_pattern = r'^[A-D1-4][).:]\s*[A-Z\u00C0-\u00DC]{2,}[\s]*[\u2014\u2013\-]{1,2}\s*.+'
        lines = answer.strip().split('\n')
        verb_lines = [l for l in lines if re.match(verb_pattern, l.strip())]
        total_verb_lines += len(verb_lines)
        print(f"\n  >>> Matched {len(verb_lines)}/3 VERBE lines")
        for vl in verb_lines:
            print(f"      {vl.strip()[:80]}")

    compliance = total_verb_lines / total_expected if total_expected > 0 else 0
    print(f"\n{'=' * 70}")
    print(f"  COMPLIANCE: {total_verb_lines}/{total_expected} ({compliance:.0%}) -- cible >80%")
    print(f"  {'PASS' if compliance >= 0.8 else 'A AMELIORER'}")
    print(f"{'=' * 70}")

if __name__ == "__main__":
    main()
