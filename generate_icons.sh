#!/bin/bash

# 创建临时目录
mkdir -p iconset.iconset

# 生成不同尺寸的PNG文件
for size in 16 32 64 128 256 512 1024; do
    # 普通分辨率
    sips -s format png -z $size $size AppIcon.svg --out "iconset.iconset/icon_${size}x${size}.png"
    # 高分辨率 (@2x)
    if [ $size -lt 512 ]; then
        sips -s format png -z $((size*2)) $((size*2)) AppIcon.svg --out "iconset.iconset/icon_${size}x${size}@2x.png"
    fi
done

# 重命名图标文件以符合Apple的命名规范
mv iconset.iconset/icon_16x16.png iconset.iconset/icon_16x16.png
mv iconset.iconset/icon_16x16@2x.png iconset.iconset/icon_32x32@2x.png
mv iconset.iconset/icon_32x32.png iconset.iconset/icon_32x32.png
mv iconset.iconset/icon_32x32@2x.png iconset.iconset/icon_64x64@2x.png
mv iconset.iconset/icon_128x128.png iconset.iconset/icon_128x128.png
mv iconset.iconset/icon_128x128@2x.png iconset.iconset/icon_256x256@2x.png
mv iconset.iconset/icon_256x256.png iconset.iconset/icon_256x256.png
mv iconset.iconset/icon_256x256@2x.png iconset.iconset/icon_512x512@2x.png
mv iconset.iconset/icon_512x512.png iconset.iconset/icon_512x512.png
mv iconset.iconset/icon_1024x1024.png iconset.iconset/icon_512x512@2x.png

# 生成icns文件
iconutil -c icns iconset.iconset -o AppIcon.icns

# 复制图标文件到应用包
cp AppIcon.icns BTCWatcher.app/Contents/Resources/

# 清理临时文件
rm -rf iconset.iconset
