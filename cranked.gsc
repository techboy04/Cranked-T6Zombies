#include maps\mp\_utility;
#include maps\_utility;
#include maps\_effects;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm;
#include maps\mp\zombies\_zm_laststand;


main()
{
	create_dvar("enable_cranked", 1);
	
	precacheshader("scorebar_zom_1");
   	precacheshader("menu_mp_weapons_1911");
	precacheshader("demo_pause");
	
	precachemodel("zombie_sign_please_wait");
	precachemodel("zombie_skull");
	
	if(getDvarInt("enable_cranked") == 1)
	{
		replacefunc(maps\mp\zombies\_zm::end_game, ::end_game_minigame);
		replacefunc(maps\mp\zombies\_zm::round_think, ::round_think_minigame);
		replacefunc(maps\mp\zombies\_zm::round_over, ::round_over_minigame);
		replacefunc(maps\mp\zombies\_zm::round_wait, ::round_wait_minigame);
		replacefunc(maps\mp\zombies\_zm_audio_announcer::init, ::init_audio_announcer);
		replacefunc(maps\mp\zombies\_zm_powerups::init_powerups, ::init_powerups_minigame);
	}
}

init()
{
	if(getDvarInt("enable_cranked") == 1)
	{
		
		level thread onPlayerConnect();
		level thread introHUD();
		level thread betaMessage();
		init_gamemode_powerups();
		level.perk_purchase_limit = 9;
		level.playersready = 0;
		level.maxtime = 300;
		level.roundspassed = 1;
		level.crankedstarted = 0;
		level.zombieskilled = 0;
		level thread maintain_zombie_count();
			
		level.zombie_vars["zombie_powerup_fire_sale_on"] = 1;
		
		for ( i = 0; i < level.chests.size; i++ )
		{
			if ( level.chest_index != i )
			{
				level.chests[i].was_temp = 0;

				if ( is_true( level.chests[i].hidden ) )
					level.chests[i] thread maps\mp\zombies\_zm_magicbox::show_chest();

				wait_network_frame();
			}
		}

		level thread nextroundtimer();

		level.leaper_rounds_enabled = 0;
		level.callbackactorkilled = ::actor_killed_override;
	}
}

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);

        player thread onPlayerSpawned();
		
		player thread respawnPlayer();
		
		player thread kill_on_downed();
    }
}

respawnPlayer()
{
	wait 5;
	if (self.sessionstate == "spectator")
	{
		self [[ level.spawnplayer ]]();
	}
	else
	{
	
	}
	self thread startHUDMessage();
}

onPlayerSpawned()
{
    self endon("disconnect");
	level endon("game_ended");

    for(;;)
    {
        self waittill("spawned_player");
        self endon("disconnect");
		
		self.lives = 999;
		self.timerpaused = 0;

		if (level.crankedstarted == 0)
		{
			self EnableInvulnerability();
			self thread wait_for_ready_input();
			level waittill ("end");
		}
		else
		{
			self disableInvulnerability();
		}
		self thread crankedHUD();
    }
}

create_dvar( dvar, set )
{
    if( getDvar( dvar ) == "" )
		setDvar( dvar, set );
}

init_powerups_minigame()
{
    flag_init( "zombie_drop_powerups" );

    if ( isdefined( level.enable_magic ) && level.enable_magic )
        flag_set( "zombie_drop_powerups" );

    if ( !isdefined( level.active_powerups ) )
        level.active_powerups = [];

    if ( !isdefined( level.zombie_powerup_array ) )
        level.zombie_powerup_array = [];

    if ( !isdefined( level.zombie_special_drop_array ) )
        level.zombie_special_drop_array = [];

	add_zombie_powerup( "nuke", "zombie_bomb", &"ZOMBIE_POWERUP_NUKE", ::func_should_never_drop, 0, 0, 0, "misc/fx_zombie_mini_nuke_hotness" );
	add_zombie_powerup( "insta_kill", "zombie_skull", &"ZOMBIE_POWERUP_INSTA_KILL", ::func_should_always_drop, 0, 0, 0, undefined, "powerup_instant_kill", "zombie_powerup_insta_kill_time", "zombie_powerup_insta_kill_on" );
	add_zombie_powerup( "full_ammo", "zombie_ammocan", &"ZOMBIE_POWERUP_MAX_AMMO", ::func_should_always_drop, 0, 0, 0 );
	add_zombie_powerup( "double_points", "zombie_x2_icon", &"ZOMBIE_POWERUP_DOUBLE_POINTS", ::func_should_never_drop, 0, 0, 0, undefined, "powerup_double_points", "zombie_powerup_point_doubler_time", "zombie_powerup_point_doubler_on" );
	add_zombie_powerup( "carpenter", "zombie_carpenter", &"ZOMBIE_POWERUP_MAX_AMMO", ::func_should_never_drop, 0, 0, 0 );
	add_zombie_powerup( "fire_sale", "zombie_firesale", &"ZOMBIE_POWERUP_MAX_AMMO", ::func_should_never_drop, 0, 0, 0, undefined, "powerup_fire_sale", "zombie_powerup_fire_sale_time", "zombie_powerup_fire_sale_on" );
	add_zombie_powerup( "bonfire_sale", "zombie_pickup_bonfire", &"ZOMBIE_POWERUP_MAX_AMMO", ::func_should_never_drop, 0, 0, 0, undefined, "powerup_bon_fire", "zombie_powerup_bonfire_sale_time", "zombie_powerup_bonfire_sale_on" );
	add_zombie_powerup( "minigun", "zombie_pickup_minigun", &"ZOMBIE_POWERUP_MINIGUN", ::func_should_never_drop, 1, 0, 0, undefined, "powerup_mini_gun", "zombie_powerup_minigun_time", "zombie_powerup_minigun_on" );
	add_zombie_powerup( "free_perk", "zombie_pickup_perk_bottle", &"ZOMBIE_POWERUP_FREE_PERK", ::func_should_never_drop, 0, 0, 0 );
	add_zombie_powerup( "tesla", "zombie_pickup_minigun", &"ZOMBIE_POWERUP_MINIGUN", ::func_should_never_drop, 1, 0, 0, undefined, "powerup_tesla", "zombie_powerup_tesla_time", "zombie_powerup_tesla_on" );
	add_zombie_powerup( "random_weapon", "zombie_pickup_minigun", &"ZOMBIE_POWERUP_MAX_AMMO", ::func_should_never_drop, 1, 0, 0 );
	add_zombie_powerup( "bonus_points_player", "zombie_z_money_icon", &"ZOMBIE_POWERUP_BONUS_POINTS", ::func_should_never_drop, 1, 0, 0 );
	add_zombie_powerup( "bonus_points_team", "zombie_z_money_icon", &"ZOMBIE_POWERUP_BONUS_POINTS", ::func_should_never_drop, 0, 0, 0 );
	add_zombie_powerup( "lose_points_team", "zombie_z_money_icon", &"ZOMBIE_POWERUP_LOSE_POINTS", ::func_should_never_drop, 0, 0, 1 );
	add_zombie_powerup( "lose_perk", "zombie_pickup_perk_bottle", &"ZOMBIE_POWERUP_MAX_AMMO", ::func_should_never_drop, 0, 0, 1 );
	add_zombie_powerup( "empty_clip", "zombie_ammocan", &"ZOMBIE_POWERUP_MAX_AMMO", ::func_should_never_drop, 0, 0, 1 );
	add_zombie_powerup( "insta_kill_ug", "zombie_skull", &"ZOMBIE_POWERUP_INSTA_KILL", ::func_should_never_drop, 1, 0, 0, undefined, "powerup_instant_kill_ug", "zombie_powerup_insta_kill_ug_time", "zombie_powerup_insta_kill_ug_on", 5000 );


    if ( isdefined( level.level_specific_init_powerups ) )
        [[ level.level_specific_init_powerups ]]();

    randomize_powerups();
    level.zombie_powerup_index = 0;
    randomize_powerups();
    level.rare_powerups_active = 0;
    level.firesale_vox_firstime = 0;
    level thread powerup_hud_monitor();

    if ( isdefined( level.quantum_bomb_register_result_func ) )
    {
        [[ level.quantum_bomb_register_result_func ]]( "random_powerup", ::quantum_bomb_random_powerup_result, 5, level.quantum_bomb_in_playable_area_validation_func );
        [[ level.quantum_bomb_register_result_func ]]( "random_zombie_grab_powerup", ::quantum_bomb_random_zombie_grab_powerup_result, 5, level.quantum_bomb_in_playable_area_validation_func );
        [[ level.quantum_bomb_register_result_func ]]( "random_weapon_powerup", ::quantum_bomb_random_weapon_powerup_result, 60, level.quantum_bomb_in_playable_area_validation_func );
        [[ level.quantum_bomb_register_result_func ]]( "random_bonus_or_lose_points_powerup", ::quantum_bomb_random_bonus_or_lose_points_powerup_result, 25, level.quantum_bomb_in_playable_area_validation_func );
    }

    registerclientfield( "scriptmover", "powerup_fx", 1000, 3, "int" );
}

kill_on_downed()
{
	for(;;)
	{
		self waittill ("player_downed");
		self thread bleed_out();
		
		foreach (player in level.players)
		{
			player thread showBelowMessage(self.name + " has been eliminated!", "zmb_weap_wall");
		}
		
		if (if_all_players_eliminated())
		{
			level.winner = self.name;
			level notify ("end_game");
		}
	}
}

if_all_players_eliminated()
{
	foreach (player in get_players())
	{
		if (self.sessionstate == "spectator")
		{
			count += 1;
		}
	}
	
	if (count == level.players.size)
	{
		return true;
	}
	else
	{
		return false;
	}
}

cranked_timer()
{
	self.seconds = level.maxtime;
	miliseconds = 10;
	while(self.timerstarted == 1 && self.seconds > 0)
	{
		if(self.timerpaused == 0)
		{
			self.seconds -= 1;
			miliseconds -= 1;
			if (miliseconds <= 0)
			{
				miliseconds = 10;
				if (self.seconds <= 100)
				{
					self thread red_glow(self.nametarget);
					self playsound ("zmb_box_poof");
				}
			}
		}
		wait 0.1;
	}
	if(level.players.size == 1)
	{
		level.winner = self.name;
	}
	self dodamage(self.health, self.origin);
}

maintain_zombie_count()
{
	while(1)
	{
		level.zombie_total = 40;
		wait 1;
	}
}

red_glow(elem)
{
	self endon("reset_glow");
	colornum = 0;
	while (colornum < 1)
	{
		elem.color = ( 1, colornum, colornum );
		colornum += 0.05;
		wait 0.01;
	}
}

green_glow(elem)
{
	self endon("reset_glow");
	colornum = 0;
	while (colornum < 1)
	{
		elem.color = ( colornum, 1, colornum );
		colornum += 0.05;
		wait 0.01;
	}
}


///////////////////////////////////////////////////
//
//
//
//			[Gamemode Specific Powerups]
//
//
//
//////////////////////////////////////////////////


new_treasure_chest_init( start_chest_name )
{

}

new_weapon_spawn_think()
{

}

new_vending_weapon_upgrade()
{

}

crankedHUD()
{
	level endon("end_game");
	self endon( "disconnect" );
	
	self.nametext = newClientHudElem(self);
	self.nametext.alignx = "left";
	self.nametext.aligny = "center";
	self.nametext.horzalign = "user_left";
	self.nametext.vertalign = "user_center";
	self.nametext.x = 8;
	self.nametext.y = 0;
	self.nametext.fontscale = 2;
	self.nametext.alpha = 1;
	self.nametext.color = ( 1, 1, 1 );
	self.nametext.hidewheninmenu = 1;
	self.nametext.foreground = 1;
	self.nametext setText ("Cranked!");
	
	self.nametarget = newClientHudElem(self);
	self.nametarget.alignx = "left";
	self.nametarget.aligny = "center";
	self.nametarget.horzalign = "user_left";
	self.nametarget.vertalign = "user_center";
	self.nametarget.x = 8;
	self.nametarget.y += 16;
	self.nametarget.fontscale = 3;
	self.nametarget.alpha = 1;
	self.nametarget.color = ( 1, 1, 1 );
	self.nametarget.hidewheninmenu = 1;
	self.nametarget.foreground = 1;
	self.nametarget.label = &"";
//	self.nametarget setText(self.seconds + ":" + self.miliseconds);
	
	while(1)
	{
		self.nametarget setValue (self.seconds/10);
		wait 0.01;
	}

}

get_remaining_player()
{
	foreach (player in level.players)
	{
		if (isAlive(player))
		{
			count += 1;
			ref = player;
		}
	}
	if (count == 1)
	{
		return ref;
	}
	else
	{
		return;
	}
}

loopmaxammo()
{
    while(1)
	{
		if ( self hasweapon( self getcurrentweapon() ) )
			self givemaxammo( self getcurrentweapon() );
		wait 0.1;
	}
}

showBelowMessage(text, sound)
{	
	if(isDefined(self.belowMSD))
	{
		return;
	}
	else
	{
	
		if(isDefined(sound))
			self playsound(sound);

	
		self.belowMSG = newclienthudelem( self );
		self.belowMSG.alignx = "center";
		self.belowMSG.aligny = "bottom";
		self.belowMSG.horzalign = "center";
		self.belowMSG.vertalign = "bottom";
		self.belowMSG.y -= 10;
    
		self.belowMSG.foreground = 1;
		self.belowMSG.fontscale = 4;
		self.belowMSG.alpha = 0;
		self.belowMSG.hidewheninmenu = 1;
		self.belowMSG.font = "default";

		self.belowMSG settext( text );
		self.belowMSG.color = ( 1, 1, 1 );

		self.belowMSG changefontscaleovertime( 0.25 );
		self.belowMSG fadeovertime( 0.25 );
		self.belowMSG.alpha = 1;
		self.belowMSG.fontscale = 2;
    
		wait 3;
    
		self.belowMSG changefontscaleovertime( 0.25 );
		self.belowMSG fadeovertime( 0.25 );
		self.belowMSG.alpha = 0;
		self.belowMSG.fontscale = 4;
		wait 1.1;
		self.belowMSG destroy();
	}
}

init_audio_announcer()
{
    game["zmbdialog"] = [];
    game["zmbdialog"]["prefix"] = "vox_zmba";
    createvox( "boxmove", "event_magicbox" );
    createvox( "dogstart", "event_dogstart" );
    thread init_gamemodespecificvox( getdvar( #"ui_gametype" ), getdvar( #"ui_zm_mapstartlocation" ) );
    level.allowzmbannouncer = 1;
}

powerup_grab_gungame( powerup_team )
{
    if ( isdefined( self ) && self.zombie_grabbable )
    {
        self thread powerup_zombie_grab( powerup_team );
        return;
    }

    self endon( "powerup_timedout" );
    self endon( "powerup_grabbed" );
    range_squared = 4096;

    while ( isdefined( self ) )
    {
        players = get_players();

        for ( i = 0; i < players.size; i++ )
        {
            if ( ( self.powerup_name == "minigun" || self.powerup_name == "tesla" || self.powerup_name == "random_weapon" || self.powerup_name == "meat_stink" ) && ( players[i] maps\mp\zombies\_zm_laststand::player_is_in_laststand() || players[i] usebuttonpressed() && players[i] in_revive_trigger() ) )
                continue;

            if ( isdefined( self.can_pick_up_in_last_stand ) && !self.can_pick_up_in_last_stand && players[i] maps\mp\zombies\_zm_laststand::player_is_in_laststand() )
                continue;

            ignore_range = 0;

            if ( isdefined( players[i].ignore_range_powerup ) && players[i].ignore_range_powerup == self )
            {
                players[i].ignore_range_powerup = undefined;
                ignore_range = 1;
            }

            if ( distancesquared( players[i].origin, self.origin ) < range_squared || ignore_range )
            {
                if ( isdefined( level._powerup_grab_check ) )
                {
                    if ( !self [[ level._powerup_grab_check ]]( players[i] ) )
                        continue;
                }

                if ( isdefined( level.zombie_powerup_grab_func ) )
                    level thread [[ level.zombie_powerup_grab_func ]]();
                else
                {
                    switch ( self.powerup_name )
                    {
                        case "nuke":
                            level thread nuke_powerup( self, players[i].team );
                            players[i] thread powerup_vo( "nuke" );
                            zombies = getaiarray( level.zombie_team );
                            players[i].zombie_nuked = arraysort( zombies, self.origin );
                            players[i] notify( "nuke_triggered" );
                            break;
                        case "full_ammo":
                            level thread full_ammo_powerup( self, players[i] );
                            players[i] thread powerup_vo( "full_ammo" );
                            break;
                        case "double_points":
                            level thread double_points_powerup( self, players[i] );
                            players[i] thread powerup_vo( "double_points" );
                            break;
                        case "insta_kill":
                            level thread insta_kill_powerup( self, players[i] );
                            players[i] thread powerup_vo( "insta_kill" );
                            break;
                        case "carpenter":
                            if ( is_classic() )
                                players[i] thread maps\mp\zombies\_zm_pers_upgrades::persistent_carpenter_ability_check();

                            if ( isdefined( level.use_new_carpenter_func ) )
                                level thread [[ level.use_new_carpenter_func ]]( self.origin);
                            else
                                players[i] thread start_carpenter(self.origin);

                            players[i] thread powerup_vo( "carpenter" );
                            break;
                        case "fire_sale":
                            level thread start_fire_sale( self );
                            players[i] thread powerup_vo( "firesale" );
                            break;
                        case "bonfire_sale":
                            level thread start_bonfire_sale( self );
                            players[i] thread powerup_vo( "firesale" );
                            break;
                        case "minigun":
                            level thread minigun_weapon_powerup( players[i] );
                            players[i] thread powerup_vo( "minigun" );
                            break;
                        case "free_perk":
                            level thread free_perk_powerup( self );
                            break;
                        case "tesla":
                            level thread tesla_weapon_powerup( players[i] );
                            players[i] thread powerup_vo( "tesla" );
                            break;
                        case "random_weapon":
                            if ( !level random_weapon_powerup( self, players[i] ) )
                                continue;

                            break;
                        case "bonus_points_player":
                            level thread bonus_points_player_powerup( self, players[i] );
                            players[i] thread powerup_vo( "bonus_points_solo" );
                            break;
                        case "bonus_points_team":
                            level thread bonus_points_team_powerup( self );
                            players[i] thread powerup_vo( "bonus_points_team" );
                            break;
                        case "teller_withdrawl":
                            level thread teller_withdrawl( self, players[i] );
                            break;
                        default:
                            if ( isdefined( level._zombiemode_powerup_grab ) )
                                level thread [[ level._zombiemode_powerup_grab ]]( self, players[i] );
                            else
                            {
/#
                                println( "Unrecognized poweup." );
#/
                            }

                            break;
                    }
                }

                maps\mp\_demo::bookmark( "zm_player_powerup_grabbed", gettime(), players[i] );

                if ( should_award_stat( self.powerup_name ) )
                {
                    players[i] maps\mp\zombies\_zm_stats::increment_client_stat( "drops" );
                    players[i] maps\mp\zombies\_zm_stats::increment_player_stat( "drops" );
                    players[i] maps\mp\zombies\_zm_stats::increment_client_stat( self.powerup_name + "_pickedup" );
                    players[i] maps\mp\zombies\_zm_stats::increment_player_stat( self.powerup_name + "_pickedup" );
                }

                if ( self.solo )
                {
                    playfx( level._effect["powerup_grabbed_solo"], self.origin );
                    playfx( level._effect["powerup_grabbed_wave_solo"], self.origin );
                }
                else if ( self.caution )
                {
                    playfx( level._effect["powerup_grabbed_caution"], self.origin );
                    playfx( level._effect["powerup_grabbed_wave_caution"], self.origin );
                }
                else
                {
                    playfx( level._effect["powerup_grabbed"], self.origin );
                    playfx( level._effect["powerup_grabbed_wave"], self.origin );
                }

                if ( isdefined( self.stolen ) && self.stolen )
                    level notify( "monkey_see_monkey_dont_achieved" );

                if ( isdefined( self.grabbed_level_notify ) )
                    level notify( self.grabbed_level_notify );

                self.claimed = 1;
                self.power_up_grab_player = players[i];
                wait 0.1;
                playsoundatposition( "zmb_powerup_grabbed", self.origin );
                self stoploopsound();
                self hide();

                if ( self.powerup_name != "fire_sale" )
                {
                    if ( isdefined( self.power_up_grab_player ) )
                    {
                        if ( isdefined( level.powerup_intro_vox ) )
                        {
                            level thread [[ level.powerup_intro_vox ]]( self );
                            return;
                        }
                        else if ( isdefined( level.powerup_vo_available ) )
                        {
                            can_say_vo = [[ level.powerup_vo_available ]]();

                            if ( !can_say_vo )
                            {
                                self powerup_delete();
                                self notify( "powerup_grabbed" );
                                return;
                            }
                        }
                    }
                }

                level thread maps\mp\zombies\_zm_audio_announcer::leaderdialog( self.powerup_name, self.power_up_grab_player.pers["team"] );
                self powerup_delete();
                self notify( "powerup_grabbed" );
            }
        }

        wait 0.1;
    }
}

end_game_minigame()
{
    level waittill( "end_game" );
	
	level.winner = get_remaining_player().name;
	
    check_end_game_intermission_delay();
/#
    println( "end_game TRIGGERED " );
#/
    clientnotify( "zesn" );

    if ( isdefined( level.sndgameovermusicoverride ) )
        level thread maps\mp\zombies\_zm_audio::change_zombie_music( level.sndgameovermusicoverride );
    else
        level thread maps\mp\zombies\_zm_audio::change_zombie_music( "game_over" );

    players = get_players();

    for ( i = 0; i < players.size; i++ )
        setclientsysstate( "lsm", "0", players[i] );

    for ( i = 0; i < players.size; i++ )
    {
        if ( players[i] player_is_in_laststand() )
        {
            players[i] recordplayerdeathzombies();
            players[i] maps\mp\zombies\_zm_stats::increment_player_stat( "deaths" );
            players[i] maps\mp\zombies\_zm_stats::increment_client_stat( "deaths" );
            players[i] maps\mp\zombies\_zm_pers_upgrades_functions::pers_upgrade_jugg_player_death_stat();
        }

        if ( isdefined( players[i].revivetexthud ) )
            players[i].revivetexthud destroy();
    }

    stopallrumbles();
    level.intermission = 1;
    level.zombie_vars["zombie_powerup_insta_kill_time"] = 0;
    level.zombie_vars["zombie_powerup_fire_sale_time"] = 0;
    level.zombie_vars["zombie_powerup_point_doubler_time"] = 0;
    wait 0.1;
    game_over = [];
    survived = [];
    players = get_players();
    setmatchflag( "disableIngameMenu", 1 );

    foreach ( player in players )
    {
        player closemenu();
        player closeingamemenu();
    }

    if ( !isdefined( level._supress_survived_screen ) )
    {
        for ( i = 0; i < players.size; i++ )
        {
            if ( isdefined( level.custom_game_over_hud_elem ) )
                game_over[i] = [[ level.custom_game_over_hud_elem ]]( players[i] );
            else
            {
                game_over[i] = newclienthudelem( players[i] );
                game_over[i].alignx = "center";
                game_over[i].aligny = "middle";
                game_over[i].horzalign = "center";
                game_over[i].vertalign = "middle";
                game_over[i].y = game_over[i].y - 130;
                game_over[i].foreground = 1;
                game_over[i].fontscale = 3;
                game_over[i].alpha = 0;
                game_over[i].color = ( 1, 1, 1 );
                game_over[i].hidewheninmenu = 1;
				if (isDefined(level.winner))
				{
					game_over[i] settext( level.winner + " wins!" );
				}
				else
				{
					game_over[i] settext( "Nobody Wins!" );
				}
                game_over[i] fadeovertime( 1 );
                game_over[i].alpha = 1;

                if ( players[i] issplitscreen() )
                {
                    game_over[i].fontscale = 2;
                    game_over[i].y = game_over[i].y + 40;
                }
            }

            survived[i] = newclienthudelem( players[i] );
            survived[i].alignx = "center";
            survived[i].aligny = "middle";
            survived[i].horzalign = "center";
            survived[i].vertalign = "middle";
            survived[i].y = survived[i].y - 100;
            survived[i].foreground = 1;
            survived[i].fontscale = 2;
            survived[i].alpha = 0;
            survived[i].color = ( 1, 1, 1 );
            survived[i].hidewheninmenu = 1;

            if ( players[i] issplitscreen() )
            {
                survived[i].fontscale = 1.5;
                survived[i].y = survived[i].y + 40;
            }

            if ( level.round_number < 2 )
            {
                if ( level.script == "zombie_moon" )
                {
                    if ( !isdefined( level.left_nomans_land ) )
                    {
                        nomanslandtime = level.nml_best_time;
                        player_survival_time = int( nomanslandtime / 1000 );
                        player_survival_time_in_mins = maps\mp\zombies\_zm::to_mins( player_survival_time );
                        survived[i] settext( &"ZOMBIE_SURVIVED_NOMANS", player_survival_time_in_mins );
                    }
                    else if ( level.left_nomans_land == 2 )
                        survived[i] settext( &"ZOMBIE_SURVIVED_ROUND" );
                }
                else
                    survived[i] settext( "Match has ended" );
            }
            else
                if (isDefined(level.winner))
				{
					survived[i] settext( "Your Score: " + players[i].weaponlevel );
				}
				else
				{
					survived[i] settext( "Match has ended" );
				}

            survived[i] fadeovertime( 1 );
            survived[i].alpha = 1;
        }
    }

    if ( isdefined( level.custom_end_screen ) )
        level [[ level.custom_end_screen ]]();

    for ( i = 0; i < players.size; i++ )
    {
        players[i] setclientammocounterhide( 1 );
        players[i] setclientminiscoreboardhide( 1 );
    }

    uploadstats();
    maps\mp\zombies\_zm_stats::update_players_stats_at_match_end( players );
    maps\mp\zombies\_zm_stats::update_global_counters_on_match_end();
    wait 1;
    wait 3.95;
    players = get_players();

    foreach ( player in players )
    {
        if ( isdefined( player.sessionstate ) && player.sessionstate == "spectator" )
            player.sessionstate = "playing";
    }

    wait 0.05;
    players = get_players();

    if ( !isdefined( level._supress_survived_screen ) )
    {
        for ( i = 0; i < players.size; i++ )
        {
            survived[i] destroy();
            game_over[i] destroy();
        }
    }
    else
    {
        for ( i = 0; i < players.size; i++ )
        {
            if ( isdefined( players[i].survived_hud ) )
                players[i].survived_hud destroy();

            if ( isdefined( players[i].game_over_hud ) )
                players[i].game_over_hud destroy();
        }
    }

    intermission();
    wait( level.zombie_vars["zombie_intermission_time"] );
    level notify( "stop_intermission" );
    array_thread( get_players(), ::player_exit_level );
    bbprint( "zombie_epilogs", "rounds %d", level.round_number );
    wait 1.5;
    players = get_players();

    for ( i = 0; i < players.size; i++ )
        players[i] cameraactivate( 0 );

    exitlevel( 0 );
    wait 666;
}

round_think_minigame( restart )
{
	if(level.crankedstarted == 0)
	{
		level waittill ("end");
	}
	
	if ( !isdefined( restart ) )
        restart = 0;

/#
    println( "ZM >> round_think start" );
#/
    level endon( "end_round_think" );

    if ( !( isdefined( restart ) && restart ) )
    {
        if ( isdefined( level.initial_round_wait_func ) )
            [[ level.initial_round_wait_func ]]();

        if ( !( isdefined( level.host_ended_game ) && level.host_ended_game ) )
        {
            players = get_players();

            foreach ( player in players )
            {
                if ( !( isdefined( player.hostmigrationcontrolsfrozen ) && player.hostmigrationcontrolsfrozen ) )
                {
                    player freezecontrols( 0 );
/#
                    println( " Unfreeze controls 8" );
#/
                }

                player maps\mp\zombies\_zm_stats::set_global_stat( "rounds", level.round_number );
            }
        }
    }

    setroundsplayed( level.round_number );

    for (;;)
    {
        maxreward = 50 * level.round_number;

        if ( maxreward > 500 )
            maxreward = 500;

        level.zombie_vars["rebuild_barrier_cap_per_round"] = maxreward;
        level.pro_tips_start_time = gettime();
        level.zombie_last_run_time = gettime();

        if ( isdefined( level.zombie_round_change_custom ) )
            [[ level.zombie_round_change_custom ]]();
        else
        {
            level thread maps\mp\zombies\_zm_audio::change_zombie_music( "round_start" );
            round_one_up();
        }

        maps\mp\zombies\_zm_powerups::powerup_round_start();
        players = get_players();
        array_thread( players, maps\mp\zombies\_zm_blockers::rebuild_barrier_reward_reset );

        if ( !( isdefined( level.headshots_only ) && level.headshots_only ) && !restart )
            level thread award_grenades_for_survivors();

        bbprint( "zombie_rounds", "round %d player_count %d", level.round_number, players.size );
/#
        println( "ZM >> round_think, round=" + level.round_number + ", player_count=" + players.size );
#/
        level.round_start_time = gettime();

        while ( level.zombie_spawn_locations.size <= 0 )
            wait 0.1;

        level thread [[ level.round_spawn_func ]]();
        level notify( "start_of_round" );
        recordzombieroundstart();
        players = getplayers();

        for ( index = 0; index < players.size; index++ )
        {
            zonename = players[index] get_current_zone();

            if ( isdefined( zonename ) )
                players[index] recordzombiezone( "startingZone", zonename );
        }

        if ( isdefined( level.round_start_custom_func ) )
            [[ level.round_start_custom_func ]]();

        [[ level.round_wait_func ]]();
        level.first_round = 0;
        level notify( "end_of_round" );
//        level thread maps\mp\zombies\_zm_audio::change_zombie_music( "round_end" );
		level thread maps\mp\zombies\_zm_audio::change_zombie_music( "round_start" );
        uploadstats();

        if ( isdefined( level.round_end_custom_logic ) )
            [[ level.round_end_custom_logic ]]();

        players = get_players();

        if ( isdefined( level.no_end_game_check ) && level.no_end_game_check )
        {
            level thread last_stand_revive();
			level thread spectators_respawn();
        }
        else if ( 1 != players.size )
            level thread spectators_respawn();

        players = get_players();
        array_thread( players, maps\mp\zombies\_zm_pers_upgrades_system::round_end );
        timer = level.zombie_vars["zombie_spawn_delay"];

        if ( timer > 0.08 )
            level.zombie_vars["zombie_spawn_delay"] = timer * 0.95;
        else if ( timer < 0.08 )
            level.zombie_vars["zombie_spawn_delay"] = 0.08;

        if ( level.gamedifficulty == 0 )
            level.zombie_move_speed = level.round_number * level.zombie_vars["zombie_move_speed_multiplier_easy"];
        else
            level.zombie_move_speed = level.round_number * level.zombie_vars["zombie_move_speed_multiplier"];

        level.round_number++;

        if ( 255 < level.round_number )
            level.round_number = 255;

        setroundsplayed( level.round_number );
        matchutctime = getutc();
        players = get_players();

        foreach ( player in players )
        {
            if ( level.curr_gametype_affects_rank && level.round_number > 3 + level.start_round )
                player maps\mp\zombies\_zm_stats::add_client_stat( "weighted_rounds_played", level.round_number );

            player maps\mp\zombies\_zm_stats::set_global_stat( "rounds", level.round_number );
            player maps\mp\zombies\_zm_stats::update_playing_utc_time( matchutctime );
        }

        check_quickrevive_for_hotjoin();
        level round_over();
        level notify( "between_round_over" );
        restart = 0;
    }
}

wait_for_ready_input()
{
	level endon ("end");
	level.introHUD setText ("Press [{+melee}] and [{+speed_throw}] to ready up!: ^5" + level.playersready + "/" + level.players.size);
	self waittill ("can_readyup");
	while(1)
	{
		if(self meleebuttonpressed() && self adsbuttonpressed())
		{
			if (self.voted == 0)
			{
				level.playersready += 1;
				self.voted = 1;
				level.introHUD setText ("Press [{+melee}] and [{+speed_throw}] to ready up!: ^5" + level.playersready + "/" + level.players.size);
				if (level.playersready == level.players.size)
				{
					wait 1;

					level.crankedstarted = 1;					

					level thread minigames_timer_hud();
					foreach (player in level.players)
					{
						player disableInvulnerability();
					}
					level notify ("end");
				}
			}
		}
		wait 0.01;
	}
}

introHUD()
{
	flag_wait( "initial_blackscreen_passed" );
	level.introHUD = newhudelem();
	level.introHUD.x = 0;
	level.introHUD.y -= 20;
	level.introHUD.alpha = 1;
	level.introHUD.alignx = "center";
	level.introHUD.aligny = "bottom";
    level.introHUD.horzalign = "user_center";
    level.introHUD.vertalign = "user_bottom";
	level.introHUD.foreground = 0;
	level.introHUD.fontscale = 1.5;
	level.introHUD setText ("Press [{+melee}] and [{+speed_throw}] to ready up!: ^5" + level.playersready + "/" + level.players.size);
	level waittill ("end");
	level.introHUD fadeovertime( 0.25 );
	level.introHUD.alpha = 0;
	level.introHUD destroy();
}

round_over_minigame()
{
    if ( isdefined( level.noroundnumber ) && level.noroundnumber == 1 )
        return;

    time = level.zombie_vars["zombie_between_round_time"];
    players = getplayers();

    for ( player_index = 0; player_index < players.size; player_index++ )
    {
        if ( !isdefined( players[player_index].pers["previous_distance_traveled"] ) )
            players[player_index].pers["previous_distance_traveled"] = 0;

        distancethisround = int( players[player_index].pers["distance_traveled"] - players[player_index].pers["previous_distance_traveled"] );
        players[player_index].pers["previous_distance_traveled"] = players[player_index].pers["distance_traveled"];
        players[player_index] incrementplayerstat( "distance_traveled", distancethisround );

        if ( players[player_index].pers["team"] != "spectator" )
        {
            zonename = players[player_index] get_current_zone();

            if ( isdefined( zonename ) )
                players[player_index] recordzombiezone( "endingZone", zonename );
        }
    }

    recordzombieroundend();
}

minigames_timer_hud()
{
	hud = newHudElem();
	hud.alignx = "left";
	hud.aligny = "top";
	hud.horzalign = "user_left";
	hud.vertalign = "user_top";
	hud.x = 25;
	hud.y += 24;
	hud.fontscale = 2;
	hud.alpha = 0;
	hud.color = ( 1, 1, 1 );
	hud.hidewheninmenu = 1;
	hud.foreground = 0;
	hud.label = &"";

	hud endon("death");

	hud.alpha = 1;

	hud thread set_time_frozen_on_end_game();

	if ( !flag( "initial_blackscreen_passed" ) )
	{
		hud set_time_frozen(0, "initial_blackscreen_passed");
	}

	if ( getDvar( "g_gametype" ) == "zgrief" )
	{
		hud set_time_frozen(0);
	}

	hud setTimerUp(0);
	hud.start_time = getTime();
	level.timer_hud_start_time = hud.start_time;
	level waittill ("end_game");
	hud destroy();
}

round_wait_minigame()
{
    level endon( "restart_round" );
/#
    if ( getdvarint( #"zombie_rise_test" ) )
        level waittill( "forever" );
#/
/#
    if ( getdvarint( #"zombie_cheat" ) == 2 || getdvarint( #"zombie_cheat" ) >= 4 )
        level waittill( "forever" );
#/
	level waittill ("force_next_round");

    wait 1;

    if ( flag( "dog_round" ) )
    {
        wait 7;

        while ( level.dog_intermission )
            wait 0.5;

        increment_dog_round_stat( "finished" );
    }
    else
    {
        while ( true )
        {
            should_wait = 0;

            if ( isdefined( level.is_ghost_round_started ) && [[ level.is_ghost_round_started ]]() )
                should_wait = 1;
			else if (( isdefined( level.next_leaper_round ) && level.next_leaper_round == ( level.round_number + 1 )))
                should_wait = 1;
            else
                should_wait = 0;

            if ( !should_wait )
                return;

            if ( flag( "end_round_wait" ) )
                return;
			
            wait 1.0;
        }
    }
}

nextroundtimer()
{
	count = 0;
	while(1)
	{
		count += 1;
		if (count == 40)
		{
			count = 0;
			level notify ("force_next_round");
			level.roundspassed += 1;
			if (level.roundspassed == 5)
			{
				level.roundspassed = 0;
				if(level.maxtime > 50)
				{
					level.maxtime -= 50;
					foreach (player in level.players)
					{
						player thread showBelowMessage("The timer shrinks!", "zmb_weap_wall");
					}
				}
				else if (level.maxtime == 50)
				{
					level.maxtime -= 10;
					foreach (player in level.players)
					{
						player thread showBelowMessage("The timer shrinks the last time!", "zmb_weap_wall");
					}				
				}
			}
		}
		wait 1;
	}
}

startHUDMessage()
{
	flag_wait( "initial_blackscreen_passed" );
	
	hud = newClientHudElem(self);
	hud.alignx = "center";
	hud.aligny = "top";
	hud.horzalign = "user_center";
	hud.vertalign = "user_top";
	hud.x = 0;
	hud.y += 24;
	hud.fontscale = 3;
	hud.alpha = 0;
	hud.color = ( 1, 1, 1 );
	hud.hidewheninmenu = 1;
	hud.foreground = 1;
	hud settext("TechnoOps Collection:");
	hud.fontscale = 3;
	hud changefontscaleovertime( 1 );
    hud fadeovertime( 1 );
    hud.alpha = 1;
    hud.fontscale = 1.5;

	wait 1;

	hud2 = newClientHudElem(self);
	hud2.alignx = "center";
	hud2.aligny = "top";
	hud2.horzalign = "user_center";
	hud2.vertalign = "user_top";
	hud2.x = 0;
	hud2.y += 42;
	hud2.fontscale = 8;
	hud2.alpha = 0;
	hud2.color = ( 1, 1, 1 );
	hud2.hidewheninmenu = 1;
	hud2.foreground = 1;

	hud2 settext("Cranked");
	hud2.fontscale = 8;
	hud2 changefontscaleovertime( 1 );
    hud2 fadeovertime( 1 );
    hud2.alpha = 1;
    hud2.fontscale = 4;

	wait 1;
	
	hud3 = newClientHudElem(self);
	hud3.alignx = "center";
	hud3.aligny = "top";
	hud3.horzalign = "user_center";
	hud3.vertalign = "user_top";
	hud3.x = 0;
	hud3.y += 90;
	hud3.fontscale = 2;
	hud3.alpha = 0;
	hud3.color = ( 1, 1, 1 );
	hud3.hidewheninmenu = 1;
	hud3.foreground = 1;

	hud3 settext("Get kills to reset the timer, when timer reaches zero, youre eliminated!");

	hud3.fontscale = 2;
	hud3 changefontscaleovertime( 1 );
    hud3 fadeovertime( 1 );
    hud3.alpha = 1;
    hud3.fontscale = 1.5;
	wait 1;
	self notify ("can_readyup");

	level waittill ("end");


    hud changefontscaleovertime( 1 );
    hud fadeovertime( 1 );
    hud.alpha = 0;
    hud.fontscale = 4;
//    wait 1;
	
    hud2 changefontscaleovertime( 1 );
    hud2 fadeovertime( 1 );
    hud2.alpha = 0;
    hud2.fontscale = 6;
//    wait 1;
	
    hud3 changefontscaleovertime( 1 );
    hud3 fadeovertime( 1 );
    hud3.alpha = 0;
    hud3.fontscale = 2;
    wait 1;
	
	hud destroy();
	hud2 destroy();
	hud3 destroy();
}


init_gamemode_powerups()
{
    if(isDefined(level._zombiemode_powerup_grab))
		level.original_zombiemode_powerup_grab = level._zombiemode_powerup_grab;

    level._zombiemode_powerup_grab = ::custom_powerup_grab;

   	include_zombie_powerup("unlimited_ammo");
   	level.unlimited_ammo_duration = 30;
   	add_zombie_powerup("unlimited_ammo", "T6_WPN_AR_GALIL_WORLD", &"ZOMBIE_POWERUP_UNLIMITED_AMMO", ::func_should_always_drop, 0, 0, 0);
	powerup_set_can_pick_up_in_last_stand("unlimited_ammo", 1);

	include_zombie_powerup("pause_timer");
	level.pause_timer_duration = 10;
	add_zombie_powerup("pause_timer", "zombie_teddybear", &"ZOMBIE_POWERUP_PAUSE_TIMER", ::func_paused_timer, 0, 0, 0);
	powerup_set_can_pick_up_in_last_stand("pause_timer", 1);
}



custom_powerup_grab(s_powerup, e_player)
{
	if (s_powerup.powerup_name == "unlimited_ammo")
		e_player thread unlimited_ammo_powerup();
		
	else if (s_powerup.powerup_name == "pause_timer")
		e_player thread pause_timer_powerup();

	
	//pass args onto the original custom powerup grab function
	else if (isDefined(level.original_zombiemode_powerup_grab))
		level thread [[level.original_zombiemode_powerup_grab]](s_powerup, e_player);
}

unlimited_ammo_powerup()
{
	self notify("end_unlimited_ammo");
	self playsound("zmb_cha_ching");
	self thread turn_on_unlimited_ammo();
	self thread unlimited_ammo_on_hud();
	self thread notify_unlimited_ammo_end();
}

pause_timer_powerup()
{
	self notify("end_pause_timer");
	self playsound("zmb_cha_ching");
	self thread turn_on_pause_timer();
	self thread pause_timer_on_hud();
	self thread notify_pause_timer_end();
}

unlimited_ammo_on_hud()
{
	self endon("disconnect");
	//hud elems for text & icon
	unlimited_ammo_hud_string = newclienthudelem(self);
	unlimited_ammo_hud_string.elemtype = "font";
	unlimited_ammo_hud_string.font = "objective";
	unlimited_ammo_hud_string.fontscale = 2;
	unlimited_ammo_hud_string.x = 0;
	unlimited_ammo_hud_string.y = 0;
	unlimited_ammo_hud_string.width = 0;
	unlimited_ammo_hud_string.height = int( level.fontheight * 2 );
	unlimited_ammo_hud_string.xoffset = 0;
	unlimited_ammo_hud_string.yoffset = 0;
	unlimited_ammo_hud_string.children = [];
	unlimited_ammo_hud_string setparent(level.uiparent);
	unlimited_ammo_hud_string.hidden = 0;
	unlimited_ammo_hud_string maps\mp\gametypes_zm\_hud_util::setpoint("TOP", undefined, 0, level.zombie_vars["zombie_timer_offset"] - (level.zombie_vars["zombie_timer_offset_interval"] * 2));
	unlimited_ammo_hud_string.sort = .5;
	unlimited_ammo_hud_string.alpha = 0;
	unlimited_ammo_hud_string fadeovertime(.5);
	unlimited_ammo_hud_string.alpha = 1;

	unlimited_ammo_hud_string setText("Bottomless Clip!");
	unlimited_ammo_hud_string thread unlimited_ammo_hud_string_move();
	
	unlimited_ammo_hud_icon = newclienthudelem(self);
	unlimited_ammo_hud_icon.horzalign = "center";
	unlimited_ammo_hud_icon.vertalign = "bottom";
	unlimited_ammo_hud_icon.x = -75;
	unlimited_ammo_hud_icon.y = 0;
	unlimited_ammo_hud_icon.alpha = 1;
	unlimited_ammo_hud_icon.hidewheninmenu = true;   
	unlimited_ammo_hud_icon setshader("menu_mp_weapons_1911", 40, 40);
	self thread unlimited_ammo_hud_icon_blink(unlimited_ammo_hud_icon);
	self thread destroy_unlimited_ammo_icon_hud(unlimited_ammo_hud_icon);
}

unlimited_ammo_hud_string_move()
{
	wait .5;
	self fadeovertime(1.5);
	self moveovertime(1.5);
	self.y = 270;
	self.alpha = 0;
	wait 1.5;
	self destroy();
}

unlimited_ammo_hud_icon_blink(elem)
{
	level endon("disconnect");
	self endon("disconnect");
	self endon("end_unlimited_ammo");
	time_left = level.unlimited_ammo_duration;
	for(;;)
	{
		//less than 5sec left on powerup, blink fast
		if(time_left <= 5)
			time = .1;
		//less than 10sec left on powerup, blink
		else if(time_left <= 10)
			time = .2;
		//over 20sec left, dont blink
		else
		{
			wait .05;
			time_left -= .05;
			continue;
		}
		elem fadeovertime(time);
		elem.alpha = 0;
		wait time;
		elem fadeovertime(time);
		elem.alpha = 1;
		wait time;
		time_left -= time * 2;
	}
}

destroy_unlimited_ammo_icon_hud(elem)
{
	level endon("game_ended");
	self waittill_any_timeout(level.unlimited_ammo_duration+1, "disconnect", "end_unlimited_ammo");
	elem destroy();
}

turn_on_unlimited_ammo()
{
	level endon("game_ended");
	self endon("disonnect");
	self endon("end_unlimited_ammo");
	for(;;)
	{
		self setWeaponAmmoClip(self GetCurrentWeapon(), 150);
		wait .05;
	}
}

notify_unlimited_ammo_end()
{
	level endon("game_ended");
	self endon("disonnect");
	self endon("end_unlimited_ammo");
	wait level.unlimited_ammo_duration;
	//the same sound that plays when instakill powerup ends
	self playsound("zmb_insta_kill");
	self notify("end_unlimited_ammo");
}

pause_timer_on_hud()
{
	self endon("disconnect");
	//hud elems for text & icon
	pause_timer_hud_string = newclienthudelem(self);
	pause_timer_hud_string.elemtype = "font";
	pause_timer_hud_string.font = "objective";
	pause_timer_hud_string.fontscale = 2;
	pause_timer_hud_string.x = 0;
	pause_timer_hud_string.y = 0;
	pause_timer_hud_string.width = 0;
	pause_timer_hud_string.height = int( level.fontheight * 2 );
	pause_timer_hud_string.xoffset = 0;
	pause_timer_hud_string.yoffset = 0;
	pause_timer_hud_string.children = [];
	pause_timer_hud_string setparent(level.uiparent);
	pause_timer_hud_string.hidden = 0;
	pause_timer_hud_string maps\mp\gametypes_zm\_hud_util::setpoint("TOP", undefined, 0, level.zombie_vars["zombie_timer_offset"] - (level.zombie_vars["zombie_timer_offset_interval"] * 2));
	pause_timer_hud_string.sort = .5;
	pause_timer_hud_string.alpha = 0;
	pause_timer_hud_string fadeovertime(.5);
	pause_timer_hud_string.alpha = 1;

	pause_timer_hud_string setText("Timer Paused!");
	pause_timer_hud_string thread pause_timer_hud_string_move();
	
	pause_timer_hud_icon = newclienthudelem(self);
	pause_timer_hud_icon.horzalign = "center";
	pause_timer_hud_icon.vertalign = "bottom";
	pause_timer_hud_icon.x = -120;
	pause_timer_hud_icon.y = 0;
	pause_timer_hud_icon.alpha = 1;
	pause_timer_hud_icon.hidewheninmenu = true;   
	pause_timer_hud_icon setshader("demo_pause", 40, 40);
	self thread pause_timer_hud_icon_blink(pause_timer_hud_icon);
	self thread destroy_pause_timer_icon_hud(pause_timer_hud_icon);
}

pause_timer_hud_string_move()
{
	wait .5;
	self fadeovertime(1.5);
	self moveovertime(1.5);
	self.y = 270;
	self.alpha = 0;
	wait 1.5;
	self destroy();
}

pause_timer_hud_icon_blink(elem)
{
	level endon("disconnect");
	self endon("disconnect");
	self endon("end_pause_timer");
	time_left = level.pause_timer_duration;
	for(;;)
	{
		//less than 5sec left on powerup, blink fast
		if(time_left <= 5)
			time = .1;
		//less than 10sec left on powerup, blink
		else if(time_left <= 10)
			time = .2;
		//over 20sec left, dont blink
		else
		{
			wait .05;
			time_left -= .05;
			continue;
		}
		elem fadeovertime(time);
		elem.alpha = 0;
		wait time;
		elem fadeovertime(time);
		elem.alpha = 1;
		wait time;
		time_left -= time * 2;
	}
}

destroy_pause_timer_icon_hud(elem)
{
	level endon("game_ended");
	self waittill_any_timeout(level.pause_timer_duration+1, "disconnect", "end_pause_timer");
	elem destroy();
}

turn_on_pause_timer()
{
	level endon("game_ended");
	self endon("disonnect");
	self endon("end_pause_timer");
	self.timerpaused = 1;
}

notify_pause_timer_end()
{
	level endon("game_ended");
	self endon("disonnect");
	self endon("end_pause_timer");
	wait level.pause_timer_duration;
	//the same sound that plays when instakill powerup ends
	self playsound("zmb_insta_kill");
	self.timerpaused = 0;
	self notify("end_pause_timer");
}

func_paused_timer()
{
	foreach (player in get_players())
	{
		if (player.timerpaused == 1)
		{
			return false;
		}
	}
	return true;
}

betaMessage()
{
	betamessage = newhudelem();
	betamessage.x -= 15;
	betamessage.y -= 20;
	betamessage.alpha = 0.2;
    betamessage.horzalign = "right";
    betamessage.vertalign = "top";
	betamessage.foreground = 1;
	betamessage setText ("TechnoOps Collection\nCranked Beta\nb0.5");
}

set_time_frozen(time, endon_notify)
{
	if ( isDefined( endon_notify ) )
	{
		level endon( endon_notify );
	}
	else if ( getDvar( "g_gametype" ) == "zgrief" )
	{
		level endon( "restart_round_start" );
	}
	else
	{
		level endon( "start_of_round" );
	}

	self endon( "death" );

	if(time != 0)
	{
		time -= 0.5; // need to set it below the number or it shows the next number
	}

	while (1)
	{
		if(time == 0)
		{
			self setTimerUp(time);
		}
		else
		{
			self setTimer(time);
		}

		wait 0.5;
	}
}

set_time_frozen_on_end_game()
{
	level endon("intermission");

	level waittill_any("end_game", "freeze_timers");

	time = int((getTime() - self.start_time) / 1000);

	self set_time_frozen(time, "forever");
}

actor_killed_override( einflictor, attacker, idamage, smeansofdeath, sweapon, vdir, shitloc, psoffsettime )
{
    if ( game["state"] == "postgame" )
        return;

    if ( isai( attacker ) && isdefined( attacker.script_owner ) )
    {
        if ( attacker.script_owner.team != self.aiteam )
            attacker = attacker.script_owner;
    }

    if ( attacker.classname == "script_vehicle" && isdefined( attacker.owner ) )
        attacker = attacker.owner;

    if ( isdefined( attacker ) && isplayer( attacker ) )
    {
        multiplier = 1;

        if ( is_headshot( sweapon, shitloc, smeansofdeath ) )
            multiplier = 1.5;

        type = undefined;

        if ( isdefined( self.animname ) )
        {
            switch ( self.animname )
            {
                case "quad_zombie":
                    type = "quadkill";
                    break;
                case "ape_zombie":
                    type = "apekill";
                    break;
                case "zombie":
                    type = "zombiekill";
                    break;
                case "zombie_dog":
                    type = "dogkill";
                    break;
            }
        }
		
		if (attacker.timerstarted == 0)
		{
			attacker.timerstarted = 1;
			attacker thread cranked_timer();
			attacker thread showBelowMessage("Let the carnage begin!", "zmb_weap_wall");
		}
		else
		{
			if (attacker.seconds < level.maxtime)
			{
				attacker.seconds = level.maxtime;
			}
		}
		attacker notify("reset_glow");
		attacker thread green_glow(attacker.nametarget);
		
    }

    if ( isdefined( self.is_ziplining ) && self.is_ziplining )
        self.deathanim = undefined;

    if ( isdefined( self.actor_killed_override ) )
        self [[ self.actor_killed_override ]]( einflictor, attacker, idamage, smeansofdeath, sweapon, vdir, shitloc, psoffsettime );
}