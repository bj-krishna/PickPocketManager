--[[
##Code wise Preference of loot : Pickpocket > JunkBoxMode > Junkbox without Mode
TODO:
	
Issues::
		There is a bug when accounting junkbox money when junkBoxMode is off
		If autoloot is off, user opens junkbox and takes time to loot all items, the money is not accounted.
		Even if autoloot is on, while looting if user gets Inventory full and loot window stays open, money is not accounted.
		**Money is accounted for junkboxes now only if loot window closes as fast as possible**
		Until I find a new way to account this money, I dont think there is a way with current code.
]]--
local debug = false

--To know whether Pick pickpocket spell has been casted
local ppLootName = ""
local ppSuccess = false

--Only used for a Specific use case - For Event CHAT_MSG_MONEY
--ppCasted is same as ppSuccess, but we need another variable for this use case
local ppCasted = false
local playerInCombat = false

local junkBoxMode = false
local junkBoxModeLootName = ""

--Accounting junkbox money even if junkBoxMode is Off
local OtherMoneyLootName = ""
local junkBoxItemClicked = false --This becomes true only if money is in loot_opened event and junkbox is clicked after that loot_opened.
--This click can be either moving/just clicking and leaving/actually opening the box.
--CHAT_MSG_MONEY event takes care of whether it is opened for that msg.

--Money Storage Variables in copper
local currentSessionMoneyLooted = 0

--Slash Commands
local function SayHelloAndShowOptions(msg)
	if(msg == "") then
		print('Welcome to PickPocketManager, Here are options to use: ')		
		print('PickPocketMoney for current session: /ppm S')
		print('PickPocketMoney total: /ppm T')
		print('PickPocketMoney maximum loot: /ppm H')
		print('PickPocketMoney minimum loot: /ppm L')
		print('Show All Stats: /ppm all')
		print('Toggle JunkBoxMode: /ppmjb')
	elseif(msg == "S" or msg == "s") then		
		print('PickPocketMoney::Session:: ' .. GetCoinTextureString(currentSessionMoneyLooted))
	elseif(msg == "T" or msg == "t") then
		print('PickPocketMoney::Total:: ' .. GetCoinTextureString(TotalMoneyLootedTillNowInCopper))
	elseif(msg == "H" or msg == "h") then		
		print('PickPocketMoney::MaxLoot:: ' .. GetCoinTextureString(highestOneTimeLooted))
	elseif(msg == "L" or msg == "l") then		
		print('PickPocketMoney::MinLoot:: ' .. GetCoinTextureString(lowestOneTimeLooted))
	elseif(msg == "all" or msg == "ALL") then		
		print('PickPocketMoney::Session:: ' .. GetCoinTextureString(currentSessionMoneyLooted))
		print('PickPocketMoney::Total:: ' .. GetCoinTextureString(TotalMoneyLootedTillNowInCopper))
		print('PickPocketMoney::MaxLoot:: ' .. GetCoinTextureString(highestOneTimeLooted))
		print('PickPocketMoney::MinLoot:: ' .. GetCoinTextureString(lowestOneTimeLooted))
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
		PP_Print('PLAYER_REGEN_DISABLED::DEBUGTRACE: Reset PP Flag')
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
		if(ppSuccess == true) then
			local lootIcon, lootName = GetLootSlotInfo(1)			
			--UpdateLootMoney(lootName, event)			
			ppLootName = lootName			
			PP_Print('ppLootName: ' .. ppLootName)
			ppSuccess = false 	--Next Loot can be normal loot, so reset this again to make sure only PP loot comes here
			ppCasted = false	--If Loot Opened event triggered, no need of CHAT_MSG_MONEY event.		
		elseif(junkBoxMode == true) then
			local lootIcon, lootName = GetLootSlotInfo(1)
			--UpdateLootMoney(lootName, event)		
			junkBoxModeLootName = lootName
			PP_Print('junkBoxModeLootName: ' .. junkBoxModeLootName)
		else
			local lootIcon, lootName, lootQuantity = GetLootSlotInfo(1)
			--PP_Print('lootIcon: ' .. lootIcon)
			--If money store, this might be money inside junk box.
			if(lootQuantity == 0 and (string.find(lootName, "Gold") ~= nil or string.find(lootName, "Silver") ~= nil or string.find(lootName, "Copper") ~= nil)) then
				OtherMoneyLootName = lootName				
				PP_Print('OtherMoneyLootName: ' .. OtherMoneyLootName)
			end
		end
	end)
	 
local LootChatMsg_EventFrame = CreateFrame("Frame")
LootChatMsg_EventFrame:RegisterEvent("CHAT_MSG_MONEY")
LootChatMsg_EventFrame:SetScript("OnEvent",
	function(self, event, ...)
		local arg1 = ...
		--Pick pocket money
		if(ppLootName ~= "") then
			UpdateLootMoney(ppLootName, event)
			ppLootName = ""
			PP_Print('ppLootName Reset')			
		end
		--Player pickpockets and immediately attacks
		--LOOT_OPENED event does not get triggered here for some reason and Player receives the pickpocket loot
		if(ppCasted == true and playerInCombat == true) then			
			--Get the money looted from the chat message
			local lootName = TrimForMoneyMessage(arg1)
			UpdateLootMoney(lootName, event)
			ppCasted = false -- Reset the flag for next pickpocketing
		end				
		--Junkbox money
		if(junkBoxModeLootName ~= "") then
			UpdateLootMoney(junkBoxModeLootName, event)
			junkBoxModeLootName = ""
			PP_Print('junkBoxModeLootName Reset')
		elseif(junkBoxItemClicked == true) then			
			UpdateLootMoney(OtherMoneyLootName, event)
			
			--Reset flags
			junkBoxItemClicked = false
			OtherMoneyLootName = ""
			PP_Print('junkBoxItemClicked Reset, OtherMoneyLootName Reset')
		elseif(OtherMoneyLootName ~= "") then
			OtherMoneyLootName = ""
			PP_Print('OtherMoneyLootName Reset')
		end
	end)
	
local ItemUnlocked_EventFrame = CreateFrame("Frame")
ItemUnlocked_EventFrame:RegisterEvent("ITEM_UNLOCKED")
ItemUnlocked_EventFrame:SetScript("OnEvent",
	function(self, event, ...)
		local arg1, arg2 = ...		
		local texture, itemCount, locked, quality, readable, lootable, itemHyperLink = GetContainerItemInfo(arg1, arg2)
		PP_Print('ITEM_UNLOCKED: ' .. itemHyperLink)
		if(OtherMoneyLootName ~= "" and string.find(itemHyperLink, "Junkbox") ~= nil) then			
			PP_Print('Junkbox item clicked after looting money')
			junkBoxItemClicked = true
		end
	end)

-- Functions --
	
function TrimForMoneyMessage(chatMsg)
	--String = You loot 15 Copper	>> Returns 15 Copper
	local moneyStr = string.sub(chatMsg, 10, -1)	
	return moneyStr
end

function ExtractGSCFromMoney(moneyLooted)
	--String = 1 Gold 2 Silver 3 Copper (each number can be 1 digit or 2 digits)
	--String = 10 Gold 2 Silver 30 Copper	
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
function UpdateLootMoney(money)
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
	
	DEFAULT_CHAT_FRAME:AddMessage('PickPocketMoney::Session:: ' .. GetCoinTextureString(currentSessionMoneyLooted))
	DEFAULT_CHAT_FRAME:AddMessage('PickPocketMoney::Total:: ' .. GetCoinTextureString(TotalMoneyLootedTillNowInCopper))
end

function ConvertToCopper(g, s, c)
	local totalCopperAmount = g*10000 + s*100 + c
	return totalCopperAmount
end

--Not used now since we are using GetCoinTextureString API which does everything and extra
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