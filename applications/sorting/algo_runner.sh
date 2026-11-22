#!/bin/bash
set -eo pipefail

if [[ -r /startsgxenv.sh ]]; then
    source /startsgxenv.sh
fi

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
output_dir=../../benchmark_output
mkdir -p -- "$output_dir"

SGX_MODE=${SGX_MODE:-HW} # HW or SIM

# Algorithms:
# ALGOs=(KWAYBUTTERFLYOSORT KWAYDISTRIBUTIONOSORT KWAYDISTRIBUTIONOSORTSHUFFLED BITONICSORT CABUCKETSORT KWAYBUTTERFLYOSHUFFLE ORSHUFFLE BITONICSHUFFLE CABUCKETSHUFFLE UNOPTBITONICSORT EXTMERGESORT)
ALGOs=(KWAYBUTTERFLYOSORT BITONICSORT KWAYBUTTERFLYOSHUFFLE ORSHUFFLE BITONICSHUFFLE)
MIN_ELEMENT_SIZE=128 # element size in bytes
MAX_ELEMENT_SIZE=128
MIN_SIZE=${MIN_SIZE:-100000} # number of elements
MAX_SIZE=${MAX_SIZE:-1100000}
STEP_RATIO=${STEP_RATIO:-1.2}
MIN_ENCLAVE_SIZE=128 # MB
MAX_ENCLAVE_SIZE=256
IO_ROUNDS=(1) # encryption/decryption rounds
CORE_ID=${CORE_ID:-5}
DISK_IO=0 # 0: memory backend, 1: disk backend

build_dir=$(mktemp -d)
trap 'rm -rf -- "$build_dir"' EXIT
builds=()

for io_round in "${IO_ROUNDS[@]}"; do
    for (( enclave_size=MIN_ENCLAVE_SIZE; enclave_size<=MAX_ENCLAVE_SIZE; enclave_size*=2 )); do
        printf -v heap_size '%x' "$((enclave_size * 1000000))"
        enclave_config="$build_dir/Enclave.config.xml"
        sed "s|<HeapMaxSize>[^<]*</HeapMaxSize>|<HeapMaxSize>0x${heap_size}</HeapMaxSize>|" \
            Enclave/Enclave.config.xml > "$enclave_config"

        for (( element_size=MIN_ELEMENT_SIZE; element_size<=MAX_ELEMENT_SIZE; element_size=element_size*3/2 )); do
            for algo in "${ALGOs[@]}"; do
                name="${algo}_${SGX_MODE}_${element_size}B_${MIN_SIZE}_${MAX_SIZE}_step${STEP_RATIO}_E${enclave_size}_IO${io_round}_DISK${DISK_IO}"
                mkdir -- "$build_dir/$name"
                printf 'Building %s (%s, %s-byte elements, %s MB enclave)\n' \
                    "$algo" "$SGX_MODE" "$element_size" "$enclave_size" >&2
                make clean
                make SGX_MODE="$SGX_MODE" SGX_PRERELEASE=1 ELEMENT_SIZE="$element_size" \
                    ALGO="$algo" MIN_SIZE="$MIN_SIZE" MAX_SIZE="$MAX_SIZE" STEP_RATIO="$STEP_RATIO" \
                    IO_ROUND="$io_round" DISK_IO="$DISK_IO" ENCLAVE_SIZE="$enclave_size" \
                    Enclave_Config_File="$enclave_config"
                cp -- sort.elf enclave.signed.so "$build_dir/$name/"
                builds+=("$name")
            done
        done
    done
done

if ((${#builds[@]} == 0)); then
    printf 'No algorithm builds were produced; check the algorithm list above.\n' >&2
    exit 1
fi

for (( run=1; run<=6; ++run )); do
    run_label="run${run}"
    if (( run == 1 )); then
        run_label+=_warmup
    fi

    shuffled_builds=$(printf '%s\n' "${builds[@]}" | shuf)
    while IFS= read -r name; do
        result="$output_dir/${name}_${run_label}.out"
        printf 'Run %d/6: writing %s\n' "$run" "$result" >&2
        if [[ ${1:-} == 1 ]]; then
            (cd -- "$build_dir/$name" && taskset -c "$CORE_ID" stdbuf -oL ./sort.elf) \
                < /dev/null | tee "$result.part"
        else
            (cd -- "$build_dir/$name" && taskset -c "$CORE_ID" stdbuf -oL ./sort.elf) \
                < /dev/null > "$result.part"
        fi
        mv -- "$result.part" "$result"
    done <<< "$shuffled_builds"
done
