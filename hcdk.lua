print("HELLO\n");
local frame = CreateFrame("Frame", "frame", UIParent);
frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 200,-200);
frame:SetWidth(100);
frame:SetHeight(100);

local texture = frame:CreateTexture("texture", "BACKGROUND");
texture:SetAllPoints("frame");
texture:SetTexture(1,0.5,0.5,1);
frame:Show();

local update_interval=0.15
local last_update = 0

local decide;

local NSLOT=15

function aid_to_rgb(action_id)
	v = action_id/NSLOT;
	return v
end

function MyOnUpdate(self, elapsed)
  last_update = last_update + elapsed; 	  
  if (last_update > update_interval) then
    last_update = 0
    action_id = decide();
    --print("aid: " .. action_id)
    r = aid_to_rgb(action_id)
    --print("r: " .. r)
    texture:SetTexture(r, r, r, 1);
    --print("action: " .. action_id)
  end
end
print("set handler\n");
frame:SetScript("OnUpdate", MyOnUpdate);
print("Done");

local rune_type = {};
local rune_ready = {}
local num_lock = 0
local num_blood = 0;
local num_frost = 0;
local num_unholy = 0;
local num_death = 0;
local runic_power = 0;
function query_runes() 
	num_lock = 1
	num_blood = 0;
	num_frost = 0;
	num_unholy = 0;
	num_death = 0;
	for i=1,6 do
		t = GetRuneType(i);
		start, duration, ready = GetRuneCooldown(i);
		rune_type[i] = t
		rune_ready[i] = ready
		if ready then				
			if t==1 then
				num_blood = num_blood+1;
			elseif t==3 then --Note: 3 is unholy!!!!
				num_frost = num_frost+1;
			elseif t==2 then
				num_unholy = num_unholy+1;
			else
				num_death = num_death+1;
			end
		end
	end	
	if (not rune_ready[0]) and (not rune_ready[1]) then
		num_lock = num_lock +1
	end
	if (not rune_ready[2]) and (not rune_ready[3]) then
		num_lock = num_lock +1
	end
	if (not rune_ready[4]) and (not rune_ready[5]) then
		num_lock = num_lock +1
	end

	runic_power = UnitPower("player");
end

local plague_leech=1
local soul_reaper=2
local summon_gargoyle=3
local death_coil = 4
local defile=5
local dark_transformation=6
local outbreak=7
local scourge_strike=8
local festering_strike=9
local plague_strike=10
local empower_rune_weapon=11
local summon_gargoyle = 12

local disease_name="冰霜疫病"
local outbreak_cd = 60
local outbreak_stat = -1 -- -1:avail, else cooling expir

function check_disease()
	for rank = 1,40 do
		name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId = UnitDebuff("target", "冰霜疫病", i, "PLAYER");
		--print("ck dis done, dura " .. duration .. " exp: " .. expirationTime);
		cur_time = GetTime()
		if duration ~= nil then
			return expirationTime - cur_time
		end
	end
	return -1
end

function check_spell_cooldown(spell_name)
	start, duration, enabled = GetSpellCooldown(spell_name);
	--print("ck cd done, enabled " .. enabled .. "dua " .. duration)
	cur_time = GetTime()
	if duration==0 or enabled==0 or start==0 then
		return -1;
	else
		return duration - (cur_time - start);
	end
end

function check_buff_count(unit_name, buf_name)
	--print("buf");
	_, _, _, count, _, ShadowInfusionDuration, ShadowInfusionExpirationTime, _, _,  _, _ = UnitBuff(unit_name, buf_name);
	--print("post buf");
	if count==nil then
		--print("cnt: " .. 0)
		return 0
	else
		--print("cnt: " .. count)
		return count
	end
end
function check_buff( unit_name, buf_name )
	name, rank, icon, count, debuffType, duration, expirationTime = UnitBuff(unit_name, buf_name);
	cur_time = GetTime()
	if name == nil then
		return -1
	else 
		return expirationTime - cur_time;
	end
end

decide = function()
	query_runes();

	--print("rune: " .. num_blood .. " " .. num_frost .. " " .. num_unholy .. " " .. num_death);
	--print("power: " .. runic_power);
	disease_stat = check_disease()
	--print("disease: " .. disease_stat);
	outbreak_stat = check_spell_cooldown("爆发");
	--print("outbreak: " .. outbreak_stat)
	--print("leech");
	plague_leech_stat = check_spell_cooldown("吸血瘟疫");
	--plague leech
	if num_lock>1 and plague_leech_stat < 0.9 then
		if disease_stat > 0 then
			if disease_stat < 1.5 or outbreak_stat<1 then
				return plague_leech
			end			
		end
	end
	--print("soul");
	target_health = UnitHealth("target");
	target_health_max = UnitHealthMax("target")
	target_health_pct = target_health/target_health_max*100
	soul_reaper_stat = check_spell_cooldown("灵魂收割");

	if check_spell_cooldown("召唤石像鬼")<0.9 then
		return summon_gargoyle
	end
	--print("hpct ".. target_health_pct)
	--soul reaper
	if soul_reaper_stat<1.1 and target_health_pct <= 45.5 and num_unholy+num_death>0 then
		return soul_reaper
	end

	if runic_power>90 then
		return death_coil
	end

	--print("defile");
	defile_stat = check_spell_cooldown("亵渎");
	if num_unholy+num_death>0 and defile_stat<1.1 then
		--print("亵渎");
		return defile
	end
	
	--print("infu");
	if check_buff_count("player", "暗影灌注") == 5 then
		return dark_transformation
	end

	--print("ps");
	--add disease	
	if disease_stat < 0 then
		if outbreak_stat < 1 then
			--print("爆发")
			return outbreak
		elseif num_unholy+num_death>0 then
			--print("暗打")
			return plague_strike
		end
	end

	if num_unholy ==2 then
		return scourge_strike
	end

	if runic_power>80 then
		return death_coil
	end

	if num_blood==2 and num_frost==2 then
		return festering_strike
	end

	doom = check_buff("player", "末日突降");
	trans = check_buff("pet", "黑暗突变")
	if (num_unholy<=1 and runic_power>=30 and trans<0) or doom>0 then
		return death_coil
	end

	if (num_unholy+num_death>0 and target_health_pct>45) or num_unholy==2 or num_unholy+num_death>=2 then
		if not (defile_stat<1.5 and num_unholy+num_death==1) then 
			return scourge_strike
		end
	end

	if num_frost>0 and num_blood>0 then
		return festering_strike
	end

	if runic_power>=30 then
		return death_coil; 
	end
	
	if num_lock>1 and plague_leech_stat<0.1 then
		return plague_leech
	end
	if num_lock>2 and check_spell_cooldown("符文武器增效")<0 then
		return empower_rune_weapon
	end

	return 0
end