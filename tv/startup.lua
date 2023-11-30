local gpu = peripheral.find("tm_gpu")
gpu.refreshSize()
gpu.setSize(64)
gpu.refreshSize()
local px_w, px_h, mon_w, mon_h, res = gpu.getSize()

while true do
    gpu.fill()
    local files = fs.list("images")
    for idx, imagePath in pairs(files) do
        local imgBuf = io.open("images/"..imagePath, "rb")
        local b = imgBuf._handle.read(1)
        local imgBin = {}
        while b do
            imgBin[#imgBin+1] = ("<I1"):unpack(b)
            b = imgBuf._handle.read(1)
        end
        local image = gpu.decodeImage(table.unpack(imgBin))
        gpu.drawBuffer(1, 1, px_w, 1, image.getAsBuffer())
        gpu.sync()
        sleep(10)
    end
end