return
{

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
        hp = 40,
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
        hp = 40,
        r_atk = {

            { rng_opt = 3 },
            { rng_max = 6 },
            { dmg = 12 }, 
            { pen = 25 },
            { img = "hvy_arms" },
        },
        move_sfx = "veh",
        shout = {

            { select = "On station" },

        },
        def_sfx = "expl", 

    }, 

}