local voiceData = {}
local voiceModes = {
	{5, "Whisper"},
	{15, "Normal"},
	{40, "Shouting"},
}
local voiceMode = 2

RegisterCommand("+voiceMode", function()
	local newMode = voiceMode + 1

	if newMode > #voiceModes then
		voiceMode = 1
	else
		voiceMode = newMode
	end

	TriggerServerEvent("mumble:SetVoiceMode", voiceMode)
end)

RegisterCommand("-voiceMode", function()
	
end)

RegisterKeyMapping("+voiceMode", "Change voice distance", "keyboard", "x")

AddEventHandler("onClientResourceStart", function (resourceName)
	if GetCurrentResourceName() ~= resourceName then
		return
	end

	TriggerServerEvent("mumble:Initialise")
end)

RegisterNetEvent("mumble:SetVoiceData")
AddEventHandler("mumble:SetVoiceData", function(data)
	voiceData = data
end)


Citizen.CreateThread(function()
	local headBone = 0x796e
	while true do
		Citizen.Wait(0)
		local playerId = PlayerId()
		local playerPed = PlayerPedId()
		local playerHeading = math.rad(GetGameplayCamRot().z % 360)
		local playerPos = GetPedBoneCoords(playerPed, headBone)
		local playerList = GetActivePlayers()

		for i = 1, #playerList do
			local remotePlayerId = playerList[i]

			if playerId ~= remotePlayerId then
				local remotePlayerServerId = GetPlayerServerId(remotePlayerId)
				local remotePlayerPed = GetPlayerPed(remotePlayerId)
				local remotePlayerPos = GetPedBoneCoords(remotePlayerPed, headBone)
				local remotePlayerData = voiceData[remotePlayerServerId]

				local distance = #(playerPos - remotePlayerPos)
				local mode = 2

				if remotePlayerData ~= nil then
					mode = remotePlayerData.mode or 2
				end

				--print("player:" .. remotePlayerServerId, "distance: " .. distance, "mode:" .. voiceModes[mode][1], "volume:" .. volume)

				if distance < voiceModes[mode][1] then
					local volume = 1.0 - (distance / voiceModes[mode][1])

					if volume < 0 then
						volume = 0.0
					end

					MumbleSetVolumeOverride(remotePlayerId, volume)
				else
					MumbleSetVolumeOverride(remotePlayerId, 0.0)
				end
			end
		end
	end
end)

local deltas = {
    vector2(-1, -1),
    vector2(-1, 0),
    vector2(-1, 1),
    vector2(0, -1),
    vector2(1, -1),
    vector2(1, 0),
    vector2(1, 1),
    vector2(0, 1),
}

local function getGridChunk(x)
    return math.floor((x + 8192) / 128)
end

local function getGridBase(x)
    return (x * 128) - 8192
end

local function toChannel(v)
    return (v.x << 8) | v.y
end

local targetList = {}
local lastTargetList = {}

-- loop
--neptunium
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		local playerId = PlayerId()
		local playerPed = PlayerPedId()
		local playerHeading = math.rad(GetGameplayCamRot().z % 360)
		local playerPos = GetPedBoneCoords(playerPed, headBone)
		local playerList = GetActivePlayers()

		local currentChunk = vector2(getGridChunk(coords.x), getGridChunk(coords.y)) -- Chunk player is in
		local chunkChannel = toChannel(currentChunk)

		NetworkSetVoiceChannel(gridZone)

		targetList = {}

		for i = 1, #deltas do -- Get nearby chunks
			local chunkSize = coords.xy + (deltas[i] * 20) -- edge size
			local chunk = vector2(getGridChunk(chunkSize.x), getGridChunk(chunkSize.y))
			local channel = toChannel(chunk)

			targetList[channel] = true
		end
		
		-- super naive hash difference
		local different = false
		print(json.encode(targetList))
		for k, _ in pairs(targetList) do
			if not lastTargetList[k] then
				different = true
				break
			end
		end

		if not different then
			for k, _ in pairs(lastTargetList) do
				if not targetList[k] then
					different = true
					break
				end
			end
		end

		if different then
			-- you might want to swap between two targets when changing
			MumbleClearVoiceTarget(2)
			
			for k, _ in pairs(targetList) do
				MumbleAddVoiceTargetChannel(2, k)
			end
			
			MumbleSetVoiceTarget(2)

			lastTargetList = targetList
		end
	end
end)