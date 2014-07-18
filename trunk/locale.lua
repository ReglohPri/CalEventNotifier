local _, vars = ...;
local Ld, La = {}, {}
local locale = GetLocale()

vars.L = setmetatable({},{
    __index = function(t, s) return La[s] or Ld[s] or rawget(t,s) or s end
})

-- Ld means default (english) if no translation found. So we don't need a translation for "enUS" or "enGB".
Ld["View"] = "View"
Ld["Ok"] = "OK"
Ld["Scheduled Event"] = "Today you have a upcoming event."
Ld["Scheduled Events"] = "Today you have %s upcoming events."
Ld["Pending Invite"] = "You have a pending invitation to an event!"
Ld["Pending Invites"] = "You have %s pending invites to an event!"
Ld["GuildEvent"] = "You have an pending guild event!"
Ld["GuildEvents"] = "You have %s pending guild events!"
Ld["TxtEventStartsSoon"] = "|cFFFF0000%s: |cff00E5EE%s |rstarts in |cff00E5EE%d |rminutes"
Ld["DlgEventStartsSoon"] = "%s starts in %d rminutes"
Ld["Dlg2EventStartsSoon"] = "|cFFFF0000%s: |r%s starts in %d rminutes"
Ld["EventRemoved"] = "It was probably removed an event."

if locale == "deDE" then do end
	La["View"] = "Zeigen"
	La["Ok"] = "OK"
	La["Scheduled Event"] = "Du hast heute eine geplante Veranstaltung."
	La["Scheduled Events"] = "Du hast heute %s geplante Veranstaltungen."
	La["Pending Invite"] = "Du hast eine ausstehende Einladung zu einer Veranstaltung!"
	La["Pending Invites"] = "Du hast %s ausstehende Einladungen zu einer Veranstaltung!"
	La["GuildEvent"] = "Du hast eine ausstehende Gildenveranstaltung!"
	La["GuildEvents"] = "Du hast %s ausstehende Gildenveranstaltungen!"
	La["TxtEventStartsSoon"] = "|cFFFF0000%s: |cff00E5EE%s |rbeginnt in |cff00E5EE%d |rMinuten"
	La["DlgEventStartsSoon"] = "%s beginnt in %d Minuten"
	La["Dlg2EventStartsSoon"] = "|cFFFF0000%s: |r%s beginnt in %d Minuten"
	La["EventRemoved"] = "Es wurde vermutlich eine Veranstaltung entfernt."
elseif locale == "frFR" then do end
	La["View"] = "Voir"
	La["Ok"] = "OK"
	La["Scheduled Event"] = "Aujourd\'hui, vous avez un \195\169v\195\169nement pr\195\169vu."
	La["Scheduled Events"] = "Vous avez %s \195\169v\195\169nements pr\195\169vus aujourd\'hui."
	La["Pending Invite"] = "Vous avez une invitation en attente d\'un \195\169v\195\169nement!"
	La["Pending Invites"] = "Vous avez %s invitations en attente d\'un \195\169v\195\169nement!"
	La["GuildEvent"] = "Vous avez un \195\169v\195\169nement de guilde exceptionnel!"
	La["GuildEvents"] = "Vous avez %s \195\169v\195\169nements les plus marquants de la guilde!"
	La["TxtEventStartsSoon"] = "|cFFFF0000 %s:|cff00E5EE%s |rcommence en |cff00E5EE%d |rminutes"
	La["DlgEventStartsSoon"] = "%s commence en %d minutes"
	La["Dlg2EventStartsSoon"] = "|cFFFF0000%s: |r%s commence en %d minutes"
	La["EventRemoved"] = "Il a \195\169t\195\169 probablement enlev\195\169 un \195\169v\195\169nement."
end