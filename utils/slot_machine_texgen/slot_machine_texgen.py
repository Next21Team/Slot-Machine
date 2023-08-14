#!/usr/bin/python3

import json
from os import makedirs, path, walk
from PIL import Image, ImageFont, ImageDraw
import shutil
import sys


root_path = path.abspath(path.dirname(__file__))
src_path = path.join(root_path, 'src')
symbols_path = path.join(root_path, 'symbols')
pattern_path = path.join(root_path, 'cfg/_pattern.json')
text_path = path.join(root_path, 'cfg/text.json')
font_path = path.join(root_path, 'font/Pumpkin/Pumpkin.otf')
bodies_path = path.join(src_path, 'bodies')
tex_path = path.join(src_path, 'textures')
reels_smd_path = path.join(bodies_path, 'reels.smd')
tex_prizes_path = path.join(tex_path, 'mon1.bmp')
tex_bet_path = path.join(tex_path, 'mon2.bmp')

dist_path = path.join(root_path, 'dist')
dist_tex_path = path.join(dist_path, 'textures')
dist_bodies_path = path.join(dist_path, 'bodies')
dist_reels_smd_path = path.join(dist_bodies_path, 'reels.smd')

reel_bg_color = (255, 255, 255)
reel_tex_size = (512, 512)

symbol_length = 128
symbol_rows = reel_tex_size[0] // symbol_length
symbol_uv_size = (0.3965121046966565, 1.0 / symbol_rows)

bet_font_max_size = 48
bet_max_width = 130
bet_pos = (434, 300)

prizes_max_width = 170
prizes_max_height = 294
prizes_pos = (90, 104)
prizes_text_pos_x = 340
prizes_font_scale = 0.65


def gen_symbol_img(img, d):
    w, h = img.size
    s = min(w, h)
    x, y = (w - s) // 2, (h - s) // 2
    return img.crop((x, y, x + s, y + s)).resize((d, d), Image.LANCZOS)


def gen_reel_img(symbols):
    reel_img = Image.new('RGB', reel_tex_size, reel_bg_color)
    uvs = {}

    for idx, img in symbols.items():
        x = 64 + idx // symbol_rows * 256
        y = idx % symbol_rows * symbol_length
        symbol_img = gen_symbol_img(img, symbol_length)
        reel_img.paste(symbol_img, (x, y), symbol_img)

        x = idx // symbol_rows * 256
        y = ((symbol_rows - 1) - idx % symbol_rows) * symbol_length

        x = (x / reel_tex_size[0]) + ((0.5 - symbol_uv_size[0]) / 2)
        y = y / reel_tex_size[1]

        uvs[idx] = (x, y, x + symbol_uv_size[0], y + symbol_uv_size[1])

    return reel_img, uvs


def rewrite_reel_smd(src_path, dist_path, pattern, uvs):
    fd_dist = open(dist_path, 'w')
    with open(src_path, 'r') as fd_src:
        vert_idx = -1
        for line in fd_src:
            try:
                reel, row = map(int, line.split('.'))
                vert_idx = 0
                symbol_idx = pattern[reel][row % 8]
                line = 'reel.bmp\n'
            except ValueError:
                if vert_idx > -1:
                    vert_data = line.split()
                    uv_x, uv_y = map(lambda v: abs(float(v)), vert_data[-2:])
                    uv_x = uvs[symbol_idx][2 if uv_x > 0.0 else 0]
                    uv_y = uvs[symbol_idx][3 if uv_y > 0.0 else 1]
                    vert_data[-2], vert_data[-1] = f'{uv_x:.6f}', f'{uv_y:.6f}'
                    line = ' '.join(vert_data) + '\n'
                    vert_idx += 1
                if vert_idx > 2:
                    vert_idx = -1
            fd_dist.write(line)

    fd_dist.close()


def draw_bet(img, bet_data):
    font_size = bet_font_max_size
    font = ImageFont.truetype(font_path, font_size)
    text = bet_data['text']
    color, shadow_color = tuple(bet_data['color']), tuple(bet_data['shadow'])

    draw = ImageDraw.Draw(img)
    while draw.textlength(text, font) > bet_max_width:
        font_size -= 1
        font = ImageFont.truetype(font_path, font_size)
    draw.text((bet_pos[0] + 3, bet_pos[1] + 3), text, shadow_color, font, anchor='ms', align='center')
    draw.text(bet_pos, text, color, font, anchor='ms', align='center')


def draw_prizes(img, symbols, prizes_data):
    s = min(prizes_max_height // len(symbols), prizes_max_width // 3)
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(font_path, int(s * prizes_font_scale))

    for idx, symbol_img in symbols.items():
        pd = prizes_data[idx]
        text, color, shadow_color = pd['text'], tuple(pd['color']), tuple(pd['shadow'])

        thumb = symbol_img.resize((s, s), Image.LANCZOS)
        shadow = Image.new("RGB", (s, s), shadow_color)
        y = prizes_pos[1] + idx * s
        for off_x in range(3):
            x = prizes_pos[0] + off_x * s
            img.paste(shadow, (x - 2, y + 2), thumb)
            img.paste(thumb, (x, y), thumb)

        x = prizes_text_pos_x
        y += int(s * (1 - prizes_font_scale)) // 2
        draw.text((x + 3, y + 3), text, shadow_color, font, anchor='ma', align='center')
        draw.text((x, y), text, color, font, anchor='ma', align='center')


def check_paths():
    if not path.exists(src_path):
        sys.exit('Source directory "%s" does not exist' % src_path)

    if not path.exists(symbols_path):
        sys.exit('Symbols directory "%s" does not exist' % symbols_path)

    if not path.isfile(pattern_path):
        sys.exit('Pattern file "%s" does not exist' % pattern_path)

    if not path.isfile(text_path):
        sys.exit('Text file "%s" does not exist' % text_path)

    if not path.isfile(reels_smd_path):
        sys.exit('Reels SMD file "%s" does not exist' % reels_smd_path)

    if not path.isfile(tex_prizes_path):
        sys.exit('Texture file "%s" does not exist' % tex_prizes_path)

    if not path.isfile(tex_bet_path):
        sys.exit('Texture file "%s" does not exist' % tex_bet_path)

    if not path.isfile(font_path):
        sys.exit('Font file "%s" does not exist' % font_path)

    if not path.exists(dist_path):
        makedirs(dist_path)

    if not path.exists(dist_tex_path):
        makedirs(dist_tex_path)


def check_pattern_dimension(pattern):
    valid = True
    if len(pattern) != 3:
        valid = False
    else:
        for p in pattern:
            if len(p) != 8:
                valid = False

    if not valid:
        sys.exit('Ivalid pattern dimension. Should be: 3x8')


def check_symbol_indices(symbols, pattern, prizes_data):
    loaded_indices = set(symbols.keys())
    pattern_indices = set()
    for p in pattern:
        pattern_indices.update(p)
    prizes_indices = set(range(len(prizes_data)))

    missing_indices = pattern_indices - loaded_indices
    if missing_indices:
        sys.exit('Missing symbol images (required in pattern cfg): ' + ' '.join(map(str, missing_indices)))

    missing_indices = loaded_indices - prizes_indices
    if missing_indices:
        sys.exit('Missing symbol indices in text cfg: ' + ' '.join(map(str, missing_indices)))


def save_img(img, path):
    img.convert('P', palette=Image.ADAPTIVE).save(path + '.bmp')
    img.convert('RGB').save(path + '.png')


def main():
    check_paths()
    shutil.copytree(src_path, dist_path, dirs_exist_ok=True)

    with open(pattern_path, 'r') as fd:
        pattern = json.load(fd)

    with open(text_path, 'r') as fd:
        text_data = json.load(fd)
    bet_data = text_data['bet']
    prizes_data = text_data['prizes']

    symbols = {}
    for _, _, files in walk(symbols_path):
        for fn in files:
            idx = int(fn.split('.')[0])
            symbols[idx] = Image.open(path.join(symbols_path, fn)).convert('RGBA')

    check_pattern_dimension(pattern)
    check_symbol_indices(symbols, pattern, prizes_data)

    reel_img, uvs = gen_reel_img(symbols)
    save_img(reel_img, path.join(dist_tex_path, 'reel'))
    rewrite_reel_smd(reels_smd_path, dist_reels_smd_path, pattern, uvs)

    prize_img = Image.open(tex_prizes_path).convert('RGBA')
    draw_prizes(prize_img, symbols, prizes_data)
    save_img(prize_img, path.join(dist_tex_path, 'mon1'))

    bet_img = Image.open(tex_bet_path).convert('RGBA')
    draw_bet(bet_img, bet_data)
    save_img(bet_img, path.join(dist_tex_path, 'mon2'))


if __name__ == "__main__":
    main()
