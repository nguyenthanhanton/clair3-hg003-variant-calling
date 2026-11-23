#!/usr/bin/env bash
set -euo pipefail

BASE="$HOME/clair3_reproduce"
DATA="$BASE/data"
URL="https://www.bio8.cs.hku.hk/clair3/demo/quick_demo/ont"

mkdir -p "$DATA"

FILES=(
    "GRCh38_no_alt_chr20.fa"
    "GRCh38_no_alt_chr20.fa.fai"
    "HG003_chr20_demo.bam"
    "HG003_chr20_demo.bam.bai"
    "HG003_GRCh38_chr20_v4.2.1_benchmark.vcf.gz"
    "HG003_GRCh38_chr20_v4.2.1_benchmark.vcf.gz.tbi"
    "HG003_GRCh38_chr20_v4.2.1_benchmark_noinconsistent.bed"
)

for file in "${FILES[@]}"; do
    dest="$DATA/$file"

    if [[ -s "$dest" ]]; then
        echo "[SKIP] $file"
        continue
    fi

    echo "[DOWNLOAD] $file"

    curl -fL \
        --retry 5 \
        --retry-delay 5 \
        --connect-timeout 30 \
        -C - \
        -o "$dest" \
        "$URL/$file"

    test -s "$dest" || {
        echo "ERROR: Empty file: $dest"
        exit 1
    }
done

printf 'chr20\t100000\t300000\n' \
    > "$DATA/quick_demo.bed"

echo "Checking dataset..."

docker run --rm \
    -v "$DATA:$DATA:ro" \
    --entrypoint samtools \
    hkubal/clair3:v2.0.2 \
    quickcheck -v "$DATA/HG003_chr20_demo.bam"

docker run --rm \
    -v "$DATA:$DATA:ro" \
    --entrypoint bcftools \
    hkubal/clair3:v2.0.2 \
    view -h \
    "$DATA/HG003_GRCh38_chr20_v4.2.1_benchmark.vcf.gz" \
    >/dev/null

echo "DATASET READY"
