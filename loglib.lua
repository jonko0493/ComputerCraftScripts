local function log(logName, message)
    if not(fs.exists("logs")) then
        fs.makeDir("logs")
    end

    local fileName = "logs/"..logName..".log"
    -- if we're over 256 KiB, clear the log file
    if fs.exists(fileName) and fs.getSize(fileName) > 262144 then
        fs.delete(fileName)
    end
    local logFile = fs.open(fileName, "a")
    logFile.write(message.."\n")
    logFile.close()
end

return { log = log }