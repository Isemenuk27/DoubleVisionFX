if CLIENT then
CreateClientConVar("dv_enable_cl", "1", true, false)
CreateClientConVar("dv_amplitude", "1.5", true, false)
CreateClientConVar("dv_period", "3", true, false)
CreateClientConVar("dv_opacity", "0.8", true, false)

local mat = Material("effects/flashlight/view")
mat:SetFloat( "$alpha", 0.2 )
local xShift = 0
local ExpEffectAlpha = 0

net.Receive( "ClearExplosionEffect", function(len)
	if !GetConVar("dv_enable_cl"):GetBool() then return end
	local ply = net.ReadEntity()
	if !IsValid( ply ) then return end
	if LocalPlayer() != ply then return end
	ExpEffectAlpha = 0
	mat:SetFloat( "$alpha", 0 )
end )

net.Receive( "DoExplosionEffect", function(len)
	if !GetConVar("dv_enable_cl"):GetBool() then return end
	local dmg = net.ReadInt(14)
	local ply = net.ReadEntity()
	if !IsValid( ply ) then return end
	if LocalPlayer() != ply then return end

	ExpEffectAlpha = math.Clamp(dmg / ply:GetMaxHealth(), 0.1, GetConVar("dv_opacity"):GetFloat())
end )

hook.Add( "RenderScreenspaceEffects", "Render_ExplosionEffect", function()
	if !GetConVar("dv_enable_cl"):GetBool() then ExpEffectAlpha = 0 return end
	if ExpEffectAlpha == 0 then mat:SetFloat( "$alpha", 0 ) return end
	render.CopyRenderTargetToTexture( render.GetScreenEffectTexture() )
	local offset = math.sin( RealTime() * GetConVar("dv_period"):GetFloat()) * ((ScrW() / 100) * GetConVar("dv_amplitude"):GetFloat() )
	ExpEffectAlpha = math.Approach(ExpEffectAlpha, 0, FrameTime() * ExpEffectAlpha * 0.2)
	mat:SetFloat( "$alpha", ExpEffectAlpha )
	render.SetMaterial( mat )
	render.DrawScreenQuadEx( xShift + offset, 0, xShift + ScrW(), ScrH() )
end )

end

if SERVER then
util.AddNetworkString( "DoExplosionEffect" )
util.AddNetworkString( "ClearExplosionEffect" )

CreateConVar("dv_enable", "1", { FCVAR_ARCHIVE }, "Enable double vision after explosion" )

hook.Add( "EntityTakeDamage", "ExplosionEffectHook", function( target, dmginfo )

	if !GetConVar("dv_enable"):GetBool() then return end
	if !target:IsPlayer() then return end
	if !dmginfo:IsDamageType(DMG_BLAST) then return end

	net.Start( "DoExplosionEffect" )
		net.WriteInt( dmginfo:GetDamage(), 14 )
		net.WriteEntity( target )
	net.Broadcast()
end)

hook.Add( "PlayerSpawn", "ExplosionEffectHookKill", function(ply) 
	net.Start( "ClearExplosionEffect" )
		net.WriteEntity( ply )
	net.Broadcast()
end)

end

hook.Add( "AddToolMenuCategories", "postprocessingMenu", function()
	spawnmenu.AddToolCategory( "Options", "postprocessing", "#spawnmenu.category.postprocess" )
end )

hook.Add( "PopulateToolMenu", "DoublevisionMenu", function()
	spawnmenu.AddToolMenuOption( "Options", "postprocessing", "postprocessingMenu", "#Double Vision", "", "", function( panel )
		panel:ClearControls()
		panel:CheckBox( "Enable on all clients", "dv_enable" )
		panel:CheckBox( "Enable", "dv_enable_cl" )
		panel:NumSlider( "Maximum opacity", "dv_opacity", 0.1, 0.9 )
		panel:NumSlider( "Amplitude %screen", "dv_amplitude", 0.01, 3 )
		panel:NumSlider( "Period", "dv_period", 0.5, 5 )
	end )
end )