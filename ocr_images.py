#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import pytesseract
from PIL import Image
from datetime import datetime

def is_image_file(fn):
    ext = fn.lower().split('.')[-1]
    return ext in ('jpg', 'jpeg', 'png', 'tiff', 'bmp')

def main(target_folder):
    print(f'處理資料夾：{target_folder}')

    # 列出資料夾下所有圖片檔
    files = sorted([f for f in os.listdir(target_folder) if is_image_file(f)])
    if not files:
        print('找不到任何圖片。')
        return

    all_text = []
    for fname in files:
        path = os.path.join(target_folder, fname)
        try:
            img = Image.open(path)
            text = pytesseract.image_to_string(img, lang='eng+chi_tra')
            all_text.append(text.strip())  # 移除前後空白，並不加檔名標頭
            print(f'OCR 完成：{fname}')
        except Exception as e:
            print(f'無法處理 {fname}：{e}')

    # 輸出檔名放在同一個資料夾
    out_name = datetime.now().strftime('%Y%m%d_%H%M%S') + '_ocr.txt'
    out_path = os.path.join(target_folder, out_name)
    with open(out_path, 'w', encoding='utf-8') as f:
        f.write('\n\n'.join(all_text))  # 用兩個換行分隔頁面文字，無標頭

    print(f'所有文字已輸出到：{out_path}')

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("使用方式: python3 ocr_images.py /path/to/folder")
        sys.exit(1)
    main(sys.argv[1])