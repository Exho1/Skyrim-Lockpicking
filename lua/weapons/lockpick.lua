----// Skyrim-like Lockpick //----
-- Author: Exho
-- Version: 4/28/15

AddCSLuaFile()

-- Prevent immediate errors in sandbox
DarkRP = DarkRP or {}
DarkRP.hookStub = DarkRP.hookStub or function() end
ServerLog = ServerLog or function( text ) print(text) end

if SERVER then
	-- Resourcing
	local files = file.Find("materials/vgui/skyrim/*.png", "GAME")
	for _, v in pairs( files ) do
		resource.AddFile("materials/vgui/skyrim/"..v)
	end
	
	local files = file.Find("sound/lockpicking/*.wav", "GAME")
	for _, v in pairs( files ) do
		resource.AddFile("sound/lockpicking/"..v)
	end
end

if CLIENT then
	SWEP.PrintName = "Lock Pick"
	SWEP.Slot = 5
	SWEP.SlotPos = 1
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
end

SWEP.Author = "Exho"
SWEP.Instructions = "Left or right click to pick a lock"
SWEP.Contact = ""
SWEP.Purpose = ""

SWEP.ViewModelFOV = 62
SWEP.ViewModelFlip = false
SWEP.ViewModel = Model("models/weapons/c_crowbar.mdl")
SWEP.WorldModel = Model("models/weapons/w_crowbar.mdl")

SWEP.UseHands = true

SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.Category = "DarkRP (Utility)"

SWEP.Sound = Sound("lockpicking/pickmovement_1.wav") -- Not sure what this does...

SWEP.Primary.ClipSize = -1 
SWEP.Primary.DefaultClip = 0
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""


function SWEP:Initialize()
	self:SetHoldType("normal")
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "IsLockpicking")
	--self:NetworkVar("Float", 0, "LockpickStartTime")
	--self:NetworkVar("Float", 1, "LockpickEndTime")
	self:NetworkVar("Float", 2, "NextSoundTime")
	self:NetworkVar("Int", 5, "TotalLockpicks")
	self:NetworkVar("Entity", 0, "LockpickEnt")
end

-- Create our materials
local matLock = Material( "vgui/skyrim/lock1.png" )
local matLockinside = Material( "vgui/skyrim/lockinside.png" )
local matLockpick = Material( "vgui/skyrim/lockpick.png" )

if SERVER then
	util.AddNetworkString("lockpick_break")
	util.AddNetworkString("lockpick_unlock")
	util.AddNetworkString("lockpick_check")
	util.AddNetworkString("lockpick_end")
	util.AddNetworkString("lockpick_start")
	
	--// When a player breaks a lockpick
	net.Receive("lockpick_break", function( len, ply )
		if ply:HasWeapon("lockpick") then
			local wep = ply:GetActiveWeapon()
			
			if wep:GetClass() == "lockpick" then
				--wep:SetTotalLockpicks( wep:GetTotalLockpicks() - 1 ) 
				wep:Fail()
				wep:SetNextPrimaryFire(CurTime() + 2)
				ply:PrintMessage( HUD_PRINTCONSOLE, "Broke lockpick" )
				ply:ChatPrint( "You broke a lockpick!" )
			end
		end
	end)
	
	--// When a player successfully unlocks a door
	net.Receive("lockpick_unlock", function( len, ply )
		if ply:HasWeapon("lockpick") then
			local wep = ply:GetActiveWeapon()
			
			if wep:GetClass() == "lockpick" then
				if wep:GetNWBool("lockpick_canTurn", false) then	
					wep:Succeed()
					ServerLog(ply:Nick().." has unlocked a door!\n")
				else
					ply:PrintMessage( HUD_PRINTCONSOLE, "Unable to unlock door because the server has not confirmed the angle" )
				end
			end
		end
	end)
	
	--// When a player backs or some other strange circumstance
	net.Receive("lockpick_end", function( len, ply )
		if ply:HasWeapon("lockpick") then
			local wep = ply:GetActiveWeapon()
			
			if wep:GetClass() == "lockpick" then
				wep:Fail( true )
				ply:PrintMessage( HUD_PRINTCONSOLE, "Cancelled lockpicking" )
			end
		end
	end)
	
	net.Receive("lockpick_check", function( len, ply )
		local angle = net.ReadInt( 8 )
		
		if ply:HasWeapon("lockpick") then
			local wep = ply:GetActiveWeapon()
		
			if angle - 10 < wep.unlockAngle and angle + 10 > wep.unlockAngle then 
				-- Lockpick has the correct angle to open, tell the client
				wep:SetNWBool("lockpick_canTurn", true)
			else
				wep:SetNWBool("lockpick_canTurn", false)
			end
		end
	end)
end
	
if CLIENT then
	function surface.DrawTexturedRectRotatedPoint( x, y, w, h, rot, x0, y0 )
		local c = math.cos( math.rad( rot ) )
		local s = math.sin( math.rad( rot ) )
		local newx = y0 * s - x0 * c
		local newy = y0 * c + x0 * s
		
		surface.DrawTexturedRectRotated( x + newx, y + newy, w, h, rot )
	end
end
	
--// Plays sounds when the cylinder turns
local nextSound = 0
local function playTurningSounds()
	if CurTime() > nextSound then
		surface.PlaySound("lockpicking/cylinderturn_"..math.random(3)..".wav")
		nextSound = CurTime() + math.Rand(0.2, 0.5)
		surface.PlaySound("lockpicking/cylindersqueak_"..math.random(3)..".wav")
	end
end

--// Plays sounds when the lockpick moves
local nextSound2 = 0
local function playPickSounds()
	if CurTime() > nextSound2 then
		surface.PlaySound("lockpicking/pickmovement_"..math.random(6)..".wav")
		nextSound2 = CurTime() + math.Rand(0.5, 1.5)
	end
end

--// Plays sounds when the the lockpick angle is near the unlock angle
local nextSound3 = 0
local function playHintSound()
	if CurTime() > nextSound3 then
		surface.PlaySound("lockpicking/lockpick_hint.wav")
		nextSound3 = CurTime() + math.Rand(0.5, 1.5)
	end
end


--[[-------------------------------------------------------
Name: SWEP:PrimaryAttack()
Desc: +attack1 has been pressed
---------------------------------------------------------]]
function SWEP:PrimaryAttack()

	local totalLockpicks = self:GetTotalLockpicks()
	
	if totalLockpicks <= 0 then
		self.Owner:ChatPrint("You have no lockpicks left!")
		return
	end

	self:SetNextPrimaryFire(CurTime() + 2)
	if self:GetIsLockpicking() then return end

	self:GetOwner():LagCompensation(true)
	local trace = self:GetOwner():GetEyeTrace()
	self:GetOwner():LagCompensation(false)
	local ent = trace.Entity

	if not IsValid(ent) then return end
	local canLockpick = hook.Call("canLockpick", nil, self:GetOwner(), ent)

	if canLockpick == false then return end
	if canLockpick ~= true and (
			trace.HitPos:Distance(self:GetOwner():GetShootPos()) > 100 or
			(not GAMEMODE.Config.canforcedooropen and ent:getKeysNonOwnable()) or
			(not ent:isDoor() and not ent:IsVehicle() and not string.find(string.lower(ent:GetClass()), "vehicle") and (not GAMEMODE.Config.lockpickfading or not ent.isFadingDoor))
		) then
		return
	end
	
	-- Get a random angle to unlock this door
	if SERVER then
		self.unlockAngle = math.random(15, 165)
		self:SetNWBool("lockpick_canTurn", false)
	end

	self:SetHoldType("pistol")

	self:SetIsLockpicking(true)
	self:SetLockpickEnt(ent)
	
	net.Start("lockpick_start")
		net.WriteInt( totalLockpicks, 8 )
	net.Send( self.Owner )

	local onFail = function(ply) if ply == self:GetOwner() then hook.Call("onLockpickCompleted", nil, ply, false, ent) end end

	-- Lockpick fails when dying or disconnecting
	hook.Add("PlayerDeath", self, fc{onFail, fn.Flip(fn.Const)})
	hook.Add("PlayerDisconnected", self, fc{onFail, fn.Flip(fn.Const)})
	-- Remove hooks when finished
	hook.Add("onLockpickCompleted", self, fc{fp{hook.Remove, "PlayerDisconnected", self}, fp{hook.Remove, "PlayerDeath", self}})
end

local function openPanel( self, totalLockpicks )
	print("Open panel", totalLockpicks)
	if SERVER then return end
	
	local baseH = ScrH()/2.5
	local baseW = baseH
	local insideH = baseH * 0.29
	local insideW = insideH
	
	local lockRotation = 0
	local newRotation = 0
	local pickRotation = 0
	local oldPickRotation = 0
	
	local rotatingLock = false
	local canRotate = true
	local unlocked = false
	
	local holdTime = 0
	local nextCheck = 0
	
	-- Play starting lockpick sound
	surface.PlaySound("lockpicking/enter.wav")
	
	if IsValid(self.frame) then
		self.frame:Remove()
	end
	
	self.frame = vgui.Create("DFrame")
	local frame = self.frame
	frame:SetSize( ScrW() / 2, ScrH() )
	frame:Center()
	frame:ShowCloseButton( false )
	frame:SetTitle("")
	frame:MakePopup()
	frame.Paint = function( pnl )	
		local x = frame:GetWide()/2 - baseW/2
		local y = frame:GetWide() - (baseH * 1)
		
		draw.DrawText( "Press 'Q' to stop picking", "TargetID", x + baseW/2, y + baseH + 30, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER )
		--draw.DrawText(pickRotation, "TargetID", x + baseW/2, y  - 30, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER )
		--draw.DrawText(self:GetNWBool("lockpick_canTurn", false) , "TargetID", x + baseW/2, y  -60, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER )
		--draw.DrawText(canRotate, "TargetID", x + baseW/2, y  -80, Color( 255, 255, 255, 255 ), TEXT_ALIGN_CENTER )
		
		-- Black background behind the inside lock just to make sure no transparency peeks through
		surface.SetDrawColor( color_black )
		surface.DrawRect( x + baseW/4, y + baseH/4, baseW/2, baseH/2 )
		
		-- The outside lock
		surface.SetDrawColor( 200, 200, 200, 255 )
		surface.SetMaterial( matLock )
		surface.DrawTexturedRect( x, y, baseW, baseH )
		
		-- The inside lock
		lockRotation = Lerp( 10 * FrameTime(), lockRotation, newRotation)
		newRotation = math.Clamp( newRotation, -90, 0 )
		
		local x, y = x + baseW/2 , y + baseH/2 + (insideH / 6)
		
		surface.SetDrawColor( 200, 200, 200, 255 )
		surface.SetMaterial( matLockinside )
		surface.DrawTexturedRectRotated( x, y, insideW, insideH, lockRotation )
		
		if rotatingLock then 
			playTurningSounds()
			
			-- The lock has been turned half way
			if math.abs( lockRotation ) > 45 then 
				if self:GetNWBool("lockpick_canTurn", false) then -- We've got the correct angle
					if math.abs( lockRotation ) > 80 then -- Turned the key far enough
						-- Time to unlock the door
						pnl.Think = function() end 
						timer.Simple(0.5, function()
							if IsValid(frame) then
								frame:Close()
								net.Start("lockpick_unlock")
								net.SendToServer()
							end
						end)
					end
				else	
					-- Invalid angle
					canRotate = false
				end
			end

			if math.abs( lockRotation ) > 15 then 
				holdTime = holdTime + FrameTime()
				
				if CurTime() > nextCheck then
					net.Start("lockpick_check")
						net.WriteInt( math.abs(pickRotation), 8 )
					net.SendToServer()
						
					nextCheck = CurTime() + 0.5
				end
				
				-- Holding an incorrect angle for too long, break the lockpick
				if holdTime > 0.1 and not self:GetNWBool("lockpick_canTurn", false) then
					holdTime = 0
					frame:Close()
					surface.PlaySound("lockpicking/pickbreak_"..math.random(3)..".wav")
					
					net.Start("lockpick_break")
						net.WriteEntity( self )
					net.SendToServer()
				end
			end
		else
			if CurTime() > nextCheck then
				net.Start("lockpick_check")
					net.WriteInt( math.abs(pickRotation), 8 )
				net.SendToServer()
					
				nextCheck = CurTime() + 0.5
			end
			
			holdTime = 0
			
			-- Get the angle from the mouse position to the lock position
			local mX, mY = pnl:ScreenToLocal( gui.MouseX(), gui.MouseY() )
			pickRotation = math.deg(math.atan2((mY - y), (mX - x)))
			
			pickRotation = math.Clamp( pickRotation, -180, 0 )
			
			-- Rotation has changed, play sounds
			if oldPickRotation != pickRotation then
				playPickSounds()
				oldPickRotation = pickRotation

				if self:GetNWBool("lockpick_canTurn", false) then
					playHintSound()
				end
			end
		end
		
		-- Draw the lockpick
		surface.SetDrawColor( 200, 200, 200, 255 )
		surface.SetMaterial( matLockpick )
		surface.DrawTexturedRectRotatedPoint( x, y, baseW, 30, 180 - pickRotation, baseW / 2, 0 )
	end
	
	local hasJiggled = false
	frame.Think = function( pnl )
		-- Exit the lockpicking screen
		if input.IsKeyDown( KEY_Q ) then
			net.Start("lockpick_end")
			net.SendToServer()
			
			pnl:Close()
		end
		
		if input.IsKeyDown( KEY_A ) and canRotate then
			rotatingLock = true
			newRotation = newRotation - 5
		else
			-- Rotate back to the starting position 
			rotatingLock = false
			newRotation = newRotation + ( 200 * FrameTime() )
			if newRotation > -5 then
				canRotate = true
			end
		end
		
		if self:GetNWBool("lockpick_canTurn", false) then
			if not hasJiggled then
				lockRotation = lockRotation - 10
				hasJiggled = true
			end
		else
			hasJiggled = false
		end
		
		if LocalPlayer():isArrested() or not LocalPlayer():Alive() then
			net.Start("lockpick_end")
			net.SendToServer()
			
			pnl:Close()
		end	
	end
	
	return
end

if CLIENT then
	net.Receive("lockpick_start", function( len, ply )
		local l = net.ReadInt( 8 )
		
		local wep
		for _, v in pairs( LocalPlayer():GetWeapons() ) do
			if v:GetClass() == "lockpick" then
				wep = v
			end
		end
		
		openPanel( wep, l )
	end)
end

function SWEP:Holster()
	self:SetIsLockpicking(false)
	self:SetLockpickEnt(nil)
	return true
end

function SWEP:Succeed()
	self:SetHoldType("normal")

	local ent = self:GetLockpickEnt()
	self:SetIsLockpicking(false)
	self:SetLockpickEnt(nil)

	if not IsValid(ent) then return end

	local override = hook.Call("onLockpickCompleted", nil, self:GetOwner(), true, ent)

	if override then return end

	if ent.isFadingDoor and ent.fadeActivate and not ent.fadeActive then
		ent:fadeActivate()
		if IsFirstTimePredicted() then timer.Simple(5, function() if IsValid(ent) and ent.fadeActive then ent:fadeDeactivate() end end) end
	elseif ent.Fire then
		ent:keysUnLock()
		ent:Fire("open", "", .6)
		ent:Fire("setanimation", "open", .6)
	end
	
	ent:EmitSound("lockpicking/unlock_"..math.random(3)..".wav")
end

function SWEP:Fail( bSilent )
	self:SetIsLockpicking(false)
	self:SetHoldType("normal")

	hook.Call("onLockpickCompleted", nil, self:GetOwner(), false, self:GetLockpickEnt())
	self:SetLockpickEnt(nil)
	
	if not bSilent then
		self.Owner:EmitSound("lockpicking/pickbreak_"..math.random(3)..".wav")
	end
end

function SWEP:Think()
	if not self:GetIsLockpicking()then return end

	local trace = self:GetOwner():GetEyeTrace()
	if not IsValid(trace.Entity) or trace.Entity ~= self:GetLockpickEnt() or trace.HitPos:Distance(self:GetOwner():GetShootPos()) > 100 then
		self:Fail()
		
		-- Close the lockpicking screen
		if IsValid( self.frame ) then
			self.frame:Close()
		end
	end
end

function SWEP:SecondaryAttack()
	self.Owner:ChatPrint( "You have "..self:GetTotalLockpicks().." lockpick(s) left!" )
end


DarkRP.hookStub{
	name = "canLockpick",
	description = "Whether an entity can be lockpicked.",
	parameters = {
		{
			name = "ply",
			description = "The player attempting to lockpick an entity.",
			type = "Player"
		},
		{
			name = "ent",
			description = "The entity being lockpicked.",
			type = "Entity"
		},
	},
	returns = {
		{
			name = "allowed",
			description = "Whether the entity can be lockpicked",
			type = "boolean"
		}
	},
	realm = "Shared"
}

DarkRP.hookStub{
	name = "onLockpickCompleted",
	description = "Result of a player attempting to lockpick an entity.",
	parameters = {
		{
			name = "ply",
			description = "The player attempting to lockpick the entity.",
			type = "Player"
		},
		{
			name = "success",
			description = "Whether the player succeeded in lockpicking the entity.",
			type = "boolean"
		},
		{
			name = "ent",
			description = "The entity that was lockpicked.",
			type = "Entity"
		},
	},
	returns = {
		{
			name = "override",
			description = "Return true to override default behaviour, which is opening the (fading) door.",
			type = "boolean"
		}
	},
	realm = "Shared"
}

DarkRP.hookStub{
	name = "lockpickTime",
	description = "The length of time, in seconds, it takes to lockpick an entity.",
	parameters = {
		{
			name = "ply",
			description = "The player attempting to lockpick an entity.",
			type = "Player"
		},
		{
			name = "ent",
			description = "The entity being lockpicked.",
			type = "Entity"
		},
	},
	returns = {
		{
			name = "time",
			description = "Seconds in which it takes a player to lockpick an entity",
			type = "number"
		}
	},
	realm = "Shared"
}



