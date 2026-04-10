import pandas as pd
import numpy as np

df = pd.read_csv('auto_labeled_full.csv', dtype=str, keep_default_na=False)

print('='*80)
print('AUTO-LABELED DATASET ANALYSIS')
print('='*80)

print(f'\nDataset shape: {df.shape[0]} rows, {df.shape[1]} columns')
print(f'Columns: {list(df.columns)}')

# Prediction distribution
print('\n--- PREDICTION DISTRIBUTION ---')
dist = df['pred_decision'].value_counts().sort_values(ascending=False)
print(dist)
print('\nPercentage breakdown:')
pct = (df['pred_decision'].value_counts(normalize=True) * 100).round(2).sort_values(ascending=False)
print(pct)

# JSON validity
print('\n--- JSON VALIDITY ---')
json_valid = (df['pred_json_valid'] == 'True').sum()
json_total = len(df)
print(f'Valid JSON: {json_valid}/{json_total} ({json_valid/json_total*100:.1f}%)')

# Confidence statistics
print('\n--- CONFIDENCE SCORES ---')
confid = pd.to_numeric(df['pred_confidence'], errors='coerce')
print(f'Mean confidence: {confid.mean():.1f}')
print(f'Median confidence: {confid.median():.1f}')
print(f'Min confidence: {confid.min():.1f}')
print(f'Max confidence: {confid.max():.1f}')
print(f'Std dev: {confid.std():.1f}')

# Latency statistics
print('\n--- LATENCY STATISTICS ---')
latency = pd.to_numeric(df['pred_latency_ms'], errors='coerce')
print(f'Mean latency: {latency.mean():.0f}ms')
print(f'Median latency: {latency.median():.0f}ms')
print(f'Min latency: {latency.min():.0f}ms')
print(f'Max latency: {latency.max():.0f}ms')

# Confidence by class
print('\n--- CONFIDENCE BY CLASS ---')
for label in ['SUBMIT', 'EXAM', 'OPPORTUNITY', 'ADMIN', 'IGNORE']:
    subset = df[df['pred_decision'] == label]
    if len(subset) > 0:
        confid_subset = pd.to_numeric(subset['pred_confidence'], errors='coerce')
        print(f'{label:12s}: mean={confid_subset.mean():5.1f}, median={confid_subset.median():5.1f}, n={len(subset)}')

# Sample some predictions
print('\n--- SAMPLE PREDICTIONS (First 8) ---')
for idx in range(min(8, len(df))):
    row = df.iloc[idx]
    subj = str(row['subject'])[:60]
    decision = str(row['pred_decision'])
    confidence = str(row['pred_confidence'])
    reasoning = str(row['pred_reasoning'])[:70]
    valid = str(row['pred_json_valid'])
    latency = str(row['pred_latency_ms'])
    
    print(f'\n[{idx+1}] Subject: {subj}')
    print(f'    Prediction: {decision} (confidence: {confidence}%)')
    print(f'    Reasoning: {reasoning}')
    print(f'    JSON Valid: {valid} | Latency: {latency}ms')

# Look at each class
print('\n--- SAMPLE BY CLASS ---')
for label in ['SUBMIT', 'EXAM', 'OPPORTUNITY', 'ADMIN', 'IGNORE']:
    subset = df[df['pred_decision'] == label]
    if len(subset) > 0:
        print(f'\n{label} (n={len(subset)}):')
        sample = subset.iloc[0]
        subj = str(sample['subject'])[:55]
        reasoning = str(sample['pred_reasoning'])[:70]
        print(f'  Example: {subj}')
        print(f'  Reasoning: {reasoning}')

print('\n' + '='*80)
