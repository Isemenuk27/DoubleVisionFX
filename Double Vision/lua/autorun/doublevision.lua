if CLIENT then
	local CVAR_Enable =  CreateClientConVar("dv_enable_cl", "1", true, false)
	local CVAR_Amplitude =  CreateClientConVar("dv_amplitude", "1.7", true, false)
	local CVAR_Period =  CreateClientConVar("dv_period", "1.1,", true, false)
	local CVAR_Opacity =  CreateClientConVar("dv_opacity", "0.3", true, false)

	local CVAR_PP_Enable = CreateClientConVar("dv_pp", "0", true, false)
	local CVAR_PP_Amplitude = CreateClientConVar("dv_pp_amplitude", "1.7", true, false)
	local CVAR_PP_Period = CreateClientConVar("dv_pp_period", "1.1,", true, false)
	local CVAR_PP_Alpha = CreateClientConVar("dv_pp_alpha", "0.3", true, false)

	local PostProcessEnabled = CVAR_PP_Enable:GetBool()
	local MaterialAlpha = CVAR_PP_Amplitude:GetFloat()
	local DVFrequency = CVAR_PP_Period:GetFloat()
	local DVAmplitude = CVAR_PP_Alpha:GetFloat()

	local DVEnabled = CVAR_Enable:GetBool()
	local DVAlpha = CVAR_Amplitude:GetFloat()
	local DVeFrequency = CVAR_Period:GetFloat()
	local DVeAmplitude = CVAR_Opacity:GetFloat()

	local mat = Material("dv_buffer")
	mat:SetFloat( "$alpha", 0.2 )
	local xShift = 0
	local ExpEffectAlpha = 0

	local SCRW = ScrW()
	local SCRH = ScrH()

	hook.Add( "OnScreenSizeChanged", "LENSFLARE.SCR", function()
		SCRW = ScrW()
		SCRH = ScrH()
	end)

	local mathsin = math.sin
	local mathApproach = math.Approach
	local RealTime = RealTime
	local renderSetMaterial = render.SetMaterial
	local renderDrawScreenQuadEx = render.DrawScreenQuadEx
	local renderGetScreenEffectTexture = render.GetScreenEffectTexture
	local renderUpdateScreenEffectTexture = render.UpdateScreenEffectTexture

	local function PPDraw()
		renderUpdateScreenEffectTexture()
		mat:SetTexture("$basetexture", renderGetScreenEffectTexture())
		local offset = mathsin( RealTime() * DVFrequency ) * ((SCRW / 100) * DVAmplitude )

		mat:SetFloat( "$alpha", MaterialAlpha )

		renderSetMaterial( mat )
		renderDrawScreenQuadEx( xShift + offset, 0, xShift + SCRW, SCRH )
	end

	local function Draw()
		if !DVEnabled then ExpEffectAlpha = 0 return end
		if ExpEffectAlpha == 0 then mat:SetFloat( "$alpha", 0 ) return end
		renderUpdateScreenEffectTexture()
		mat:SetTexture("$basetexture", renderGetScreenEffectTexture())

		local offset = mathsin( RealTime() * DVeFrequency ) * ((SCRW / 100) * DVeAmplitude )
		ExpEffectAlpha = mathApproach(ExpEffectAlpha, 0, FrameTime() * ExpEffectAlpha * 0.2)

		mat:SetFloat( "$alpha", ExpEffectAlpha )
		renderSetMaterial( mat )
		renderDrawScreenQuadEx( xShift + offset, 0, xShift + SCRW, SCRH )
	end

	local function Enable()
		hook.Add( "RenderScreenspaceEffects", "DoublevisionDrawHook", Draw)
	end
	
	local function Disable()
		hook.Remove( "RenderScreenspaceEffects", "DoublevisionDrawHook")
	end
	
	local function EnablePP()
		hook.Add( "RenderScreenspaceEffects", "DoublevisionDrawHook", PPDraw)
	end
	
	local function DisablePP()
		hook.Remove( "RenderScreenspaceEffects", "DoublevisionDrawHook")
	end
	
	cvars.AddChangeCallback("dv_enable_cl", function(CVarName, OldVar, NewVar)
		DVEnabled = tobool(NewVar)
	end)
	cvars.AddChangeCallback("dv_amplitude", function(CVarName, OldVar, NewVar) DVeFrequency = tonumber(NewVar) end)
	cvars.AddChangeCallback("dv_period", function(CVarName, OldVar, NewVar) DVeAmplitude = tonumber(NewVar) end)
	cvars.AddChangeCallback("dv_opacity", function(CVarName, OldVar, NewVar) DVAlpha = tonumber(NewVar) end)

	cvars.AddChangeCallback("dv_pp", function(CVarName, OldVar, NewVar) 
		PostProcessEnabled = tobool(NewVar) 
		Disable()
	end)
	cvars.AddChangeCallback("dv_pp_amplitude", function(CVarName, OldVar, NewVar) DVFrequency = tonumber(NewVar) end)
	cvars.AddChangeCallback("dv_pp_period", function(CVarName, OldVar, NewVar) DVAmplitude = tonumber(NewVar) end)
	cvars.AddChangeCallback("dv_pp_alpha", function(CVarName, OldVar, NewVar) MaterialAlpha = tonumber(NewVar) end)

	net.Receive( "DoubleVision.CLEAR", function(len)
		if ( !DVEnabled || PostProcessEnabled ) then return end
		ExpEffectAlpha = 0
		mat:SetFloat( "$alpha", 0 )
		Disable()
	end )

	net.Receive( "DoubleVision.Add", function(len)
		if (!DVEnabled || PostProcessEnabled) then return end
		local dmg = net.ReadInt(14)
		ExpEffectAlpha = math.Clamp( LocalPlayer():GetMaxHealth()/dmg, 0.1, DVAlpha)
		Enable()
	end )

end

if SERVER then
	util.AddNetworkString( "DoubleVision.Add" )
	util.AddNetworkString( "DoubleVision.CLEAR" )

	local DVBENABLE = CreateConVar("dv_enable", "1", { FCVAR_ARCHIVE }, "Enable double vision after explosion" )

	hook.Add( "EntityTakeDamage", "ExplosionEffectHook", function( target, dmginfo )

		if !DVBENABLE:GetBool() then return end
		if !target:IsPlayer() then return end
		if !dmginfo:IsDamageType(DMG_BLAST) then return end

		net.Start( "DoubleVision.Add" )
			net.WriteInt( dmginfo:GetDamage(), 14 )
		net.Send( target )
	end)

	hook.Add( "PlayerSpawn", "ExplosionEffectHookKill", function(ply) 
		net.Start( "DoubleVision.CLEAR" )
		net.Send( ply )
	end)
else
	hook.Add( "AddToolMenuCategories", "DoublevisionMenu", function()
		spawnmenu.AddToolCategory( "Options", "postprocessing", "#spawnmenu.category.postprocess" )
	end )

	hook.Add( "PopulateToolMenu", "DoublevisionMenu", function()
		spawnmenu.AddToolMenuOption( "Options", "postprocessing", "postprocessingMenu", "#Double Vision", "", "", function( panel )
			panel:ClearControls()

			local Default = {
				["dv_enable_cl"] = true,
				["dv_amplitude"] = 1.7,
				["dv_period"] = 1.1,
				["dv_opacity"] = 0.3
			}

			panel:AddControl( "ComboBox" , { ["MenuButton"] = 1 , ["Folder"] = "doublevision_common" , ["Options"] = { [ "#preset.default" ] = Default } , ["CVars"] = table.GetKeys( Default ) } )

			if LocalPlayer():IsAdmin() then
				panel:CheckBox( "Enable on all clients", "dv_enable" )
			end

			panel:CheckBox( "Enable", "dv_enable_cl" )
			panel:NumSlider( "Maximum opacity", "dv_opacity", 0.1, 0.9 )
			panel:NumSlider( "Amplitude", "dv_amplitude", 0.01, 3 )
			panel:NumSlider( "Period", "dv_period", 0.5, 5 )
		end )
	end )

	list.Set( "PostProcess", "#Double Vision", {

		icon = "gui/postprocess/doublevision.png",
		convar = "dv_pp",
		category = "#effects_pp",

		cpanel = function( CPanel )

			local Default = {
				["dv_pp"] = 0,
				["dv_pp_amplitude"] = 1.7,
				["dv_pp_period"] = 1.1,
				["dv_pp_alpha"] = 0.3
			}

			CPanel:AddControl( "ComboBox" , { ["MenuButton"] = 1 , ["Folder"] = "doublevision_pp_common" , ["Options"] = { [ "#preset.default" ] = Default } , ["CVars"] = table.GetKeys( Default ) } )

			CPanel:AddControl( "CheckBox", { Label = "#Enable Double Vision PostProcess", Command = "dv_pp" } )

			CPanel:AddControl( "Slider", { Label = "#Amplitude", Command = "dv_pp_amplitude", Type = "Float", Min = "0", Max = "10" } )
			CPanel:AddControl( "Slider", { Label = "#Period", Command = "dv_pp_period", Type = "Float", Min = "0", Max = "10" } )
			CPanel:AddControl( "Slider", { Label = "#Opacity", Command = "dv_pp_alpha", Type = "Float", Min = "0", Max = "1" } )
		end

	} )
end