# GTX 1070 8GB 跑 Gemma 4 12B — 完整 Benchmark

> **Gemma 4 12B Q4_K_M on NVIDIA GTX 1070 8GB (Pascal, CC 6.1) — Full Sweep**
>
> Context 32K、KV q8_0/q8_0、Flash Attention、llama.cpp b9500 CUDA 12.4

---

## 硬體 / Hardware

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

## Benchmark 結論 / Conclusions

### 日用推薦 / Daily Driver

```
llama-server.exe \
  -m "F:/MODELS/.../gemma-4-12B-it-Q4_K_M.gguf" \
  --host 0.0.0.0 --port 8081 \
  -c 32768 -ngl 40 -fa on \
  -ctk q8_0 -ctv q8_0 -b 512 -ub 256 \
  --metrics
```

| Metric | Value |
|---|---|
| VRAM | ~7560 MiB（~600 MiB headroom） |
| Decode（短 prompt） | ~10.4 tok/s |
| Prefill（657 tokens） | ~226 tok/s |
| Prefill（12K tokens） | ~185 tok/s |
| 穩定性 | 全長度無 thrashing，長短 prompt 皆可 |

### 性能模式 / Performance Mode

```
-ngl 42 -ub 64（其他同上）
```

| Metric | Value |
|---|---|
| VRAM | ~7788 MiB（~400 MiB headroom） |
| Decode（短 prompt） | **~11.3 tok/s** |
| Prefill（657 tokens） | ~174 tok/s |
| 適用場景 | 多輪對話、code gen（prompt < 4K） |

---

## Round 1：最小可行測試 / Smoke Test

目的：確認 32K + q8/q8 能否啟動。

| # | ctk | ctv | ngl | ubatch | start | gen | VRAM | prompt t/s | decode t/s |
|---|---:|---|---:|---:|---:|---|---|---:|---:|---:|
| 1 | q8_0 | q8_0 | auto→36 | 128 | ✅ | ✅ | 6833 MiB | 22.7 | 9.65 |
| 2 | q8_0 | q4_0 | auto→37 | 128 | ✅ | ✅ | 6726 MiB | 23.4 | 9.40 |
| 3 | q8_0 | q8_0 | auto→36 | 64 | ✅ | ✅ | 6832 MiB | 23.0 | **9.74** |

**結論：q8/q8 完全可行，VRAM 83% 使用率，無 thrashing。**

---

## Round 2：NGL Sweep（手動指定）

固定：ctx=32768, q8/q8, b512, ub=64, prompt=657 tok, gen=256 tok

| ngl | VRAM peak | GPU model | GPU KV | prompt t/s | decode t/s | Note |
| --: | --------: | --------: | -----: | ---------: | ---------: | ---- |
| 36 | 6899 MiB | 5312 MiB | 524 MiB | 125.6 | 9.15 | baseline (=auto) |
| 38 | 7173 MiB | 5579 MiB | 542 MiB | 149.3 | 9.79 | |
| 40 | 7449 MiB | 5819 MiB | 578 MiB | 161.8 | **10.52** | ⭐ sweet spot |
| 42 | 7745 MiB | 6076 MiB | 614 MiB | 177.9 | **11.44** | ⚠️ high risk |
| 44 | 7878 MiB | 6341 MiB | 632 MiB | **59.1** ⬇ | 11.23 | 🔴 thrashing |

**ngl=44 prompt 速度崩跌 3x（178→59 tok/s），判定 thrashing，淘汰。**
**decode 線性改善至 ngl=42；每 +2 層約 +0.5 tok/s。**

---

## Round 3：精修 NGL + ubatch

固定：ctx=32768, q8/q8, b512, prompt=657 tok, gen=512 tok

| # | ngl | ubatch | VRAM | compute buf | prompt t/s | decode t/s | Note |
| --: | --: | -----: | --------: | ----------: | ---------: | ---------: | ---- |
| A | 41 | 64 | 7653 MiB | 114 MiB | 170.8 | 10.87 | |
| B | 40 | 128 | 7511 MiB | 127 MiB | **198.7** | 10.40 | prompt +22.8% |
| C | 41 | 128 | 7667 MiB | 127 MiB | **204.8** | 10.83 | prompt peak |
| D | 42 | 64 | 7786 MiB | 114 MiB | 174.4 | **11.31** | decode peak |

**ub=128 顯著提升 prompt 速度（+22.8%），decode 微降可忽略。ngl=42 重測穩定。**

---

## Round 4：長 Context + ubatch 驗證

### 4A：ubatch=256 測試

固定：ngl=40, prompt=657 tok, gen=512 tok

| ubatch | VRAM | compute buf | prompt t/s | decode t/s |
| -----: | --------: | ----------: | ---------: | ---------: |
| 128 | 7475 MiB | 127 MiB | 197.6 | 10.40 |
| 256 | 7515 MiB | 155 MiB | **225.6** | 10.39 |

**ub=256 再 +14% prompt 速度，VRAM 僅 +40 MiB，強烈推薦。**

### 4B：長 Prompt Prefill

固定：ngl=40, ub=256, gen=128 tok

| Prompt tokens | VRAM peak | prompt t/s | decode t/s |
| ------------: | --------: | ---------: | ---------: |
| 2,618 | 7560 MiB | **238.1** | 9.6 |
| 5,261 | 7560 MiB | 216.1 | 9.2 |
| 10,345 | 7560 MiB | 191.6 | 8.7 |
| 12,192 | 7560 MiB | 184.6 | 8.6 |

**VRAM 全程鎖定 7560 MiB（KV cache 預分配），速度線性優雅衰減，無 thrashing。**

### 4C：Performance Stretch（ngl=42）

| ngl | Prompt tokens | VRAM | prompt t/s | decode t/s |
| --: | ------------: | --------: | ---------: | ---------: |
| 42 | 5,261 | 7788 MiB | 166.1 | 9.9 |
| 42 | 10,345 | 7788 MiB | 147.2 | 9.4 |

**ngl=42 在長 prompt 下 prompt 速度僅為 ngl=40 的 ~77%，但 decode 仍快 ~7%。適合 prompt < 4K 場景。**

---

## 模型架構 / Model Architecture

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

完整 logs 在 `logs_round4/`，Round 1-3 在 `logs/`。

---

## License

MIT — feel free to use, share, and adapt. PRs with additional benchmarks welcome!
