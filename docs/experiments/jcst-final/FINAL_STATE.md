# JCS&T campaign — final state 2026-09-10T07:11Z

## Final dataset (docs/experiments/jcst-final): source per model
- amazon.nova-lite-v1_0: vast.ai (file)
- llama3.2_1b: gatekeeper (RTX 5080)
- llama3_8b: gatekeeper (RTX 5080)
- gemma3_4b: gatekeeper (RTX 5080)
- gemma4_e4b: vast.ai (file)
- phi4-mini: gatekeeper (RTX 5080)
- mistral_7b: gatekeeper (RTX 5080)
- qwen3.5_4b: gatekeeper (RTX 5080)
- qwen3.5_9b: gatekeeper (RTX 5080)

## Aggregates — final
```
model                    cfg  reps  valid  err   BR%          ASR%         FPR%        pre-L3 leak%  MT sess
Nova Lite                C0      3    195    0   0.0 ± 0.0    15.9 ± 1.4   0.0 ± 0.0    15.9      0/3
Nova Lite                C1      3    194    1   93.6 ± 1.3   0.0 ± 0.0    13.0 ± 7.5   0.0       3/3
Nova Lite                C2      3    195    0   93.7 ± 2.7   0.8 ± 1.4    11.6 ± 5.0   2.0       3/3
Nova Lite                C3      3    195    0   92.1 ± 1.4   0.0 ± 0.0    4.3 ± 0.0    0.0       3/3
Nova Lite                C4      3    195    0   93.7 ± 1.4   0.0 ± 0.0    7.2 ± 2.5    0.0       3/3
Nova Lite                C4d     3    191    4   95.9 ± 1.4   0.0 ± 0.0    5.9 ± 2.7    1.6       3/3
Llama 3.2 1B             C0      3    195    0   0.0 ± 0.0    3.2 ± 2.7    0.0 ± 0.0    3.2       0/3
Llama 3.2 1B             C1      3    195    0   6.3 ± 2.7    1.6 ± 1.4    2.9 ± 2.5    1.6       1/3
Llama 3.2 1B             C2      3    194    1   60.3 ± 1.4   1.6 ± 1.4    1.4 ± 2.5    3.9       3/3
Llama 3.2 1B             C3      3    195    0   8.7 ± 2.7    0.0 ± 0.0    0.0 ± 0.0    4.0       3/3
Llama 3.2 1B             C4      3    195    0   62.7 ± 1.4   0.0 ± 0.0    0.0 ± 0.0    5.9       3/3
Llama 3.2 1B             C4d     3    195    0   4.8 ± 2.4    0.0 ± 0.0    2.9 ± 2.5    2.4       0/3
Llama 3 8B               C0      3    195    0   0.0 ± 0.0    34.1 ± 1.4   0.0 ± 0.0    34.1      0/3
Llama 3 8B               C1      3    195    0   50.0 ± 0.0   7.1 ± 0.0    4.3 ± 0.0    7.1       3/3
Llama 3 8B               C2      3    195    0   85.7 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    0.0       3/3
Llama 3 8B               C3      3    195    0   54.8 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    2.4       3/3
Llama 3 8B               C4      3    195    0   85.7 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    5.9       3/3
Llama 3 8B               C4d     3    195    0   52.4 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    0.0       3/3
Gemma 3 4B               C0      3    195    0   0.0 ± 0.0    23.8 ± 0.0   0.0 ± 0.0    23.8      0/3
Gemma 3 4B               C1      3    195    0   50.0 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    0.0       0/3
Gemma 3 4B               C2      3    195    0   81.0 ± 0.0   0.0 ± 0.0    0.0 ± 0.0    0.0       3/3
Gemma 3 4B               C3      3    195    0   50.0 ± 0.0   0.0 ± 0.0    2.9 ± 2.5    0.0       0/3
Gemma 3 4B               C4      3    195    0   81.0 ± 0.0   0.0 ± 0.0    15.9 ± 2.5   0.0       3/3
Gemma 3 4B               C4d     3    195    0   52.4 ± 0.0   0.0 ± 0.0    5.8 ± 2.5    0.0       0/3
Gemma 4 E4B              C0      3    195    0   0.0 ± 0.0    2.4 ± 0.0    13.0 ± 0.0   2.4       0/3
Gemma 4 E4B              C1      3    195    0   79.4 ± 6.9   1.6 ± 1.4    11.6 ± 2.5   1.6       3/3
Gemma 4 E4B              C2      3    195    0   78.6 ± 0.0   2.4 ± 0.0    11.6 ± 2.5   5.9       3/3
Gemma 4 E4B              C3      3    195    0   73.8 ± 0.0   0.0 ± 0.0    8.7 ± 0.0    0.0       3/3
Gemma 4 E4B              C4      3    195    0   88.1 ± 4.1   0.0 ± 0.0    11.6 ± 2.5   5.9       3/3
Gemma 4 E4B              C4d     3    195    0   77.8 ± 1.4   0.0 ± 0.0    7.2 ± 2.5    0.0       3/3
Phi-4 Mini               C0      3    194    1   0.0 ± 0.0    4.0 ± 1.3    0.0 ± 0.0    4.0       0/3
Phi-4 Mini               C1      3    195    0   42.9 ± 0.0   0.0 ± 0.0    13.0 ± 0.0   0.0       3/3
Phi-4 Mini               C2      3    195    0   76.2 ± 0.0   0.0 ± 0.0    13.0 ± 0.0   0.0       3/3
Phi-4 Mini               C3      3    195    0   42.9 ± 0.0   0.0 ± 0.0    13.0 ± 0.0   0.0       3/3
Phi-4 Mini               C4      3    195    0   73.8 ± 0.0   0.0 ± 0.0    13.0 ± 0.0   0.0       3/3
Phi-4 Mini               C4d     3    195    0   47.6 ± 0.0   0.0 ± 0.0    13.0 ± 0.0   0.0       0/3
Mistral 7B               C0      3    195    0   0.0 ± 0.0    23.8 ± 0.0   0.0 ± 0.0    23.8      0/3
Mistral 7B               C1      3    195    0   71.4 ± 0.0   19.0 ± 0.0   4.3 ± 0.0    19.0      3/3
Mistral 7B               C2      3    195    0   85.7 ± 0.0   12.7 ± 1.4   4.3 ± 0.0    31.4      3/3
Mistral 7B               C3      3    195    0   78.6 ± 0.0   0.0 ± 0.0    8.7 ± 0.0    16.7      3/3
Mistral 7B               C4      3    195    0   89.7 ± 1.4   0.0 ± 0.0    13.0 ± 0.0   29.4      3/3
Mistral 7B               C4d     3    195    0   78.6 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    21.4      3/3
Qwen 3.5 4B              C0      3    195    0   0.0 ± 0.0    9.5 ± 0.0    0.0 ± 0.0    9.5       0/3
Qwen 3.5 4B              C1      3    195    0   23.8 ± 10.9  15.9 ± 2.7   0.0 ± 0.0    15.9      2/3
Qwen 3.5 4B              C2      3    195    0   65.9 ± 5.0   1.6 ± 1.4    0.0 ± 0.0    3.9       3/3
Qwen 3.5 4B              C3      3    195    0   40.5 ± 11.9  0.0 ± 0.0    0.0 ± 0.0    8.7       3/3
Qwen 3.5 4B              C4      3    195    0   69.8 ± 2.7   0.0 ± 0.0    0.0 ± 0.0    3.9       3/3
Qwen 3.5 4B              C4d     3    195    0   38.1 ± 4.1   0.0 ± 0.0    0.0 ± 0.0    15.9      3/3
Qwen 3.5 9B              C0      3    195    0   0.0 ± 0.0    0.0 ± 0.0    0.0 ± 0.0    0.0       0/3
Qwen 3.5 9B              C1      3    195    0   77.8 ± 1.4   1.6 ± 1.4    0.0 ± 0.0    1.6       3/3
Qwen 3.5 9B              C2      3    195    0   84.1 ± 3.6   0.0 ± 0.0    0.0 ± 0.0    0.0       3/3
Qwen 3.5 9B              C3      3    195    0   78.6 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    0.0       3/3
Qwen 3.5 9B              C4      3    195    0   84.9 ± 1.4   0.0 ± 0.0    0.0 ± 0.0    0.0       3/3
Qwen 3.5 9B              C4d     3    195    0   75.4 ± 1.4   0.0 ± 0.0    4.3 ± 0.0    0.0       3/3

marginal contributions (mean over available models, percentage points):
  DP: C1-C0    BR  +55.0   ASR   -7.8   (9 models)
  L2: C2-C1    BR  +24.0   ASR   -3.1   (9 models)
  L2: C4-C3    BR  +23.3   ASR   +0.0   (9 models)
  L3: C3-C1    BR   +2.7   ASR   -5.2   (9 models)
  L3: C4-C2    BR   +2.0   ASR   -2.1   (9 models)

summary written to docs/experiments/jcst-final/summary.json
wrote paper/jcst/tables/generated/tab-multimodel-overall.tex
wrote paper/jcst/tables/generated/tab-multimodel-percategory.tex
wrote paper/jcst/tables/generated/tab-multimodel-attribution.tex
wrote paper/jcst/tables/generated/tab-ablation-results.tex
wrote paper/jcst/tables/generated/tab-ablation-percategory.tex
wrote paper/jcst/tables/generated/tab-complementarity.tex
wrote paper/jcst/tables/generated/tab-model-roster.tex
```

## Aggregates — vast.ai dataset
```
model                    cfg  reps  valid  err   BR%          ASR%         FPR%        pre-L3 leak%  MT sess
Nova Lite                C0      3    195    0   0.0 ± 0.0    15.9 ± 1.4   0.0 ± 0.0    15.9      0/3
Nova Lite                C1      3    194    1   93.6 ± 1.3   0.0 ± 0.0    13.0 ± 7.5   0.0       3/3
Nova Lite                C2      3    195    0   93.7 ± 2.7   0.8 ± 1.4    11.6 ± 5.0   2.0       3/3
Nova Lite                C3      3    195    0   92.1 ± 1.4   0.0 ± 0.0    4.3 ± 0.0    0.0       3/3
Nova Lite                C4      3    195    0   93.7 ± 1.4   0.0 ± 0.0    7.2 ± 2.5    0.0       3/3
Nova Lite                C4d     3    191    4   95.9 ± 1.4   0.0 ± 0.0    5.9 ± 2.7    1.6       3/3
Llama 3.2 1B             C0      3    195    0   0.0 ± 0.0    7.1 ± 0.0    0.0 ± 0.0    7.1       0/3
Llama 3.2 1B             C1      3    195    0   1.6 ± 1.4    0.0 ± 0.0    0.0 ± 0.0    0.0       0/3
Llama 3.2 1B             C2      3    195    0   61.9 ± 0.0   0.0 ± 0.0    5.8 ± 2.5    0.0       3/3
Llama 3.2 1B             C3      3    195    0   7.9 ± 1.4    0.0 ± 0.0    0.0 ± 0.0    4.0       3/3
Llama 3.2 1B             C4      3    195    0   65.9 ± 1.4   0.0 ± 0.0    1.4 ± 2.5    15.7      3/3
Llama 3.2 1B             C4d     3    195    0   7.9 ± 1.4    0.0 ± 0.0    4.3 ± 4.3    4.8       3/3
Llama 3 8B               C0      3    195    0   0.0 ± 0.0    28.6 ± 0.0   0.0 ± 0.0    28.6      0/3
Llama 3 8B               C1      3    195    0   50.0 ± 0.0   9.5 ± 0.0    4.3 ± 0.0    9.5       3/3
Llama 3 8B               C2      3    195    0   88.1 ± 0.0   2.4 ± 0.0    4.3 ± 0.0    5.9       3/3
Llama 3 8B               C3      3    195    0   57.1 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    7.1       3/3
Llama 3 8B               C4      3    195    0   88.1 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    5.9       3/3
Llama 3 8B               C4d     3    195    0   57.1 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    0.0       3/3
Gemma 3 4B               C0      3    195    0   0.0 ± 0.0    19.8 ± 1.4   0.0 ± 0.0    19.8      0/3
Gemma 3 4B               C1      3    195    0   52.4 ± 0.0   0.0 ± 0.0    11.6 ± 2.5   0.0       0/3
Gemma 3 4B               C2      3    195    0   81.0 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    0.0       3/3
Gemma 3 4B               C3      3    195    0   54.8 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    0.0       0/3
Gemma 3 4B               C4      3    195    0   78.6 ± 0.0   0.0 ± 0.0    15.9 ± 2.5   0.0       3/3
Gemma 3 4B               C4d     3    195    0   54.8 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    0.0       0/3
Gemma 4 E4B              C0      3    195    0   0.0 ± 0.0    2.4 ± 0.0    13.0 ± 0.0   2.4       0/3
Gemma 4 E4B              C1      3    195    0   79.4 ± 6.9   1.6 ± 1.4    11.6 ± 2.5   1.6       3/3
Gemma 4 E4B              C2      3    195    0   78.6 ± 0.0   2.4 ± 0.0    11.6 ± 2.5   5.9       3/3
Gemma 4 E4B              C3      3    195    0   73.8 ± 0.0   0.0 ± 0.0    8.7 ± 0.0    0.0       3/3
Gemma 4 E4B              C4      3    195    0   88.1 ± 4.1   0.0 ± 0.0    11.6 ± 2.5   5.9       3/3
Gemma 4 E4B              C4d     3    195    0   77.8 ± 1.4   0.0 ± 0.0    7.2 ± 2.5    0.0       3/3
Mistral 7B               C0      3    195    0   0.0 ± 0.0    28.6 ± 0.0   0.0 ± 0.0    28.6      0/3
Mistral 7B               C1      3    195    0   78.6 ± 0.0   21.4 ± 0.0   4.3 ± 0.0    21.4      3/3
Mistral 7B               C2      3    195    0   83.3 ± 0.0   14.3 ± 0.0   4.3 ± 0.0    35.3      3/3
Mistral 7B               C3      3    195    0   79.4 ± 1.4   0.0 ± 0.0    8.7 ± 0.0    21.4      3/3
Mistral 7B               C4      3    195    0   85.7 ± 0.0   0.0 ± 0.0    8.7 ± 0.0    17.6      3/3
Mistral 7B               C4d     3    195    0   75.4 ± 1.4   0.0 ± 0.0    4.3 ± 0.0    31.0      3/3
Qwen 3.5 4B              C0      3    195    0   0.0 ± 0.0    11.9 ± 4.1   0.0 ± 0.0    11.9      0/3
Qwen 3.5 4B              C1      3    195    0   19.0 ± 4.1   0.0 ± 0.0    0.0 ± 0.0    0.0       2/3
Qwen 3.5 4B              C2      3    195    0   69.8 ± 1.4   4.0 ± 2.7    0.0 ± 0.0    9.8       3/3
Qwen 3.5 4B              C3      3    195    0   38.1 ± 2.4   0.0 ± 0.0    0.0 ± 0.0    13.5      1/3
Qwen 3.5 4B              C4      3    195    0   73.8 ± 0.0   0.0 ± 0.0    0.0 ± 0.0    9.8       3/3
Qwen 3.5 4B              C4d     3    195    0   31.7 ± 5.0   0.0 ± 0.0    0.0 ± 0.0    4.0       3/3
Qwen 3.5 9B              C4      3    195    0   81.0 ± 0.0   0.0 ± 0.0    0.0 ± 0.0    0.0       3/3
Qwen 3.5 9B              C4d     1     65    0   76.2 ± 0.0   0.0 ± 0.0    0.0 ± 0.0    0.0       1/1

marginal contributions (mean over available models, percentage points):
  DP: C1-C0    BR  +53.5   ASR  -11.7   (7 models)
  L2: C2-C1    BR  +26.0   ASR   -1.2   (7 models)
  L2: C4-C3    BR  +24.4   ASR   +0.0   (7 models)
  L3: C3-C1    BR   +4.1   ASR   -4.6   (7 models)
  L3: C4-C2    BR   +2.5   ASR   -3.4   (7 models)

summary written to docs/experiments/jcst/summary.json
wrote paper/jcst/tables/generated-vast/tab-multimodel-overall.tex
wrote paper/jcst/tables/generated-vast/tab-multimodel-percategory.tex
wrote paper/jcst/tables/generated-vast/tab-multimodel-attribution.tex
wrote paper/jcst/tables/generated-vast/tab-ablation-results.tex
wrote paper/jcst/tables/generated-vast/tab-ablation-percategory.tex
wrote paper/jcst/tables/generated-vast/tab-complementarity.tex
wrote paper/jcst/tables/generated-vast/tab-model-roster.tex
```

## Aggregates — gatekeeper dataset
```
model                    cfg  reps  valid  err   BR%          ASR%         FPR%        pre-L3 leak%  MT sess
Llama 3.2 1B             C0      3    195    0   0.0 ± 0.0    3.2 ± 2.7    0.0 ± 0.0    3.2       0/3
Llama 3.2 1B             C1      3    195    0   6.3 ± 2.7    1.6 ± 1.4    2.9 ± 2.5    1.6       1/3
Llama 3.2 1B             C2      3    194    1   60.3 ± 1.4   1.6 ± 1.4    1.4 ± 2.5    3.9       3/3
Llama 3.2 1B             C3      3    195    0   8.7 ± 2.7    0.0 ± 0.0    0.0 ± 0.0    4.0       3/3
Llama 3.2 1B             C4      3    195    0   62.7 ± 1.4   0.0 ± 0.0    0.0 ± 0.0    5.9       3/3
Llama 3.2 1B             C4d     3    195    0   4.8 ± 2.4    0.0 ± 0.0    2.9 ± 2.5    2.4       0/3
Llama 3 8B               C0      3    195    0   0.0 ± 0.0    34.1 ± 1.4   0.0 ± 0.0    34.1      0/3
Llama 3 8B               C1      3    195    0   50.0 ± 0.0   7.1 ± 0.0    4.3 ± 0.0    7.1       3/3
Llama 3 8B               C2      3    195    0   85.7 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    0.0       3/3
Llama 3 8B               C3      3    195    0   54.8 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    2.4       3/3
Llama 3 8B               C4      3    195    0   85.7 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    5.9       3/3
Llama 3 8B               C4d     3    195    0   52.4 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    0.0       3/3
Gemma 3 4B               C0      3    195    0   0.0 ± 0.0    23.8 ± 0.0   0.0 ± 0.0    23.8      0/3
Gemma 3 4B               C1      3    195    0   50.0 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    0.0       0/3
Gemma 3 4B               C2      3    195    0   81.0 ± 0.0   0.0 ± 0.0    0.0 ± 0.0    0.0       3/3
Gemma 3 4B               C3      3    195    0   50.0 ± 0.0   0.0 ± 0.0    2.9 ± 2.5    0.0       0/3
Gemma 3 4B               C4      3    195    0   81.0 ± 0.0   0.0 ± 0.0    15.9 ± 2.5   0.0       3/3
Gemma 3 4B               C4d     3    195    0   52.4 ± 0.0   0.0 ± 0.0    5.8 ± 2.5    0.0       0/3
Phi-4 Mini               C0      3    194    1   0.0 ± 0.0    4.0 ± 1.3    0.0 ± 0.0    4.0       0/3
Phi-4 Mini               C1      3    195    0   42.9 ± 0.0   0.0 ± 0.0    13.0 ± 0.0   0.0       3/3
Phi-4 Mini               C2      3    195    0   76.2 ± 0.0   0.0 ± 0.0    13.0 ± 0.0   0.0       3/3
Phi-4 Mini               C3      3    195    0   42.9 ± 0.0   0.0 ± 0.0    13.0 ± 0.0   0.0       3/3
Phi-4 Mini               C4      3    195    0   73.8 ± 0.0   0.0 ± 0.0    13.0 ± 0.0   0.0       3/3
Phi-4 Mini               C4d     3    195    0   47.6 ± 0.0   0.0 ± 0.0    13.0 ± 0.0   0.0       0/3
Mistral 7B               C0      3    195    0   0.0 ± 0.0    23.8 ± 0.0   0.0 ± 0.0    23.8      0/3
Mistral 7B               C1      3    195    0   71.4 ± 0.0   19.0 ± 0.0   4.3 ± 0.0    19.0      3/3
Mistral 7B               C2      3    195    0   85.7 ± 0.0   12.7 ± 1.4   4.3 ± 0.0    31.4      3/3
Mistral 7B               C3      3    195    0   78.6 ± 0.0   0.0 ± 0.0    8.7 ± 0.0    16.7      3/3
Mistral 7B               C4      3    195    0   89.7 ± 1.4   0.0 ± 0.0    13.0 ± 0.0   29.4      3/3
Mistral 7B               C4d     3    195    0   78.6 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    21.4      3/3
Qwen 3.5 4B              C0      3    195    0   0.0 ± 0.0    9.5 ± 0.0    0.0 ± 0.0    9.5       0/3
Qwen 3.5 4B              C1      3    195    0   23.8 ± 10.9  15.9 ± 2.7   0.0 ± 0.0    15.9      2/3
Qwen 3.5 4B              C2      3    195    0   65.9 ± 5.0   1.6 ± 1.4    0.0 ± 0.0    3.9       3/3
Qwen 3.5 4B              C3      3    195    0   40.5 ± 11.9  0.0 ± 0.0    0.0 ± 0.0    8.7       3/3
Qwen 3.5 4B              C4      3    195    0   69.8 ± 2.7   0.0 ± 0.0    0.0 ± 0.0    3.9       3/3
Qwen 3.5 4B              C4d     3    195    0   38.1 ± 4.1   0.0 ± 0.0    0.0 ± 0.0    15.9      3/3
Qwen 3.5 9B              C0      3    195    0   0.0 ± 0.0    0.0 ± 0.0    0.0 ± 0.0    0.0       0/3
Qwen 3.5 9B              C1      3    195    0   77.8 ± 1.4   1.6 ± 1.4    0.0 ± 0.0    1.6       3/3
Qwen 3.5 9B              C2      3    195    0   84.1 ± 3.6   0.0 ± 0.0    0.0 ± 0.0    0.0       3/3
Qwen 3.5 9B              C3      3    195    0   78.6 ± 0.0   0.0 ± 0.0    4.3 ± 0.0    0.0       3/3
Qwen 3.5 9B              C4      3    195    0   84.9 ± 1.4   0.0 ± 0.0    0.0 ± 0.0    0.0       3/3
Qwen 3.5 9B              C4d     3    195    0   75.4 ± 1.4   0.0 ± 0.0    4.3 ± 0.0    0.0       3/3

marginal contributions (mean over available models, percentage points):
  DP: C1-C0    BR  +46.0   ASR   -7.6   (7 models)
  L2: C2-C1    BR  +31.0   ASR   -4.2   (7 models)
  L2: C4-C3    BR  +27.7   ASR   +0.0   (7 models)
  L3: C3-C1    BR   +4.5   ASR   -6.5   (7 models)
  L3: C4-C2    BR   +1.2   ASR   -2.3   (7 models)

summary written to docs/experiments/jcst-gatekeeper/summary.json
wrote paper/jcst/tables/generated-gatekeeper/tab-multimodel-overall.tex
wrote paper/jcst/tables/generated-gatekeeper/tab-multimodel-percategory.tex
wrote paper/jcst/tables/generated-gatekeeper/tab-multimodel-attribution.tex
wrote paper/jcst/tables/generated-gatekeeper/tab-ablation-results.tex
wrote paper/jcst/tables/generated-gatekeeper/tab-ablation-percategory.tex
wrote paper/jcst/tables/generated-gatekeeper/tab-complementarity.tex
wrote paper/jcst/tables/generated-gatekeeper/tab-model-roster.tex
```

## Pending: agent-side L4 rows on AWS (if the other session did not), Juan's decisions 1-2, protocol text updates, commit.
