local RSGCore = exports['rsg-core']:GetCoreObject()

local Active = false
local medicHorse = nil
local medicPed = nil
local CooldownActive = false
local lastMedicPos = vector3(0,0,0)

local function IsPlayerMedic()
    local Player = RSGCore.Functions.GetPlayerData()
    return Player.job.name == "medic"
end

-- Helper Functions
local function CleanupEntities()
    if DoesEntityExist(medicHorse) then
        DeletePed(medicHorse)
    end
    if DoesEntityExist(medicPed) then
        DeletePed(medicPed)
    end
end

local function ResetScriptState()
    Active = false
    medicHorse = nil
    medicPed = nil
    CooldownActive = false
end

local function Notify(msg, type, duration)
    RSGCore.Functions.Notify(msg, type, duration)
end

local function FindSafeRoadSpawnPoint(playerCoords, radius)
    local attempt = 0
    local maxAttempts = 100  -- Increase this if needed for larger search area

    while attempt < maxAttempts do
        local angle = math.random() * 2 * math.pi
        local checkPoint = vector3(
            playerCoords.x + radius * math.cos(angle),
            playerCoords.y + radius * math.sin(angle),
            playerCoords.z
        )

        local retval, outPosition = GetClosestVehicleNode(checkPoint.x, checkPoint.y, checkPoint.z, 1, 3.0, 0)

        if retval then
            local roadPosition = vector3(outPosition.x, outPosition.y, outPosition.z)
            if not IsPositionOccupied(roadPosition.x, roadPosition.y, roadPosition.z, 10.0, false, true, true, false, false, 0, false) then
                local _, groundZ = GetGroundZFor_3dCoord(roadPosition.x, roadPosition.y, roadPosition.z + 10.0, 0)
                roadPosition = vector3(roadPosition.x, roadPosition.y, groundZ)
                return roadPosition
            end
        end

        attempt = attempt + 1
        radius = radius + 5.0  -- Gradually increase search radius
    end

    return nil  -- Return nil if no suitable position found
end

-- Main Command
RegisterCommand("help", function(source, args, raw)
    local playerPed = PlayerPedId()

    if IsEntityDead(playerPed) then
        if IsPlayerMedic() then
            Notify("As a medic, you can't call for medical assistance. Use your skills!", 'error', 3000)
        elseif not CooldownActive then
            -- Check if there are any online medics
            RSGCore.Functions.TriggerCallback('rsg-medic:server:anyMedicsOnline', function(medicsOnline)
                if medicsOnline then
                    Notify("There are medics on duty. Please wait for their assistance or use /911 to call them.", 'info', 5000)
                else
                    Notify("A medic is on the way!", 'success', 3000)
                    TriggerEvent('rsg-medic:client:spawnMedic')
                    CooldownActive = true
                end
            end)
        else
            Notify("Please wait before trying again!", 'error', 3000)
        end
    else
        Notify("This can only be used when dead!", 'error', 3000)
    end
end)

-- Medic Spawn Event
RegisterNetEvent('rsg-medic:client:spawnMedic')
AddEventHandler('rsg-medic:client:spawnMedic', function()
    CleanupEntities()
    CooldownActive = true

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local spawnPos = FindSafeRoadSpawnPoint(playerCoords, 50.0)

    if not spawnPos then
        Notify("Unable to find a suitable spawn location for the medic.", 'error', 5000)
        return
    end

    local horseHash = GetHashKey("A_C_Horse_Arabian_White")
    local pedModelHash = GetHashKey("cs_sddoctor_01")

    RequestModel(horseHash)
    RequestModel(pedModelHash)

    while not HasModelLoaded(horseHash) or not HasModelLoaded(pedModelHash) do
        Wait(1)
    end

    medicHorse = CreatePed(horseHash, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
    Citizen.InvokeNative(0x283978A15512B2FE, medicHorse, true)

    -- Add saddle to the horse
    local saddleHash = GetHashKey("HORSE_EQUIPMENT_MCCLELLAN_01")
    Citizen.InvokeNative(0xD3A7B003ED343FD9, medicHorse, saddleHash, true, true, true)

    -- Set horse's attributes for faster speed
    Citizen.InvokeNative(0xA95F667A755725DA, medicHorse, 1.9)
    Citizen.InvokeNative(0x4EB122210A90E2D8, medicHorse, 1.9)

    medicPed = CreatePed(pedModelHash, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
    Citizen.InvokeNative(0x283978A15512B2FE, medicPed, true)

    Citizen.InvokeNative(0x028F76B6E78246EB, medicPed, medicHorse, -1)
    
    TaskGoToCoordAnyMeans(medicPed, playerCoords.x, playerCoords.y, playerCoords.z, 4.0, 0, 0, 786603, 0xbf800000)

    Active = true
    print("Medic spawned at: " .. tostring(spawnPos))
    print("Player position: " .. tostring(playerCoords))
end)

-- Update Medic Destination
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3000)  -- Update more frequently (every 3 seconds)
        if Active and DoesEntityExist(medicPed) then
            local playerCoords = GetEntityCoords(PlayerPedId())
            TaskGoToCoordAnyMeans(medicPed, playerCoords.x, playerCoords.y, playerCoords.z, 4.0, 0, 0, 786603, 0xbf800000)
        end
    end
end)

-- Check for Stuck Medic
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)  -- Check every 10 seconds
        if Active and DoesEntityExist(medicPed) then
            local currentPos = GetEntityCoords(medicPed)
            if #(currentPos - lastMedicPos) < 0.1 then
                -- Medic hasn't moved, try to unstuck
                local playerCoords = GetEntityCoords(PlayerPedId())
                SetEntityCoordsNoOffset(medicPed, playerCoords.x + 3.0, playerCoords.y + 3.0, playerCoords.z, false, false, false)
                TaskGoToCoordAnyMeans(medicPed, playerCoords.x, playerCoords.y, playerCoords.z, 4.0, 0, 0, 786603, 0xbf800000)
            end
            lastMedicPos = currentPos
        end
    end
end)

-- Main Loop
-- Main Loop
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(200)
        if Active then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local medicCoords = GetEntityCoords(medicPed)
            local distToMedicPed = #(playerCoords - medicCoords)
            
            if distToMedicPed <= 15.0 and IsPedOnMount(medicPed) then
                -- Medic is close, dismount from horse
                TaskDismountAnimal(medicPed, 1, 0, 0, 0, 0)
                Citizen.Wait(1000)  -- Reduced wait time for dismount animation
            end
            
            if distToMedicPed <= 3.0 then  -- Increased distance for interaction
                -- Medic reached the player
                ClearPedTasks(medicPed)
                
                if IsEntityDead(playerPed) then
                    Notify("The medic is treating you...", 'primary', 3000)
                    
                    
                    
                    TaskStartScenarioInPlace(PlayerPedId(), GetHashKey("WORLD_HUMAN_CANNED_FOOD_COOKING"), -1, true, "StartScenario", 0, false)
                    
                    Citizen.Wait(Config.ReviveTime) -- Wait for Config.ReviveTime before reviving
                    
                    TriggerEvent('rsg-medic:client:revive')
                    TriggerServerEvent('hhfw:charge')  -- Charge the player
                    Notify("The medic has revived you and returned you to a safe zone!", 'success', 3000)
                    
                    CleanupEntities()
                    ResetScriptState()
                else
                    Notify("The medic has arrived but you don't need treatment.", 'primary', 3000)
                    CleanupEntities()
                    ResetScriptState()
                end
            end
        else
            Citizen.Wait(5000)  -- Reduced wait time when inactive
        end
    end
end)

-- Cooldown Reset
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000)  -- Check every minute
        if CooldownActive then
            CooldownActive = false
        end
    end
end)

