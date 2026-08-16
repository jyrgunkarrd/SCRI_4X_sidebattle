return
{

    -- Agents --

    {

        id = "mam",
        name = "Mammoth",
        scale = 1.2,
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
        shout = {

            { select = "As a river bends" },

        },
        def_sfx = "fem", 

    },

    -- Units -- 

    {

        id = "blakber",
        name = "Black Beret",
        scale = 1,
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
        shout = {

            { select = "Popping smoke" },

        },
        def_sfx = "fem", 

    },

    {

        id = "vic",
        name = "Vicky",
        scale = 1.1,
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
        shout = {

            { select = "Fully functional" },

        },
        def_sfx = "fem", 

    },    

    {

        id = "ifvjunk",
        name = "Antique IFV",
        scale = 1.9,
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
        shout = {

            { select = "On station" },

        },
        def_sfx = "expl", 

    }, 

}