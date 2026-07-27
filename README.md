# GTX 1070 8GB 跑 Gemma 4 12B — 快速設定與實測

[English Version](README_EN.md)

這個 repo 的目的很單純：**之後只要有一台電腦插上 GTX 1070 8GB，就能快速把 Gemma 4 12B Q4_K_M 跑起來，並直接套用已經測過的參數。**

不是要求完全複製原本的 i7-7700K 平台。CPU、RAM、OS 不同時絕對速度會有差，但 GTX 1070 的 VRAM 配置、GPU offload 與 ubatch 的甜蜜點仍可作為很實用的起始值。

---

## TL;DR：直接這樣跑

### 穩定 / 長 context 推薦

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

原始測試機結果：

| 項目 | 約略結果 |
|---|---:|
| VRAM | ~7560 MiB |
| VRAM headroom | ~600 MiB |
| Decode（短 prompt） | ~10.4 tok/s |
| Prefill（657 tokens） | ~226 tok/s |
| Prefill（12K tokens） | ~185 tok/s |
| 32K context | 可正常啟動 |

**這組是預設建議。** VRAM 還留有一些空間，長 prompt 也沒有出現明顯效能崩跌。

### 短 prompt / 追求 decode

```text
-ngl 42 -ub 64
```

其他設定相同。

原始測試機約：

| 項目 | 約略結果 |
|---|---:|
| VRAM | ~7788 MiB |
| Decode | ~11.3 tok/s |
| Prefill（657 tokens） | ~174 tok/s |

`ngl=42` 比較接近 8GB VRAM 上限。短 prompt 可以換到較快 decode，但長 prompt prefill 明顯不如 `ngl=40 / ub=256`。

---

## Reference machine

這只是原始數據的參考平台，**不是必要硬體**。

| Item | Spec |
|---|---|
| GPU | NVIDIA GeForce GTX 1070 8GB（8192 MiB, Pascal CC 6.1） |
| CPU | Intel Core i7-7700K @ 4.20GHz（4C/8T） |
| RAM | 32 GB DDR4 |
| OS | Windows 10 |
| Driver | 582.28 |
| llama.cpp | b9500, commit `3d1998634`, CUDA 12.4 |
| Model | `gemma-4-12B-it-Q4_K_M.gguf` |
| Model repo | `lmstudio-community/gemma-4-12B-it-GGUF` |
| Quant | Q4_K_M, ~7.04 GB, 4.95 BPW |

CPU 或 RAM 不同時，尤其因為模型不是 100% GPU-resident，絕對 tok/s 可能不同。這份資料主要用來快速找到 GTX 1070 的合理 VRAM / offload 設定。

---

## 最重要的已知結論

### 1. `ngl=40` 是最實用的平衡點

固定條件：ctx=32768、KV q8_0/q8_0、b512、ub64、原始短 prompt 約 657 tokens。

| ngl | VRAM peak | GPU model | GPU KV | prompt t/s | decode t/s | 判讀 |
|---:|---:|---:|---:|---:|---:|---|
| 36 | 6899 MiB | 5312 MiB | 524 MiB | 125.6 | 9.15 | baseline |
| 38 | 7173 MiB | 5579 MiB | 542 MiB | 149.3 | 9.79 | 可用 |
| 40 | 7449 MiB | 5819 MiB | 578 MiB | 161.8 | 10.52 | **sweet spot** |
| 42 | 7745 MiB | 6076 MiB | 614 MiB | 177.9 | 11.44 | VRAM 很緊 |
| 44 | 7878 MiB | 6341 MiB | 632 MiB | 59.1 | 11.23 | 明顯異常慢 |

`ngl=44` 時 prefill 從約 178 tok/s 掉到約 59 tok/s，而且 VRAM 已非常接近上限。這個行為與記憶體壓力 / paging 或 thrashing 相符，因此不建議。

### 2. `ubatch=256` 對 prefill 很划算

固定 `ngl=40`：

| ubatch | VRAM | compute buf | prompt t/s | decode t/s |
|---:|---:|---:|---:|---:|
| 128 | 7475 MiB | 127 MiB | 197.6 | 10.40 |
| 256 | 7515 MiB | 155 MiB | **225.6** | 10.39 |

只多約 40 MiB VRAM，prefill 明顯提升，decode 幾乎不變。

### 3. 長 prompt 用 `ngl=40 / ub=256` 比較穩

| Prompt tokens | VRAM peak | prompt t/s | decode t/s |
|---:|---:|---:|---:|
| 2,618 | 7560 MiB | 238.1 | 9.6 |
| 5,261 | 7560 MiB | 216.1 | 9.2 |
| 10,345 | 7560 MiB | 191.6 | 8.7 |
| 12,192 | 7560 MiB | 184.6 | 8.6 |

KV cache 預先配置後，這幾個長度下 VRAM 都維持約 7560 MiB。

相反地，`ngl=42`：

| Prompt tokens | VRAM | prompt t/s | decode t/s |
|---:|---:|---:|---:|
| 5,261 | 7788 MiB | 166.1 | 9.9 |
| 10,345 | 7788 MiB | 147.2 | 9.4 |

所以：

- **一般聊天、長 context：`ngl=40 / ub=256`**
- **短 prompt、在意 decode：`ngl=42 / ub=64`**
- **不要直接衝 `ngl=44`**

---

## 新電腦快速上手流程

1. 裝 NVIDIA driver。
2. 準備 CUDA 版 `llama.cpp`。
3. 下載 `gemma-4-12B-it-Q4_K_M.gguf`。
4. 先用 `ngl=40 / ub=256 / ctx=32768 / KV q8_0` 啟動。
5. 看啟動後 VRAM 是否仍保留約 400–600 MiB 以上。
6. 如果該台機器背景程式較多或 VRAM 不夠，先降到 `ngl=38`。
7. 若只跑短 prompt，而且 VRAM 很乾淨，再試 `ngl=42 / ub=64`。

Windows 可直接修改 repo 裡的 `gemma4_12b_perf.bat`，只需要填入本機的 llama.cpp 與模型路徑。

---

## 早期 smoke test 紀錄

32K context + q8/q8 KV 可以正常工作：

| ctk | ctv | ngl | ubatch | VRAM | prompt t/s | decode t/s |
|---|---|---:|---:|---:|---:|---:|
| q8_0 | q8_0 | auto→36 | 128 | 6833 MiB | 22.7 | 9.65 |
| q8_0 | q4_0 | auto→37 | 128 | 6726 MiB | 23.4 | 9.40 |
| q8_0 | q8_0 | auto→36 | 64 | 6832 MiB | 23.0 | 9.74 |

後續固定採用 q8_0/q8_0。

---

## 其他已測組合

固定 ctx=32768、q8/q8、b512：

| ngl | ubatch | VRAM | compute buf | prompt t/s | decode t/s |
|---:|---:|---:|---:|---:|---:|
| 41 | 64 | 7653 MiB | 114 MiB | 170.8 | 10.87 |
| 40 | 128 | 7511 MiB | 127 MiB | 198.7 | 10.40 |
| 41 | 128 | 7667 MiB | 127 MiB | 204.8 | 10.83 |
| 42 | 64 | 7786 MiB | 114 MiB | 174.4 | 11.31 |

---

## 關於可重現性

這份 repo 保存的是**當時實際量到的參數與結果**，目的是讓未來快速重建環境，而不是做跨平台嚴格科學 benchmark。

原始 benchmark 使用的完整 prompt 文字與 raw logs 目前沒有保存在 repo，因此這些舊數據應視為 reference measurements，而不是 bit-for-bit reproducible benchmark。

之後若重新測試，建議順手記錄：

- GPU / CPU / RAM
- driver 與 llama.cpp commit
- GGUF 檔名與 SHA256
- 完整 command line
- prompt token 數
- prompt / decode tok/s
- peak VRAM

這樣以後換電腦時就很好比。

---

## Model architecture

| Field | Value |
|---|---|
| Architecture | Gemma 4 |
| Layers | 48 |
| Attention heads | 16（8 KV heads，alternating SWA/global） |
| Embedding dim | 3840 |
| Feed-forward dim | 15360 |
| SWA window | 1024 |
| Max context | 131072 |
| Quant | Q4_K_M（4.95 BPW） |

---

## License

MIT — 可自由使用、分享與修改。