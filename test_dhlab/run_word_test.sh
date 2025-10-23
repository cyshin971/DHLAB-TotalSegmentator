#!/usr/bin/env bash
# Run TotalSegmentator over WORD imagesVal (colon only) with preview.
# Safe to re-run (skips completed cases). Works headless if xvfb-run exists.

set -euo pipefail

# ---- CONFIG ----
INPUT_DIR="/home/data/2025_RAOS/RAOS-Real/RAOS-Real/CancerImages(Set1)/imagesVal"
OUT_BASE="/home/cyshin/projects/DHLAB-TotalSegmentator/_output"
ROI="colon"
USE_PREVIEW=1
NICE_LEVEL=0                   # lower CPU priority (0..19); set to 0 to disable
IONICE_CLASS="best-effort"      # or "idle"; set empty to disable
TOTALSEG_CMD="TotalSegmentator"
# Optional: centralize weights so they’re reused by all runs
# export TOTALSEG_WEIGHTS_PATH="/home/data/totalseg_weights"

# ---- PREP ----
mkdir -p "$OUT_BASE"
LOG_DIR="$OUT_BASE/_logs"
mkdir -p "$LOG_DIR"

# Headless preview support
RUNNER=()
if [[ "$USE_PREVIEW" -eq 1 ]] && command -v xvfb-run >/dev/null 2>&1; then
  RUNNER=(xvfb-run -a -s "-screen 0 1280x1024x24")
fi

# Nice / ionice wrappers
NICE_WRAP=()
[[ "${NICE_LEVEL:-}" != "" ]] && NICE_WRAP=(nice -n "$NICE_LEVEL")
if command -v ionice >/dev/null 2>&1 && [[ -n "${IONICE_CLASS:-}" ]]; then
  NICE_WRAP+=(ionice -c2 -n7)  # best-effort, lowest prio
fi

# ---- LOOP ----
echo "=== Starting batch at $(date) ==="
echo "Input:  $INPUT_DIR"
echo "Output: $OUT_BASE"
echo "ROI:    $ROI"
echo "Preview:${USE_PREVIEW}"
echo "Runner: ${RUNNER[*]:-none}"
echo

shopt -s nullglob
# robust recursive find (handles spaces/newlines)
while IFS= read -r -d '' IMG; do
  base="$(basename "${IMG%.nii.gz}")"
  OUT_DIR="${OUT_BASE}/${base}"
  mkdir -p "$OUT_DIR"
  LOG_FILE="${LOG_DIR}/${base}.log"

  # Define a simple "done" condition: colon mask or preview already exists
  DONE_FLAG=0
  [[ -f "${OUT_DIR}/${ROI}.nii.gz" ]] && DONE_FLAG=1
  [[ "$USE_PREVIEW" -eq 1 && -f "${OUT_DIR}/preview.png" ]] && DONE_FLAG=1

  if [[ "$DONE_FLAG" -eq 1 ]]; then
    echo "[SKIP] ${base}  (found output)" | tee -a "$LOG_FILE"
    continue
  fi

  echo "[RUN ] ${base}  -> ${OUT_DIR}" | tee -a "$LOG_FILE"

  # Build command
  CMD=("${RUNNER[@]}" "${NICE_WRAP[@]}" "${TOTALSEG_CMD}"
       -i "$IMG"
       -o "$OUT_DIR"
       --roi_subset "$ROI"
  )

  [[ "$USE_PREVIEW" -eq 1 ]] && CMD+=("--preview")

  # Execute and log
  {
    echo "----- $(date)  ${base} -----"
    printf 'CMD: %q ' "${CMD[@]}"; echo
    "${CMD[@]}"
    echo "----- DONE $(date)  ${base} -----"
  } |& tee -a "$LOG_FILE"

done < <(find "$INPUT_DIR" -maxdepth 1 -type f -name '*.nii.gz' -print0)

echo "=== All done at $(date) ==="
