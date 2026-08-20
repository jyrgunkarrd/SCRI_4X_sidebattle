return

{

    {

        -- General --

        id = "en_forg",
        name = "Forgiven",
        start_faction = "enemy",
        shout = {

            { select = "Here" },

        },

        -- Arena --

        scale = 1,
        layer = 1,
        h_mov = 3,
        size = 2,
        hp = 20,
        m_atk = {

            { type = "multihit" },
            { dmg = 5 },
            { img = "sml_arms" },

        },
        tags = {

            "assault",
            "meat",

        },
        def_sfx = "masc", 

        -- World Map --

        map_move = 2,

    },

    {

        -- General --

        id = "en_6wifv",
        name = "6-Wheeled IFV",
        start_faction = "enemy",
        shout = {

            { select = "Here" },

        },

        -- Arena --

        scale = 2,
        layer = 3,
        h_mov = 5,
        size = 4,
        hp = 85,
        armor = 75,
        r_atk = {

            { rng_opt = 3 },
            { rng_max = 6 },
            { type = "multihit" },
            { dmg = 7 },
            { img = "hvy_arms" },

        },
        tags = {

            "vehicle",
            "machine",

        },
        move_sfx = "veh",
        def_sfx = "expl", 

        -- World Map --

        map_move = 2,

    },    

}
