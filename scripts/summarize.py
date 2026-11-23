import csv
import re
from pathlib import Path

base = Path.home() / "clair3_reproduce"

experiments = {
    "E0_pileup": "E0",
    "E1_default": "E1",
    "E2_full90": "E2",
    "E3_indel10": "E3",
}

time_files = {
    "E0_pileup": "E0_time.txt",
    "E1_default": "E1_time.txt",
    "E2_full90": "E2_time.txt",
    "E3_indel10": "E3_time.txt",
}

rows = []

for folder, label in experiments.items():
    summary = base / "results" / folder / "happy.summary.csv"

    with open(summary, newline="") as f:
        records = list(csv.DictReader(f))

    time_path = base / "logs" / time_files[folder]
    match = re.search(
        r"Wall time:\s*([\d.]+)",
        time_path.read_text()
    ) if time_path.exists() else None

    runtime = float(match.group(1)) if match else ""

    for variant in ("SNP", "INDEL"):
        matched = [
            r for r in records
            if r["Type"] == variant
            and r["Filter"] == "PASS"
        ]

        if len(matched) != 1:
            raise ValueError(
                f"Expected one PASS row: {folder}, {variant}"
            )

        r = matched[0]

        # Support common hap.py header spellings
        f1 = r.get("METRIC.F1_Score")
        if f1 is None:
            f1 = r.get("METRIC.F1-Score")
        if f1 is None:
            raise KeyError("F1 column not found")

        rows.append({
            "Experiment": label,
            "Variant": variant,
            "TP": r["TRUTH.TP"],
            "FP": r["QUERY.FP"],
            "FN": r["TRUTH.FN"],
            "Precision": r["METRIC.Precision"],
            "Recall": r["METRIC.Recall"],
            "F1": f1,
            "Runtime_seconds": runtime,
        })

output = base / "results" / "comparison.csv"

with open(output, "w", newline="") as f:
    writer = csv.DictWriter(
        f, fieldnames=list(rows[0].keys())
    )
    writer.writeheader()
    writer.writerows(rows)

for row in rows:
    print(
        row["Experiment"],
        row["Variant"],
        "Precision =", row["Precision"],
        "Recall =", row["Recall"],
        "F1 =", row["F1"],
        "Time =", row["Runtime_seconds"]
    )

print("Saved:", output)
