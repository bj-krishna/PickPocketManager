--[[
TODO:
	Junkboxes money 
	Junkboxes count
	
]]--
local debug = true

--To know whether Pick pickpocket spell has been casted
local ppSuccess = false

--Only used for a Specific use case - For Event CHAT_MSG_MONEY
--ppCasted is same as ppSuccess, but we need another variable for this use case
local ppCasted = false
local playerInCombat = false

--local bagIndex, slotIndex
local junkBoxMode = false

--Money Storage Variables in copper
local currentSessionMoneyLooted = 0

--Slash Commands
local function SayHelloAndShowOptions(msg)
	if(msg == "") then
		print('Welcome to PickPocketManager, Here are options to use: ')
		print('Toggle PPM: /ppm on/off')
		print('Current Session - Money looted: /ppm S')
		print('Total Money looted: /ppm T')
		print('Highest loot: /ppm H')
		print('Lowest loot: /ppm L')
		print('Show All Stats: /ppm all')
	elseif(msg == "S") then
		local tG, tS, tC = ConvertToGSC(currentSessionMoneyLooted)
		print('Current Session Money looted: ' .. tG .. ' Gold ' .. tS .. ' Silver ' .. tC .. ' Copper')
	elseif(msg == "T") then
		local tG, tS, tC = ConvertToGSC(TotalMoneyLootedTillNowInCopper)
		print('Total Money looted: ' .. tG .. ' Gold ' .. tS .. ' Silver ' .. tC .. ' Copper')
	elseif(msg == "H") then
		local tG, tS, tC = ConvertToGSC(highestOneTimeLooted)
		print('Max loot: ' .. tG .. ' Gold ' .. tS .. ' Silver ' .. tC .. ' Copper')
	elseif(msg == "L") then
		local tG, tS, tC = ConvertToGSC(lowestOneTimeLooted)
		print('Min loot: ' .. tG .. ' Gold ' .. tS .. ' Silver ' .. tC .. ' Copper')
	elseif(msg == "all") then
		local tG, tS, tC = ConvertToGSC(currentSessionMoneyLooted)
		print('Current Session Money looted: ' .. tG .. ' Gold ' .. tS .. ' Silver ' .. tC .. ' Copper')
		local tG, tS, tC = ConvertToGSC(TotalMoneyLootedTillNowInCopper)
		print('Total Money looted: ' .. tG .. ' Gold ' .. tS .. ' Silver ' .. tC .. ' Copper')
		local tG, tS, tC = ConvertToGSC(highestOneTimeLooted)
		print('Max loot: ' .. tG .. ' Gold ' .. tS .. ' Silver ' .. tC .. ' Copper')
		local tG, tS, tC = ConvertToGSC(lowestOneTimeLooted)
		print('Min loot: ' .. tG .. ' Gold ' .. tS .. ' Silver ' .. tC .. ' Copper')
	end
end

local function ToggleJunkMode(msg)
	if(junkBoxMode == true) then
		junkBoxMode = false
		print('JunkBoxMode Off')
	else
		junkBoxMode = true
		print('JunkBoxMode On')
	end
end

SLASH_PPM1 = "/ppm"
SlashCmdList["PPM"] = SayHelloAndShowOptions

SLASH_PPMJB1 = "/ppmjb"
SlashCmdList["PPMJB"] = ToggleJunkMode

local AddonLoaded_EventFrame = CreateFrame("Frame")
AddonLoaded_EventFrame:RegisterEvent("ADDON_LOADED")
AddonLoaded_EventFrame:SetScript("OnEvent",
	function(self, event, ...)
		local arg1 = ...
		if(arg1 == "PickPocketManager") then
			DEFAULT_CHAT_FRAME:AddMessage("PickPocketManager Loaded successfully... Happy pickpocketing!!!")
			if(TotalMoneyLootedTillNowInCopper == nil) then
				TotalMoneyLootedTillNowInCopper = 0
			end
			if(highestOneTimeLooted == nil) then
				highestOneTimeLooted = 0
			end
			if(lowestOneTimeLooted == nil) then
				lowestOneTimeLooted = 0			
			end
		end
	end)
	
--This event will be triggered even if you try to pickpocket the already tapped NPC or even if NPC resists the pickpocket spell
--Hence we need to set the flag false when player goes into combat mode.(Else, Pickpocket gives error, still we set the flag and then normal loot will be assumed as pickpocketed loot)
local PPSpellSuccess_EventFrame = CreateFrame("Frame")
PPSpellSuccess_EventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
PPSpellSuccess_EventFrame:SetScript("OnEvent",
	function(self, event, ...)
		local arg1, arg2, arg3 = ...				
		if(arg3 == 921) then
			PP_Print('Pick Pocket spell casted successfully...') 
			ppSuccess = true
			ppCasted = true
		end
	end)
	
local PlayerInCombat_EventFrame = CreateFrame("Frame")
PlayerInCombat_EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
PlayerInCombat_EventFrame:SetScript("OnEvent",
	function(self, event, ...)
		--No arguments for this event
		PP_Print('PLAYER_REGEN_DISABLED::DEBUGTRACE: Reset PP flag')
		ppSuccess = false
		playerInCombat = true
	end)
	
local PlayerOutOfCombat_EventFrame = CreateFrame("Frame")
PlayerOutOfCombat_EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
PlayerOutOfCombat_EventFrame:SetScript("OnEvent",
	function(self, event, ...)
		--No arguments for this event
		PP_Print('PLAYER_REGEN_ENABLED::DEBUGTRACE: Out of combat')		
		playerInCombat = false
	end)
	
local LootOpened_EventFrame = CreateFrame("Frame")
LootOpened_EventFrame:RegisterEvent("LOOT_OPENED")
LootOpened_EventFrame:SetScript("OnEvent",
	function(self, event, ...)
		print('LOOT_OPENED')
		if(ppSuccess == true) then
			local lootIcon, lootName = GetLootSlotInfo(1)			
			UpdateLootMoney(lootName, event)						
			ppSuccess = false 	--Next Loot can be normal loot, so reset this again to make sure only PP loot comes here
			ppCasted = false	--If Loot Opened event triggered, no need of CHAT_MSG_MONEY event.		
		elseif(junkBoxMode == true) then
			local lootIcon, lootName = GetLootSlotInfo(1)
			UpdateLootMoney(lootName, event)
		end
	end)
	
--This is for one specific use case.
--Player pickpockets and immediately attacks 
--(LOOT_OPENED event does not get triggered here for some reason and after around 1 sec, 
--	Player receives the pickpocket loot and chat msg is displayed.)	
local LootChatMsg_EventFrame = CreateFrame("Frame")
LootChatMsg_EventFrame:RegisterEvent("CHAT_MSG_MONEY")
LootChatMsg_EventFrame:SetScript("OnEvent",
	function(self, event, ...)
		local arg1 = ...		
		if(ppCasted == true and playerInCombat == true) then			
			--Get the money looted from the chat message
			local lootName = TrimForMoneyMessage(arg1)
			UpdateLootMoney(lootName, event)					
			ppCasted = false -- Reset the flag for next pickpocketing
		end		
	end)
	
--[[local testKB_EventFrame = CreateFrame("Frame")
testKB_EventFrame:RegisterEvent("ITEM_UNLOCKED")
testKB_EventFrame:SetScript("OnEvent",
	function(self, event, ...)
		local arg1, arg2 = ...		
		print('ITEM_UNLOCKED::DEBUGTRACE: ' .. arg1)
		print('ITEM_UNLOCKED::DEBUGTRACE: ' .. arg2)
		
		local texture, itemCount, locked, quality, readable, lootable, ilink = GetContainerItemInfo(arg1, arg2)
		print(texture) print(itemCount) print(locked) print(quality) print(readable) print(lootable) print(ilink)
		if(otherLootOpened == true) then
			bagIndex = arg1
			slotIndex = arg2
			print('battered1') print('battered2')
		end
	end) ]]--

-- Functions --
	
function TrimForMoneyMessage(chatMsg)
	--String = You loot 15 Copper	>> Returns 15 Copper
	local moneyStr = string.sub(chatMsg, 10, -1)	
	return moneyStr
end

function ExtractGSCFromMoney(moneyLooted)
	--String = 1 Gold 2 Silver 3 Copper (each number can be 1 digit or 2 digits)
	--String = 10 Gold 2 Silver 30 Copper
	--print('ExtractGSCFromMoney::DEBUGTRACE:FunctionCall')
	local goldAmount = 0
	local silverAmount = 0
	local copperAmount = 0
	local amount = 0
	
	for i=1,string.len(moneyLooted),1 
	do
		local c = string.sub(moneyLooted,i,i)		
		local cInt = tonumber(c)
		if(cInt ~= nil) then			
			amount = amount*10 + cInt			
		elseif(c == "G") then
			goldAmount = amount
			amount = 0
		elseif(c == "S") then
			silverAmount = amount
			amount = 0
		elseif(c == "C") then
			copperAmount = amount
			amount = 0
		end		
	end	
	
	return goldAmount, silverAmount, copperAmount
end

--This Argument must be in GSC string format (Eg: 1 Gold 2 Silver 25 Copper)
function UpdateLootMoney(money, event)
	if(string.find(money, "Gold") == nil and string.find(money, "Silver") == nil and string.find(money, "Copper") == nil) then
		PP_Print('Not Money')
		return
	end
	
	local g, s, c = ExtractGSCFromMoney(money)
	local ppCopperAmount = ConvertToCopper(g, s, c)
	
	if(highestOneTimeLooted == 0) then
		highestOneTimeLooted = ppCopperAmount
	elseif(highestOneTimeLooted < ppCopperAmount) then
		highestOneTimeLooted = ppCopperAmount
	end
	
	if(lowestOneTimeLooted == 0) then
		lowestOneTimeLooted = ppCopperAmount
	elseif(ppCopperAmount < lowestOneTimeLooted) then
		lowestOneTimeLooted = ppCopperAmount
	end
		
	currentSessionMoneyLooted = currentSessionMoneyLooted + ppCopperAmount
	TotalMoneyLootedTillNowInCopper = TotalMoneyLootedTillNowInCopper + ppCopperAmount
	
	PP_PrintMoney(currentSessionMoneyLooted, "Current Session", event)
	PP_PrintMoney(TotalMoneyLootedTillNowInCopper, "Total", event)
end

function ConvertToCopper(g, s, c)
	local totalCopperAmount = g*10000 + s*100 + c
	return totalCopperAmount
end

function ConvertToGSC(totalCopperAmount)
	local gold = 0
	local silver = 0
	local copper = 0
	
	copper = totalCopperAmount%100
	if(totalCopperAmount >= 100) then
		silver = totalCopperAmount/100
		silver = math.floor(silver)
	end	
	
	if(silver >= 100) then
		gold = silver/100
		gold = math.floor(gold)
		silver = silver%100
	end
	
	return gold, silver, copper	
end

function PP_Print(message)
	if(debug == true) then
		print(message)
	end
end

function PP_PrintMoney(moneyInCopper, info, event)
	if(debug == true) then
		local tG, tS, tC = ConvertToGSC(moneyInCopper)
		print(event .. '::DEBUGTRACE: ' .. info .. ' Money looted: ' .. tG .. ' Gold ' .. tS .. ' Silver ' .. tC .. ' Copper')
	end
end