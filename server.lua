local RSGCore = exports['rsg-core']:GetCoreObject()

RSGCore.Functions.CreateCallback('hhfw:docOnline', function(source, cb)
	local src = source
	local Ply = RSGCore.Functions.GetPlayer(src)
	local xPlayers = RSGCore.Functions.GetPlayers()
	local doctor = 0
	local canpay = false
	if Ply.PlayerData.money["cash"] >= Config.Price then
		canpay = true
	else
		if Ply.PlayerData.money["bank"] >= Config.Price then
			canpay = true
		end
	end

	for i=1, #xPlayers, 1 do
		local xPlayer = RSGCore.Functions.GetPlayer(xPlayers[i])
		if xPlayer.PlayerData.job.name == 'medic' then
			doctor = doctor + 1
		end
	end

	cb(doctor, canpay)
end)


RSGCore.Functions.CreateCallback('rsg-medic:server:anyMedicsOnline', function(source, cb)
    local medics = 0
    local players = RSGCore.Functions.GetPlayers()
    for _, v in pairs(players) do
        local Player = RSGCore.Functions.GetPlayer(v)
        if Player.PlayerData.job.name == "medic" then
            medics = medics + 1
        end
    end
    cb(medics > 0)
end)

RegisterServerEvent('hhfw:charge')
AddEventHandler('hhfw:charge', function()
	local src = source
	local xPlayer = RSGCore.Functions.GetPlayer(src)
	if xPlayer.PlayerData.money["cash"] >= Config.Price then
		xPlayer.Functions.RemoveMoney("cash", Config.Price)
	else
		xPlayer.Functions.RemoveMoney("bank", Config.Price)
	end
	TriggerEvent("rsg-bossmenu:server:addAccountMoney", 'medic', Config.Price)
end)