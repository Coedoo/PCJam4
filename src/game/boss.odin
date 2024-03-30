package game

import dm "../dmcore"
import "core:math"
import "core:slice"

import "core:fmt"

Boss :: struct {
    position: v2,
    hp: f32,

    isAlive: bool,

    waitingTimer: f32,

    currentSeqIdx: int,
    // sequences: []Sequence,
}

//////////////////
Phase :: struct {
    hp: f32,
    sequence: Sequence,
}

SequenceType :: enum {
    Serial,
    Parallel,
}

Sequence :: struct {
    type: SequenceType,

    sequenceT: f32,

    iterations: int,
    stepT: f32,

    stepIndex: int,
    steps: []SequenceStep,

    stop: SequenceStopPredicate,
}

/////

SequenceStep :: union {
    WaitSeconds,
    FireCircle,
    Sequence,
    MoveTo,
    FireBullet,
    FireShotgun,
}

WaitSeconds :: struct {
    seconds: f32,
}

FireCircle :: struct {
    count: int,
    radius: f32,
    spawnOffset: v2,
    iterAngle: f32,

    bullet: BulletType,
    speed: f32,
}

FireTarget :: enum {
    Angle,
    Player,
}

FireBullet :: struct {
    // count: int,
    bullet: BulletType,
    speed: f32,
    target: FireTarget,
}

FireShotgun :: struct {
    bullet: BulletType,
    count: int,
    speed: f32,
    arcAngle: f32,
}

MoveTo :: struct {
    _from: v2,
    to: v2,
    time: f32,
}

//////

SequenceStopPredicate :: union #no_nil {
    Never,
    Once,
    AfterTime,
    AfterIter,
}

AfterTime :: struct {
    time: f32,
}

AfterIter :: struct {
    count: int
}

Once :: struct {}
Never :: struct {}

////

BossSequence := []Phase{
    // Phase 1
    {
        hp = 600,
        sequence = {
            steps = {
                MoveTo{to = {0, 3}, time = 1},

                Sequence {
                    steps = {
                        Sequence {
                            stop = Once{},
                            steps = {
                                Sequence {
                                    stop = AfterIter{20},
                                    steps = {
                                        FireBullet {
                                            .Pointy,
                                            8,
                                            .Player
                                        },
                                        WaitSeconds{0.1}
                                    }
                                },
                            },
                        },

                        FireShotgun{.Manta, 7, 7, math.PI / 3 },
                        WaitSeconds{0.5},
                    },
                }
            }
        }
    },

    // Phase 2
    {
        hp = 700,
        sequence = {
            steps = {
                MoveTo{to={0, 0}, time=0.5},

                Sequence {
                    type = .Parallel,
                    steps = {
                        Sequence {
                            stop = AfterIter{6},
                            steps = {
                                FireCircle{16, .4, 0, 4, .Manta, 6},
                                WaitSeconds{0.3}
                            },
                        },

                        Sequence {
                            stop = AfterIter{6},
                            steps = {
                                FireCircle{16, .4, 0, -4, .Manta, 6},
                                WaitSeconds{0.3}
                            }
                        },
                    }
                }
            }
        },
    },

    // Phase 3
    {
        hp = 800,
        sequence = {
            steps = {
                MoveTo{to={0, 4}, time=0.5},

                Sequence {
                    type = .Serial,
                    steps = {
                        MoveTo{to={6, 4.5}, time=0.5},
                        FireCircle{16, .5, 0, 0, .Ball, 3},

                        Sequence {
                            stop = AfterIter{10},
                            steps = {
                                FireBullet { .Pointy, 8, .Player},
                                WaitSeconds{0.05}
                            },
                        },

                        MoveTo{to={0, 4.5}, time=0.5},
                        FireCircle{16, .5, 0, 0, .Ball, 3},

                        Sequence {
                            stop = AfterIter{10},
                            steps = {
                                FireBullet { .Pointy, 8, .Player},
                                WaitSeconds{0.05}
                            },
                        },

                        MoveTo{to={-6, 4.5}, time=0.5},
                        FireCircle{16, .5, 0, 0, .Ball, 3},

                        Sequence {
                            stop = AfterIter{10},
                            steps = {
                                FireBullet { .Pointy, 8, .Player},
                                WaitSeconds{0.05}
                            },
                        },

                        MoveTo{to={0, 4.5}, time=0.5},
                        FireCircle{16, .5, 0, 0, .Ball, 3},

                        Sequence {
                            stop = AfterIter{10},
                            steps = {
                                FireBullet { .Pointy, 8, .Player},
                                WaitSeconds{0.05}
                            },
                        },

                    }
                }
            }
        }
    },

    // Phase 4
    {
        hp = 1000,
        sequence = {
            steps = {
                MoveTo{to={0, 5}, time=0.5},

                Sequence {
                steps = {
                    Sequence {
                        type = .Parallel,
                        stop = AfterTime{0.8},
                        steps = {
                            MoveTo{to = {-5, -5}, time = 0.8},
                            Sequence {
                                steps = {
                                    FireCircle{12, .5, 0, 0, .Ball, 5},
                                    WaitSeconds{.15},
                                }
                            }
                        }
                    },

                    //////////////

                    WaitSeconds{2},


                    Sequence {
                        type = .Parallel,
                        stop = AfterTime{0.8},

                        steps = {
                            MoveTo{to = {5, -5}, time = 0.8},
                            Sequence {
                                steps = {
                                    FireCircle{12, .5, 0, 0, .Ball, 5},
                                    WaitSeconds{.15}
                                }
                            }
                        }
                    },

                    ///////////////

                    WaitSeconds{2},

                    Sequence {
                        type = .Parallel,
                        stop = AfterTime{0.8},
                        steps = {
                            MoveTo{to = {0, 5}, time = 0.8},
                            Sequence {
                                steps = {
                                    FireCircle{12, .5, 0, 0, .Ball, 5},
                                    WaitSeconds{.15}
                                }
                            }
                        }
                    },

                    WaitSeconds{2},
                }
            }}
        },
    },

}

/////////

UpdateBoss :: proc(boss: ^Boss) {
    if boss.waitingTimer > 0 {
        boss.waitingTimer -= f32(dm.time.deltaTime)
        return
    }

    phase := &BossSequence[boss.currentSeqIdx]
    RunSequence(boss, &phase.sequence)
}

ResetBossSequence :: proc(boss: ^Boss) {
    boss.waitingTimer = PRE_SEQUENCE_WAIT

    phase := &BossSequence[boss.currentSeqIdx]
    ResteSequence(&phase.sequence, boss)
}

BossNextSequence :: proc(boss: ^Boss) -> bool {
    boss.currentSeqIdx += 1
    if boss.currentSeqIdx >= len(BossSequence) {
        boss.isAlive = false
        return false
    }
    else {
        boss.hp = BossSequence[boss.currentSeqIdx].hp
        ResetBossSequence(boss)
        return true
    }
}


RotOffset :: proc(rot: f32, radius: f32) -> v2 {
    return {
        math.cos(math.to_radians(rot)),
        math.sin(math.to_radians(rot)),
    } * radius
}

RunSequence :: proc(boss: ^Boss, sequence: ^Sequence) -> bool {
    finished := false
    if sequence.type == .Parallel {
        finishedCount := 0
        for &step in sequence.steps {
            if RunStep(&step, sequence.stepT, sequence.iterations, boss) {
                finishedCount += 1
            }
        }

        sequence.iterations += 1
        sequence.stepT += f32(dm.time.deltaTime)

        finished = finishedCount == len(sequence.steps)
    }
    else if sequence.type == .Serial {
        if RunStep(&sequence.steps[sequence.stepIndex], sequence.stepT, sequence.iterations, boss) {
            // fmt.println(sequence.stepIndex, len(sequence.steps) - 1)
            if sequence.stepIndex == len(sequence.steps) - 1 {
                sequence.iterations += 1
            }

            // fmt.println("Finished", sequence.steps[sequence.stepIndex])

            sequence.stepT = 0
            sequence.stepIndex = (sequence.stepIndex + 1) % len(sequence.steps)
            ResetStep(&sequence.steps[sequence.stepIndex], boss)

            finished = sequence.stepIndex == 0
            // if seq, ok := &sequence.steps[sequence.stepIndex].(Sequence); ok {
            //     ResetSequence(seq)
            // }
        }
        else {
            sequence.stepT += f32(dm.time.deltaTime)
        }
    }

    sequence.sequenceT += f32(dm.time.deltaTime)

    switch p in sequence.stop {
    case Never: 
        return false
    case Once:
        return finished
    case AfterIter:
        return sequence.iterations > p.count
    case AfterTime:
        return sequence.sequenceT > p.time
    }

    return false
}

ResteSequence :: proc(seq: ^Sequence, boss: ^Boss) {
    seq.sequenceT = 0
    seq.iterations = 0
    seq.stepT = 0
    seq.stepIndex = 0

    for &step in seq.steps {
        ResetStep(&step, boss)
    }
}

ResetStep :: proc(step: ^SequenceStep, boss: ^Boss) {
    switch &s in step {
    case WaitSeconds:
    case FireCircle:

    case MoveTo:
        s._from = boss.position

    case Sequence:
        ResteSequence(&s, boss)

    case FireBullet:
    case FireShotgun:
    }
}

RunStep :: proc(step: ^SequenceStep, t: f32, iteration: int, boss: ^Boss) -> bool {
    switch &s in step {
    case WaitSeconds:
        return t >= s.seconds

    case FireCircle:
        if t != 0 {
            return true
        }

        pos := boss.position + s.spawnOffset
        for i in 0..<s.count {
            rot := f32(i) / f32(s.count - 1) * 360 + s.iterAngle * f32(iteration)
            SpawnBullet(boss.position + RotOffset(rot, s.radius) + s.spawnOffset, 
                        math.to_radians(rot),
                        s.bullet,
                        false,
                        speed = s.speed,
                    )
        }

        return true

    case FireBullet:

        delta := PlayerPos() - boss.position
        angle := math.atan2(delta.y, delta.x)

        SpawnBullet(boss.position, 
            angle,
            s.bullet,
            false,
            speed = s.speed,
        )
    case FireShotgun:
        delta := PlayerPos() - boss.position
        angle := math.atan2(delta.y, delta.x)

        angleStep := s.arcAngle / f32(s.count)
        angle -= s.arcAngle / 2

        for i in 0..<s.count {
            SpawnBullet(boss.position, 
                angle,
                s.bullet,
                false,
                speed = s.speed,
            )

            angle += angleStep
        }

    case Sequence:
        return RunSequence(boss, &s)

    case MoveTo:
        p := t / s.time
        boss.position = math.lerp(s._from, s.to, p)

        return p >= 1
    }

    // fmt.eprintln("Unhandled step return", step)
    return true
}