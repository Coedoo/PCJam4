package game

import dm "../dmcore"
import "core:math"

import "core:fmt"

Boss :: struct {
    position: v2,
    hp: f32,

    isAlive: bool,

    waitingTimer: f32,
    sequence: Sequence,
}

//////////////////

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

    stopPredicate: SequenceStopPredicate,
}

/////

SequenceStep :: union {
    WaitSeconds,
    FireCircle,
    Sequence,
    MoveTo,
}

WaitSeconds :: struct {
    seconds: f32,
}

FireCircle :: struct {
    count: int,
    radius: f32,
    spawnOffset: v2,
    iterAngle: f32,
}

MoveTo :: struct {
    pos: v2,
    time: f32,
}

//////

SequenceStopPredicate :: union #no_nil {
    Never,
    AfterTime,
    AfterIter,
}

AfterTime :: struct {
    time: f32,
}

AfterIter :: struct {
    count: int
}

Never :: struct {}

////

aaaa := Sequence{
    steps = {
        FireCircle{10, 1, 0, 10},
        WaitSeconds{0.2}
    }
}

bbbb := Sequence{
    steps = {
        Sequence {
            stopPredicate = AfterIter{6},
            steps = {
                FireCircle{10, 1, 0, 2},
                WaitSeconds{0.1}
            },
        },

        WaitSeconds{1},
        
        Sequence {
            stopPredicate = AfterIter{6},
            steps = {
                FireCircle{10, 1, 0, -2},
                WaitSeconds{0.1}
            }
        },

        WaitSeconds{1},
    }
}

cccc := Sequence{
    type = .Parallel,
    steps = {
        // Sequence {
        //     stopPredicate = AfterIter{6},
        //     steps = {
        //         FireCircle{10, 1, 0, 2},
        //         WaitSeconds{0.1}
        //     },
        // },

        // Sequence {
        //     stopPredicate = AfterIter{6},
        //     steps = {
        //         FireCircle{10, 1, 0, -2},
        //         WaitSeconds{0.1}
        //     }
        // },

        Sequence {
            steps = {
                MoveTo{{5, 5}, 2},
                WaitSeconds{2},
                MoveTo{{-5, 3}, 2},
                WaitSeconds{2},
            }
        }

    }
}

UpdateBoss :: proc(boss: ^Boss) {
    if boss.waitingTimer > 0 {
        boss.waitingTimer -= f32(dm.time.deltaTime)
        return
    }

    RunSequence(boss, &boss.sequence)
}

ResetBossSequence :: proc(boss: ^Boss) {
    boss.waitingTimer = PRE_SEQUENCE_WAIT
    ResetSequence(&boss.sequence)
}

ResetSequence :: proc(seq: ^Sequence) {
    seq.sequenceT = 0
    seq.iterations = 0
    seq.stepT = 0
    seq.stepIndex = 0

    for &step in seq.steps {
        if subSeq, ok := &step.(Sequence); ok {
            ResetSequence(subSeq)
        }
    }
}

RotOffset :: proc(rot: f32, radius: f32) -> v2 {
    return {
        math.cos(math.to_radians(rot)),
        math.sin(math.to_radians(rot)),
    } * radius
}

RunSequence :: proc(boss: ^Boss, sequence: ^Sequence) -> bool {
    if sequence.type == .Parallel {
        finishedCount := 0
        for &step in sequence.steps {
            if RunStep(&step, sequence.stepT, sequence.iterations, boss) {

            }
        }

        sequence.iterations += 1
        sequence.stepT += f32(dm.time.deltaTime)
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

            if seq, ok := &sequence.steps[sequence.stepIndex].(Sequence); ok {
                ResetSequence(seq)
            }
        }
        else {
            sequence.stepT += f32(dm.time.deltaTime)
        }
    }

    sequence.sequenceT += f32(dm.time.deltaTime)

    switch p in sequence.stopPredicate {
    case Never: 
        return false
    case AfterIter:
        return sequence.iterations > p.count
    case AfterTime:
        return sequence.sequenceT > p.time
    }

    return false
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
            SpawnBullet(boss.position + RotOffset(rot, s.radius) + s.spawnOffset, math.to_radians(rot), false)
        }
        return true
    case Sequence:
        return RunSequence(boss, &s)

    case MoveTo:
        p := t / s.time
        boss.position = math.lerp(boss.position, s.pos, p)

        return p >= 1
    }

    // fmt.eprintln("Unhandled step return", step)
    return true
}