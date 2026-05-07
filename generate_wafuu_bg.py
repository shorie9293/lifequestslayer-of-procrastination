#!/usr/bin/env python3
"""和風テクスチャ背景画像 生成スクリプト"""
from PIL import Image, ImageDraw, ImageFilter
import os
import shutil

SIZE = 640
DARK_PURPLE = (26, 16, 64)    # #1A1040
INK_BLACK = (13, 13, 26)      # #0D0D1A
WASHI_BLACK = (42, 37, 32)    # #2A2520
DARK_BROWN = (53, 37, 25)     # 木目調
DARK_RED = (64, 20, 20)       # 朱色に近い暗赤
PALE_GOLD = (120, 100, 60)    # 金具的な薄金
DARK_GREEN = (20, 40, 25)     # 苔色

def make_base(w, h, color):
    """ベース画像作成"""
    return Image.new('RGB', (w, h), color)

def draw_wood_grain(draw, x_start, y_start, w, h, base_color=DARK_BROWN, grain_color=(40, 28, 20)):
    """木目調パターン"""
    for y in range(y_start, y_start + h, 16):
        # 木目線（微妙に波打たせる）
        offset_amp = 2
        for x in range(x_start, x_start + w):
            offset = int(offset_amp * (0.5 - abs((x % 64) - 32) / 64))
            draw.point((x, y + offset), grain_color)
            draw.point((x, y + offset + 1), grain_color)
        # 年輪風の太い線をたまに
        if (y - y_start) % 48 < 2:
            for x in range(x_start, x_start + w):
                offset = int(offset_amp * (0.5 - abs((x % 40) - 20) / 40))
                draw.point((x, y + offset), (60, 45, 30))

def draw_tatami_pattern(draw, x_start, y_start, w, h, color=(50, 55, 40)):
    """畳パターン"""
    for y in range(y_start, y_start + h, 8):
        for x in range(x_start, x_start + w, 4):
            if (x // 4 + y // 8) % 2 == 0:
                draw.point((x, y), color)

def draw_shoji_grid(draw, x_start, y_start, w, h, grid_size=40, line_color=(60, 55, 48)):
    """障子の格子"""
    for x in range(x_start, x_start + w, grid_size):
        draw.line([(x, y_start), (x, y_start + h)], fill=line_color, width=2)
    for y in range(y_start, y_start + h, grid_size):
        draw.line([(x_start, y), (x_start + w, y)], fill=line_color, width=2)

def draw_shimenawa(draw, cx, cy, width=200):
    """注連縄（抽象的な波形）"""
    import math
    for x in range(cx - width // 2, cx + width // 2):
        rel = (x - (cx - width // 2)) / width
        y_offset = int(10 * math.sin(rel * 12 * math.pi))
        y = cy + y_offset
        # 縄の部分（太めに）
        for dy in range(-5, 6):
            brightness = 60 - abs(dy) * 3
            draw.point((x, y + dy), (brightness, brightness - 10, brightness - 15))
        # 紙垂（しで）の抽象表現
        if abs(rel - 0.3) < 0.02 or abs(rel - 0.7) < 0.02:
            draw.line([(x, y - 10), (x, y + 15)], fill=(100, 90, 80), width=2)

def draw_vertical_lattice(draw, x_start, y_start, w, h, spacing=20, color=(55, 48, 40)):
    """縦格子"""
    for x in range(x_start, x_start + w, spacing):
        draw.line([(x, y_start), (x, y_start + h)], fill=color, width=3)

def draw_ichimatsu(draw, x_start, y_start, w, h, tile_size=20, color1=(45, 40, 55), color2=(35, 30, 42)):
    """市松模様"""
    for y in range(0, h, tile_size):
        for x in range(0, w, tile_size):
            color = color1 if ((x // tile_size) + (y // tile_size)) % 2 == 0 else color2
            draw.rectangle([x_start + x, y_start + y, x_start + x + tile_size - 1, y_start + y + tile_size - 1], fill=color)

def draw_asa_no_ha(draw, x_start, y_start, w, h, scale=24, color=(50, 45, 55)):
    """麻の葉模様（簡易ヘキサゴン）"""
    import math
    for gy in range(0, h + scale, scale * 3 // 2):
        for gx in range(0, w + scale, scale * 2):
            ox = gx + (scale if (gy // (scale * 3 // 2)) % 2 else 0)
            oy = gy
            # 六角形の中心
            cx = x_start + ox
            cy = y_start + oy
            if cx < x_start or cx > x_start + w or cy < y_start or cy > y_start + h:
                continue
            for angle in range(6):
                a1 = math.radians(angle * 60)
                a2 = math.radians((angle + 1) * 60)
                x1 = int(cx + scale * 0.5 * math.cos(a1))
                y1 = int(cy + scale * 0.5 * math.sin(a1))
                x2 = int(cx + scale * 0.5 * math.cos(a2))
                y2 = int(cy + scale * 0.5 * math.sin(a2))
                draw.line([(x1, y1), (x2, y2)], fill=color, width=1)

def add_vignette(img, radius=1.5):
    """画面周辺を暗くするビネット効果"""
    w, h = img.size
    cx, cy = w // 2, h // 2
    max_dist = ((cx)**2 + (cy)**2) ** 0.5
    result = img.copy()
    pixels = result.load()
    for y in range(h):
        for x in range(w):
            dist = ((x - cx)**2 + (y - cy)**2) ** 0.5
            factor = max(0, 1.0 - (dist / max_dist) * radius)
            factor = max(0.3, min(1.0, factor))
            r, g, b = pixels[x, y]
            pixels[x, y] = (int(r * factor), int(g * factor), int(b * factor))
    return result

def add_noise(img, intensity=8):
    """テクスチャノイズ"""
    import random
    pixels = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b = pixels[x, y]
            n = random.randint(-intensity, intensity)
            pixels[x, y] = (max(0, min(255, r + n)),
                            max(0, min(255, g + n)),
                            max(0, min(255, b + n)))
    return img

# ========== 1. home_bg.png — 修練場（道場） ==========
def create_dojo():
    img = make_base(SIZE, SIZE, DARK_PURPLE)
    draw = ImageDraw.Draw(img)
    # 床：木板
    for i in range(12):
        y = 300 + i * 30
        draw.rectangle([0, y, SIZE, y + 28], fill=(45, 35, 28))
        for x in range(0, SIZE, 60):
            draw.line([(x, y), (x, y + 28)], fill=(38, 28, 22), width=1)
    # 畳エリア上半分
    draw_ichimatsu(draw, 80, 40, 480, 260, 16, (42, 45, 35), (38, 40, 30))
    # 障子格子（奥）
    draw_shoji_grid(draw, 0, 0, SIZE, 300, 40, (55, 50, 42))
    # 壁
    draw_vertical_lattice(draw, 0, 0, SIZE, 40, 80, (50, 42, 35))
    # 柔らかく
    img = img.filter(ImageFilter.GaussianBlur(1))
    img = add_noise(img, 6)
    img = add_vignette(img, 1.2)
    return img

# ========== 2. guild_bg.png — 寄合所 ==========
def create_guild():
    img = make_base(SIZE, SIZE, WASHI_BLACK)
    draw = ImageDraw.Draw(img)
    # 和紙の壁面
    for y in range(0, 400, 60):
        for x in range(0, SIZE, 80):
            c = (55 + (x + y) % 10, 48 + (x + y) % 8, 40 + (x + y) % 6)
            draw.rectangle([x, y, x + 78, y + 58], fill=c, outline=(48, 42, 35))
    # 格子窓
    for wx in range(60, SIZE - 60, 100):
        draw.rectangle([wx, 80, wx + 70, 200], fill=(25, 22, 20))
        draw_shoji_grid(draw, wx, 80, 70, 120, 20, (60, 55, 48))
    # 床板
    for y in range(400, SIZE, 25):
        draw.rectangle([0, y, SIZE, y + 22], fill=(45, 35, 28))
    # 梁
    draw.line([(0, 60), (SIZE, 60)], fill=(38, 28, 20), width=8)
    draw.line([(0, 400), (SIZE, 400)], fill=(38, 28, 20), width=6)
    # 柱
    for x in range(60, SIZE, 100):
        draw.rectangle([x, 0, x + 12, SIZE], fill=(40, 30, 22))
    img = img.filter(ImageFilter.GaussianBlur(1))
    img = add_noise(img, 5)
    img = add_vignette(img, 1.0)
    return img

# ========== 3. temple_bg.png — 社（神社内観） ==========
def create_temple():
    img = make_base(SIZE, SIZE, DARK_PURPLE)
    draw = ImageDraw.Draw(img)
    # 木の柱（両脇）
    draw.rectangle([30, 0, 60, SIZE], fill=(45, 35, 25))
    draw.rectangle([SIZE - 60, 0, SIZE - 30, SIZE], fill=(45, 35, 25))
    # 注連縄
    draw_shimenawa(draw, SIZE // 2, 120, 400)
    # 賽銭箱エリア
    draw.rectangle([240, 380, 400, 480], fill=(38, 28, 20))
    draw.rectangle([250, 390, 390, 470], fill=(30, 22, 16))
    # 鈴と縄（抽象）
    for dy in range(0, 60, 8):
        draw.line([(320, 200 + dy), (325, 200 + dy)], fill=(80, 70, 50), width=3)
    # 鈴（丸）
    draw.ellipse([310, 260, 330, 280], fill=(70, 55, 30))
    # 床の間
    draw_ichimatsu(draw, 0, 500, SIZE, 140, 30, (45, 40, 35), (40, 35, 30))
    draw_vertical_lattice(draw, 0, 480, SIZE, 20, 120, (50, 42, 35))
    # 天井の木目
    draw_wood_grain(draw, 0, 0, SIZE, 40, DARK_BROWN, (40, 30, 22))
    img = img.filter(ImageFilter.GaussianBlur(1))
    img = add_noise(img, 7)
    img = add_vignette(img, 1.5)
    return img

# ========== 4. home_0.png — 野宿（焚き火と夜空） ==========
def create_camp():
    img = make_base(SIZE, SIZE, (8, 8, 20))
    draw = ImageDraw.Draw(img)
    import random
    # 星空
    random.seed(42)
    for _ in range(120):
        x = random.randint(0, SIZE - 1)
        y = random.randint(0, 300)
        b = random.randint(80, 200)
        draw.point((x, y), (b, b, b))
    # 月
    draw.ellipse([520, 30, 580, 90], fill=(180, 170, 130))
    # 地面
    draw.rectangle([0, 400, SIZE, SIZE], fill=(30, 25, 18))
    # 焚き火
    cx, cy = SIZE // 2, 410
    # 薪
    for angle in range(-30, 35, 15):
        import math
        rad = math.radians(angle)
        ex = cx + int(40 * math.sin(rad))
        ey = cy + int(20 * math.cos(rad))
        draw.line([(cx, cy), (ex, ey)], fill=(55, 35, 20), width=4)
    # 炎
    for _ in range(30):
        fx = cx + random.randint(-20, 20)
        fy = cy - random.randint(5, 50)
        r = random.randint(100, 180)
        g = random.randint(40, 80)
        b = random.randint(10, 30)
        draw.ellipse([fx - 3, fy - 3, fx + 3, fy + 3], fill=(r, g, b))
    # 木のシルエット
    for tree_x in [40, 100, 200, 500, 570, 600]:
        draw.line([(tree_x, 400), (tree_x, random.randint(150, 300))], fill=(18, 15, 12), width=5)
    img = add_noise(img, 4)
    img = add_vignette(img, 1.8)
    return img

# ========== 5. home_1.png — 小さな庵（藁葺き屋根） ==========
def create_hut():
    img = make_base(SIZE, SIZE, (20, 18, 14))
    draw = ImageDraw.Draw(img)
    # 藁葺き屋根（三角形）
    roof_pts = [(100, 320), (320, 100), (540, 320)]
    draw.polygon(roof_pts, fill=(50, 38, 20))
    # 屋根の藁の線
    for y in range(120, 320, 8):
        x1 = int(100 + (y - 120) * 220 / 200)
        x2 = int(540 - (y - 120) * 220 / 200)
        draw.line([(x1, y), (x2, y)], fill=(42, 30, 16), width=1)
    # 壁（土壁）
    draw.rectangle([180, 320, 460, 500], fill=(38, 32, 25))
    # 柱
    draw.rectangle([180, 320, 200, 500], fill=(45, 32, 20))
    draw.rectangle([440, 320, 460, 500], fill=(45, 32, 20))
    # 障子
    draw.rectangle([220, 360, 420, 480], fill=(35, 30, 25))
    draw_shoji_grid(draw, 220, 360, 200, 120, 30, (45, 40, 35))
    # 地面
    draw.rectangle([0, 500, SIZE, SIZE], fill=(30, 26, 18))
    # 周囲の草
    for x in range(0, SIZE, 4):
        y = 500 + int(10 * (0.5 - abs((x % 80) - 40) / 80))
        draw.point((x, y), (35, 40, 25))
    img = add_noise(img, 6)
    img = add_vignette(img, 1.3)
    return img

# ========== 6. home_2.png — 木造長屋 ==========
def create_nagaya():
    img = make_base(SIZE, SIZE, (25, 22, 18))
    draw = ImageDraw.Draw(img)
    # 長屋の外観
    # 複数の店/住居ユニット
    for i in range(4):
        x_base = 10 + i * 155
        # 壁
        draw.rectangle([x_base, 100, x_base + 145, 480], fill=(45, 38, 30))
        # 戸
        draw.rectangle([x_base + 15, 300, x_base + 60, 480], fill=(38, 30, 22))
        draw_vertical_lattice(draw, x_base + 15, 300, 45, 180, 40, (50, 40, 32))
        # 窓（格子）
        draw.rectangle([x_base + 70, 160, x_base + 130, 240], fill=(30, 25, 20))
        draw_shoji_grid(draw, x_base + 70, 160, 60, 80, 20, (50, 45, 38))
        # 庇
        draw.line([(x_base - 10, 100), (x_base + 155, 100)], fill=(38, 28, 18), width=6)
    # 屋根（連続）
    for i in range(4):
        x_base = 10 + i * 155
        draw.polygon([(x_base - 15, 100), (x_base + 77, 50), (x_base + 160, 100)], fill=(42, 32, 20))
    # 地面
    draw.rectangle([0, 480, SIZE, SIZE], fill=(28, 22, 16))
    # 道
    for y in range(480, SIZE, 15):
        draw.line([(0, y), (SIZE, y)], fill=(35, 28, 20), width=1)
    img = add_noise(img, 5)
    img = add_vignette(img, 1.2)
    return img

# ========== 7. home_3.png — 石造り蔵 ==========
def create_kura():
    img = make_base(SIZE, SIZE, (28, 25, 22))
    draw = ImageDraw.Draw(img)
    # 蔵の外壁（石積み）
    for y in range(80, 500, 25):
        for x in range(40, SIZE - 40, 30):
            offset = 15 if (y // 25) % 2 else 0
            shade = (x + y) % 15
            c = (48 + shade, 42 + shade//2, 35 + shade//3)
            draw.rectangle([x + offset, y, x + 28 + offset, y + 23], fill=c, outline=(35, 30, 25))
    # 漆喰壁の上部
    draw.rectangle([40, 80, SIZE - 40, 130], fill=(55, 50, 42))
    # 観音開きの扉
    draw.rectangle([240, 200, 400, 480], fill=(38, 28, 18))
    draw_vertical_lattice(draw, 240, 200, 160, 280, 30, (50, 38, 28))
    # 金具
    draw.ellipse([310, 440, 330, 460], fill=(80, 70, 40))
    draw.ellipse([350, 440, 370, 460], fill=(80, 70, 40))
    # 屋根
    draw.polygon([(20, 80), (320, 20), (620, 80)], fill=(42, 35, 25))
    draw.rectangle([0, 80, SIZE, 110], fill=(40, 33, 24))
    # 地面
    draw.rectangle([0, 500, SIZE, SIZE], fill=(30, 25, 18))
    img = add_noise(img, 8)
    img = add_vignette(img, 1.4)
    return img

# ========== 8. home_4.png — 寄合所長屋 ==========
def create_guild_nagaya():
    img = make_base(SIZE, SIZE, (30, 26, 22))
    draw = ImageDraw.Draw(img)
    # 長屋内部の寄合所風
    # 天井
    draw_wood_grain(draw, 0, 0, SIZE, 60, (45, 35, 28), (38, 28, 22))
    # 柱
    for x in range(40, SIZE, 140):
        draw.rectangle([x, 0, x + 16, SIZE], fill=(42, 32, 22))
    # 壁（左側）
    draw.rectangle([0, 60, 200, SIZE], fill=(42, 37, 30))
    draw_vertical_lattice(draw, 0, 60, 200, SIZE - 60, 40, (52, 45, 38))
    # 障子（中央）
    draw.rectangle([220, 180, 400, 500], fill=(35, 30, 25))
    draw_shoji_grid(draw, 220, 180, 180, 320, 30, (50, 45, 38))
    # 床（畳）
    draw_ichimatsu(draw, 40, 520, SIZE - 80, 120, 25, (50, 48, 40), (42, 40, 35))
    draw_tatami_pattern(draw, 40, 520, SIZE - 80, 120, (45, 48, 38))
    # 座布団
    for zx in [80, 240, 400, 520]:
        draw.ellipse([zx, 380, zx + 50, 430], fill=(50, 30, 25))
    # 行灯
    draw.rectangle([280, 60, 300, 160], fill=(55, 45, 35))
    draw.ellipse([275, 50, 305, 70], fill=(70, 55, 30))
    # 灯り
    for x in range(278, 302, 4):
        for y in range(65, 75, 4):
            draw.point((x, y), (80, 60, 20))
    img = img.filter(ImageFilter.GaussianBlur(1))
    img = add_noise(img, 5)
    img = add_vignette(img, 1.3)
    return img

# ========== メイン処理 ==========
def main():
    assets_dir = 'assets/images'
    
    # バックアップ
    print("=== 既存画像をバックアップ ===")
    for f in os.listdir(assets_dir):
        if f.endswith('.png') and not f.endswith('.bak.png'):
            src = os.path.join(assets_dir, f)
            dst = os.path.join(assets_dir, f + '.bak')
            shutil.copy2(src, dst)
            print(f"  {f} → {f}.bak")
    
    # 生成
    generators = {
        'home_bg.png': ('修練場（道場）', create_dojo),
        'guild_bg.png': ('寄合所（集会所）', create_guild),
        'temple_bg.png': ('社（神社内観）', create_temple),
        'home_0.png': ('野宿（焚き火と夜空）', create_camp),
        'home_1.png': ('小さな庵（藁葺き屋根）', create_hut),
        'home_2.png': ('木造長屋', create_nagaya),
        'home_3.png': ('石造り蔵', create_kura),
        'home_4.png': ('寄合所長屋', create_guild_nagaya),
    }
    
    print("\n=== 和風テクスチャ生成 ===")
    for filename, (desc, func) in generators.items():
        path = os.path.join(assets_dir, filename)
        img = func()
        img.save(path, 'PNG')
        print(f"  {filename}: {img.size[0]}x{img.size[1]} — {desc}")
    
    print("\n=== 完了 ===")

if __name__ == '__main__':
    main()
