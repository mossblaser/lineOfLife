import sys
from PIL import Image

img = Image.open(sys.argv[1])

out_bytes = []

for col in range(img.size[0]):
	col_bytes = []
	for byte_num in range(img.size[1]/8):
		cur_byte = 0
		for row in range(byte_num*8, byte_num*8 + 8):
			cur_byte <<= 1
			cur_byte |= int(img.getpixel((col,row))[0] < 128)
		col_bytes.append(cur_byte)
	out_bytes.append(col_bytes)

print ",\n".join("{%s}"%(",".join("0x%02X"%b for b in col_bytes[::-1])) for col_bytes in out_bytes)
#print ",\n".join("{%s}"%(",".join("%08s"%(bin(b)[2:]) for b in col_bytes)) for col_bytes in out_bytes).replace("0"," ")
