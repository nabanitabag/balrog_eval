# Time-Aware BALROG Benchmark

## Research Question
Does extended LLM deliberation hurt performance in time-sensitive
interactive environments?

## Approach
Modified BALROG's evaluator to inject no-op environment steps
proportional to LLM output tokens (K tokens = 1 no-op step).

## Results
| Config    | K   | BabyAI Progression |
|-----------|-----|--------------------|
| Baseline  | —   | 41.3% ± 7.3%      |
| Lenient   | 100 | TBD                |
| Medium    | 50  | TBD                |
| Harsh     | 10  | TBD                |

## How to Reproduce
[instructions here]