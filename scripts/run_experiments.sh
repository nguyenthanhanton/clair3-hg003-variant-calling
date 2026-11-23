#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/clair3_reproduce"
DATA="$BASE/data"
RESULTS="$BASE/results"
LOGS="$BASE/logs"

CLAIR="hkubal/clair3:v2.0.2"
THREADS=4

mkdir -p "$DATA" "$RESULTS" "$LOGS"

# Check Docker
command -v docker >/dev/null || {
    echo "ERROR: Docker not found"
    exit 1
}

docker info >/dev/null 2>&1 || {
    echo "ERROR: Docker daemon unavailable"
    exit 1
}

# Check required inputs
for file in \
    HG003_chr20_demo.bam \
    HG003_chr20_demo.bam.bai \
    GRCh38_no_alt_chr20.fa \
    GRCh38_no_alt_chr20.fa.fai \
    quick_demo.bed
do
    [[ -s "$DATA/$file" ]] || {
        echo "ERROR: Missing $DATA/$file"
        exit 1
    }
done

run_experiment() {
    local NAME="$1"
    local VCF_NAME="$2"
    shift 2

    local OUT="$RESULTS/$NAME"
    local VCF="$OUT/$VCF_NAME"
    local LOG="$LOGS/${NAME}.log"
    local TIMELOG="$LOGS/${NAME}_time.txt"

    mkdir -p "$OUT"

    if [[ -s "$VCF" ]]; then
        echo "[SKIP] $NAME: output exists"
        return
    fi

    echo "================================"
    echo "Running $NAME"
    echo "================================"

    /usr/bin/time \
        -f "Wall time: %e seconds" \
        -o "$TIMELOG" \
        docker run --rm \
            -v "$DATA:$DATA:ro" \
            -v "$OUT:$OUT" \
            "$CLAIR" \
            /opt/bin/run_clair3.sh \
            --bam_fn="$DATA/HG003_chr20_demo.bam" \
            --ref_fn="$DATA/GRCh38_no_alt_chr20.fa" \
            --threads="$THREADS" \
            --platform=ont \
            --model_path=/opt/models/ont \
            --output="$OUT" \
            --bed_fn="$DATA/quick_demo.bed" \
            "$@" \
            > "$LOG" 2>&1

    [[ -s "$VCF" ]] || {
        echo "ERROR: Missing output $VCF"
        tail -n 40 "$LOG"
        exit 1
    }

    echo "COMPLETED: $NAME"
    cat "$TIMELOG"
}

# E0: Pileup-only baseline
run_experiment \
    "E0_pileup" \
    "pileup.vcf.gz" \
    --pileup_only

# E1: Default Clair3
run_experiment \
    "E1_default" \
    "merge_output.vcf.gz"

# E2: Higher full-alignment candidate proportion
run_experiment \
    "E2_full90" \
    "merge_output.vcf.gz" \
    --var_pct_full=0.9

# E3: Lower Indel allele-frequency threshold
run_experiment \
    "E3_indel10" \
    "merge_output.vcf.gz" \
    --indel_min_af=0.10

echo "================================"
echo "ALL EXPERIMENTS COMPLETED"
echo "================================"
