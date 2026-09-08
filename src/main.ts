import * as rm from "https://deno.land/x/remapper@4.2.3/src/mod.ts"
import * as bundleInfo from '../bundleinfo.json' with { type: 'json' }
import { SetMaterialProperty } from "https://deno.land/x/remapper@4.2.3/src/internals/mod.ts";

const pipeline = await rm.createPipeline({ bundleInfo })

const bundle = rm.loadBundle(bundleInfo)
const materials = bundle.materials
const prefabs = bundle.prefabs

// ----------- { SCRIPT } -----------

async function doMap(file: rm.DIFFICULTY_NAME, chromaOnly: boolean = false) {
    const map = await rm.readDifficultyV3(pipeline, file);

    if(!chromaOnly) map.require("Vivify", true);
    map.suggest("Chroma", true);
    if(!chromaOnly) map.require("Noodle Extensions", true);

    /// ---- { FUNCTIONS } -----
    /**
     * Places the lasers in their correct positions. Copied from The Big Goodbye lol
     * @param side Which side (left or right) to position.
     */
    function setLaserPositions(side: "left" | "right") {
        const sideOffset = 3;
        const rotationOffset = 2;
        if(side == "left") {
            rm.environment(map, {
                id: "s.[0]PillarL",
                lookupMethod: "EndsWith",
                "localRotation": [
                    60,
                    -45 - rotationOffset,
                    0
                ],
                "localPosition": [
                    35 - sideOffset,
                    0,
                    5
                ]
            })
            for(let i = 1; i < 9;i++) {
                rm.environment(map, {
                    id: `s (${i}).[0]PillarL`,
                    lookupMethod: "EndsWith",
                    "localRotation": [
                        60,
                        -45 - rotationOffset * (i + 1),
                        0
                    ],
                    "localPosition": [
                        35 - sideOffset * (i + 1),
                        0,
                        5
                    ]
                })
            }
        }
        else {
            rm.environment(map, {
                id: "s.[1]PillarR",
                lookupMethod: "EndsWith",
                "localRotation": [
                    60,
                    45 + rotationOffset,
                    0
                ],
                "localPosition": [
                    -35 + sideOffset,
                    0,
                    5
                ]
            })
            for(let i = 1; i < 9;i++) {
                rm.environment(map, {
                    id: `s (${i}).[1]PillarR`,
                    lookupMethod: "EndsWith",
                    "localRotation": [
                        60,
                        45 + rotationOffset * (i + 1),
                        0
                    ],
                    "localPosition": [
                        -35 + sideOffset * (i + 1),
                        0,
                        5
                    ]
                })
            }
        }
    }

    /// ---- { ENVIRONMENT } -----
    if(!chromaOnly) rm.environmentRemoval(map, [
        "Rain",
        "Water",
        "LeftRail",
        "RightRail",
        "LeftFarRail",
        "RightFarRail",
        "RailingFull",
        "Curve",
        "LightRailingSegment",
        "PlayersPlace",
        "Smoke",
        "Clouds",
        "Mountains"
    ], "Contains")

    if(!chromaOnly) {
        rm.environment(map, {
            id: "Sun",
            lookupMethod: "EndsWith",
            localPosition: [0, 40, 110],
            localRotation: [-15, 0, 0]
        })

        rm.environment(map, {
            id: "TunnelRotatingLasersPair (4)",
            lookupMethod: "EndsWith",
            track: "sunbeams"
        })
        rm.environment(map, {
            id: "TunnelRotatingLasersPair (5)",
            lookupMethod: "EndsWith",
            track: "sunbeams"
        })

        rm.environment(map, {
            id: "TunnelRotatingLasersPair (6)",
            lookupMethod: "EndsWith",
            track: "sunbeams"
        })

        rm.environment(map, {
            id: "TunnelRotatingLasersPair (7)",
            lookupMethod: "EndsWith",
            track: "sunbeams"
        })

        rm.environment(map, {
            id: "TunnelRotatingLasersPair (8)",
            lookupMethod: "EndsWith",
            track: "sunbeams"
        })

        rm.environment(map, {
            id: "TunnelRotatingLasersPair (9)",
            lookupMethod: "EndsWith",
            track: "sunbeams"
        })

        rm.environment(map, {
            id: "TunnelRotatingLasersPair (10)",
            lookupMethod: "EndsWith",
            track: "sunbeams"
        })

        rm.environment(map, {
            id: "TunnelRotatingLasersPair (11)",
            lookupMethod: "EndsWith",
            track: "sunbeams"
        })
        rm.environment(map, {
            id: "TunnelRotatingLasersPair (12)",
            lookupMethod: "EndsWith",
            track: "sunbeams"
        })
        rm.environment(map, {
            id: "TunnelRotatingLasersPair (13)",
            lookupMethod: "EndsWith",
            track: "sunbeams"
        })
        rm.environment(map, {
            id: "TunnelRotatingLasersPair (14)",
            lookupMethod: "EndsWith",
            track: "sunbeams"
        })


        rm.animateTrack(map, {
            track: "sunbeams",
            animation: {
                localPosition: [
                    [0, 40, 110, 0]
                ],
                localRotation: [
                    [-12, 0, 0, 0]
                ]
            }
        })
    }

    if(!chromaOnly) rm.setRenderingSettings(map, {
        qualitySettings: {
            realtimeReflectionProbes: rm.BOOLEAN.True,
            shadows: rm.SHADOWS.HardOnly,
            shadowDistance: 64,
            shadowResolution: rm.SHADOW_RESOLUTION.High,
            softParticles: rm.BOOLEAN.True,
        },
        beat: 0
    })
    

    /// ---- { EVENTS } -----
    prefabs.accumulatown.instantiate(map, 0);
    prefabs.skybox.instantiate(map, 0);
    prefabs.clouds.instantiate(map, 0);
    prefabs.man.instantiate(map, 0);
    prefabs.woman.instantiate(map, 0);
    prefabs.oldman.instantiate(map, 0);
    prefabs.oldwoman.instantiate(map, 0);
    prefabs.furret.instantiate(map, 0);
    prefabs.furretwalk.instantiate(map, 0);
    prefabs.playermale.instantiate(map, 0);
    prefabs.playerfemale.instantiate(map, 0);

    setLaserPositions("left");
    setLaserPositions("right");

    // Assign all notes to a track
    if(!chromaOnly) map.allNotes.forEach(note => {
        note.track.add("allNotes")
    })

    // Apply custom note prefab to all notes
    if(!chromaOnly) rm.assignObjectPrefab(map, {
        colorNotes: {
            track: "allNotes",
            asset: prefabs.customnote.path,
            debrisAsset: prefabs.customnotedebris.path,
            anyDirectionAsset: prefabs.customnotedot.path
        },
        chainHeads: {
            track: "allNotes",
            asset: prefabs.customchain.path,
            debrisAsset: prefabs.customchaindebris.path
        },
        chainLinks: {
            track: "allNotes",
            asset: prefabs.customchainlink.path,
            debrisAsset: prefabs.customchainlinkdebris.path
        }
    })
}

await Promise.all([
    doMap('ExpertPlusStandard')
])

// ----------- { OUTPUT } -----------

pipeline.export({
    outputDirectory: '../OutputMaps/Accumula Town'
})
