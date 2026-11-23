#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/clair3_reproduce"
DATA="$BASE/data"
RESULTS="$BASE/results"
LOGS="$BASE/logs"

CLAIR="hkubal/clair3:v2.0.2"
HAPPY="jmcdani20/hap.py:v0.3.12"

for EXP in E0_pileup E1_default E2_full90 E3_indel10
do
    OUT="$RESULTS/$EXP"

    if [[ "$EXP" == "E0_pileup" ]]; then
        VCF="$OUT/pileup.vcf.gz"
    else
        VCF="$OUT/merge_output.vcf.gz"
    fi

    echo "================================"
    echo "Evaluating: $EXP"
    echo "================================"

    if [[ ! -s "$VCF" ]]; then
        echo "ERROR: Missing $VCF"
        exit 1
    fi

    # Index VCF for hap.py
    docker run --rm \
        -v "$OUT:$OUT" \
        --entrypoint tabix \
        "$CLAIR" \
        -f -p vcf "$VCF"

    # Benchmark
    docker run --rm \
        -v "$DATA:$DATA:ro" \
        -v "$OUT:$OUT" \
        "$HAPPY" \
        /opt/hap.py/bin/hap.py \
        "$DATA/HG003_GRCh38_chr20_v4.2.1_benchmark.vcf.gz" \
        "$VCF" \
        -f "$DATA/HG003_GRCh38_chr20_v4.2.1_benchmark_noinconsistent.bed" \
        -r "$DATA/GRCh38_no_alt_chr20.fa" \
        -o "$OUT/happy" \
        -l chr20:100000-300000 \
        --engine=vcfeval \
        --threads=4 \
        --pass-only \
        > "$LOGS/${EXP}_happy.log" 2>&1

    if [[ ! -s "$OUT/happy.summary.csv" ]]; then
        echo "ERROR: hap.py failed for $EXP"
        tail -n 30 "$LOGS/${EXP}_happy.log"
        exit 1
    fi

    echo "Completed: $EXP"
done

echo "ALL BENCHMARKS COMPLETED"
