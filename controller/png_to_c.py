import sys
from PIL import Image

img = Image.open(sys.argv[1])

out_bytes = []

for col in range(img.size[0]):
	cur_byte = 0
	for row in range(img.size[1]):
		cur_byte <<= 1
		cur_byte |= int(img.getpixel((col,row))[0] == 0)
	out_bytes.append(cur_byte)

print ",".join("0x%02X"%b for b in out_bytes)
