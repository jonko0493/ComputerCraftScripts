local CHANNEL = "mob-report"

local trackedMobs = {
    { key = "minecraft:blaze", name = "Blaze", icon = "https://minecraft.wiki/images/BlazeFace.png" },
    { key = "minecraft:cave_spider", name = "Cave Spider", icon = "https://minecraft.wiki/images/CaveSpiderFace.png" },
    { key = "minecraft:creeper", name = "Creeper", icon = "https://minecraft.wiki/images/CreeperFace.png" },
    { key = "minecraft:drowned", name = "Drowned", icon = "https://minecraft.wiki/images/DrownedFace.png" },
    { key = "minecraft:enderman", name = "Enderman", icon = "https://minecraft.wiki/images/EndermanFace.png" },
    { key = "minecraft:ender_dragon", name = "Ender Dragon", icon = "https://minecraft.wiki/images/EnderdragonFace.png" },
    { key = "minecraft:elder_guardian", name = "Elder Guardian", icon = "https://minecraft.wiki/images/ElderGuardianFace.png" },
    { key = "minecraft:endermite", name = "Endermite", icon = "https://minecraft.wiki/images/EndermiteFace.png" },
    { key = "minecraft:evoker", name = "Evoker", icon = "https://minecraft.wiki/images/EvokerFace.png" },
    { key = "minecraft:ghast", name = "Ghast", icon = "https://minecraft.wiki/images/GhastFace.png" },
    { key = "minecraft:guardian", name = "Guardian", icon = "https://minecraft.wiki/images/GuardianFace.png" },
    { key = "minecraft:hoglin", name = "Hoglin", icon = "https://minecraft.wiki/images/HoglinFace.png" },
    { key = "minecraft:husk", name = "Husk", icon = "https://minecraft.wiki/images/HuskFace.png" },
    { key = "minecraft:magma_cube", name = "Magma Cube", icon = "https://minecraft.wiki/images/MagmaCubeFace.png" },
    { key = "minecraft:phantom", name = "Phantom", icon = "https://minecraft.wiki/images/PhantomFace.png" },
    { key = "minecraft:piglin", name = "Piglin", icon = "https://minecraft.wiki/images/thumb/PiglinFace.png/188px-PiglinFace.png" },
    { key = "minecraft:piglin_brute", name = "Piglin Brute", icon = "https://minecraft.wiki/images/thumb/PiglinBruteFace.png/188px-PiglinBruteFace.png" },
    { key = "minecraft:pillager", name = "Pillager", icon = "https://minecraft.wiki/images/PillagerFace.png" },
    { key = "minecraft:ravager", name = "Ravager", icon = "https://minecraft.wiki/images/RavagerFace.png" },
    { key = "minecraft:shulker", name = "Shulker", icon = "https://minecraft.wiki/images/ShulkerFace.png" },
    { key = "minecraft:silverfish", name = "Silverfish", icon = "https://minecraft.wiki/images/SilverfishFace.png" },
    { key = "minecraft:skeleton", name = "Skeleton", icon = "https://minecraft.wiki/images/SkeletonFace.png" },
    { key = "minecraft:slime", name = "Slime", icon = "https://minecraft.wiki/images/SlimeFace.png" },
    { key = "minecraft:spider", name = "Spider", icon = "https://minecraft.wiki/images/SpiderFace.png" },
    { key = "minecraft:stray", name = "Stray", icon = "https://minecraft.wiki/images/StrayFace.png" },
    { key = "minecraft:vex", name = "Vex", icon = "https://minecraft.wiki/images/VexFace.png" },
    { key = "minecraft:vindicator", name = "Vindicator", icon = "https://minecraft.wiki/images/VindicatorFace.png" },
    { key = "minecraft:warden", name = "Warden", icon = "https://minecraft.wiki/images/WardenFace.png" },
    { key = "minecraft:witch", name = "Witch", icon = "https://minecraft.wiki/images/WitchFace.png" },
    { key = "minecraft:wither", name = "Wither", icon = "https://minecraft.wiki/images/WitherFace.png" },
    { key = "minecraft:wither_skeleton", name = "Wither Skeleton", icon = "https://minecraft.wiki/images/WitherSkeletonFace.png" },
    { key = "minecraft:zoglin", name = "Zoglin", icon = "https://minecraft.wiki/images/ZoglinFace.png" },
    { key = "minecraft:zombie", name = "Zombie", icon = "https://minecraft.wiki/images/ZombieFace.png" },
    { key = "minecraft:zombie_villager", name = "Zombie Villager", icon = "https://minecraft.wiki/images/ZombieVillagerFace.png" },
    { key = "minecraft:zombified_piglin", name = "Zombified Piglin", icon = "https://minecraft.wiki/images/thumb/ZombifiedPiglinFace.png/158px-ZombifiedPiglinFace.png" }
}

local function getTrackedMobData(key)
    for idx, mob in pairs(trackedMobs) do
        if mob.key == key then
            return mob
        end
    end
end

peripheral.find("modem", rednet.open)
local sensor = peripheral.find("plethora:sensor")

while true do
    local sense = sensor.sense()
    local mobReport = {}
    for idx, entity in pairs(sense) do
        local trackedMobData = getTrackedMobData(entity.key)
        local my_x, my_y, my_z = gps.locate()
        if trackedMobData ~= nil then
            local report = { id = entity.id, name = entity.displayName, icon = trackedMobData.icon, x = entity.x + my_x, y = entity.y + my_y, z = entity.z + my_z }
            table.insert(mobReport, report)
        end
    end
    rednet.broadcast(textutils.serialize(mobReport), CHANNEL)
    sleep(1)
end