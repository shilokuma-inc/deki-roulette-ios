#!/usr/bin/env swift
// App Store Connect にスクリーンショットをアップロードする。
//
//   swift scripts/asc-upload-screenshots.swift [--dir screenshots] [--version 1.0.0] [--dry-run]
//
// 認証は App Store Connect API Key（環境変数）:
//   ASC_KEY_ID           キー ID（例: ABC123DEFG）
//   ASC_ISSUER_ID        Issuer ID
//   ASC_PRIVATE_KEY_PATH AuthKey_XXXX.p8 のパス
//   ASC_BUNDLE_ID        省略時は ml.mrs1669.DekiRoulette
//
// 入力は scripts/capture-screenshots.sh の出力ディレクトリ:
//   <dir>/<ASC ロケール>/<screenshotDisplayType>/NN-name.png
// ロケール × displayType ごとにスクリーンショットセットを見つけ（無ければ作り）、
// 既存の画像をすべて消してからファイル名順にアップロードする。
// 対象バージョンは --version で指定するか、省略時は編集可能な状態の最新バージョン。
// ロケールに対応する App Store 情報（appStoreVersionLocalization）が無い場合はスキップする。

import CryptoKit
import Foundation

// MARK: - 引数と環境変数

struct Options {
    var dir = "screenshots"
    var version: String?
    var dryRun = false
    var bundleID = ProcessInfo.processInfo.environment["ASC_BUNDLE_ID"] ?? "ml.mrs1669.DekiRoulette"

    init(arguments: [String]) {
        var it = arguments.makeIterator()
        while let arg = it.next() {
            switch arg {
            case "--dir": dir = it.next() ?? dir
            case "--version": version = it.next()
            case "--dry-run": dryRun = true
            case "-h", "--help":
                print("usage: asc-upload-screenshots.swift [--dir DIR] [--version X.Y.Z] [--dry-run]")
                exit(0)
            default: fail("unknown argument: \(arg)")
            }
        }
    }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func log(_ message: String) {
    print("==> \(message)")
}

func env(_ name: String) -> String {
    guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
        fail("環境変数 \(name) が設定されていません")
    }
    return value
}

// MARK: - JWT (ES256)

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func makeToken(keyID: String, issuerID: String, privateKeyPEM: String) throws -> String {
    let key = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
    let header: [String: Any] = ["alg": "ES256", "kid": keyID, "typ": "JWT"]
    let now = Int(Date().timeIntervalSince1970)
    let payload: [String: Any] = [
        "iss": issuerID,
        "iat": now,
        "exp": now + 15 * 60,
        "aud": "appstoreconnect-v1",
    ]
    let signingInput = try [header, payload]
        .map { base64URL(try JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys])) }
        .joined(separator: ".")
    let signature = try key.signature(for: Data(signingInput.utf8))
    return signingInput + "." + base64URL(signature.rawRepresentation)
}

// MARK: - HTTP

struct HTTPError: Error, CustomStringConvertible {
    let status: Int
    let body: String
    var description: String { "HTTP \(status): \(body)" }
}

final class HTTP {
    private let session = URLSession(configuration: .ephemeral)

    /// 同期的にリクエストを送る。スクリプトなのでメインスレッドを塞いでよい。
    func send(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<(Data, HTTPURLResponse), Error>!
        session.dataTask(with: request) { data, response, error in
            if let error {
                result = .failure(error)
            } else if let response = response as? HTTPURLResponse {
                result = .success((data ?? Data(), response))
            } else {
                result = .failure(URLError(.badServerResponse))
            }
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return try result.get()
    }
}

final class ASCClient {
    static let base = URL(string: "https://api.appstoreconnect.apple.com")!
    private let http = HTTP()
    private let token: String

    init(token: String) {
        self.token = token
    }

    typealias JSON = [String: Any]

    @discardableResult
    func call(_ method: String, _ path: String, query: [String: String] = [:], body: JSON? = nil) throws -> JSON {
        var components = URLComponents(url: Self.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try http.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw HTTPError(status: response.statusCode, body: String(decoding: data, as: UTF8.self))
        }
        if data.isEmpty { return [:] }
        return try JSONSerialization.jsonObject(with: data) as? JSON ?? [:]
    }

    /// 署名付き URL へチャンクを PUT する（Authorization は付けない）
    func upload(operation: JSON, file: Data) throws {
        guard
            let urlString = operation["url"] as? String, let url = URL(string: urlString),
            let method = operation["method"] as? String,
            let offset = operation["offset"] as? Int, let length = operation["length"] as? Int
        else { fail("uploadOperation の形式が不正です: \(operation)") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        for header in operation["requestHeaders"] as? [JSON] ?? [] {
            if let name = header["name"] as? String, let value = header["value"] as? String {
                request.setValue(value, forHTTPHeaderField: name)
            }
        }
        request.httpBody = file.subdata(in: offset..<min(offset + length, file.count))
        let (data, response) = try http.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw HTTPError(status: response.statusCode, body: String(decoding: data, as: UTF8.self))
        }
    }
}

// MARK: - JSON:API ヘルパ

typealias Resource = [String: Any]

func items(_ json: [String: Any]) -> [Resource] {
    json["data"] as? [Resource] ?? []
}

func attribute<T>(_ resource: Resource, _ name: String, as type: T.Type = T.self) -> T? {
    (resource["attributes"] as? [String: Any])?[name] as? T
}

func id(_ resource: Resource) -> String {
    resource["id"] as? String ?? ""
}

func relationship(type: String, id: String) -> [String: Any] {
    ["data": ["type": type, "id": id]]
}

// MARK: - 本体

let options = Options(arguments: Array(CommandLine.arguments.dropFirst()))
let fm = FileManager.default
let rootURL = URL(fileURLWithPath: options.dir, isDirectory: true)
guard fm.fileExists(atPath: rootURL.path) else {
    fail("\(options.dir) がありません。先に scripts/capture-screenshots.sh を実行してください")
}

func subdirectories(of url: URL) -> [URL] {
    ((try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])) ?? [])
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

func pngs(in url: URL) -> [URL] {
    ((try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? [])
        .filter { $0.pathExtension.lowercased() == "png" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
}

let keyID = env("ASC_KEY_ID")
let issuerID = env("ASC_ISSUER_ID")
let privateKeyPath = env("ASC_PRIVATE_KEY_PATH")
guard let pem = try? String(contentsOfFile: privateKeyPath, encoding: .utf8) else {
    fail("秘密鍵を読めません: \(privateKeyPath)")
}

let client: ASCClient
do {
    client = ASCClient(token: try makeToken(keyID: keyID, issuerID: issuerID, privateKeyPEM: pem))
} catch {
    fail("JWT の生成に失敗しました: \(error)")
}

do {
    // 1. アプリ
    let apps = items(try client.call("GET", "/v1/apps", query: ["filter[bundleId]": options.bundleID]))
    guard let app = apps.first else { fail("Bundle ID \(options.bundleID) のアプリが見つかりません") }
    log("app: \(attribute(app, "name") as String? ?? "") (\(id(app)))")

    // 2. バージョン（編集できる状態のもの）
    let editableStates: Set<String> = [
        "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
        "WAITING_FOR_REVIEW", "INVALID_BINARY",
    ]
    var versionQuery = ["filter[platform]": "IOS", "limit": "20"]
    if let version = options.version { versionQuery["filter[versionString]"] = version }
    let versions = items(try client.call("GET", "/v1/apps/\(id(app))/appStoreVersions", query: versionQuery))
    guard let version = versions.first(where: { v in
        let state: String = attribute(v, "appVersionState") ?? attribute(v, "appStoreState") ?? ""
        return options.version != nil || editableStates.contains(state)
    }) else {
        let listing = versions.map { "\(attribute($0, "versionString") as String? ?? "?") [\(attribute($0, "appVersionState") as String? ?? attribute($0, "appStoreState") as String? ?? "?")]" }
        fail("編集可能なバージョンが見つかりません。候補: \(listing.joined(separator: ", "))。--version で指定するか、App Store Connect で新しいバージョンを作ってください")
    }
    let versionState: String = attribute(version, "appVersionState") ?? attribute(version, "appStoreState") ?? "?"
    log("version: \(attribute(version, "versionString") as String? ?? "?") [\(versionState)]")

    // 3. ロケールごとの App Store 情報
    let localizations = items(try client.call(
        "GET", "/v1/appStoreVersions/\(id(version))/appStoreVersionLocalizations", query: ["limit": "50"]
    ))
    let localizationByLocale = Dictionary(
        uniqueKeysWithValues: localizations.compactMap { loc in (attribute(loc, "locale") as String?).map { ($0, loc) } }
    )

    var uploaded = 0
    var pending: [(name: String, id: String)] = []

    for localeDir in subdirectories(of: rootURL) {
        let locale = localeDir.lastPathComponent
        guard let localization = localizationByLocale[locale] else {
            log("skip \(locale): このバージョンにロケール \(locale) の App Store 情報がありません（App Store Connect で追加してください）")
            continue
        }
        var sets = items(try client.call(
            "GET", "/v1/appStoreVersionLocalizations/\(id(localization))/appScreenshotSets", query: ["limit": "50"]
        ))

        for typeDir in subdirectories(of: localeDir) {
            let displayType = typeDir.lastPathComponent
            let files = pngs(in: typeDir)
            guard !files.isEmpty else { continue }
            log("\(locale) / \(displayType): \(files.count) 枚")

            // 4. スクリーンショットセット
            var setID: String
            if let existing = sets.first(where: { attribute($0, "screenshotDisplayType") == displayType }) {
                setID = id(existing)
            } else if options.dryRun {
                print("    [dry-run] セットを作成: \(displayType)")
                setID = "(new)"
            } else {
                let created = try client.call("POST", "/v1/appScreenshotSets", body: [
                    "data": [
                        "type": "appScreenshotSets",
                        "attributes": ["screenshotDisplayType": displayType],
                        "relationships": [
                            "appStoreVersionLocalization": relationship(type: "appStoreVersionLocalizations", id: id(localization)),
                        ],
                    ],
                ])
                let resource = created["data"] as? Resource ?? [:]
                setID = id(resource)
                sets.append(resource)
                print("    セットを作成: \(displayType) (\(setID))")
            }

            // 5. 既存の画像を消す
            if setID != "(new)" {
                let existing = items(try client.call("GET", "/v1/appScreenshotSets/\(setID)/appScreenshots", query: ["limit": "50"]))
                for shot in existing {
                    if options.dryRun {
                        print("    [dry-run] 削除: \(attribute(shot, "fileName") as String? ?? id(shot))")
                    } else {
                        try client.call("DELETE", "/v1/appScreenshots/\(id(shot))")
                        print("    削除: \(attribute(shot, "fileName") as String? ?? id(shot))")
                    }
                }
            }

            // 6. アップロード（予約 → チャンク PUT → コミット）
            for file in files {
                let data = try Data(contentsOf: file)
                if options.dryRun {
                    print("    [dry-run] アップロード: \(file.lastPathComponent) (\(data.count) bytes)")
                    continue
                }
                let reserved = try client.call("POST", "/v1/appScreenshots", body: [
                    "data": [
                        "type": "appScreenshots",
                        "attributes": ["fileName": file.lastPathComponent, "fileSize": data.count],
                        "relationships": ["appScreenshotSet": relationship(type: "appScreenshotSets", id: setID)],
                    ],
                ])
                let shot = reserved["data"] as? Resource ?? [:]
                let operations: [Resource] = attribute(shot, "uploadOperations") ?? []
                for operation in operations {
                    try client.upload(operation: operation, file: data)
                }
                let checksum = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
                try client.call("PATCH", "/v1/appScreenshots/\(id(shot))", body: [
                    "data": [
                        "type": "appScreenshots",
                        "id": id(shot),
                        "attributes": ["uploaded": true, "sourceFileChecksum": checksum],
                    ],
                ])
                pending.append((name: "\(locale)/\(displayType)/\(file.lastPathComponent)", id: id(shot)))
                uploaded += 1
                print("    アップロード: \(file.lastPathComponent)")
            }
        }
    }

    // 7. Apple 側の処理完了を待つ
    if !pending.isEmpty {
        log("処理待ち (\(pending.count) 枚)")
        let deadline = Date(timeIntervalSinceNow: 180)
        while !pending.isEmpty && Date() < deadline {
            Thread.sleep(forTimeInterval: 5)
            for (index, item) in pending.enumerated().reversed() {
                let shot = try client.call("GET", "/v1/appScreenshots/\(item.id)")["data"] as? Resource ?? [:]
                let delivery: [String: Any] = attribute(shot, "assetDeliveryState") ?? [:]
                let state = delivery["state"] as? String ?? "?"
                switch state {
                case "COMPLETE":
                    print("    ✓ \(item.name)")
                    pending.remove(at: index)
                case "FAILED":
                    print("    ✗ \(item.name): \(delivery["errors"] ?? "")")
                    pending.remove(at: index)
                default:
                    continue
                }
            }
        }
        for item in pending {
            print("    … \(item.name) はまだ処理中です。App Store Connect で確認してください")
        }
    }

    log(options.dryRun ? "dry-run 完了（変更は行っていません）" : "完了: \(uploaded) 枚アップロード")
} catch let error as HTTPError {
    fail(error.description)
} catch {
    fail("\(error)")
}
