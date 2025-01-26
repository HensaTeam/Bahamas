-----------------------------------------------------------------------------------------------------------------------------------------
-- VRP
-----------------------------------------------------------------------------------------------------------------------------------------
local Proxy = module("lib/Proxy")
local Tunnel = module("lib/Tunnel")
vRPC = Tunnel.getInterface("vRP")
-----------------------------------------------------------------------------------------------------------------------------------------
-- CONNECTION
-----------------------------------------------------------------------------------------------------------------------------------------
vRP = {}
tvRP = {}
vRP.userIds = {}
vRP.userTables = {}
vRP.userSources = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- TUNNER/PROXY
-----------------------------------------------------------------------------------------------------------------------------------------
Proxy.addInterface("vRP",vRP)
Tunnel.bindInterface("vRP",tvRP)
-----------------------------------------------------------------------------------------------------------------------------------------
-- QUERIES
-----------------------------------------------------------------------------------------------------------------------------------------
local Prepares = {}
-----------------------------------------------------------------------------------------------------------------------------------------
-- PREPARE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.prepare(name,query)
	Prepares[name] = query
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- QUERY
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.query(name,params)
	return exports.oxmysql:query_async(Prepares[name], params)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETIDENTITIES
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.getIdentities(source)
	local result = false

	local identifiers = GetPlayerIdentifiers(source)
	for _,v in pairs(identifiers) do
		if string.find(v,"license") then
			local splitName = splitString(v,":")
			result = splitName[2]
			break
		end
	end

	return result
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATETXT
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.updateTxt(archive,text)
	archive = io.open("resources/logsystem/"..archive,"a")
	if archive then
		archive:write(text.."\n")
	end

	archive:close()
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKBANNED
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.checkBanned(license)
	local consult = vRP.query("banneds/getBanned",{ license = license })
	if consult[1] then
		local timeCheck = vRP.query("banneds/getTimeBanned",{ license = license })
		if timeCheck[1] ~= nil then
			vRP.query("banneds/removeBanned",{ license = license })
			return false
		end

		return true
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHECKWHITELIST
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.checkWhitelist(license)
	local infoAccount = vRP.infoAccount(license)
	if infoAccount then
		return infoAccount["whitelist"]
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- INFOACCOUNT
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.infoAccount(license)
	local infoAccount = vRP.query("accounts/getInfos",{ license = license })
	if infoAccount[1] then
		return infoAccount[1]
	end

	return false
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USERDATA
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.userData(user_id,key)
	local consult = vRP.query("playerdata/getUserdata",{ user_id = parseInt(user_id), key = key })
	if consult[1] then
		return json.decode(consult[1]["dvalue"])
	else
		return {}
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEHOMEPOSITION
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.updateHomePosition(user_id,x,y,z)
	local dataTable = vRP.getDatatable(user_id)
	if dataTable then
		dataTable["position"] = { x = mathLegth(x), y = mathLegth(y), z = mathLegth(z) }
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USERINVENTORY
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.userInventory(user_id)
	local dataTable = vRP.getDatatable(user_id)
	if dataTable then
		if dataTable["inventory"] == nil then
			dataTable["inventory"] = {}
		end

		return dataTable["inventory"]
	end

	return {}
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATESELECTSKIN
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.updateSelectSkin(user_id,hash)
	local dataTable = vRP.getDatatable(user_id)
	if dataTable then
		dataTable["skin"] = hash
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETUSERID
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.getUserId(source)
	return vRP.userIds[parseInt(source)]
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USERLIST
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.userList()
	return vRP.userSources
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- USERPLAYERS
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.userPlayers()
	return vRP.userIds
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETUSERSOURCE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.userSource(user_id)
	return vRP.userSources[parseInt(user_id)]
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- GETDATATABLE
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.getDatatable(user_id)
	return vRP.userTables[parseInt(user_id)]
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYERDROPPED
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("playerDropped",function(reason)
	playerDropped(source,reason)
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- KICK
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.kick(user_id,reason)
	local userSource = vRP.userSource(user_id)
	if userSource then
		playerDropped(userSource,"Kick/Afk")
		DropPlayer(userSource,reason)
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYERDROPPED
-----------------------------------------------------------------------------------------------------------------------------------------
function playerDropped(source,reason)
	local source = source
	local user_id = vRP.getUserId(source)
	if user_id then
		TriggerEvent("discordLogs","Disconnect","**Passaporte:** "..parseFormat(user_id).."\n**Motivo:** "..reason.."\n**Horário:** "..os.date("%H:%M:%S"),3092790)

		local dataTable = vRP.getDatatable(user_id)
		if dataTable then
			TriggerEvent("vRP:playerLeave",user_id,source)
			vRP.query("playerdata/setUserdata",{ user_id = parseInt(user_id), key = "Datatable", value = json.encode(dataTable) })
			vRP.userSources[parseInt(user_id)] = nil
			vRP.userTables[parseInt(user_id)] = nil
			vRP.userIds[parseInt(source)] = nil
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATEINFORMATIONS
-----------------------------------------------------------------------------------------------------------------------------------------
function tvRP.userUpdate(pArmour,pHealth,pCoords)
	local source = source
	local user_id = vRP.getUserId(source)
	if user_id then
		local dataTable = vRP.getDatatable(user_id)
		if dataTable then
			dataTable["armour"] = parseInt(pArmour)
			dataTable["health"] = parseInt(pHealth)
			dataTable["position"] = { x = mathLegth(pCoords["x"]), y = mathLegth(pCoords["y"]), z = mathLegth(pCoords["z"]) }
		end
	end
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- PLAYERCONNECTING
-----------------------------------------------------------------------------------------------------------------------------------------
AddEventHandler("Queue:playerConnecting",function(source,identifiers,deferrals)
	local license = vRP.getIdentities(source)
	if license then
		if not vRP.checkBanned(license) then
			if vRP.checkWhitelist(license) then
				vRP.query("accounts/dateLogin",{ license = license, login = os.date("%d/%m/%Y") })
				deferrals.done()
			else
				local infoAccount = vRP.infoAccount(license)
				if not infoAccount then
					vRP.query("accounts/newAccount",{ license = license, login = os.date("%d/%m/%Y") })
				end

				deferrals.done("Envie na sala liberação: "..license)
				TriggerEvent("Queue:removeQueue",identifiers)
			end
		else
			deferrals.done("Banido.")
			TriggerEvent("Queue:removeQueue",identifiers)
		end
	else
		deferrals.done("Conexão perdida.")
		TriggerEvent("Queue:removeQueue",identifiers)
	end
end)
-----------------------------------------------------------------------------------------------------------------------------------------
-- CHARACTERCHOSEN
-----------------------------------------------------------------------------------------------------------------------------------------
function vRP.characterChosen(source,user_id,model)
	vRP.userIds[source] = user_id
	vRP.userSources[user_id] = source
	vRP.userTables[user_id] = vRP.userData(user_id,"Datatable")

	if model ~= nil then
		vRP.userTables[user_id]["backpack"] = 50
		vRP.userTables[user_id]["inventory"] = {}
		vRP.generateItem(user_id,"water",3,false)
		vRP.generateItem(user_id,"sandwich",3,false)
		vRP.generateItem(user_id,"cellphone",1,false)
		vRP.userTables[user_id]["skin"] = GetHashKey(model)
	end

	local identity = vRP.userIdentity(user_id)
	if identity["serial"] == nil then
		vRP.query("characters/setSerial",{ user_id = user_id, serial = vRP.generateSerial() })
	end

	TriggerEvent("vRP:playerSpawn",user_id,source)
end
-----------------------------------------------------------------------------------------------------------------------------------------
-- THREADSERVER
-----------------------------------------------------------------------------------------------------------------------------------------
CreateThread(function()
	SetGameType("Bahamas")
	SetMapName("www.bahamascity.com.br")
end)