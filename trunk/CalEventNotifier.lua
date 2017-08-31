local _, vars = ...;
local L = vars.L

--inviteStatus

--CALENDAR_INVITESTATUS_INVITED      = 1
--CALENDAR_INVITESTATUS_ACCEPTED     = 2
--CALENDAR_INVITESTATUS_DECLINED     = 3
--CALENDAR_INVITESTATUS_CONFIRMED    = 4
--CALENDAR_INVITESTATUS_OUT          = 5
--CALENDAR_INVITESTATUS_STANDBY      = 6
--CALENDAR_INVITESTATUS_SIGNEDUP     = 7
--CALENDAR_INVITESTATUS_NOT_SIGNEDUP = 8
--CALENDAR_INVITESTATUS_TENTATIVE    = 9


EventNotifies = {}
MsgToGuild = false
local debug = false
local GuildMembers = {}
local GuildNotifies = {}
local CommandQueue = {}
local addonLoaded = false
local todayCheck = true
local MyChar = ""
local MyRealm = ""
local iTimerCanStart = false
local checkTimers = false
local lastTime = 0
local lastGTime = 0
local fadeTime = 0
local fading = false
local elapsedTime = 0
local inCombat = false
local invitesInCombat = false
local iamInGuild = false
local guildMaster = false
local lastNotifyTimer = 0
local lastNotifySender = ""
local lastNotifyLeader = ""
local iCanSendToGuild = true
local iamSenderNow = false
local GuildMembersLoaded = false

local CEN_OFFLINE = string.format(ERR_FRIEND_OFFLINE_S, "(.+)")

local frame = CreateFrame("Frame")
frame:Hide();
frame:SetHeight(120)
frame:SetWidth(430)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
frame:EnableMouse(true)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = {
        left = 11,
        right = 12,
        top = 12,
        bottom = 11
    }
})

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
frame:RegisterEvent("CALENDAR_UPDATE_GUILD_EVENTS")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")


local font = frame:CreateFontString("NewInvite", "ARTWORK", "GameFontNormal")
font:SetPoint("TOP", frame, "TOP", 0, -20)
local font2 = frame:CreateFontString("NewEvent", "ARTWORK", "GameFontNormal")
font2:SetPoint("TOP", frame, "TOP", 0, -40)
local font3 = frame:CreateFontString("Reminder", "ARTWORK", "GameFontNormal")
font3:SetPoint("TOP", frame, "TOP", 0, -60)

function button_OnClick()
	GameTimeFrame_OnClick(GameTimeFrame)
	frame:Hide()
end

function okButton_OnClick(self)
	frame:Hide()
	self:Hide()
end

local button = CreateFrame("Button", "CalendarButton", frame, "UIPanelButtonTemplate")
button:SetHeight(25)
button:SetWidth(125)
button:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)
button:SetText(L["View"])
button:RegisterForClicks("AnyUp")
button:SetScript("OnClick", button_OnClick)

local okButton = CreateFrame("Button", "OkButton", frame, "UIPanelButtonTemplate")
okButton:SetHeight(25)
okButton:SetWidth(125)
okButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 15)
okButton:SetText(L["Ok"])
okButton:Hide()
okButton:RegisterForClicks("AnyUp")
okButton:SetScript("OnClick", okButton_OnClick)

local close = CreateFrame("Button", "CloseButton", frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)

local function DPrint(msg)
	if debug then
		print("|cFF99FF99CalEventNotifier_Debug:|r "..msg)
	end
end

local function CPrint(msg)
	print("|cFF99FF99CalEventNotifier:|r "..msg)
end

local function GuildMessage(msg)
	if iamInGuild then
		SendChatMessage("CalEventNotifier: "..msg, "GUILD")
	else
		CPrint("Yor aren't in a guild")
	end
end

local function AddonMessage(msg)
	if iamInGuild then
		SendAddonMessage("DMD_CEN", msg, "GUILD")
	else
		CPrint("Yor aren't in a guild")
	end
end

local function GetGuildMemberIdx(gName, gArray)
	local gIndex, i = 0

	i = table.maxn(gArray)
	if (i == 0) then
		return 0
	end

	for gIndex = 1, i do
		if (gArray[gIndex].Name == gName) then
			return gIndex
		end
	end

	return 0
end

local function CreateGuildMembers(gArray)
	local maxMembers, i = 0
	local sName, memberName, memberRealm

	if iamInGuild then
		maxMembers = GetNumGuildMembers()

		if (maxMembers ~= nil) and (maxMembers > 1) then
			for i = 1, maxMembers do
				memberName = GetGuildRosterInfo(i)
				sName, memberRealm = strsplit("-", memberName, 2)
				if not memberRealm then
					memberName = sName.."-"..string.gsub(MyRealm, " ", "")
				end

				table.insert(gArray, {Name = memberName})
				DPrint("Insert Guild Member: "..memberName)
			end

			-- We need more than one member in a guild. Otherwise no messages would be send.
			if (i ~= nil) and (i > 1) then
				GuildMembersLoaded = true
			end
		end
	end
end

local function GetShortName(cName)
	local sMember, mRealm = strsplit("-", cName, 2)

	return sMember
end

local function GetOwnCharIndex(cName, cArray)
	local cIndex, i = 0

	i = table.maxn(cArray)
	if (i == 0) then
		return 0
	end

	for cIndex = 1, i do
		if (cArray[cIndex].Name == cName) then
			return cIndex
		end
	end

	return 0
end

local function InitGuildNotifies(gArray)
	while (table.maxn(gArray) > 0) do
		table.remove(gArray)
	end
end

local function AddGuildNotify(gArray, aTitle, aYear, aMonth, aDay, aHour, aMin)
	local CalendarTimeStamp = time({year = aYear, month = aMonth, day = aDay, hour = aHour, min = aMin})
	local CalendarAlarmTime = CalendarTimeStamp - (15 * 60) -- 15 Min.

	table.insert(gArray, {EventTitle = aTitle, CalendarTime = CalendarTimeStamp, CalendarAlarm = CalendarAlarmTime})
end

local function InitNotifies(cName, cArray)
	local cIndex = GetOwnCharIndex(cName, cArray)

	if (cIndex == 0) then
		table.insert(cArray, {Name = cName})
		cIndex = GetOwnCharIndex(cName, cArray)
		cArray[cIndex][cArray[cIndex].Name] = {}
	else
		table.remove(cArray, cIndex)
		table.insert(cArray, {Name = cName})
		cIndex = GetOwnCharIndex(cName, cArray)
		cArray[cIndex][cArray[cIndex].Name] = {}
	end
end

local function InsertNotifies(cName, cArray, aTitle, aYear, aMonth, aDay, aHour, aMin)
	local cIndex = GetOwnCharIndex(cName, cArray)
	local CalendarTimeStamp = time({year = aYear, month = aMonth, day = aDay, hour = aHour, min = aMin})
	local CalendarAlarmTime = CalendarTimeStamp - (15 * 60) -- 15 Min.

	if (cIndex == 0) then
		table.insert(cArray, {Name = cName})
		cIndex = GetOwnCharIndex(cName, cArray)
		cArray[cIndex][cArray[cIndex].Name] = {}
	end

	if (cIndex > 0) then
		table.insert(cArray[cIndex][cArray[cIndex].Name], {EventTitle = aTitle, CalendarTime = CalendarTimeStamp, CalendarAlarm = CalendarAlarmTime})
	end
end

function checkRemovedEvents()
	local tmpStr = ""
	local tmpStrLen = 0

	tmpStr = font3:GetText()
	if tmpStr ~= nil then
		tmpStrLen = tmpStrLen + string.len(tmpStr)
	end
	tmpStr = font:GetText()
	if tmpStr ~= nil then
		tmpStrLen = tmpStrLen + string.len(tmpStr)
	end
	tmpStr = font2:GetText()
	if tmpStr ~= nil then
		tmpStrLen = tmpStrLen + string.len(tmpStr)
	end

	if (tmpStrLen == 0) then
		font2:SetText(L["EventRemoved"])
	end
end

local function CheckToday()
	local curweekday, curmonth, curday, curyear = CalendarGetDate()
	local numtodaysEvents = CalendarGetNumDayEvents(0, curday)
	local todaysevents = 0

	MyChar = UnitName("player")
	MyRealm = GetRealmName()
	MyChar = MyChar.."-"..MyRealm
	font3:SetText("")
	iTimerCanStart = false
	InitNotifies(MyChar, EventNotifies)
	InitGuildNotifies(GuildNotifies)

	if numtodaysEvents ~= 0 then
		for i = 1, numtodaysEvents do
			local title3, hour3, minute3, calendarType3, _, _, _, _, inviteStatus3, invitedBy3 = CalendarGetDayEvent(0, curday, i)
			if calendarType3 == "PLAYER" or calendarType3 == "GUILD_EVENT" then
				if inviteStatus3 ~= 8 and inviteStatus3 ~= 3 and inviteStatus3 ~= 5 then
					InsertNotifies(MyChar, EventNotifies, title3, curyear, curmonth, curday, hour3, minute3)
					todaysevents = todaysevents + 1
					if (todaysevents > 1) then
						font3:SetText(string.format(L["Scheduled Events"], todaysevents ))
					elseif (todaysevents == 1) then
						font3:SetText(L["Scheduled Event"])
					end

					checkRemovedEvents()

					if not frame:IsShown() then
						button:Show()
						frame:Show()
					end
				end
			end

			if (calendarType3 == "GUILD_EVENT") then
				AddGuildNotify(GuildNotifies, title3, curyear, curmonth, curday, hour3, minute3)
			end
		end
	end
	if CalendarFrame and CalendarFrame:IsShown() then
		frame:Hide()
	end

	if frame:IsShown() then
		checkRemovedEvents()
	end

	iTimerCanStart = true
end

local function GetInvites()
	local MyPendingInvites = CalendarGetNumPendingInvites()
	local tmpStr = ""
	local tmpStrLen = 0

	font:SetText("")
	if MyPendingInvites ~= 0 then
		if (MyPendingInvites > 1) then
			font:SetText(string.format(L["Pending Invites"], MyPendingInvites))
		elseif (MyPendingInvites == 1) then
			font:SetText(L["Pending Invite"])
		end

		checkRemovedEvents()

		if not frame:IsShown() then
			button:Show()
			frame:Show()
		end
	end
	if CalendarFrame and CalendarFrame:IsShown() then
		frame:Hide()
	end

	if frame:IsShown() then
		checkRemovedEvents()
	end
end

local function ReInitNotifies(cArray)
	while (table.maxn(cArray) > 0) do
		table.remove(cArray)
	end

	CPrint(L["ResetFinish"])
	CheckToday()
end

local function GetCmdIndex(qCmd, qArray)
	local qIndex, i = 0

	i = table.maxn(qArray)
	if (i == 0) then
		return 0
	end

	for qIndex = 1, i do
		if (qArray[qIndex] == qCmd) then
			return qIndex
		end
	end

	return 0
end

local function AddCommand(qCmd, qArray)
	local qIndex = GetCmdIndex(qCmd, qArray)

	if (qIndex == 0) then
		table.insert(qArray, qCmd)
	end
end

local function checkDoubleEvents(xTitle, xDay, xMonthOffset, xHour, xMin, tmpTable)
	local cIndex, i = 0

	i = table.maxn(tmpTable)

	if (i == 0) then
		table.insert(tmpTable, {Title = xTitle, Day = xDay, MonthOffset = xMonthOffset, Hour = xHour, Min = xMin})
		return false
	else
		for cIndex = 1, i do
			if (tmpTable[cIndex].Title == xTitle) and (tmpTable[cIndex].Day == xDay) and
			   (tmpTable[cIndex].MonthOffset == xMonthOffset) and
			   (tmpTable[cIndex].Hour == xHour) and (tmpTable[cIndex].Min == xMin) then
				return true
			end
		end

		table.insert(tmpTable, {Title = xTitle, Day = xDay, MonthOffset = xMonthOffset, Hour = xHour, Min = xMin})
		return false
	end
end

local function GetGuildEvents()
	local pendinginvites = 0
	local numguildEvents = CalendarGetNumGuildEvents()
	local tmpTable = {}
	local currentweekday, currentmonth, currentday, currentyear = CalendarGetDate()
	local tmpStr = ""
	local tmpStrLen = 0

	font2:SetText("")
	for eventIndex = 1, numguildEvents do

		local month, day, weekday, hour, minute, eventType, title, calendarType, textureName = CalendarGetGuildEventInfo(eventIndex)
		local monthOffset = month - currentmonth
		local numEvents = CalendarGetNumDayEvents(monthOffset, day)

		if numEvents ~= 0 then
			for i = 1, numEvents do
			local title2, hour2, minute2, calendarType2, _, _, _, _, inviteStatus, invitedBy = CalendarGetDayEvent(monthOffset, day, i)
				if (inviteStatus == 8) and (calendarType2 == "GUILD_EVENT") and not checkDoubleEvents(title2, day, monthOffset, hour2, minute2, tmpTable) then
					pendinginvites = pendinginvites + 1
					if (pendinginvites > 1) then
						font2:SetText(string.format(L["GuildEvents"], pendinginvites))
					elseif (pendinginvites == 1) then
						font2:SetText(L["GuildEvent"])
					end

					checkRemovedEvents()

					if not frame:IsShown() then
						button:Show()
						frame:Show()
					end
				end
			end
		end
	end
	if CalendarFrame and CalendarFrame:IsShown() then
		frame:Hide()
	end

	if frame:IsShown() then
		checkRemovedEvents()
	end
end

local function toggleMsgToGuild()
	if iamInGuild then
		MsgToGuild = not MsgToGuild
		if MsgToGuild then
			CPrint(L["MsgToGuild"])
			if guildMaster then
				AddonMessage("IAMLEADER-0001")
				iCanSendToGuild = true
			else
				AddonMessage("IFLEADERON-0001")
			end
		else
			CPrint(L["NoMsgToGuild"])
			if guildMaster or iamSenderNow then
				AddonMessage("NOMSGTOGUILD-0001")
				iamSenderNow = false
			end
		end
	else
		CPrint(L["NoGuild"])
	end
end

local function initCEN()
	iamInGuild = IsInGuild()
	MyChar = UnitName("player")
	MyRealm = GetRealmName()
	MyChar = MyChar.."-"..MyRealm

	if iamInGuild then
		CPrint(L["InGuild"])
		guildMaster = IsGuildLeader()
		if guildMaster then
			CPrint(L["GuildLeader"])
		end

		CreateGuildMembers(GuildMembers)
		if MsgToGuild then
			CPrint(L["MsgToGuild"])
			if guildMaster then
				AddonMessage("IAMLEADER-0001")
			else
				AddonMessage("IFLEADERON-0001")
			end
		end
	else
		CPrint(L["NoGuild"])
	end
end

local function eventHandler(self, event, ...)
	if event == "ADDON_LOADED" then
		local arg1 = ...;
		if arg1 == "CalEventNotifier" then
			addonLoaded = true
			CPrint(L["Loaded"])
			CPrint(L["EnterCommands"])

			if not todayCheck then
				initCEN()
				CheckToday()
			end
		end
	elseif event == "CHAT_MSG_ADDON" then
		local prefix, msg, channel, sender = ...;
		local absRealm, msgID, msgValue, tmpSender

		if (prefix == "DMD_CEN") and (iamInGuild) then
			sender, absRealm = strsplit("-", sender, 2)
			msgID, msgValue = strsplit("-", msg, 2)

			if (sender ~= GetShortName(MyChar)) then
				-- CPrint Should be removed or changed to DPrint
				DPrint("Other - msgID: "..msgID.." msgValue: "..msgValue)
				if (msgID == "NOTIFYTIME") then
					lastNotifySender = sender.."-"..string.gsub(MyRealm, " ", "")
					lastNotifyTimer = msgValue
					iCanSendToGuild = false
					iamSenderNow = false
				elseif (msgID == "IFLEADERON") then
					if guildMaster and MsgToGuild then
						AddonMessage("IAMLEADER-0001")
					elseif iamSenderNow and MsgToGuild then
						AddonMessage("IAMSENDERNOW-0001")
					end
				elseif (msgID == "IAMLEADER") then
					lastNotifyLeader = sender.."-"..string.gsub(MyRealm, " ", "")

					-- I am a guild master
					if guildMaster then
						iCanSendToGuild = true
					else
						iCanSendToGuild = false
						iamSenderNow = false
					end
				elseif (msgID == "IAMSENDERNOW") then
					lastNotifySender = sender.."-"..string.gsub(MyRealm, " ", "")
					iCanSendToGuild = false
					iamSenderNow = false
				elseif (msgID == "NOMSGTOGUILD") then
					tmpSender = sender.."-"..string.gsub(MyRealm, " ", "")
					if (tmpSender == lastNotifySender) or (tmpSender == lastNotifyLeader) then
						lastNotifySender = ""
						lastNotifyTimer = 0
						iCanSendToGuild = true
					end
				end
			else
				-- CPrint Should be removed or changed to DPrint
				DPrint("Self - msgID: "..msgID.." msgValue: "..msgValue)
				if (msgID == "NOTIFYTIME") then
					iCanSendToGuild = true
					iamSenderNow = true
				end
			end
		end
	elseif event == "CHAT_MSG_SYSTEM" then
		local sArg1 = ...;
		if (sArg1 ~= nil) and (iamInGuild) then
			local _, _, gMember = string.find(sArg1, CEN_OFFLINE)
			if (gMember ~= "") and (gMember ~= nil) then
				local sMember, mRealm = strsplit("-", gMember, 2)
				if not mRealm then
					gMember = sMember.."-"..string.gsub(MyRealm, " ", "")
				end

				DPrint("CHAT_MSG_SYSTEM: "..gMember)

				if not GuildMembersLoaded then
					CreateGuildMembers(GuildMembers)
				end

				if (GetGuildMemberIdx(gMember, GuildMembers) > 0) then
					DPrint("GuildMemberIdx: "..GetGuildMemberIdx(gMember, GuildMembers))
					DPrint("LastNotifyLeader: "..lastNotifyLeader)
					DPrint("LastNotifySender: "..lastNotifySender)
					if (gMember == lastNotifySender) then
						lastNotifySender = ""
						lastNotifyTimer = 0
						iCanSendToGuild = true
						DPrint("Sender ist offline")
					elseif (gMember == lastNotifyLeader) then
						lastNotifyLeader = ""
						lastNotifySender = ""
						lastNotifyTimer = 0
						iCanSendToGuild = true
						DPrint("Leader ist offline")
					end
				end
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		local _, todaysmonth, _, todaysyear = CalendarGetDate()
		CalendarSetAbsMonth(todaysmonth, todaysyear)
		OpenCalendar()
		GetInvites()
		GetGuildEvents()

		if addonLoaded then
			initCEN()
			CheckToday()
		else
			todayCheck = false
		end
		frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
	elseif event == "CALENDAR_UPDATE_PENDING_INVITES" or event == "CALENDAR_UPDATE_GUILD_EVENTS" or event == "CALENDAR_UPDATE_EVENT_LIST" then
		if (not inCombat) and (not checkTimers) then
			GetInvites()
			GetGuildEvents()

			if addonLoaded then
				CheckToday()
			else
				todayCheck = false
			end
		else
			invitesInCombat = true
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
	end
end

if not RegisterAddonMessagePrefix("DMD_CEN") then
	CPrint("Error: unable to register CEN addon message prefix (reached client side addon message filter limit), synchronization with guild will be unavailable")
end

frame:SetScript("OnEvent", eventHandler)

local textFrame = CreateFrame("Frame")
textFrame:SetAlpha(0)
textFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 250)
textFrame:SetHeight(30)
textFrame:SetWidth(600)

local tFont = textFrame:CreateFontString("NotifyMsg", "ARTWORK", "GameFontNormal")
tFont:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
tFont:SetPoint("TOP", textFrame, "TOP", 0, -20)

local notifyTimer = CreateFrame("Frame")
notifyTimer:SetScript("OnUpdate", function (self, elapsed)
	local i, i2, cInd
	local cAnz = 0
	local cNotifies = 0
	local twNotifies = 0
	local currTime = 0
	local cIndex = 0
	local leftTime = 0
	local qCommand = ""
	local tmpStr = ""
	local oneNotify = false

	if fading and (fadeTime > 0) then
		currTime = time()

		if (currTime >= fadeTime) then
			fadeTime = 0
			fading = false
			UIFrameFadeOut(textFrame, 3, 1, 0)
		end
	end

	elapsedTime = elapsedTime + elapsed

	if (elapsedTime < 60) then
		return
	else
		elapsedTime = 0
	end

	if invitesInCombat and not inCombat then
		GetInvites()
		GetGuildEvents()
		CheckToday()
		invitesInCombat = false
	end

	-- Read CommandQueue at first
	while (table.maxn(CommandQueue)) > 0 do
		qCommand = table.remove(CommandQueue)
		if (qCommand == "RESET") then
			ReInitNotifies(EventNotifies)
		end
	end

	if iTimerCanStart and not checkTimers then
		checkTimers = true
		cAnz = table.maxn(EventNotifies)

		if (cAnz > 0) then
			currTime = time()
			cIndex = GetOwnCharIndex (MyChar, EventNotifies)

			if (cIndex > 0) then
				cNotifies = table.maxn(EventNotifies[cIndex][EventNotifies[cIndex].Name])

				if (cNotifies > 0) then
					for i = 1, cNotifies do
						if (currTime >= EventNotifies[cIndex][EventNotifies[cIndex].Name][i].CalendarAlarm) and
						   (currTime <= EventNotifies[cIndex][EventNotifies[cIndex].Name][i].CalendarTime) then

							oneNotify = true

							if (lastTime == 0) then
								lastTime = currTime + 180
								leftTime = math.modf((EventNotifies[cIndex][EventNotifies[cIndex].Name][i].CalendarTime - currTime) / 60)
								if ((leftTime >= 3) and not fading) or ((leftTime >= 0) and inCombat and not fading) then
									fadeTime = currTime + 15
									fading = true
									tFont:SetText(string.format(L["TxtEventStartsSoon"], EventNotifies[cIndex].Name,
																EventNotifies[cIndex][EventNotifies[cIndex].Name][i].EventTitle, leftTime))
									UIFrameFadeIn(textFrame, 3, 0, 1)
								elseif (leftTime >= 0) and not inCombat then
									font:SetText(string.format(L["DlgEventStartsSoon"], EventNotifies[cIndex][EventNotifies[cIndex].Name][i].EventTitle, leftTime))
									font2:SetText("")
									font3:SetText("")
									button:Show()
									frame:Show()
									PlaySound(12889) --AlarmClockwarning3
									if CalendarFrame and CalendarFrame:IsVisible() then
										frame:Hide()
									end
								end
							elseif (currTime >= lastTime) then
								lastTime = 0
							end

							break -- Only the first found timestamp would be used. You can't participate at more than one event at the same time (+/- 15 Minutes)
						end
					end

					if not oneNotify then
						for cInd = 1, cAnz do
							if (cInd ~= cIndex) then
								twNotifies = table.maxn(EventNotifies[cInd][EventNotifies[cInd].Name])

								if (twNotifies > 0) then
									for i2 = 1, twNotifies do
										if (currTime >= EventNotifies[cInd][EventNotifies[cInd].Name][i2].CalendarAlarm) and
										   (currTime <= EventNotifies[cInd][EventNotifies[cInd].Name][i2].CalendarTime) then

											oneNotify = true

											if (lastTime == 0) then
												lastTime = currTime + 180
												leftTime = math.modf((EventNotifies[cInd][EventNotifies[cInd].Name][i2].CalendarTime - currTime) / 60)
												if ((leftTime >= 3) and not fading) or ((leftTime >= 0) and inCombat and not fading) then
													fadeTime = currTime + 15
													fading = true
													tFont:SetText(string.format(L["TxtEventStartsSoon"], EventNotifies[cInd].Name,
																				EventNotifies[cInd][EventNotifies[cInd].Name][i2].EventTitle, leftTime))
													UIFrameFadeIn(textFrame, 3, 0, 1)
												elseif (leftTime >= 0) and not inCombat then
													font:SetText(string.format(L["Dlg2EventStartsSoon"], GetShortName(EventNotifies[cInd].Name),
																			   EventNotifies[cInd][EventNotifies[cInd].Name][i2].EventTitle, leftTime))
													font2:SetText("")
													font3:SetText("")
													button:Hide()
													okButton:Show()
													frame:Show()
													PlaySound(12889) --AlarmClockwarning3
												end
											elseif (currTime >= lastTime) then
												lastTime = 0
											end

											break -- Only the first found timestamp would be used. You can't participate at more than one event at the same time (+/- 15 Minutes)
										end
									end
								end
							end

							if oneNotify then
								break
							end
						end
					end
				else
					for cInd = 1, cAnz do
						if (cInd ~= cIndex) then
							twNotifies = table.maxn(EventNotifies[cInd][EventNotifies[cInd].Name])

							if (twNotifies > 0) then
								for i2 = 1, twNotifies do
									if (currTime >= EventNotifies[cInd][EventNotifies[cInd].Name][i2].CalendarAlarm) and
										(currTime <= EventNotifies[cInd][EventNotifies[cInd].Name][i2].CalendarTime) then

										oneNotify = true

										if (lastTime == 0) then
											lastTime = currTime + 180
											leftTime = math.modf((EventNotifies[cInd][EventNotifies[cInd].Name][i2].CalendarTime - currTime) / 60)
											if ((leftTime >= 3) and not fading) or ((leftTime >= 0) and inCombat and not fading) then
												fadeTime = currTime + 15
												fading = true
												tFont:SetText(string.format(L["TxtEventStartsSoon"], EventNotifies[cInd].Name,
																			EventNotifies[cInd][EventNotifies[cInd].Name][i2].EventTitle, leftTime))
												UIFrameFadeIn(textFrame, 3, 0, 1)
											elseif (leftTime >= 0) and not inCombat then
												font:SetText(string.format(L["Dlg2EventStartsSoon"], GetShortName(EventNotifies[cInd].Name),
																			EventNotifies[cInd][EventNotifies[cInd].Name][i2].EventTitle, leftTime))
												font2:SetText("")
												font3:SetText("")
												button:Hide()
												okButton:Show()
												frame:Show()
												PlaySound(12889) --AlarmClockwarning3
											end
										elseif (currTime >= lastTime) then
											lastTime = 0
										end

										break -- Only the first found timestamp would be used. You can't participate at more than one event at the same time (+/- 15 Minutes)
									end
								end
							end
						end

						if oneNotify then
							break
						end
					end
				end
			else
				for cInd = 1, cAnz do
					twNotifies = table.maxn(EventNotifies[cInd][EventNotifies[cInd].Name])

					if (twNotifies > 0) then
						for i2 = 1, twNotifies do
							if (currTime >= EventNotifies[cInd][EventNotifies[cInd].Name][i2].CalendarAlarm) and
								(currTime <= EventNotifies[cInd][EventNotifies[cInd].Name][i2].CalendarTime) then

								oneNotify = true

								if (lastTime == 0) then
									lastTime = currTime + 180
									leftTime = math.modf((EventNotifies[cInd][EventNotifies[cInd].Name][i2].CalendarTime - currTime) / 60)
									if ((leftTime >= 3) and not fading) or ((leftTime >= 0) and inCombat and not fading) then
										fadeTime = currTime + 15
										fading = true
										tFont:SetText(string.format(L["TxtEventStartsSoon"], EventNotifies[cInd].Name,
																	EventNotifies[cInd][EventNotifies[cInd].Name][i2].EventTitle, leftTime))
										UIFrameFadeIn(textFrame, 3, 0, 1)
									elseif (leftTime >= 0) and not inCombat then
										font:SetText(string.format(L["Dlg2EventStartsSoon"], GetShortName(EventNotifies[cInd].Name),
																   EventNotifies[cInd][EventNotifies[cInd].Name][i2].EventTitle, leftTime))
										font2:SetText("")
										font3:SetText("")
										button:Hide()
										okButton:Show()
										frame:Show()
										PlaySound(12889) --AlarmClockwarning3
									end
								elseif (currTime >= lastTime) then
									lastTime = 0
								end

								break -- Only the first found timestamp would be used. You can't participate at more than one event at the same time (+/- 15 Minutes)
							end
						end
					end

					if oneNotify then
						break
					end
				end
			end
		end

		if iCanSendToGuild and MsgToGuild then
			cAnz = table.maxn(GuildNotifies)
			if (cAnz > 0) then
				currTime = time()
				if (lastGTime == 0) then
					lastGTime = currTime + 180
					for i = 1, cAnz do
						if (currTime >= GuildNotifies[i].CalendarAlarm) and
							(currTime <= GuildNotifies[i].CalendarTime) then
							leftTime = math.modf((GuildNotifies[i].CalendarTime - currTime) / 60)
							if (leftTime >= 0) and (lastNotifyTimer ~= GuildNotifies[i].CalendarTime) then
								AddonMessage(string.format("NOTIFYTIME-%d", GuildNotifies[i].CalendarTime))
								GuildMessage(string.format(L["DlgEventStartsSoon"], GuildNotifies[i].EventTitle, leftTime))
								iamSenderNow = true
							end
						end
					end
				elseif (currTime >= lastGTime) then
					lastGTime = 0
				end
			end
		end

		checkTimers = false
	end
end)

local function HelpCmds()
	print(" ")
	CPrint(L["HelpHeader"])
	CPrint(L["HelpSendMsg"])
	CPrint(L["HelpReset"])
	print(" ")
end

local function SlashHandler(arg)
	if ((arg ~= "") and (arg ~= nil)) then
		if (arg:lower() == "sendmsg") then
			toggleMsgToGuild()
		elseif (arg:lower() == "reset") then
			if checkTimers then
				AddCommand("RESET", CommandQueue)
				CPrint(L["Queued"])
			else
				iTimerCanStart = false
				ReInitNotifies(EventNotifies)
			end
		else
			HelpCmds()
		end
	else
		HelpCmds()
	end
end

SlashCmdList["CalEventNotifier"] = SlashHandler
SLASH_CalEventNotifier1 = "/cen"
