return

{

    {

        id = "en_forg",
        name = "Forgiven",
        enemy = true,
        scale = 1,
        h_mov = 3,
        size = 2,
        hp = 20,
        m_atk = {

            { type = "multihit" },
            { dmg = 5 },
            { img = "sml_arms" },

        },
        shout = {

            { select = "Here" },

        },
        def_sfx = "masc", 

    },

    {

        id = "en_6wifv",
        name = "6-Wheeled IFV",
        enemy = true,
        scale = 2,
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
        move_sfx = "veh",
        shout = {

            { select = "Wagon reporting" },

        },

    },    

}