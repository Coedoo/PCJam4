package game

import dm "../dmcore"
import "core:math"

import "core:fmt"

Boss :: struct {
    position: v2,
    hp: f32,

    isAlive: bool,

    attackTimer: f32,

    sequence: Sequence,
}

Sequence :: struct {
    sequenceT: f32,

    iterations: int,
    stepIndex: int,
    stepT: f32,
    steps: []SequenceStep,
}

SequenceStep :: union {
    WaitSeconds,
    FireCircle,
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

aaaa := Sequence{
    steps = {
        FireCircle{10, 1, 0, 10},
        WaitSeconds{0.2}
    }
}

RotOffset :: proc(rot: f32, radius: f32) -> v2 {
    return {
        math.cos(math.to_radians(rot)),
        math.sin(math.to_radians(rot)),
    } * radius
}

RunSequence :: proc(boss: ^Boss, using sequence: ^Sequence) {
    if RunStep(steps[stepIndex], stepT, boss.position, iterations) {
        stepT = 0
        stepIndex = (stepIndex + 1) % len(steps)
        if stepIndex == 0 {
            sequence.iterations += 1
        }
    }

    stepT += f32(dm.time.deltaTime)
    sequenceT += f32(dm.time.deltaTime)
}

RunStep :: proc(step: SequenceStep, t: f32, bossPos: v2, iteration: int) -> bool {
    switch s in step {
    case WaitSeconds:
        return t >= s.seconds

    case FireCircle:
        pos := bossPos + s.spawnOffset
        for i in 0..<s.count {
            rot := f32(i) / f32(s.count - 1) * 360 + s.iterAngle * f32(iteration)
            SpawnBullet(bossPos + RotOffset(rot, s.radius), math.to_radians(rot), false)
        }
        return true
    }

    // fmt.eprintln("Unhandled step return", step)
    return true
}