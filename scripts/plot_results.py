import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

out = Path.home() / "clair3_reproduce/results"
df = pd.read_csv(out / "comparison.csv")

# F1 SNP versus Indel
pivot = df.pivot(
    index="Experiment",
    columns="Variant",
    values="F1"
)

pivot = pivot.reindex(["E0", "E1", "E2", "E3"])

ax = pivot.plot(kind="bar", figsize=(9, 5))
ax.set_title("Clair3: SNP and Indel F1-score")
ax.set_xlabel("Experiment")
ax.set_ylabel("F1-score")
ax.set_ylim(0, 1.05)
ax.tick_params(axis="x", rotation=0)

plt.tight_layout()
plt.savefig(out / "f1_comparison.png", dpi=200)
plt.close()

# Runtime (once per experiment)
runtime = df.drop_duplicates("Experiment")
runtime = runtime.set_index("Experiment")
runtime = runtime.reindex(["E0", "E1", "E2", "E3"])

ax = runtime["Runtime_seconds"].plot(
    kind="bar", figsize=(8, 5)
)
ax.set_title("Clair3 Runtime Comparison")
ax.set_xlabel("Experiment")
ax.set_ylabel("Runtime (seconds)")
ax.tick_params(axis="x", rotation=0)

plt.tight_layout()
plt.savefig(out / "runtime_comparison.png", dpi=200)
plt.close()

print("Saved both plots in:", out)
