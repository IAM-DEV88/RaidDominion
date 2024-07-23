playerRoles = {
    ["PRIMARY"] = {"MAIN TANK", "HEALER 1", "OFF TANK", "HEALER 2", "HEALER 3", "HEALER 4", "HEALER 5"},
    ["BUFF"] = {"REZOS DE ESPIRITU, PROTECCION Y ENTEREZA", "DON DE LO SALVAJE", "SALVAGUARDA", "PODERIO", "REYES",
                "SABIDURIA", "VIGILANCIA", "GRITO DE ORDEN", "GRITO DE BATALLA", "GRITO DESMORALIZADOR", "ENFOQUE",
                "TOTEM DE CORRIENTE DE SANACION"},
    ["SKILL"] = {"HEROISMO", "DESACTIVAR TRAMPA", "SECRETOS DEL OFICIO", "REDIRECCION", "TRAMPA DE ESCARCHA",
                 "COLERA SAGRADA", "POLIMORFIA", "CICLON", "RAICES ENREDADORAS", "AHUYENTAR EL MAL", "TIFON",
                 "CADENAS DE HIELO", "ENCADENAR NO MUERTO"},
    ["SECONDARY"] = {"FRAGMENTADOR", "ABOMINACION", "TANQUE DUAL AUXILIAR", "HEALER DUAL AUXILIAR", "MAESTRIA EN AURAS",
                     "IMPOSICION DE MANOS", "MANO DE SACRIFICIO", "MANO DE LIBERTAD"},
    ["EXTRA"] = {"RESUCITAR CAIDOS", "RITUAL DE INVOCACION", "RITUAL DE REFRIGERIO", "PIEDRA DE ALMA",
                 "TOTEM DE NEXO TERRESTRE"}
}

rulesAndMechanics = {
    ["REVISO Y REEMPLAZO"] = {
        ["RULES"] = {
            ["SHARED"] = {"AFK/OFFs sin avisar // DPS debajo del Tanque // No respetar pulls o mecanincas = No botin"}
        }
    },
    ["DC OBLIGATORIO"] = {
        ["RULES"] = {
            ["SHARED"] = {"No DC = No Botin"}
        }
    },
    ["CUMPLIMIENTO DE REGLAS"] = {
        ["RULES"] = {
            ["SHARED"] = {"Se recomienda devolver items en caso de error en loteo // Toda falta baneable sera apoyada con pantallazos, grabaciones, etc."}
        }
    },
    ["BUEN JUEGO Y BUENA VIBRA"] = {
        ["RULES"] = {
            ["SHARED"] = {"Concentrados en BUENAS MECANICAS // raid SIEMPRE BUFFEADA y atenta para AVANZAR RAPIDO // Portales listos siempre que sean necesarios // Que esta sea una excelente raid."}
        }
    },
    ["CULTO DEL OSARIO"] = {
        ["RULES"] = {
            ["SHARED"] = {"Todos invitados a unirse a la hermandad."}
        }
    },
    ["RE-ARME RAPIDO"] = {
        ["RULES"] = {
            ["SHARED"] = {"Por favor continuar // Ya se esta buscando por posada // Conocidos interesados que WISP"}
        }
    },
    ["LA CAMARA DE ARCHAVON"] = {
        ["RULES"] = {
            ["SHARED"] = {"BOTIN => PVE: Por función MAIN // PVP: Por clase"}
        },
        ["MECHANICS"] = {
            ["TOVARON EL VIGIA DE HIELO"] = {"Tanques intercambian cada 4 marcas // DPS destruyen orbes totalmente y continuan con boss"}
        }
    },
    ["CIUDADELA DE LA CORONA DE HIELO"] = {
        ["RULES"] = {
            ["SHARED"] = {"PRIORIDAD DE LOTEO: Por función MAIN > DUAL."},
            ["10"] = {},
            ["25"] = {"MARCAS: Debe linkear 1 t10 engemado/encantado. // ABACO: top3 cerrado  en Reina.",
                      "TESTAMENTO: top5 daño en Panza cerrado + 5% en bestias. Rollean warrior fury, dk profano/escarcha, pícaro combate y druida feral, hunter punteria",
                      "TARRO: top5 daño en Panza cerrado + 5% en bestias, rollea paladín retry, pícaro asesinato. // OBJETO: top5 cerrado daño en Panza + 3% en bestias. // FILACTERIA: top3 cerrado daño en Profe + 10% en mocos.",
                      "COLMILLO: prioridad tanques activos en su rol, luego el resto. // RESERVADOS: Fragmentos, Items no ligados y Saros. // ARMAS LK: top10 daño en LK + 5% en Valkyrs y top3 conteo de sanacion en LK.",
                      "Un abalorio, Un arma, Dos marcas por raid. Un ítem por main(excepto tankes), sin limite por dual. Marcas tambien por dual. Arma y sostener cuentan como ítem. Solo excentas armas de Lk. Armas 2.6 pueden ser loteadas por tanques",
                      "Si en algun top no necesitan el ítem o no cumplen la regla para lotear, pasará al siguiente en top."}
        },
        ["MECHANICS"] = {
            ["TUETANO"] = {
                "Tanques derecha // Grupo detrás y debajo del boss // Hunters izquierda // HEROISMO de entrada // DESTRUIR púas de inmediato // RANGED destruyen púas lejanas al grupo // Evitar trazos de fuego",
                "Maestría y defensivos durante tormentas // Tanques retoman boss cerca de escaleras"
            },
            ["LADY DEATHWISPER"] = {
                "TODOS fondo a la derecha // Tanques juntan agro adds // DPS áreas sobre adds // Evitar áreas de daño // CADENAS y CICLÓN sobre aliado controlado // Evitar tocar fantasmas y llevarlos lejos del grupo"
            },
            ["BARCOS"] = {
                "MAIN TANK SOLO por su lado // DPS lado contrario // Evitar ser rajados // Cañones entre 87~100% del poder de ataque antes de ataque especial // DESTRUIR mago y regresar por el mismo lado // Cañones terminan el trabajo",
                "Esperar en terraza de libra, nadie abra el cofre de loot o perderá todo loteo"
            },
            ["LIBRA"] = {
                "TANQUES bajo escaleras atentos a marcas // Cuerpo a cuerpo sobre escaleras // Ranged a /range 12 evitan marcas // Trampa de Escarcha al caleo // Marcados no atacan bestias // HEROISMO al caleo",
                "IMPORTANTE: Tomar distancia = No marcas // Aniquilar bestias sin que los toquen = Libra no se cura"
            },
            ["PANZACHANCRO"] = {
                "MAIN TANK absorbe 9 marcas y cambia // Ranged a /range 12 para no vomitarse // Juntar desde SEGUNDA espora // DOBLE ESPORA EN CUERPO A CUERPO O DOBLE EN RANGED: Una espora se reune con el grupo que no tenga",
                "ATENCIÓN: Acumular 3 esporas o daño masivo en explosión de gas"
            },
            ["CARAPUTREA"] = {
                "MAIN TANK siempre frente al BOSS // Banda siempre detrás del boss // Unir 2xMOCOS PEQUEÑO al costado // SIN DAÑO DE ÁREA CON MOCO GRANDE CERCA // OFF mocos grandes // Deben alejarse del boss al momento de la explosión de anublo"
            },
            ["PROFESOR PUTRICIDIO"] = {
                "Fase 1: 100% a 80% // LADO DERECHO DE LA SALA // No dispel sobre ABOMINACIÓN // Si Imbuir y Rejuvenecer // ABO limpia charcos y vomita mocos // Parar DPS antes de cada moco // Marcado por moco naranja corre al caleo",
                "Fase 2: 80% a 35% // BOTELLAS sobre la pared y separan mínimo 10 metros // Esquivan maleables",
                "Fase 3: 35% a 0% // Máximo DPS // HEROISMO // TANQUES cambian boss a DOS dosis de PESTE MUTADA: una vez los tanks tengan 2 dosis, tendrán que rotar de nuevo tomando 1 dosis más en cada rotación hasta 4 dosis. Si cualquiera de los tanks adquiere 5 dosis, el daño en raid será masivo."
            },
            ["REINA DE SANGRE LANA'THEL"] = {
                "MAIN TANK sobre escaleras // OFF Tank cerca para espejo // Cuerpo a cuerpo a máximo rango posible // Sombras a la pared lejos del centro // Unir PACTO rápidamente // Rotar MORDIDA rápido entre los mayores DPS",
                "TERROR: antifear sacerdote y comparte paladín // TODOS mitigan con escudos"
            },
            ["VALITHRIA DREAMWALKER"] = {
                "Minimizar daño en banda // Full Heal sobre Valithria // Tomar Portales de Pesadilla para amplificar con Nubes oníricas",
                "PRIORIDAD: // 1 Esqueleto Ardiente // 2 Supresor // 3 Archimago resucitado // 4 Zombie Virulento // 5 Abominación glotona // Tanques atentos para agrear todo y llevarlo lejos de Valithria",
                "SOLO Cazador pega y mata Zombies Virulentos lejos de la raid // Limpiar enfermedades en todo momento"
            },
            ["CONCEJO DE PRINCIPES DE SANGRE"] = {
                "Main Tank gemelos // OFF Tank Keleseth y agrea Núcleos Oscuros (Mínimo 3) // DPS Cuerpo a Cuerpo se retiran al fondo en cada vórtice // Hunters y Locks mantienen cinéticas arriba",
                "Ranged toman distancia durante vórtices y se mantienen en grupo para mitigar daño // Atentos a cada cambio de príncipe"
            },
            ["SINDRAGOSA"] = {
                "Main tank BOSS // OFF y DPS cuidan marcas: Máximo 6 // Re-agruparse sobre escaleras con defensivos // Tumbas de Hielo según nombres: 1 y 2 Izquierda // 3 centro // 4 y 5 Derecha // A un metro en frente del primer escalón",
                "Columnear sin pegar hasta 4to impacto // SEGUNDA FASE: marcados primero Izquierda luego centro // HEROISMO al caleo // Cambio de tanque"
            },
            ["LICK KING"] = {
                "MAIN TANK LK // OFF HORRORES // Banda al 90% de salud antes de cada Infestar // Atacar HORROR al caleo hasta 15% // Faseo en borde exterior // Full Redirecciones ESPÍRITUS // Hunter PULSOS // Capa de LK",
                "Atentos a cada PROFANAR lejos del centro SIN SALTAR // Destruir VAL'KIR en cada spawn // Retri ESCUDO DIVINO al caleo para FANTASMAS // Shadow DISPERSIÓN al caleo para FANTASMAS"
            }
        }
        
    }
}
