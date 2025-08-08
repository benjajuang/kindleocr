#!/bin/bash
# Kindle 頁面截圖 + OCR 文字提取腳本 (macOS Kindle App 專用)
# ✅ 請先確認以下三項系統權限都已開啟給 Terminal：
# - 系統設定 > 隱私與安全性 > 螢幕錄製
# - 系統設定 > 隱私與安全性 > 輔助使用
# - 系統設定 > 隱私與安全性 > 自動化（允許 Terminal 控制 System Events）

# 新增：裁切參數（單位：像素），根據你的 Kindle 視窗測量調整
TOP_CROP=80    # 頂部裁切像素（例如標題列）
BOTTOM_CROP=50 # 底部裁切像素（例如進度條、頁碼）

# 詢問要截圖的頁數（作為最大上限）
read -p "請輸入預估的最大頁數（若到書末會自動停止）: " MAX_PAGES
echo "即將截取 Kindle 視窗最多 $MAX_PAGES 頁，請先將 Kindle APP 視窗定位到起始頁並停好位置…"
read -p "確認後按 Enter 開始。"

# 建立輸出資料夾
OUTDIR="/Users/benm4pro/Documents/kindle screenshot/KindleWindowShots_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"
echo "截圖檔案將儲存於：$OUTDIR"

# 初始變數
i=1
last_file=""

# 第一次截圖（起始頁）
open -b com.amazon.Lassen
sleep 1
POS=$(osascript -e 'tell application "System Events" to get position of window 1 of process "Kindle"')
SIZE=$(osascript -e 'tell application "System Events" to get size of window 1 of process "Kindle"')
POS=($(echo ${POS//,/})) # 分割為陣列 [x y]
SIZE=($(echo ${SIZE//,/})) # 分割為陣列 [w h]
x=${POS[0]}; y=${POS[1]}; w=${SIZE[0]}; h=${SIZE[1]}
if [[ -z "$x" || -z "$y" || -z "$w" || -z "$h" ]]; then
  echo "❌ 無法取得 Kindle 視窗座標/尺寸，請確認權限設定與 Kindle 是否開啟。"
  exit 1
fi
cropped_y=$((y + TOP_CROP))
cropped_h=$((h - TOP_CROP - BOTTOM_CROP))
if (( cropped_h <= 0 )); then
  echo "❌ 裁切設定導致高度無效，請調整 TOP_CROP 和 BOTTOM_CROP。"
  exit 1
fi
GEOM="${x},${cropped_y},${w},${cropped_h}"
current_file="$OUTDIR/page_$(printf "%03d" $i).png"
screencapture -R"$GEOM" -x "$current_file"
echo "✅ 已截第 $i 頁 (區域: $GEOM)。"
last_file="$current_file"

# 循環截圖 & 翻頁，直到到末頁或達上限
while (( i < MAX_PAGES )); do
  # 翻頁
  osascript -e 'tell application "System Events" to key code 124'
  sleep 0.8

  # 強制喚醒（確保焦點）
  open -b com.amazon.Lassen
  sleep 1

  # 取得視窗資訊（重取，以防變更）
  POS=$(osascript -e 'tell application "System Events" to get position of window 1 of process "Kindle"')
  SIZE=$(osascript -e 'tell application "System Events" to get size of window 1 of process "Kindle"')
  POS=($(echo ${POS//,/}))
  SIZE=($(echo ${SIZE//,/}))
  x=${POS[0]}; y=${POS[1]}; w=${SIZE[0]}; h=${SIZE[1]}
  if [[ -z "$x" || -z "$y" || -z "$w" || -z "$h" ]]; then
    echo "❌ 無法取得 Kindle 視窗座標/尺寸。"
    break
  fi
  cropped_y=$((y + TOP_CROP))
  cropped_h=$((h - TOP_CROP - BOTTOM_CROP))
  if (( cropped_h <= 0 )); then
    echo "❌ 裁切高度無效。"
    break
  fi
  GEOM="${x},${cropped_y},${w},${cropped_h}"

  # 截取臨時圖片
  temp_file="$OUTDIR/temp.png"
  screencapture -R"$GEOM" -x "$temp_file"

  # 比較是否與上一張相同
  if cmp -s "$last_file" "$temp_file"; then
    echo "✅ 偵測到書本已到末頁，停止截圖。"
    rm "$temp_file"
    break
  fi

  # 不相同，儲存為下一頁
  ((i++))
  current_file="$OUTDIR/page_$(printf "%03d" $i).png"
  mv "$temp_file" "$current_file"
  echo "✅ 已截第 $i 頁 (區域: $GEOM)。"
  last_file="$current_file"
done

echo "🎉 截圖完成（共 $i 頁）！現在開始 OCR 文字提取…"

# 呼叫 Python OCR 腳本，傳入輸出資料夾
python3 "/Users/benm4pro/Documents/kindle screenshot/ocr_images.py" "$OUTDIR"

echo "🎉 全部完成！截圖與 OCR 文字檔皆存於：$OUTDIR"