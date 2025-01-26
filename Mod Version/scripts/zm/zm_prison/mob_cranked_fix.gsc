#include maps\mp\_utility;
#include maps\_utility;
#include maps\_effects;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_ai_brutus;
#include maps\mp\zombies\_zm_afterlife;
#include maps\mp\zm_alcatraz_classic;


main()
{
	if(getDvarInt("enable_cranked") == 1)
	{
		replacefunc(maps\mp\zombies\_zm_ai_brutus::wait_on_box_alarm, ::wait_on_box_alarm_new);
		replacefunc(maps\mp\zombies\_zm_ai_brutus::get_best_brutus_spawn_pos, ::get_best_brutus_spawn_pos_new);
		replacefunc(maps\mp\zm_prison::alcatraz_afterlife_doors, ::alcatraz_afterlife_doors_new);
		replacefunc(maps\mp\zm_alcatraz_classic::fake_kill_player, ::fake_kill_player_new);
		replacefunc(maps\mp\zombies\_zm_afterlife::init, ::init_afterlife);
		replacefunc(maps\mp\zm_alcatraz_classic::power_on_perk_machines, ::power_on_perk_machines_new);
	}
}

power_on_perk_machines_new()
{
    a_shockboxes = getentarray( "perk_afterlife_trigger", "script_noteworthy" );

    foreach ( e_shockbox in a_shockboxes )
    {
        e_shockbox notify( "damage", 1, level );
        wait 1;
    }
}

init_afterlife()
{
    level.zombiemode_using_afterlife = 1;
    flag_init( "afterlife_start_over" );
    level.afterlife_revive_tool = "syrette_afterlife_zm";
    precacheitem( level.afterlife_revive_tool );
    precachemodel( "drone_collision" );
    maps\mp\_visionset_mgr::vsmgr_register_info( "visionset", "zm_afterlife", 9000, 120, 1, 1 );
    maps\mp\_visionset_mgr::vsmgr_register_info( "overlay", "zm_afterlife_filter", 9000, 120, 1, 1 );

    registerclientfield( "toplayer", "player_lives", 9000, 2, "int" );
    registerclientfield( "toplayer", "player_in_afterlife", 9000, 1, "int" );
    registerclientfield( "toplayer", "player_afterlife_mana", 9000, 5, "float" );
    registerclientfield( "allplayers", "player_afterlife_fx", 9000, 1, "int" );
    registerclientfield( "toplayer", "clientfield_afterlife_audio", 9000, 1, "int" );
    registerclientfield( "toplayer", "player_afterlife_refill", 9000, 1, "int" );
    registerclientfield( "scriptmover", "player_corpse_id", 9000, 3, "int" );
    afterlife_load_fx();
    level thread afterlife_hostmigration();
    precachemodel( "c_zom_ghost_viewhands" );
    precachemodel( "c_zom_hero_ghost_fb" );
    precacheitem( "lightning_hands_zm" );
    precachemodel( "p6_zm_al_shock_box_on" );
    precacheshader( "waypoint_revive_afterlife" );
    a_afterlife_interact = getentarray( "afterlife_interact", "targetname" );
    array_thread( a_afterlife_interact, ::afterlife_interact_object_think );
    level.zombie_spawners = getentarray( "zombie_spawner", "script_noteworthy" );
    array_thread( level.zombie_spawners, ::add_spawn_function, ::afterlife_zombie_damage );
    a_afterlife_triggers = getstructarray( "afterlife_trigger", "targetname" );

    foreach ( struct in a_afterlife_triggers )
        afterlife_trigger_create( struct );

    level.afterlife_interact_dist = 256;
    level.is_player_valid_override = ::is_player_valid_afterlife;
    level.can_revive = ::can_revive_override;
    level.round_prestart_func = ::afterlife_start_zombie_logic;
    level.custom_pap_validation = ::is_player_valid_afterlife;
    level.player_out_of_playable_area_monitor_callback = ::player_out_of_playable_area;
    level thread afterlife_gameover_cleanup();
    level.afterlife_get_spawnpoint = ::afterlife_get_spawnpoint;
    level.afterlife_zapped = ::afterlife_zapped;
    level.afterlife_give_loadout = ::afterlife_give_loadout;
    level.afterlife_save_loadout = ::afterlife_save_loadout;
}


wait_on_box_alarm_new()
{
    while ( true )
    {
        self.zbarrier waittill( "randomization_done" );
        level.num_pulls_since_brutus_spawn++;

        if ( level.brutus_in_grief )
            level.brutus_min_pulls_between_box_spawns = randomintrange( 7, 10 );

        if ( level.num_pulls_since_brutus_spawn >= level.brutus_min_pulls_between_box_spawns )
        {
            rand = randomint( 1000 );

            if ( level.brutus_in_grief )
                level notify( "spawn_brutus", 1 );
            else if ( rand <= level.brutus_alarm_chance )
            {
                if ( flag( "moving_chest_now" ) )
                    continue;

                if ( attempt_brutus_spawn( 1 ) )
                {
                    if ( level.next_brutus_round == level.round_number + 1 )
                        level.next_brutus_round++;

                    level.brutus_alarm_chance = level.brutus_min_alarm_chance;
                }
            }
            else if ( level.brutus_alarm_chance < level.brutus_max_alarm_chance )
                level.brutus_alarm_chance = level.brutus_alarm_chance + level.brutus_alarm_chance_increment;
        }
		wait 0.1;
    }
}

get_best_brutus_spawn_pos_new( zone_name )
{

}

#using_animtree("fxanim_props");

alcatraz_afterlife_doors_new()
{
    wait 0.05;

    if ( !isdefined( level.shockbox_anim ) )
    {
        level.shockbox_anim["on"] = %fxanim_zom_al_shock_box_on_anim;
        level.shockbox_anim["off"] = %fxanim_zom_al_shock_box_off_anim;
    }

    if ( isdefined( self.script_noteworthy ) && self.script_noteworthy == "afterlife_door" )
    {
        self sethintstring( &"ZM_PRISON_AFTERLIFE_DOOR" );
/#
        self thread afterlife_door_open_sesame();
#/
        s_struct = getstruct( self.target, "targetname" );

        if ( !isdefined( s_struct ) )
        {
/#
            iprintln( "Afterlife Door was not targeting a valid struct" );
#/
            return;
        }
        else
        {
            m_shockbox = getent( s_struct.target, "targetname" );
            m_shockbox.health = 5000;
            m_shockbox setcandamage( 1 );
            m_shockbox useanimtree( #animtree );
            t_bump = spawn( "trigger_radius", m_shockbox.origin, 0, 28, 64 );
            t_bump.origin = m_shockbox.origin + anglestoforward( m_shockbox.angles ) * 0 + anglestoright( m_shockbox.angles ) * 28 + anglestoup( m_shockbox.angles ) * 0;

            if ( isdefined( t_bump ) )
            {
                t_bump setcursorhint( "HINT_NOICON" );
                t_bump sethintstring( &"ZM_PRISON_AFTERLIFE_INTERACT" );
            }

            while ( true )
            {
				if (1)
                {
                    if ( isdefined( level.afterlife_interact_dist ) )
                    {
						if(1)
                        {
                            t_bump delete();
                            m_shockbox playsound( "zmb_powerpanel_activate" );
                            playfxontag( level._effect["box_activated"], m_shockbox, "tag_origin" );
                            m_shockbox setmodel( "p6_zm_al_shock_box_on" );
                            m_shockbox setanim( level.shockbox_anim["on"] );

                            if ( isdefined( m_shockbox.script_string ) && ( m_shockbox.script_string == "wires_shower_door" || m_shockbox.script_string == "wires_admin_door" ) )
                                array_delete( getentarray( m_shockbox.script_string, "script_noteworthy" ) );

                            break;
                        }
                    }
                }
            }
        }
    }
    else
    {
        while ( true )
        {
            if ( !self maps\mp\zombies\_zm_blockers::door_buy() )
                continue;

            break;
        }
    }
}

fake_kill_player_new( n_start_pos )
{

}