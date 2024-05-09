playerRoles = {
    ["PRIMARY"] = {"MAIN TANK", "HEALER 1", "OFF TANK", "HEALER 2", "HEALER 3", "HEALER 4", "HEALER 5"},
    ["BUFF"] = {"REZOS DE ESPIRITU, PROTECCION Y ENTEREZA","DON DE LO SALVAJE","SALVAGUARDA", "PODERIO", "REYES", "SABIDURIA", "ENFOQUE", "TOTEM DE MANA", "TOTEM DE CORRIENTE DE SANACION", "AURA DE DISPARO CERTERO", "VIGILANCIA", "GRITO DE ORDEN", "GRITO DE BATALLA", "GRITO DESMORALIZADOR"},
    ["SKILL"] = {"SECRETOS DEL OFICIO", "REDIRECCION", "TRAMPA DE ESCARCHA", "TOTEM DE NEXO TERRESTRE", "DESACTIVAR TRAMPA", "HEROISMO", "POLIMORFIA", "ENCADENAR NO MUERTO", "TIFON", "MIEDO", "COLERA SAGRADA", "RAICES ENREDADORAS", "AHUYENTAR EL MAL", "MAESTRIA EN AURAS", "PIEDRA DE ALMA", "MANO DE SALVACION", "IMPOSICION DE MANOS", "MANO DE SACRIFICIO", "MANO DE SALVACION"},
    ["SECONDARY"] = {"FRAGMENTADOR", "AYUDANTE", "RESUCITAR CAIDOS", "RITUAL DE INVOCACION", "RITUAL DE REFRIGERIO"}
}

rulesAndMechanics = {
    ["AFK/OFFs"] = {
        ["RULES"] = {
            ["SHARED"] = {"El jugador que se quede AFK/OFF por mucho tiempo sin avisar, no siga mecanincas o tenga DPS debajo del Tanque se queda sin loteo y puede ser expulsado de la raid."}
        }
    },
    ["LA CAMARA DE ARCHAVON"] = {
        ["RULES"] = {
            ["SHARED"] = {"PRIORIDAD DE LOTEO PVE: Por función MAIN.", "PRIORIDAD DE LOTEO PVP: Por clase."}
        },
        ["MECHANICS"] = {
            ["TOVARON EL VIGIA DE HIELO"] = {"Los dos tanques intercambian boss cada 4 marcas",
                                             "Los DPS destruyen orbes totalmente y continuan con boss"}
        }
    },
    ["CIUDADELA DE LA CORONA DE HIELO"] = {
        ["RULES"] = {
            ["SHARED"] = {"PRIORIDAD DE LOTEO: Por función MAIN > DUAL > ENCHANT > CODICIA.", "DBM y Discord son obligatorios, DC se comparte antes de iniciar Tuetano; la falta de alguno conllevará a la expulsión de la raid",},
            ["10"] = {},
            ["25"] = {"MARCAS: Para lotear marca debe tener 2 t10 engemados/encantados. Caster 7k dps(3% bestias) Meles 7k dps en Libra (3% bestias). Heals top3 de Lady y Reina.",
                      "TESTAMENTO: top5 daño inflingido en Libra cerrado con 3% en bestias, al igual que Tarro . (Testa palas sólo con agonía).",
                      "ABACO: top3 heal en Reina, si no cae se toma el recuento de Panzachancro. Trauma igual.",
                      "FILACTERIA: top2 cerrado daño inflingido en Libramorte con 3% en bestias.",
                      "OBJETO: top3 cerrado daño inflingido en Libramorte con 3% en bestias."}
        },
        ["MECHANICS"] = {
            ["TUETANO"] = {"Tanques a la derecha, resto del grupo detras y debajo del boss, hunter alejado en costado opuesto a tanques",
                           "DPS destruyen puas, si la pua esta a distancia solo caster y ranged la destruiran, un healer cuida empalados",
                           "Todos evitan trazos de fuego sobre el suelo sin alejarse del grupo y de las posiciones iniciales",
                           "En las tormentas iniciales aplican defensivos y mitigadores sobre ustedes y healers",
                           "En la ultimma tomenta los tanques toman boss y se mueven hacia las escaleras, todos cuidan sus posiciones"},
            ["LADY"] = {"Tanque MAIN a la derecha, Tanque OFF a la izquierda, resto frente al escenario, picaro con lady todo el tiempo",
                        "DPS eliminan adds de ambos lados y continuan con lady",
                        "Todos de retiran de areas de daño de inmediato",
                        "Usar habilidades de control sin daño sobre aliado controlado",
                        "Al fasear Tanques llevan a lady al centro del salon",
                        "Evitar tocar fantasmas morados, si los siguen llevarlos fuera del grupo",
                        "Apenas pasen los 10min de ansias castearla de nuevo",
                        "Utilizar habilidades para ceder todo el agro sobre los tanques en el centro de la sala"},
            ["BARCOS"] = {"Solo el Tanque MAIN salta por su lado del barco, DPS saltan por el lado contrario al tank para evitar ser rajados",
                          "Dos DPS bajos toman cañones y los mantienen entre 85~100% del poder de ataque antes de ataque especial",
                          "DPS solamente destruyen mago y regresan por el mismo lado que saltaron a limpiar nuestro barco",
                          "Los cañones deben terminan el trabajo",
                          "Por favor esperar en la terraza de libra, nadie abra el cofre de loot o perdera todo loteo"},
            ["LIBRA"] = {"Libra coloca en el tanque con mayor agro una Runa de sangre, el otro tanque debe quitarle el boss inmediatamente",
                         "DPS rango y caster se mantienen a distancia /range 12 para evitar propagar marcas",
                         "Cada que salgan DPS se enfocan y destruyen las antes de continuar con boss",
                         "Deben ralentizarlas utilizando Trampas de Escarcha, Tótem de Nexo Terrestre, Veneno entorpecedor, Profanación o Cadenas de Hielo. También pueden incapacitarlas, utilizar raíces, empujarlas hacia atrás, etc",
                         "Los marcados se aplican defensivos y mitigadores de daño y no atacan bestias, un healer se enfoca a cuidarlos",
                         "Castear ansias al 35% del boss y aplicar todos los booster y multiplicadores de daño",
                         "IMPORTANTE: Tomar distancia = No marcas / Aniquilar bestias sin que los toquen = Libra no se cura"},
            ["PANZACHANCRO"] = {"Tanques intercambian al boss cada 9 marcas, el tanque con 9 marcas deja de pegar totalmente hasta limpiarse la marca!",
                                "Los Tanques mantienen al boss de espaldas en el centro de la sala",
                                "DPS cuerpo a cuerpo deben permanecer siempre juntos detras del boss",
                                "DPS rango toman distancia /range 10 entre ustedes para no vomitarse",
                                "La espora sobre DPS rango se juntan con todos los rangos y caster, la otra espora se queda con los cuerpo a cuerpo y los tanques",
                                "DOBLE ESPORA EN CUERPO A CUERPO: Uno de los jugadores con espora se reune con los caster para compartirles espora",
                                "ATENCION: Quien no acumula 3 esporas absorbera daño masivo en explosion de gas"},
            ["CARAPUTREA"] = {"El Main Tank mantiene al boss en el centro de la sala",
                              "Los DPS siempre detras del jefe y fuera de zonas de inundacion de mocos",
                              "INFECCION: Al limpiar al tanque un infeccion saltara como un moco pequeño",
                              "El OFF TANK toma los mocos pequeños de inmediato y los tanquea moviendose en circulo dandole vueltas alrededor pero lejos del grupo y fuera de la inundacion de mocos",
                              "OFF TANK: los mocos pequeños se unen y comienzan a fusionarse con hasta 5 mocos mas para explotar, mantenlos lejos del grupo",
                              "El Boss gira y todos deben cuidar sus posiciones detras del boss y fuera de los charcos de moco"}

        }
    }
}
