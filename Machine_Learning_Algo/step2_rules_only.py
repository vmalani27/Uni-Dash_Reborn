import pandas as pd
import random

def clean(text):
    # Placeholder for the clean function
    return text

def preview(text, length=50):
    # Placeholder for the preview function
    return text[:length] + "..." if len(text) > length else text

def review_labels(input_file, output_file, sample_size=10):
    df = pd.read_csv(input_file, dtype=str, keep_default_na=False)

    # Randomly sample rows from the dataset
    sampled_rows = df.sample(n=sample_size, random_state=42)

    for idx, row in sampled_rows.iterrows():
        sender = row["from"]
        text = clean(row["clean_text"])
        current_label = row["label_source"]

        print("\n----------------------------------")
        print(f"Row {idx}")
        print("Sender:", sender)
        print("Preview:", preview(text))
        print("Current Label:", current_label)
        print("----------------------------------")

        # Ask user for input
        user_input = input("Enter new label (ENTER=keep current): ").strip()

        # If user input is empty, keep the current label
        if user_input:
            df.at[idx, "label_source"] = user_input
            print("✔ Updated Label:", user_input)
        else:
            print("✔ Kept Current Label:", current_label)

    # Save the updated dataset
    df.to_csv(output_file, index=False)
    print(f"Updated dataset saved to {output_file}")

# Call the function to review labels
review_labels("c:\\Users\\malan\\OneDrive\\Documents\\GitHub\\Uni-Dash_Reborn\\Machine_Learning_Algo\\labeled_level1.csv", 
              "c:\\Users\\malan\\OneDrive\\Documents\\GitHub\\Uni-Dash_Reborn\\Machine_Learning_Algo\\labeled_level1.csv")