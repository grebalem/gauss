from PIL import Image
rawData = open("alena_8bit.raw",'rb').read()
imgSize = (640,512)
img = Image.frombytes('L', imgSize, rawData)
img.save("alena.png")


