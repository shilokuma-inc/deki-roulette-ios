import Foundation
import Testing
@testable import DekiRoulette

struct WheelTiltTests {
    /// 画面の横軸まわりに `degrees` だけ起こした姿勢の重力（0 で水平、90 で縦）。
    private func raised(_ degrees: Double) -> DeviceGravity {
        let rad = degrees * .pi / 180
        return DeviceGravity(x: 0, y: -sin(rad), z: -cos(rad))
    }

    /// 水平に置いたまま右を `degrees` だけ下げた姿勢の重力。
    private func rolledRight(_ degrees: Double) -> DeviceGravity {
        let rad = degrees * .pi / 180
        return DeviceGravity(x: sin(rad), y: 0, z: -cos(rad))
    }

    private func isClose(_ a: WheelTilt, _ b: WheelTilt) -> Bool {
        abs(a.pitch - b.pitch) < 1e-9 && abs(a.roll - b.roll) < 1e-9
    }

    // MARK: 端末の傾き

    @Test func 水平に置くと正面() throws {
        let tilt = try #require(TiltMapping.deviceTilt(.flat))
        #expect(isClose(tilt, .zero))
    }

    @Test func 起こすと盤の上端が奥へ倒れる() throws {
        let tilt = try #require(TiltMapping.deviceTilt(raised(30)))
        #expect(isClose(tilt, WheelTilt(pitch: 30, roll: 0)))
        let upright = try #require(TiltMapping.deviceTilt(raised(90)))
        #expect(isClose(upright, WheelTilt(pitch: 90, roll: 0)))
    }

    @Test func 右を下げると盤の右端が手前に起きる() throws {
        let tilt = try #require(TiltMapping.deviceTilt(rolledRight(20)))
        #expect(isClose(tilt, WheelTilt(pitch: 0, roll: 20)))
        let left = try #require(TiltMapping.deviceTilt(rolledRight(-20)))
        #expect(isClose(left, WheelTilt(pitch: 0, roll: -20)))
    }

    @Test func 重力の大きさに依らない() throws {
        let unit = try #require(TiltMapping.deviceTilt(DeviceGravity(x: 0.3, y: -0.4, z: -0.866)))
        let scaled = try #require(TiltMapping.deviceTilt(DeviceGravity(x: 0.6, y: -0.8, z: -1.732)))
        #expect(isClose(unit, scaled))
    }

    @Test func 重力が読めないときは傾きを出さない() {
        #expect(TiltMapping.deviceTilt(DeviceGravity(x: 0, y: 0, z: 0)) == nil)
    }

    // MARK: 水平に置いた状態を基準にする

    @Test func 水平基準では重力の向きでそのまま傾ける() {
        let tilt = TiltMapping.target(gravity: raised(10), baseline: .flat, reduceMotion: false, maxAngle: 25)
        #expect(isClose(tilt, WheelTilt(pitch: 10, roll: 0)))
        let rolled = TiltMapping.target(gravity: rolledRight(-8), baseline: .flat, reduceMotion: false, maxAngle: 25)
        #expect(isClose(rolled, WheelTilt(pitch: 0, roll: -8)))
    }

    @Test func 縦に起こすと最大角で止まる() {
        let tilt = TiltMapping.target(gravity: raised(90), baseline: .flat, reduceMotion: false, maxAngle: 25)
        #expect(isClose(tilt, WheelTilt(pitch: 25, roll: 0)))
    }

    @Test func 最大角の既定はConfigの値() {
        let tilt = TiltMapping.target(gravity: raised(90), baseline: .flat, reduceMotion: false)
        #expect(abs(tilt.magnitude - Config.wheelMaxTilt) < 1e-9)
    }

    // MARK: 画面を開いたときの持ち方を基準にする

    @Test func 持ち方基準では基準の姿勢のときに正面() {
        let tilt = TiltMapping.target(gravity: raised(60), baseline: raised(60), reduceMotion: false, maxAngle: 25)
        #expect(isClose(tilt, .zero))
    }

    @Test func 持ち方基準では基準からの変化で傾ける() {
        let back = TiltMapping.target(gravity: raised(70), baseline: raised(60), reduceMotion: false, maxAngle: 25)
        #expect(isClose(back, WheelTilt(pitch: 10, roll: 0)))
        let forward = TiltMapping.target(gravity: raised(45), baseline: raised(60), reduceMotion: false, maxAngle: 25)
        #expect(isClose(forward, WheelTilt(pitch: -15, roll: 0)))
    }

    @Test func 基準が無いときは正面() {
        let tilt = TiltMapping.target(gravity: raised(30), baseline: nil, reduceMotion: false, maxAngle: 25)
        #expect(isClose(tilt, .zero))
    }

    @Test func 基準が読めないときは正面() {
        let tilt = TiltMapping.target(gravity: raised(30), baseline: DeviceGravity(x: 0, y: 0, z: 0), reduceMotion: false, maxAngle: 25)
        #expect(isClose(tilt, .zero))
    }

    @Test func 持ち方基準でも最大角で止まる() {
        let tilt = TiltMapping.target(gravity: raised(0), baseline: raised(80), reduceMotion: false, maxAngle: 25)
        #expect(isClose(tilt, WheelTilt(pitch: -25, roll: 0)))
    }

    /// 基準が裏返し（画面が下向き）をまたいでも、差が一周分ずれて最大角に張り付かない。
    @Test func 基準からの差は一周をまたがない() {
        let tilt = TiltMapping.target(gravity: raised(185), baseline: raised(175), reduceMotion: false, maxAngle: 25)
        #expect(abs(tilt.pitch - 10) < 1e-9)
    }

    // MARK: 視差効果を減らす

    @Test func 視差効果を減らす設定では正面() {
        #expect(TiltMapping.target(gravity: raised(40), baseline: .flat, reduceMotion: true, maxAngle: 25) == .zero)
        #expect(TiltMapping.target(gravity: raised(40), baseline: raised(10), reduceMotion: true, maxAngle: 25) == .zero)
    }

    // MARK: 最大角で抑える

    @Test func 抑えるときは向きを保つ() {
        let tilt = TiltMapping.clamped(WheelTilt(pitch: 30, roll: 40), maxAngle: 25)
        #expect(abs(tilt.magnitude - 25) < 1e-9)
        #expect(abs(tilt.pitch / tilt.roll - 0.75) < 1e-9)
    }

    @Test func 最大角以内はそのまま() {
        let tilt = WheelTilt(pitch: 10, roll: -12)
        #expect(TiltMapping.clamped(tilt, maxAngle: 25) == tilt)
    }
}
