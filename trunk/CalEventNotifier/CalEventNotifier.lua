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
local addonLoaded = false
local todayCheck = true
local MyChar = ""
local iTimerCanStart = false
local checkTimers = false
local lastTime = 0
local fadeTime = 0
local fading = false
local elapsedTime = 0

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
frame:RegisterEvent("CALENDAR_UPDATE_PENDING_INVITES")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
frame:RegisterEvent("CALENDAR_UPDATE_GUILD_EVENTS")


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

local function CheckToday()
local curweekday, curmonth, curday, curyear = CalendarGetDate()
local numtodaysEvents = CalendarGetNumDayEvents(0, curday)
local todaysevents = 0
	MyChar = UnitName("player")
	font3:SetText("")
	iTimerCanStart = false
	InitNotifies(MyChar, EventNotifies)
	if numtodaysEvents ~= 0 then
		for i = 1, numtodaysEvents do
			local title3, hour3, minute3, calendarType3, _, _, _, _, inviteStatus3, invitedBy3 = CalendarGetDayEvent(0, curday, i)
			if calendarType3 == "PLAYER" or calendarType3 == "GUILD_EVENT" then
				if inviteStatus3 ~= 8 and inviteStatus3 ~= 3 and inviteStatus3 ~= 5 then
					InsertNotifies(MyChar, EventNotifies, title3, curyear, curmonth, curday, hour3, minute3)
					todaysevents = todaysevents + 1
					if todaysevents > 1 then
						font3:SetText(string.format(L["Scheduled Events"], todaysevents ))
					else
						font3:SetText(L["Scheduled Event"])
					end
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

	iTimerCanStart = true
end

local function GetInvites()
	local MyPendingInvites = CalendarGetNumPendingInvites()

	font:SetText("")
	if MyPendingInvites ~= 0 then
		if MyPendingInvites > 1 then
			font:SetText(string.format(L["Pending Invites"], MyPendingInvites))
		else
			font:SetText(L["Pending Invite"])
		end
		if not frame:IsShown() then
			button:Show()
			frame:Show()
		end
	end
	if CalendarFrame and CalendarFrame:IsShown() then
		frame:Hide()
	end
end

local function checkDoubleEvents(xTitle, xHour, xMin, tmpTable)
	local cIndex, i = 0

	i = table.maxn(tmpTable)

	if (i == 0) then
		table.insert(tmpTable, {Title = xTitle, Hour = xHour, Min = xMin})
		return false
	else
		for cIndex = 1, i do
			if (tmpTable[cIndex].Title == xTitle) and (tmpTable[cIndex].Hour == xHour) and (tmpTable[cIndex].Min == xMin) then
				return true
			end
		end

		table.insert(tmpTable, {Title = xTitle, Hour = xHour, Min = xMin})
		return false
	end
end

local function GetGuildEvents()
	local pendinginvites = 0
	local numguildEvents = CalendarGetNumGuildEvents()
	local tmpTable = {}
	local currentweekday, currentmonth, currentday, currentyear = CalendarGetDate()

	font2:SetText("")
	for eventIndex = 1, numguildEvents do

		local month, day, weekday, hour, minute, eventType, title, calendarType, textureName = CalendarGetGuildEventInfo(eventIndex)
		local monthOffset = month - currentmonth
		local numEvents = CalendarGetNumDayEvents(monthOffset, day)

		if numEvents ~= 0 then
			for i = 1, numEvents do
			local title2, hour2, minute2, calendarType2, _, _, _, _, inviteStatus, invitedBy = CalendarGetDayEvent(monthOffset, day, i)
				if (inviteStatus == 8) and (calendarType2 == "GUILD_EVENT") and not checkDoubleEvents(title2, hour2, minute, tmpTable) then
					pendinginvites = pendinginvites + 1
					if pendinginvites > 1 then
						font2:SetText(string.format(L["GuildEvents"], pendinginvites))
					else
						font2:SetText(L["GuildEvent"])
					end
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
end

local function eventHandler(self, event, ...)
	if event == "ADDON_LOADED" then
		local arg1 = ...;
		if arg1 == "CalEventNotifier" then
			addonLoaded = true
			print("CalEventNotifier: loaded: ")
			if not todayCheck then
				CheckToday()
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		local _, todaysmonth, _, todaysyear = CalendarGetDate()
		CalendarSetAbsMonth(todaysmonth, todaysyear)
		OpenCalendar()
		GetInvites()
		GetGuildEvents()

		if addonLoaded then
			CheckToday()
		else
			todayCheck = false
		end
		frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
	elseif event == "CALENDAR_UPDATE_PENDING_INVITES" or event == "CALENDAR_UPDATE_GUILD_EVENTS" or event == "CALENDAR_UPDATE_EVENT_LIST" then
		GetInvites()
		GetGuildEvents()

		if addonLoaded then
			CheckToday()
		else
			todayCheck = false
		end
	end
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
								if (leftTime >= 3) and not fading then
									fadeTime = currTime + 15
									fading = true
									tFont:SetText(string.format(L["TxtEventStartsSoon"], EventNotifies[cIndex].Name,
																EventNotifies[cIndex][EventNotifies[cIndex].Name][i].EventTitle, leftTime))
									UIFrameFadeIn(textFrame, 3, 0, 1)
								elseif (leftTime >= 0) then
									font:SetText(string.format(L["DlgEventStartsSoon"], EventNotifies[cIndex][EventNotifies[cIndex].Name][i].EventTitle, leftTime))
									font2:SetText("")
									font3:SetText("")
									button:Show()
									frame:Show()
									PlaySound("AlarmClockwarning3")
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
												if (leftTime >= 3) and not fading then
													fadeTime = currTime + 15
													fading = true
													tFont:SetText(string.format(L["TxtEventStartsSoon"], EventNotifies[cInd].Name,
																				EventNotifies[cInd][EventNotifies[cInd].Name][i2].EventTitle, leftTime))
													UIFrameFadeIn(textFrame, 3, 0, 1)
												elseif (leftTime >= 0) then
													font:SetText(string.format(L["Dlg2EventStartsSoon"], EventNotifies[cInd].Name,
																			   EventNotifies[cInd][EventNotifies[cInd].Name][i2].EventTitle, leftTime))
													font2:SetText("")
													font3:SetText("")
													button:Hide()
													okButton:Show()
													frame:Show()
													PlaySound("AlarmClockwarning3")
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
											if (leftTime >= 3) and not fading then
												fadeTime = currTime + 15
												fading = true
												tFont:SetText(string.format(L["TxtEventStartsSoon"], EventNotifies[cInd].Name,
																			EventNotifies[cInd][EventNotifies[cInd].Name][i2].EventTitle, leftTime))
												UIFrameFadeIn(textFrame, 3, 0, 1)
											elseif (leftTime >= 0) then
												font:SetText(string.format(L["Dlg2EventStartsSoon"], EventNotifies[cInd].Name,
																			EventNotifies[cInd][EventNotifies[cInd].Name][i2].EventTitle, leftTime))
												font2:SetText("")
												font3:SetText("")
												button:Hide()
												okButton:Show()
												frame:Show()
												PlaySound("AlarmClockwarning3")
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
									if (leftTime >= 3) and not fading then
										fadeTime = currTime + 15
										fading = true
										tFont:SetText(string.format(L["TxtEventStartsSoon"], EventNotifies[cInd].Name,
																	EventNotifies[cInd][EventNotifies[cInd].Name][i2].EventTitle, leftTime))
										UIFrameFadeIn(textFrame, 3, 0, 1)
									elseif (leftTime >= 0) then
										font:SetText(string.format(L["Dlg2EventStartsSoon"], EventNotifies[cInd].Name,
																   EventNotifies[cInd][EventNotifies[cInd].Name][i2].EventTitle, leftTime))
										font2:SetText("")
										font3:SetText("")
										button:Hide()
										okButton:Show()
										frame:Show()
										PlaySound("AlarmClockwarning3")
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

		checkTimers = false
	end
end)

