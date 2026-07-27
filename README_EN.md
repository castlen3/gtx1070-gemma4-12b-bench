# GTX 1070 8GB + Gemma 4 12B — Quick Setup & Reference Benchmarks

[中文版](README.md)

This repo is intended as a **practical setup reference**: plug a GTX 1070 8GB into another PC, install llama.cpp, and start from settings that have already been tested with Gemma 4 12B Q4_K_M.

The original measurements used an i7-7700K, but an identical CPU is **not required**. Different CPUs, RAM, drivers, and operating systems will change absolute throughput. The main value here is the known-good VRAM/offload configuration for the GTX 1070.

---

## TL;DR — start here

### Stable / long-context profile

```bat
llama-server.exe ^
  -m "gemma-4-12B-it-Q4_K_M.gguf" ^
  -c 32768 ^
  -ngl 40 ^
  -fa on ^
  -ctk q8_0 ^
  -ctv q8_0 ^
  -b 512 ^
  -ub 256 ^
  --metrics
```

Reference-system results:

| Metric | Approx. result |
|---|---:|
| VRAM | ~7560 MiB |
| VRAM headroom | ~600 MiB |
| Decode, short prompt | ~10.4 tok/s |
| Prefill, 657 tokens | ~226 tok/s |
| Prefill, ~12K tokens | ~185 tok/s |
| 32K context | Starts and runs normally |

**This is the recommended default.** It leaves some VRAM headroom and behaves well with longer prompts.

### Short prompts / maximum decode

```text
-ngl 42 -ub 64
```

Keep the remaining options unchanged.

Reference-system results:

| Metric | Approx. result |
|---|---:|
| VRAM | ~7788 MiB |
| Decode | ~11.3 tok/s |
| Prefill, 657 tokens | ~174 tok/s |

`ngl=42` runs much closer to the 8 GB VRAM limit. It can improve decode speed, but long-prompt prefill is substantially slower than `ngl=40 / ub=256`.

---

## Reference machine

This is the machine used for the recorded measurements. It is **not a hardware requirement**.

| Item | Spec |
|---|---|
| GPU | NVIDIA GeForce GTX 1070 8GB (8192 MiB, Pascal CC 6.1) |
| CPU | Intel Core i7-7700K @ 4.20GHz (4C/8T) |
| RAM | 32 GB DDR4 |
| OS | Windows 10 |
| Driver | 582.28 |
| llama.cpp | b9500, commit `3d1998634`, CUDA 12.4 |
| Model | `gemma-4-12B-it-Q4_K_M.gguf` |
| Model repo | `lmstudio-community/gemma-4-12B-it-GGUF` |
| Quant | Q4_K_M, ~7.04 GB, 4.95 BPW |

Because the model is not fully GPU-resident, CPU and memory performance can affect absolute tok/s. Treat these figures as practical reference measurements rather than cross-platform normalized scores.

---

## Key findings

### 1. `ngl=40` is the most useful balance

Fixed conditions: ctx=32768, KV q8_0/q8_0, b512, ub64, original short prompt ~657 tokens.

| ngl | VRAM peak | GPU model | GPU KV | prompt t/s | decode t/s | Interpretation |
|---:|---:|---:|---:|---:|---:|---|
| 36 | 6899 MiB | 5312 MiB | 524 MiB | 125.6 | 9.15 | baseline |
| 38 | 7173 MiB | 5579 MiB | 542 MiB | 149.3 | 9.79 | usable |
| 40 | 7449 MiB | 5819 MiB | 578 MiB | 161.8 | 10.52 | **sweet spot** |
| 42 | 7745 MiB | 6076 MiB | 614 MiB | 177.9 | 11.44 | very tight VRAM |
| 44 | 7878 MiB | 6341 MiB | 632 MiB | 59.1 | 11.23 | severe slowdown |

At `ngl=44`, prefill throughput fell from roughly 178 tok/s to 59 tok/s while VRAM was very close to the card limit. This is consistent with memory-pressure-induced paging/thrashing, so `ngl=44` is not recommended.

### 2. `ubatch=256` is very worthwhile for prefill

At `ngl=40`:

| ubatch | VRAM | compute buf | prompt t/s | decode t/s |
|---:|---:|---:|---:|---:|
| 128 | 7475 MiB | 127 MiB | 197.6 | 10.40 |
| 256 | 7515 MiB | 155 MiB | **225.6** | 10.39 |

About 40 MiB of additional VRAM produced a clear prefill gain with essentially unchanged decode performance.

### 3. Long prompts favor `ngl=40 / ub=256`

| Prompt tokens | VRAM peak | prompt t/s | decode t/s |
|---:|---:|---:|---:|
| 2,618 | 7560 MiB | 238.1 | 9.6 |
| 5,261 | 7560 MiB | 216.1 | 9.2 |
| 10,345 | 7560 MiB | 191.6 | 8.7 |
| 12,192 | 7560 MiB | 184.6 | 8.6 |

The preallocated KV cache kept VRAM at roughly 7560 MiB across these prompt lengths.

For comparison, `ngl=42`:

| Prompt tokens | VRAM | prompt t/s | decode t/s |
|---:|---:|---:|---:|
| 5,261 | 7788 MiB | 166.1 | 9.9 |
| 10,345 | 7788 MiB | 147.2 | 9.4 |

Practical rule:

- **General chat / long context: `ngl=40 / ub=256`**
- **Short prompts / prioritize decode: `ngl=42 / ub=64`**
- **Avoid jumping straight to `ngl=44`**

---

## Quick setup on another PC

1. Install an NVIDIA driver.
2. Prepare a CUDA build of `llama.cpp`.
3. Download `gemma-4-12B-it-Q4_K_M.gguf`.
4. Start with `ngl=40 / ub=256 / ctx=32768 / KV q8_0`.
5. Check that several hundred MiB of VRAM remain free after startup.
6. If the machine has more background GPU usage, reduce to `ngl=38`.
7. For short prompts on an otherwise clean GPU, optionally try `ngl=42 / ub=64`.

On Windows, edit `gemma4_12b_perf.bat` and set only the local llama.cpp and model paths.

---

## Early smoke-test results

32K context with q8/q8 KV was confirmed to work:

| ctk | ctv | ngl | ubatch | VRAM | prompt t/s | decode t/s |
|---|---|---:|---:|---:|---:|---:|
| q8_0 | q8_0 | auto→36 | 128 | 6833 MiB | 22.7 | 9.65 |
| q8_0 | q4_0 | auto→37 | 128 | 6726 MiB | 23.4 | 9.40 |
| q8_0 | q8_0 | auto→36 | 64 | 6832 MiB | 23.0 | 9.74 |

Later tests standardized on q8_0/q8_0.

---

## Other tested combinations

Fixed ctx=32768, q8/q8, b512:

| ngl | ubatch | VRAM | compute buf | prompt t/s | decode t/s |
|---:|---:|---:|---:|---:|---:|
| 41 | 64 | 7653 MiB | 114 MiB | 170.8 | 10.87 |
| 40 | 128 | 7511 MiB | 127 MiB | 198.7 | 10.40 |
| 41 | 128 | 7667 MiB | 127 MiB | 204.8 | 10.83 |
| 42 | 64 | 7786 MiB | 114 MiB | 174.4 | 11.31 |

---

## Reproducibility note

This repository preserves the **settings and measurements that were recorded at the time**. Its main purpose is fast environment reconstruction, not a strict cross-platform scientific benchmark.

The exact original prompt text and raw benchmark logs are not currently preserved in the repository. Therefore, the historical numbers should be treated as reference measurements rather than bit-for-bit reproducible benchmark results.

For future runs, it is useful to record:

- GPU / CPU / RAM
- driver and llama.cpp commit
- GGUF filename and SHA256
- full command line
- prompt token count
- prompt / decode tok/s
- peak VRAM

---

## Model architecture

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

## License

MIT — free to use, share, and adapt.