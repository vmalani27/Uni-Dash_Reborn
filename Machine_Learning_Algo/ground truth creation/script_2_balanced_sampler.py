"""
PHASE 2: Balanced Sampling + Ground Truth Generation
================================
Goal: Create balanced evaluation dataset from auto-labeled predictions
       and generate ground_truth_final.csv directly

Key insight:
- Each TOPIC class gets equal representation
- Model predictions ARE ground truth (no human annotation)
- This prevents biasing your ground truth toward over-represented classes
"""

import pandas as pd
import numpy as np

# ----------------------------------------------------------
# Config
# ----------------------------------------------------------

INPUT_FILE = "auto_labeled_full.csv"
OUTPUT_BALANCED = "balanced_dataset.csv"
OUTPUT_GROUND_TRUTH = "ground_truth_final.csv"

SAMPLES_PER_CLASS = 28  # Adjust based on capacity (28 * 8 topics ≈ 224 samples)

# ----------------------------------------------------------
# Main
# ----------------------------------------------------------

def main():
    """Load predictions, apply stratified sampling, generate ground truth"""
    
    # Load auto-labeled data
    df = pd.read_csv(INPUT_FILE, dtype=str, keep_default_na=False)
    print(f"Loaded {len(df)} auto-labeled emails")
    
    # Filter out emails with "nan" in clean_text
    print("\n--- FILTERING CORRUPTED EMAILS ---")
    initial_count = len(df)
    df_cleaned = df[~df["clean_text"].str.contains("nan", case=False, na=False)].copy()
    removed_count = initial_count - len(df_cleaned)
    
    if removed_count > 0:
        print(f"[WARNING] Found {removed_count} emails with 'nan' in body")
        print(f"  Removed {removed_count} corrupted emails")
        print(f"  Remaining: {len(df_cleaned)} emails")
        
        # Show which ones were removed
        removed_df = df[df["clean_text"].str.contains("nan", case=False, na=False)]
        if len(removed_df) > 0:
            print(f"\n  Removed emails:")
            for idx, row in removed_df.iterrows():
                subject = row.get('subject', '')[:60]
                print(f"    - {subject}")
    else:
        print("[OK] No corrupted emails found")
    
    df = df_cleaned
    
    # Stratified sampling by decision
    print(f"\n--- STRATIFIED SAMPLING: {SAMPLES_PER_CLASS} per class ---")
    
    balanced_df = (
        df.groupby("pred_decision", group_keys=False)
          .apply(lambda x: x.sample(min(len(x), SAMPLES_PER_CLASS), random_state=42))
          .reset_index(drop=True)
    )
    
    print(f"\nOriginal dataset: {len(df)} emails")
    print(f"Balanced dataset: {len(balanced_df)} emails")
    
    # Report what happened per class
    print("\n--- SAMPLES PER CLASS ---")
    class_counts = balanced_df["pred_decision"].value_counts().sort_index()
    for decision, count in class_counts.items():
        original_count = (df["pred_decision"] == decision).sum()
        symbol = "[OK]" if count == SAMPLES_PER_CLASS else "[LOW]"
        print(f"{symbol} {decision}: {count}/{SAMPLES_PER_CLASS} samples")

    
    # Analyze source distribution
    print("\n--- SOURCE DISTRIBUTION ---")
    source_dist = balanced_df["label_source"].value_counts()
    print(source_dist)
    

    # Save balanced dataset
    balanced_df.to_csv(OUTPUT_BALANCED, index=False)
    print(f"\n[OK] Saved balanced dataset: {OUTPUT_BALANCED}")
    
    # ==== Generate Ground Truth (model predictions are ground truth) ====
    print("\n" + "="*80)
    print("GENERATING GROUND TRUTH FROM MODEL PREDICTIONS")
    print("="*80)
    
    # Create ground truth dataset
    gt_df = balanced_df.copy()
    gt_df["gt_decision"] = gt_df["pred_decision"]
    
    # Save ground truth
    gt_df.to_csv(OUTPUT_GROUND_TRUTH, index=False)
    print(f"[OK] Saved ground truth: {OUTPUT_GROUND_TRUTH}")
    
    # Statistics for your methodology section
    print("\n" + "="*80)
    print("STATISTICS FOR METHODOLOGY SECTION:")
    print("="*80)
    print(f"Total emails in evaluation set: {len(gt_df)}")
    print(f"Unique decisions represented: {gt_df['gt_decision'].nunique()}")
    print(f"Unique sources: {gt_df['label_source'].nunique()}")
    print(f"Min samples per decision: {gt_df['gt_decision'].value_counts().min()}")
    print(f"Max samples per decision: {gt_df['gt_decision'].value_counts().max()}")
    
    # Report any classes that couldn't be filled
    insufficient = SAMPLES_PER_CLASS - gt_df["gt_decision"].value_counts().min()
    if insufficient > 0:
        print(f"\n[WARNING] NOTE: Some classes had fewer than {SAMPLES_PER_CLASS} samples.")
        print(f"  Shortfall: {insufficient} samples per underrepresented class")
        print("  This is unavoidable and should be noted in limitations.")
    
    print("\n" + "="*80)
    print("GROUND TRUTH DISTRIBUTION:")
    print("="*80)
    print("\nDecision distribution:")
    print(gt_df["gt_decision"].value_counts().sort_index())

if __name__ == "__main__":
    main()
