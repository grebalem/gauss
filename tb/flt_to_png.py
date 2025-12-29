from PIL import Image
rawData = open("alena_8bit.flt",'rb').read()
imgSize = (640,512)
img = Image.frombytes('L',imgSize,rawData)
img.save("alena_flt.png")


