# GTX 1070 8GB Benchmark: Gemma 4 12B Q4_K_M

> **Full performance sweep for running Gemma 4 12B Q4_K_M on NVIDIA GTX 1070 8GB (Pascal, CC 6.1)**
>
> 32K context, KV cache q8_0/q8_0, Flash Attention, llama.cpp b9500 CUDA 12.4

[中文版](README.md)

---

## Hardware / Software

| Item | Spec |
|---|---|
| GPU | NVIDIA GeForce GTX 1070 (8192 MiB, Pascal CC 6.1) |
| CPU | Intel Core i7-7700K @ 4.20GHz (4c/8t) |
| RAM | 32 GB DDR4 |
| OS | Windows 10 |
| Driver | 582.28 |
| llama.cpp | b9500 (3d1998634), Clang 19.1.5, CUDA 12.4 |
| Model | [google/gemma-4-12b-it-Q4_K_M](https://huggingface.co/lmstudio-community/gemma-4-12B-it-GGUF) (7.04 GB, 4.95 BPW) |

---

## Conclusions

### Daily Driver (Stable, Long Context)

```
llama-server.exe \
  -m <path-to>/gemma-4-12B-it-Q4_K_M.gguf \
  -c 32768 -ngl 40 -fa on \
  -ctk q8_0 -ctv q8_0 -b 512 -ub 256 \
  --metrics
```

| Metric | Value |
|---|---|
| VRAM | ~7560 MiB (~600 MiB headroom) |
| Decode (short prompt) | ~10.4 tok/s |
| Prefill (657 tokens) | ~226 tok/s |
| Prefill (12K tokens) | ~185 tok/s |
| Stability | No thrashing at any context length |

### Performance Mode (Max Speed, Shorter Context)

```
-ngl 42 -ub 64 (everything else same as above)
```

| Metric | Value |
|---|---|
| VRAM | ~7788 MiB (~400 MiB headroom) |
| Decode (short prompt) | **~11.3 tok/s** |
| Prefill (657 tokens) | ~174 tok/s |
| Best for | Multi-turn chat, code generation (prompt < 4K tokens) |

---

## Round 1: Smoke Test

**Goal:** Confirm 32K context with q8/q8 KV cache works.

| # | ctk | ctv | ngl | ubatch | start | gen | VRAM | prompt t/s | decode t/s |
|---|---:|---|---:|---:|---:|---|---|---:|---:|
| 1 | q8_0 | q8_0 | auto→36 | 128 | ✅ | ✅ | 6833 MiB | 22.7 | 9.65 |
| 2 | q8_0 | q4_0 | auto→37 | 128 | ✅ | ✅ | 6726 MiB | 23.4 | 9.40 |
| 3 | q8_0 | q8_0 | auto→36 | 64 | ✅ | ✅ | 6832 MiB | 23.0 | **9.74** |

**Conclusion: q8/q8 is fully viable — 83% VRAM usage, no thrashing.**

---

## Round 2: NGL (GPU Layer) Sweep

Fixed: ctx=32768, q8/q8, b512, ub=64, prompt=657 tok, gen=256 tok

| ngl | VRAM peak | GPU model | GPU KV | prompt t/s | decode t/s | Note |
| --: | --------: | --------: | -----: | ---------: | ---------: | ---- |
| 36 | 6899 MiB | 5312 MiB | 524 MiB | 125.6 | 9.15 | baseline (=auto) |
| 38 | 7173 MiB | 5579 MiB | 542 MiB | 149.3 | 9.79 | |
| 40 | 7449 MiB | 5819 MiB | 578 MiB | 161.8 | **10.52** | ⭐ sweet spot |
| 42 | 7745 MiB | 6076 MiB | 614 MiB | 177.9 | **11.44** | ⚠️ high risk |
| 44 | 7878 MiB | 6341 MiB | 632 MiB | **59.1** ⬇ | 11.23 | 🔴 thrashing |

**ngl=44 crashes prompt speed by 3× (178→59 tok/s) — thrashing confirmed, eliminated.**
**Decode improves linearly up to ngl=42; each +2 layers ≈ +0.5 tok/s.**

---

## Round 3: Fine-Tuning NGL + ubatch

Fixed: ctx=32768, q8/q8, b512, prompt=657 tok, gen=512 tok

| # | ngl | ubatch | VRAM | compute buf | prompt t/s | decode t/s | Note |
| --: | --: | -----: | --------: | ----------: | ---------: | ---------: | ---- |
| A | 41 | 64 | 7653 MiB | 114 MiB | 170.8 | 10.87 | |
| B | 40 | 128 | 7511 MiB | 127 MiB | **198.7** | 10.40 | prompt +22.8% |
| C | 41 | 128 | 7667 MiB | 127 MiB | **204.8** | 10.83 | prompt peak |
| D | 42 | 64 | 7786 MiB | 114 MiB | 174.4 | **11.31** | decode peak |

**ubatch=128 gives a significant prompt speed boost (+22.8%) with negligible decode trade-off. ngl=42 re-tested stable.**

---

## Round 4: Long Context & Final Tuning

### 4A: ubatch=256 Test

Fixed: ngl=40, prompt=657 tok, gen=512 tok

| ubatch | VRAM | compute buf | prompt t/s | decode t/s |
| -----: | --------: | ----------: | ---------: | ---------: |
| 128 | 7475 MiB | 127 MiB | 197.6 | 10.40 |
| 256 | 7515 MiB | 155 MiB | **225.6** | 10.39 |

**ubatch=256 adds another +14% prompt speed for only ~40 MiB more VRAM. Strongly recommended.**

### 4B: Long Prompt Prefill

Fixed: ngl=40, ub=256, gen=128 tok

| Prompt tokens | VRAM peak | prompt t/s | decode t/s |
| ------------: | --------: | ---------: | ---------: |
| 2,618 | 7560 MiB | **238.1** | 9.6 |
| 5,261 | 7560 MiB | 216.1 | 9.2 |
| 10,345 | 7560 MiB | 191.6 | 8.7 |
| 12,192 | 7560 MiB | 184.6 | 8.6 |

**VRAM stays constant at 7560 MiB (pre-allocated KV cache). Speed degrades gracefully — no thrashing at any length.**

### 4C: Performance Stretch (ngl=42)

| ngl | Prompt tokens | VRAM | prompt t/s | decode t/s |
| --: | ------------: | --------: | ---------: | ---------: |
| 42 | 5,261 | 7788 MiB | 166.1 | 9.9 |
| 42 | 10,345 | 7788 MiB | 147.2 | 9.4 |

**ngl=42 runs ~23% slower on long prompts vs. ngl=40, but decode is still ~7% faster. Best suited for prompt < 4K scenarios.**

---

## Model Architecture

| Field | Value |
|---|---|
| Architecture | Gemma 4 |
| Layers | 48 |
| Attention heads | 16 (8 KV heads, alternating SWA/global) |
| Embedding dim | 3840 |
| Feed-forward dim | 15360 |
| SWA window | 1024 |
| Max context | 131072 |
| Quant | Q4_K_M (4.95 BPW) |

---

## Logs

Full logs are in `logs_round4/`, with Round 1–3 logs in `logs/`.

---

## License

MIT — feel free to use, share, and adapt. PRs with additional benchmarks welcome!
