return
{

    -- Agents --

    {

        -- General -- 

        id = "mam",
        name = "Mammoth",
        start_faction = "player",
        shout = {

            { select = "As a river bends" },

        },

        -- Arena --

        scale = 1.2,
        layer = 3,
        h_mov = 4,
        size = 2,
        hp = 40,
        m_atk = {

            { type = "multihit" },
            { dmg = 6 }, 
            { img = "shank" },

        },
        tags = {

            "assault",
            "demon",
            "lex",

        },
        def_sfx = "masc_mon", 

        -- World Map --

        map_move = 2,
        stack_prio = 1,

    },

    -- Units -- 

    {

        -- General --

        id = "blakber",
        name = "Black Beret",
        start_faction = "player",
        shout = {

            { select = "Popping smoke" },

        },

        -- Arena --

        scale = 1,
        layer = 1,
        h_mov = 4,
        size = 2,
        hp = 40,
        m_atk = {

            { type = "multihit" },
            { dmg = 6 }, 
            { img = "shank" },

        },
        tags = {

            "assault",
            "meat",

        },
        def_sfx = "fem", 

        -- World Map --

        map_move = 2,
        stack_prio = 12,
    },

    {

        -- General -- 

        id = "vic",
        name = "Vicky",
        start_faction = "player",
        shout = {

            { select = "Fully functional" },

        },

        -- Arena --

        scale = 1.1,
        layer = 2,
        h_mov = 3,
        size = 3,
        hp = 60,
        armor = 25,
        m_atk = {

            { dmg = 12 }, 
            { pen = 75 },
            { img = "pnch" },

        },
        r_atk = {

            { rng_opt = 3 },
            { rng_max = 6 },
            { type = "multihit" },
            { dmg = 6 }, 
            { img = "sml_arms" },

        },
        tags = {

            "assault",
            "machine",
            "droid",
            "last war",

        },
        def_sfx = "fem", 

         -- World Map --

        map_move = 2,
        stack_prio = 10,
    },    

    {

        -- General --

        id = "ifvjunk",
        name = "Antique IFV",
        start_faction = "player",
        shout = {

            { select = "On station" },

        },

         -- Arena --

        scale = 1.9,
        layer = 10,
        h_mov = 5,
        size = 4,
        hp = 65,
        armor = 50,
        r_atk = {

            { rng_opt = 3 },
            { rng_max = 6 },
            { dmg = 12 }, 
            { pen = 25 },
            { img = "hvy_arms" },
        },
        move_sfx = "veh",
        tags = {

            "vehicle",
            "machine",
            "last war",

        },
        def_sfx = "expl", 

        -- World Map --

        map_move = 4,
        stack_prio = 5,
    }, 

}
