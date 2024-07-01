playerRoles = {
    ["PRIMARY"] = {"MAIN TANK", "HEALER 1", "OFF TANK", "HEALER 2", "HEALER 3", "HEALER 4", "HEALER 5"},
    ["BUFF"] = {"REZOS DE ESPIRITU, PROTECCION Y ENTEREZA", "DON DE LO SALVAJE", "SALVAGUARDA", "PODERIO Y REYES", "SABIDURIA Y REYES",
                "SABIDURIA", "VIGILANCIA", "GRITO DE ORDEN", "GRITO DE BATALLA", "GRITO DESMORALIZADOR", "ENFOQUE",
                "TOTEM DE CORRIENTE DE SANACION"},
    ["SKILL"] = {"HEROISMO", "DESACTIVAR TRAMPA", "SECRETOS DEL OFICIO", "REDIRECCION", "TRAMPA DE ESCARCHA", "COLERA SAGRADA",
                 "POLIMORFIA", "CICLON", "RAICES ENREDADORAS", "AHUYENTAR EL MAL", "TIFON", "CADENAS DE HIELO",
                 "ENCADENAR NO MUERTO"},
    ["SECONDARY"] = {"RESUCITAR CAIDOS", "RITUAL DE INVOCACION", "RITUAL DE REFRIGERIO", "PIEDRA DE ALMA", "TOTEM DE NEXO TERRESTRE"},
    ["EXTRA"] = {"FRAGMENTADOR", "ABOMINACION", "TANQUE DUAL AUXILIAR", "HEALER DUAL AUXILIAR", "MAESTRIA EN AURAS",
    "IMPOSICION DE MANOS", "MANO DE SACRIFICIO", "MANO DE LIBERTAD"}
}

rulesAndMechanics = {
    ["ADVERTENCIA: AFK/OFFs"] = {
        ["RULES"] = {
            ["SHARED"] = {"El jugador que se quede AFK/OFF por mucho tiempo sin avisar, no siga mecanincas o tenga DPS debajo del Tanque se queda sin loteo y puede ser expulsado de la raid."}
        }
    },
    ["PRE-ARMADO ICC 25"] = {
        ["RULES"] = {
            ["SHARED"] = {"DBM Y DC son OBLIGATORIOS // DC al llenar raid // Reglas frente Tuetano",
                          "Inspección del Grupo 6 en Zona de Vuelo, Dalaran"}
        }
    },
    ["PRE-ARMADO ICC 10"] = {
        ["RULES"] = {
            ["SHARED"] = {"DBM Y DC son OBLIGATORIOS // DC al llenar raid",
                          "Inspección del Grupo 3 en Zona de Vuelo, Dalaran"}
        }
    },
    ["BUEN JUEGO Y BUENA VIBRA"] = {
        ["RULES"] = {
            ["SHARED"] = {"Concentremonos en realizar BUENAS MECANICAS, mantener SIEMPRE BUFFEADO al grupo y estar atentos para AVANZAR RAPIDO y seguros. Portales listos siempre que sean necesarios. Que esta sea una excelente raid."}
        }
    },
    ["BLACKLISTED"] = {
        ["RULES"] = {
            ["SHARED"] = {"Ha incumplido con lo minimo requerido para el buen desarrollo de la banda."}
        }
    },
    ["RE-ARME RAPIDO"] = {
        ["RULES"] = {
            ["SHARED"] = {"Por favor continuar. Ya se esta buscando por posada. Conocidos interesados que WISP."}
        }
    },
    ["LA CAMARA DE ARCHAVON"] = {
        ["RULES"] = {
            ["SHARED"] = {"PRIORIDAD BOTIN PVE: Por función MAIN.", "PRIORIDAD BOTIN PVP: Por clase."}
        },
        ["MECHANICS"] = {
            ["TOVARON EL VIGIA DE HIELO"] = {"Tanques intercambian cada 4 marcas",
                                             "DPS destruiyen orbes totalmente y continuan con boss"}
        }
    },
    ["CIUDADELA DE LA CORONA DE HIELO"] = {
        ["RULES"] = {
            ["SHARED"] = {"PRIORIDAD DE LOTEO: Por función MAIN > DUAL > ENCHANT > CODICIA."},
            ["10"] = {},
            ["25"] = {"MARCAS: Debe linkear 1 t10 engemado/encantado.",
                      "TESTAMENTO: top5 daño en Panza cerrado + 5% en bestias, al igual que Tarro.",
                      "OBJETO: top5 cerrado daño en Panza + 3% en bestias.",
                      "FILACTERIA: top3 cerrado daño en Profe + 10% en mocos.",
                      "ABACO: top3 cerrado  en Reina.",
                      "COLMILLO: prioridad tanques activos en su rol, luego el resto.",
                      "RESERVADOS: Fragmentos, Items no ligados y Saros.",
                      "ARMAS LK: top10 daño en LK + 5% en Valkyrs y top3 conteo de sanacion en LK.",
                      "Un abalorio, arma y marca por raid. Un ítem por main, 2 ítems dual. Marcas se rolean por dual. Arma y sostener cuentan como ítem. Solo excentas armas de Lk.",
                      "Si en algun top no necesitan el ítem o no cumplen la regla para lotear, pasará al siguiente en top."}
        },
        ["MECHANICS"] = {
            ["TUETANO"] = {"Tanques a la derecha, grupo detras y debajo del boss, hunters alejados en costado opuesto a tanques. DPS destruyen puas de inmediato. Caster y ranged destruyen puas lejanas al grupo",
                           "Evitar trazos de fuego sobre el suelo y castear defensivos durante tormentas. En ultima tormenta tanques toman boss cerca a las escaleras"},
            ["LADY DEATHWISPER"] = {"OFF TANK, Grupos 1 y 3 IZQUIERDA // MAIN TANK, Grupos 2 y 4 DERECHA, picaros con lady todo el tiempo",
                                    "Destruir adds de ambos lados y continuar con lady // Retirarse de areas de daño de inmediato",
                                    "Usar habilidades de control sin daño sobre aliado controlado // Evitar tocar fantasmas y llevarlos lejos grupo",
                                    "Heroismo al terminar los 10min de ansias // Ceder agro sobre los tanques todo el tiempo"},
            ["BARCOS"] = {"MAIN TANK salta SOLO por su lado del barco, DPS saltan por el lado contrario y evitan ser rajados",
                          "Cañones se mantienen entre 87~100% del poder de ataque antes de ataque especial",
                          "DPS saltan a destruir mago y regresan por el mismo lado que saltaron a limpiar nuestro barco",
                          "Los cañones deben terminar el trabajo",
                          "Por favor esperar en la terraza de libra, nadie abra el cofre de loot o perdera todo loteo"},
            ["LIBRA"] = {"TANQUES voltean boss y estan atentos a intercambiar marca de inmediato. Cuerpo a cuerpo detras. DPS rango y caster distanciados a /range 12 para evitar propagar marcas",
                         "RALENTIZAR Y ANIQUILAR BESTIAS EN CADA OLEADA: Trampa de Escarcha, Tótem de Nexo Terrestre, Veneno entorpecedor, Cadenas de Hielo, Raíces, Tifon, etc",
                         "Marcados evitan atacar bestias y se aplican defensivos para seguir en Libra", "Heroismo al 35%",
                         "IMPORTANTE: Tomar distancia = No marcas // Aniquilar bestias sin que los toquen = Libra no se cura"},
            ["PANZACHANCRO"] = {"TANQUES intercambian cada 9 marcas y ubican al boss de espaldas al grupo en el centro de la sala",
                                "DPS Caster y ranged => G1 y G3 IZQ // G2 y G4 DER toman distancia /range 12 para no vomitarse",
                                "Juntarse con su espora, sea con los Cuerpo a Cuerpo o los ranged",
                                "DOBLE ESPORA EN CUERPO A CUERPO: Uno de los jugadores con espora se reune con los caster para compartirles espora",
                                "ATENCION: Quien no acumule 3 esporas absorbera daño masivo en explosion de gas"},
            ["CARAPUTREA"] = {"MAIN TANK ubica al boss en el centro de la sala",
                              "DPS siempre detras del boss y fuera de zonas de inundacion de mocos",
                              "MOCO PEQUEÑO: ubicarse al costado mas cercano al transito del moco grande // SIN DAÑO DE AREA CUANDO MOCO GRANDE ESTE CERCA",
                              "OFF TANK toma mocos grandes estando siempre fuera de la inundacion de mocos y apuntando los vomitos lejos del grupo",
                              "Deben alejarse del boss al momento de la explosion de anublo"},
            ["PROFESOR PUTRICIDIO"] = {"Fase 1: 100% a 80% // LADO DERECHO DE LA SALA",
                                       "No dispel sobre ABOMINACION // Si Imbuir y Rejuvenecer // ABO consume charcos y ralentiza mocos antes de que comiencen a moverse",
                                       "Ranged y caster atacan mocos apenas aparecen // Cuerpo a cuerpo atacan mocos apenas marque un aliado",
                                       "MOCO NARANJA: marcado huye. Healers overheal y dots sobre marcado. // MOCO VERDE: Empuja 3yrds y causa daño de area al impactar marcado o morir. // TODOS esquivan MOCO MALEABLE",
                                       "Fase 2: 80% a 35% // Tanques llevan boss sobre la pared y se separan minimo 10 metros de los frascos",
                                       "Fase 3: 35% a 0% // Maximo DPS // HEROISMO",
                                       "TANQUES cambian boss a DOS dosis de PESTE MUTADA: una vez los tanks tengan 2 dosis, tendrán que rotar de nuevo tomando 1 dosis mas, en cada rotacion hasta 4 dosis. Si cualquiera de los tank adquiere 5 dosis el daño en raid será masivo."},
            ["REINA DE SANGRE LANA'THEL"] = {"MAIN TANK ubica al boss sobre las escaleras // OFF Tank se mentiene cerca al main para hacer espejo",
                                             "DPS cuerpo a cuerpo atacan al maximo rango posible // Marcado por sombras corre junto a la pared lejos del centro",
                                             "Marcados por pacto unen lazo rapidamente evitando que los healer tengan que moverse // Marcados por mordida rotar rapidamente entre los DPS mas equipados que no hayan sido mordidos",
                                             "EN 2DO TERROR: a 3segs de levantar vuelo TODOS aplican defensivos. Antifear sobre sacerdotes. Paladines comparten daño si esta disponible"},
            ["VALITHRIA DREAMWALKER"] = {"Minimizar a toda costa el daño que reciba la banda para dar a los healers la mayor cantidad de tiempo de sanar a Valithria // Healers usar Portales de Pesadilla para amplificar sanacion y mana con las Nubes oníricas",
                                         "PRIORIDAD: // 1 Esqueleto Ardiente // 2 Supresor // 3 Archimago resucitado // 4 Zombie Virulento // 5 Ablominación glotona // Tanques atentos para agrear todo y llevarlo lejos de Valithria",
                                         "Alejarse de Zombies Virulentos al estallar // Atentos a limpiar y eliminar enfermedades al instante y en todo momento"},
            ["CONCEJO DE PRINCIPES DE SANGRE"] = {"Main Tank toma gemelos sobre escaleras",
                                                  "OFF Tank toma a Keleseth a la izquierda y agrea Nucleos Oscuros (Minimo 3). Ayudarlo con secretos o redi",
                                                  "DPS Cuerpo a Cuerpo se retiran al fondo en cada vortice",
                                                  "Hunters y Locks con sus mascostas mantienen cineticas arriba",
                                                  "Casters y ranged tomar distancia durante vortices y mantenerse en grupo para mitigar daño",
                                                  "Atentos a cada cambio de principe"},
            ["SINDRAGOSA"] = {"Main tank ubica de costado al boss para el resto de la banda",
                              "DPS dejan de golpear al tener 6 o mas marcas hasta limpiarse",
                              "Todo el grupo debe correr de regreso y agruparse sobre escaleras. Utilizar mitigadores de daño y escudos durante el regreso",
                              "Marcados por Tumba de Hielo se distribuyen segun sus nombres: 1 y 2 Izquierda // 3 centro // 4 y 5 Derecha // a un metro en frente del primer escalon",
                              "Resto del grupo se cubre de los impactos de sindra evitando recibir onda de choque con Tumba de Hielo",
                              "Ir destruyendo Tumbas de Hielo lentamente sincronizados hasta el ultimo disparo de sindra",
                              "Segunda fase marcados por Tumba de Hielo intercalan posicion a un metro frente a escaleras, primero Izquierda luego centro",
                              "Resto del grupo se limpia tras tumba y destruye rapidamente antes de continuar con sindra"},
            ["LICK KING"] = {"MAIN TANK LK // OFF HORRORES cerca al MAIN ambos de espaldas al grupo",
                             "HEALERS: Banda al 90% de salud siempre para evitar cada Infestar",
                             "Atacar HORRORES solo luego del taunt del OFF hasta el 15%. Luego focus LK.",
                             "Durante cada INVIERNO salimos al anillo exterior, OFF tauntea cada ESPIRITU. Destruimos ESPIRITUS y regresamos a capa de LK",
                             "Alejarse 5s antes de cada PROFANAR lejos del centro. Marcado por PROFANAR se aleja sin saltar. Todos regresan detras de capa LK.",
                             "Destruir VALKIRS en cada spawn. Marcado lleva PROFANAR direccion lejos de VALKYRS y LK",
                             "Paladines se turnan ESCUDO DIVINO y limpian cada oleada de FANTASMAS",


                            }

        }
    }
}
