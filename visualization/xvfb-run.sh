# optional: create a tiny wrapper so you don't babysit DISPLAY
cat > xvfb-run.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
Xvfb :99 -screen 0 1280x1024x24 -nolisten tcp &
pid=$!
export DISPLAY=:99
trap 'kill $pid 2>/dev/null || true' EXIT
exec "$@"
EOF
chmod +x xvfb-run.sh

# render a preview
./xvfb-run.sh TotalSegmentator -i ct.nii.gz -o out_dir --preview
ls -lh out_dir/preview.png