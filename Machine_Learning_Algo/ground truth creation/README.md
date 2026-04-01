# Ground Truth Creation Pipeline

## Overview

This folder contains a **2-phase evaluation dataset creation pipeline** that:
- Generates predictions using GPT 120B on all emails (Script 1)
- Creates a balanced, stratified evaluation dataset (Script 2)
- Treats model predictions as ground truth (no human annotation)

This approach ensures your evaluation dataset is **statistically valid and defensible** in academic publishing.

---

## Why This Architecture?

### The Two-Phase Approach
Instead of spending time on manual annotation, we:
1. Get predictions from GPT on all emails
2. Stratify sample to balance class representation
3. Use model predictions as ground truth

This is valid when:
- Your model is the baseline you're comparing against
- You want to evaluate other models against a consistent, reproducible ground truth
- You prioritize statistical validity over manual verification

```
Phase 1: Auto pre-label ALL emails
          ↓
Phase 2: Select balanced subset + generate ground truth
          ↓
Phase 3: Evaluate all models against this ground truth
```

---

## Pipeline Details

### Phase 1: Auto Pre-Label (`script_1_auto_prelabel.py`)

**Goal**: Generate GPT predictions for ALL 1522 emails

**What it does**:
```python
for each email:
    - Send to GPT 120B
    - Store pred_topic, pred_urgency
    - Save to auto_labeled_full.csv
```

**Naming**: Uses `pred_*` (prediction) not `gt_*` (ground truth) initially.

**Input**: `source_labeled_dataset.csv` (1522 emails)
**Output**: `auto_labeled_full.csv` (1522 with predictions)
**Time**: ~2-3 hours (depending on Ollama speed)

**Run it**:
```bash
python script_1_auto_prelabel.py
```

---

### Phase 2: Balanced Sampling + Ground Truth Generation (`script_2_balanced_sampler.py`)

**Goal**: Create a statistically balanced evaluation dataset and generate ground truth

**Key insight**:
- Each **topic class** gets equal representation (28 samples/class)
- **Urgency distribution** is left NATURAL (not forced)
  - Why? Because urgency depends on topic in real data
- Model predictions ARE the ground truth

**What it does**:
```python
# Stratified sampling by topic
balanced_df = (
    df.groupby("pred_topic", group_keys=False)
      .apply(lambda x: x.sample(min(len(x), 28), random_state=42))
)

# Convert predictions to ground truth labels
ground_truth_df["gt_topic"] = ground_truth_df["pred_topic"]
ground_truth_df["gt_urgency"] = ground_truth_df["pred_urgency"]
```

**Output statistics**:
- 9 topics × 28 samples = ~252 emails
- Outputs TWO CSVs:
  - `balanced_dataset.csv` — for reference
  - `ground_truth_final.csv` — for evaluation script

**Input**: `auto_labeled_full.csv`
**Output**: 
  - `balanced_dataset.csv`
  - `ground_truth_final.csv` ← use this for evaluation
**Time**: < 1 second

**Run it**:
```bash
python script_2_balanced_sampler.py
```

**Key outputs for your paper**:
- Samples per class (with shortfall notes for insufficient classes)
- Urgency by topic cross-tab (shows real-world distribution)
- Source distribution analysis

---

## Expected Outputs

After completing both phases:

### auto_labeled_full.csv (1522 rows)
```
subject | clean_text | label_source | pred_topic | pred_urgency | ...
```

### ground_truth_final.csv (~252 rows) ← Use this for evaluation
```
[all original columns] | gt_topic | gt_urgency | is_ambiguous | was_corrected
```

---

## For Your Methodology Section

Include these statistics:

```
Evaluation Dataset Creation:

Ground Truth Source:
- Model baseline: GPT 120B
- Total emails processed: 1522
- Evaluation set size: ~252 (stratified sample)

Stratification:
- Sampling method: Stratified by topic class
- Samples per class: 28 (or min available)
- Topic classes: 9 (balanced representation)
- Urgency levels: 5 (natural distribution)

Data Source Distribution:
- [List unique sources and counts from Phase 2 output]

Limitations:
- Some topic classes had <28 samples available (see Phase 2 output)
- Ground truth is model-generated (not human-verified)
  - Justification: Reproducible baseline for consistent comparison
  - Used to evaluate other 3 models against
```

---

## Files Reference

| Script | Purpose | Input | Output | Time |
|--------|---------|-------|--------|------|
| `script_1_auto_prelabel.py` | Get GPT predictions for all emails | `source_labeled_dataset.csv` | `auto_labeled_full.csv` | 2-3h |
| `script_2_balanced_sampler.py` | Create balanced + generate ground truth | `auto_labeled_full.csv` | `balanced_dataset.csv`, `ground_truth_final.csv` | <1s |

---

## How to Run

### Step 1: Auto Pre-Label (all 1522 emails)
```bash
python script_1_auto_prelabel.py
```
⏱️ Takes 2-3 hours  
📊 Output: `auto_labeled_full.csv`

### Step 2: Create Balanced Dataset + Generate Ground Truth
```bash
python script_2_balanced_sampler.py
```
⏱️ Takes < 1 second  
📊 Outputs: `balanced_dataset.csv` + `ground_truth_final.csv`

**Done!** Use `ground_truth_final.csv` with the evaluation script.

---

## Next Steps

1. **Evaluate all 3 models** against `ground_truth_final.csv`
2. **Compare model accuracy** with GPT baseline
3. **Analyze failures**: Where does each model disagree with GPT?
4. **Report**: Accuracy, F1, confusion matrices

This gives you a reproducible, defensible evaluation baseline. ✓
