# Pre-flight Spec — AiPipe Router v2: Complexity Scoring + Model Selection

**Story ID:** aip-r1  
**Type:** Standard  
**Priority:** Critical  
**Effort:** 4–6h  
**Risk:** Medium (hot path change — must not regress latency)  
**Date:** 2026-02-20  
**Repo:** /home/openclaw/projects/AiPipe/Server/

---

## Assumptions

1. We are NOT changing the proxy, translation, or cache layers — surgical changes to `util/` and `model/` only.
2. All existing tests must pass. New tests required for each new signal.
3. Benchmark gate: `ComplexityScore` (renamed `Scorer.Score`) must be ≤1.2μs on hot path, ≤2 allocs.
4. `Pick()` signature changes are wrapped in a `PickRequest` struct — no callers break.
5. No external dependencies added. Everything stays stdlib.
6. `MaxContextWindow` is added to `ModelConfig` and `DefaultModels()` — callers that don't set it get safe defaults (0 = unconstrained).

---

## Success Criteria

- [ ] `Scorer.Score()` replaces `ComplexityScore()` — multi-signal, categorized keywords
- [ ] `Registry.PickFor(PickRequest)` replaces `Registry.Pick()` — context window guard + stream preference
- [ ] Per-model TTFT tracked with EMA in `model.State` (atomic, no lock on hot path)
- [ ] `MaxContextWindow int` added to `ModelConfig` and all `DefaultModels()` entries
- [ ] All existing tests pass
- [ ] New unit tests: one per signal, edge cases (empty, single message, 10-turn conversation)
- [ ] Benchmark: `BenchmarkScorerScore` ≤ 1.2μs, ≤ 2 allocs
- [ ] `go test -race ./...` passes
- [ ] `go vet ./...` clean

---

## Design

### 1. Multi-Signal Scorer (replaces `ComplexityScore`)

**Key principle:** pre-compile everything at startup, zero regex at call time, only byte scanning + arithmetic on hot path.

```go
// internal/util/scorer.go

type Scorer struct {
    // all keyword tables are []string pre-sorted for binary search
    // OR just plain []string for strings.Index (SSE2-accelerated, faster than map lookup for <30 items)
}

var DefaultScorer = NewScorer()

func (s *Scorer) Score(messages []types.Message) float64 {
    return s.lengthSignal(messages)*0.30 +
           s.codeSignal(messages)*0.25 +
           s.keywordSignal(messages)*0.25 +
           s.structuralSignal(messages)*0.10 +
           s.depthSignal(messages)*0.10
}
```

**Signals (each returns 0.0–1.0):**

#### Signal 1: Length (weight 0.30)
Better token estimate than `chars/4`:
```go
func tokenEstimate(s string) int {
    chars := len(s)
    spaces := strings.Count(s, " ") + strings.Count(s, "\n")
    // code is char-dense but token-heavy; prose approximates 3.8 chars/token
    return int(float64(chars+spaces/3) / 3.8)
}
```
Normalize to 8000 tokens → `clamp(tokens/8000, 0, 1.0)`

#### Signal 2: Code (weight 0.25)
Scan only the last 4 messages (not all — keep hot path fast).
```
No code:                              0.00
Generic ``` block:                    0.40
2+ code blocks:                       0.60
Language marker present (any):        +0.20
Complex language (rust/go/cpp/zig/
  assembly/typescript/python):        +0.30 (cumulative, capped at 1.0)
```
Language detection: scan the byte immediately after ``` for the language identifier.
Pre-defined sets:
- `complexLangs`: `["rust","go","cpp","c++","c","zig","assembly","typescript","swift","kotlin","haskell"]`
- `simpleLangs`: `["bash","sh","shell","json","yaml","toml","text",""]`

#### Signal 3: Keyword (weight 0.25)
Categorized keyword table with per-category weights. Sum of matched categories, capped at 1.0.

```go
type kwCategory struct {
    keywords []string
    score    float64
}

var kwCategories = []kwCategory{
    // High complexity — strong positive signal
    {["proof", "derive", "theorem", "formula", "mathematical", "formal", "induction", "complexity class"], 0.90},
    {["architecture", "distributed", "scalability", "consensus", "fault tolerance", "latency", "throughput"], 0.80},
    {["security", "vulnerability", "attack vector", "cryptography", "authentication", "injection", "exploit"], 0.75},
    
    // Medium-high — positive signal  
    {["analyze", "analysis", "compare", "tradeoff", "evaluate", "benchmark", "profile", "optimize"], 0.60},
    {["algorithm", "data structure", "time complexity", "space complexity", "big-o"], 0.65},
    {["debug", "error", "stack trace", "reproduce", "root cause", "crash", "panic", "race condition"], 0.55},
    {["refactor", "redesign", "migrate", "upgrade", "technical debt"], 0.50},
    
    // Medium — slight positive
    {["explain", "how does", "what is", "describe", "walk me through"], 0.30},
    {["write", "implement", "build", "create", "generate code"], 0.40},
    
    // Low complexity — negative signal (reduces score)
    {["translate", "convert to language"], -0.20},
    {["summarize", "summarise", "tldr", "brief", "shorten"], -0.15},
    {["list", "enumerate", "what are the"], -0.10},
    {["hello", "hi ", "thanks", "thank you", "good morning"], -0.30},
}
```

Scoring: for each category, if ANY keyword matches → add category.score.
Final: `clamp(base(0.1) + sum(matched), 0.0, 1.0)`

Note: negative categories can bring the score below base. This is intentional — a pure "translate this sentence to French" should score very low and route to cheapest model.

#### Signal 4: Structural (weight 0.10)
Scan only the last message content (byte scan, no regex):
```
Multiple question marks (≥2):     +0.40
Numbered list (lines starting 1./2.): +0.35
Bullet points (lines starting -/*/•): +0.25
Markdown headers (## or ###):     +0.20
```
Cap at 1.0. This detects "multi-part complex questions" which require more model capability.

#### Signal 5: Depth (weight 0.10)
Pure turn count on the messages slice — zero scanning:
```go
turns := 0
for _, m := range messages {
    if strings.EqualFold(m.Role, "user") { turns++ }
}
// turns == 1:  0.10 (fresh start)
// turns == 3:  0.40 (established context)
// turns == 5:  0.65 (deep conversation)
// turns >= 8:  1.00 (long session — model needs full context comprehension)
depthScore := clamp(float64(turns-1)/7.0, 0.0, 1.0)
```

---

### 2. Registry.PickFor (replaces Registry.Pick)

```go
type PickRequest struct {
    Complexity    float64
    InTokens      int
    MaxOutTokens  int
    TotalContext   int    // InTokens + prior conversation tokens (for context window guard)
    Stream        bool
}

func (r *Registry) PickFor(req PickRequest) *State
```

**Filtering changes:**
1. **Context window guard** (new): `model.MaxContextWindow == 0 || req.TotalContext <= model.MaxContextWindow`
2. **Complexity fit** (unchanged): `model.MaxComplexity >= req.Complexity`
3. **Quality gate** (unchanged): `EffectiveSuccessRate() >= 0.95`

**Sorting changes:**
```go
sort.SliceStable(filtered, func(i, j int) bool {
    ci := estimatedCost(filtered[i], req.InTokens, req.MaxOutTokens)
    cj := estimatedCost(filtered[j], req.InTokens, req.MaxOutTokens)
    
    // For streaming: bias toward low TTFT
    if req.Stream {
        // Add TTFT penalty: normalize p50 TTFT to [0, 0.3] of cost
        ci += ci * filtered[i].TTFTFactor()   // 0.0 = fast, 0.3 = slow
        cj += cj * filtered[j].TTFTFactor()
    }
    
    if ci == cj {
        return filtered[i].EffectiveSuccessRate() > filtered[j].EffectiveSuccessRate()
    }
    return ci < cj
})
```

---

### 3. Per-Model TTFT EMA (model.State addition)

Zero-lock on hot path using atomic int64 (store TTFT as fixed-point microseconds × 1000):

```go
type State struct {
    Config
    // ... existing fields ...
    
    // TTFT EMA — stored as int64 microseconds × 1000, updated with alpha=0.1
    // No lock needed: CAS loop for update, relaxed read for routing
    ttftEMAUs atomic.Int64   // 0 = no data
}

const ttftEMAAlpha = 0.1

func (s *State) RecordTTFT(ttftMs float64) {
    newUs := int64(ttftMs * 1000)
    for {
        current := s.ttftEMAUs.Load()
        var next int64
        if current == 0 {
            next = newUs
        } else {
            next = int64(float64(current)*(1-ttftEMAAlpha) + float64(newUs)*ttftEMAAlpha)
        }
        if s.ttftEMAUs.CompareAndSwap(current, next) {
            return
        }
    }
}

func (s *State) TTFTFactor() float64 {
    v := s.ttftEMAUs.Load()
    if v == 0 {
        return 0.0  // no data — no penalty
    }
    ttftMs := float64(v) / 1000.0
    // Normalize: 0ms = 0.0, 500ms = 0.15, 2000ms = 0.30 (max penalty)
    return clamp(ttftMs/6666.0, 0.0, 0.30)
}
```

---

### 4. MaxContextWindow in ModelConfig

```go
type Config struct {
    ID             string
    Provider       types.Provider
    MaxComplexity  float64
    CostInput1M    float64
    CostOutput1M   float64
    MaxContextWindow int   // 0 = unconstrained
}

// DefaultModels() updated:
{ID: "claude-haiku-4-5",   MaxContextWindow: 200_000, ...}
{ID: "claude-sonnet-4-5",  MaxContextWindow: 200_000, ...}
{ID: "claude-opus-4-6",    MaxContextWindow: 200_000, ...}
{ID: "gpt-4o-mini",        MaxContextWindow: 128_000, ...}
{ID: "gpt-4o-2024-11-20",  MaxContextWindow: 128_000, ...}
{ID: "grok-4-1-fast-*",    MaxContextWindow: 131_072, ...}
{ID: "grok-4",             MaxContextWindow: 131_072, ...}
```

---

### 5. server.go callsite update

```go
// In handleProxy, replace:
picked := s.registry.Pick(complexity, estInTokens, estOutTokens)

// With:
totalContext := estInTokens + (estOutTokens / 2)  // conservative estimate
picked := s.registry.PickFor(model.PickRequest{
    Complexity:   complexity,
    InTokens:     estInTokens,
    MaxOutTokens: estOutTokens,
    TotalContext:  totalContext,
    Stream:       unified.Stream,
})
```

And in `processJob`, after recording call:
```go
if upstream.TTFTMs > 0 {
    j.picked.RecordTTFT(upstream.TTFTMs)
}
```

Also replace `util.ComplexityScore(unified.Messages)` with `util.DefaultScorer.Score(unified.Messages)`.

---

## File Changes (surgical scope)

| File | Change |
|------|--------|
| `internal/util/scorer.go` | **NEW** — Scorer struct + Score() method |
| `internal/util/util.go` | Remove ComplexityScore(), keep EstimateInputTokens, NormalizePrompt, CacheKey |
| `internal/util/scorer_test.go` | **NEW** — signal unit tests + benchmark |
| `internal/util/util_test.go` | Remove TestComplexityScoreRangeAndSignal, BenchmarkComplexityScore |
| `internal/model/models.go` | Add MaxContextWindow to Config, add PickRequest, PickFor(), TTFTFactor(), RecordTTFT() |
| `internal/model/models_test.go` | Add tests for context window guard, stream preference, TTFT factor |
| `internal/app/server.go` | Update callsite: PickFor() + RecordTTFT() |

**Total scope: ~4 files modified, 2 new files. No changes to cache, stats, translate, provider, types, config.**

---

## Performance Budget

| Operation | Current | Target | Method |
|-----------|---------|--------|--------|
| Scorer.Score() | ~300-600ns | ≤800ns | byte scan, pre-compiled tables, no regex at call |
| Registry.PickFor() | ~40ns | ≤80ns | one extra atomic.Load() per model |
| RecordTTFT() | — | ≤50ns | CAS loop (typically 1 iteration) |
| Zero allocs? | 1-2 | 0 | avoid strings.Join, pre-allocate |

---

## What We Are NOT Building

- ML-based classifier (no external model, no embeddings)
- Semantic complexity analysis (requires tokenizer)
- Per-request latency SLOs (routing policy)
- Streaming passthrough (separate story)
- Dynamic model config reload (restart required)

---

## Test Plan

```go
// Signal isolation tests
TestScorerLengthSignal_ShortChat_Low()
TestScorerLengthSignal_LongTechnical_High()
TestScorerCodeSignal_NoCode_Zero()
TestScorerCodeSignal_RustBlock_High()
TestScorerCodeSignal_BashBlock_Low()
TestScorerKeywordSignal_HelloWorld_Negative()
TestScorerKeywordSignal_ProveTheorem_High()
TestScorerKeywordSignal_AnalyzeArchitecture_High()
TestScorerKeywordSignal_TranslateFrench_Low()
TestScorerStructuralSignal_MultipleQuestions_High()
TestScorerDepthSignal_TenTurns_High()
TestScorerDepthSignal_OneTurn_Low()

// Integration tests (end-to-end score)
TestScorer_SimpleGreeting_ScoreBelow0p2()
TestScorer_AnalyzeRustArchitecture_ScoreAbove0p7()
TestScorer_TranslateToFrench_ScoreBelow0p3()
TestScorer_MathProof_ScoreAbove0p8()
TestScorer_EmptyMessages_NoError()

// PickFor tests
TestPickFor_ContextWindowGuard_ExcludesSmallContextModels()
TestPickFor_StreamTrue_PrefersLowTTFT()
TestPickFor_StreamFalse_PurelyByEstimatedCost()

// TTFT EMA test
TestRecordTTFT_FirstSample_StoresDirectly()
TestRecordTTFT_SubsequentSample_EMADecay()
TestTTFTFactor_NoData_ReturnsZero()
TestTTFTFactor_500ms_Returns0p075()

// Benchmark
BenchmarkScorerScore_HotPath()  // must be ≤1.2μs, ≤2 allocs
```

---

## Red Flags

- Benchmark regresses beyond 1.2μs → profile and identify which signal is slow, simplify
- Negative keyword categories cause routing failures (score → 0 for valid non-trivial request) → add floor of 0.05
- Context window guard removes ALL candidates → fall back to ignoring context window (same as today)
- TTFT EMA races under `go test -race` → switch to mutex-protected update if CAS loop is problematic
