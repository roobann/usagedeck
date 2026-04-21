import Foundation
import GRDB

/// Fetch Kiro usage by calling the CodeWhisperer `GetUsageLimits` endpoint
/// using the bearer token that `kiro-cli` stores in its local SQLite DB.
///
/// This is the same internal API the CLI itself invokes to check credit
/// quotas during chat sessions — we just read the token from disk and
/// reproduce the call. Works for any kiro-cli-logged-in user (social
/// providers, Builder ID, IAM Identity Center) without any Keychain prompts,
/// cookie scraping, or separate web-portal login.
public struct KiroCLIStrategy: ProviderFetchStrategy, Sendable {
    public let id = "kiro-cli"
    public let kind = ProviderFetchKind.cli

    public init() {}

    public func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.cliDBPath().flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } != nil
    }

    public func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard var creds = try? Self.loadCredentials() else {
            throw ProviderFetchError.authenticationRequired(
                .kiro,
                message: "Run `kiro-cli login` to sign in."
            )
        }

        // If the access token is expired or close to expiring, ask kiro-cli
        // to refresh it using the refresh_token it already has stored. We
        // piggyback on `kiro-cli whoami`, which exercises kiro-cli's own
        // refresh path and writes the new token back to the SQLite DB.
        if let expiresAt = creds.expiresAt, expiresAt.timeIntervalSinceNow < 120 {
            await Self.refreshViaCLI()
            if let refreshed = try? Self.loadCredentials() {
                creds = refreshed
            }
        }

        let response = try await Self.fetchUsageLimits(
            accessToken: creds.accessToken,
            profileArn: creds.profileArn,
            region: creds.region
        )

        let identity = await Self.buildIdentity(from: response, fallback: creds)
        let snapshot = Self.buildSnapshot(response: response, identity: identity)
        return makeResult(usage: snapshot, sourceLabel: "cli")
    }

    public func shouldFallback(on error: Error, context: ProviderFetchContext) -> Bool {
        true
    }

    /// True when kiro-cli local DB exists on disk. Used for first-launch
    /// provider auto-detection — filesystem-only, no subprocess, no Keychain.
    public static func isSignedInLocally() -> Bool {
        guard let db = cliDBPath() else { return false }
        return FileManager.default.fileExists(atPath: db.path)
    }

    // MARK: - DB access

    static func cliDBPath() -> URL? {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/kiro-cli/data.sqlite3")
    }

    struct LocalCredentials {
        let accessToken: String
        let profileArn: String
        let region: String
        let expiresAt: Date?
    }

    static func loadCredentials() throws -> LocalCredentials {
        guard let dbPath = cliDBPath(),
              FileManager.default.fileExists(atPath: dbPath.path) else {
            throw ProviderFetchError.authenticationRequired(.kiro)
        }

        // Read-only DB queue so we don't interfere with running kiro-cli.
        var config = Configuration()
        config.readonly = true
        let queue = try DatabaseQueue(path: dbPath.path, configuration: config)

        let tokenJSON = try queue.read { db in
            try String.fetchOne(db, sql: "SELECT value FROM auth_kv WHERE key = ?", arguments: ["kirocli:social:token"])
                ?? String.fetchOne(db, sql: "SELECT value FROM auth_kv WHERE key = ?", arguments: ["kirocli:idc:token"])
        }
        guard let tokenJSON,
              let tokenData = tokenJSON.data(using: .utf8),
              let tokenDict = try JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
              let accessToken = tokenDict["access_token"] as? String else {
            throw ProviderFetchError.invalidCredentials(.kiro)
        }

        let profileJSON = try queue.read { db in
            try String.fetchOne(db, sql: "SELECT CAST(value AS TEXT) FROM state WHERE key = ?",
                                arguments: ["api.codewhisperer.profile"])
        }
        guard let profileJSON,
              let profileData = profileJSON.data(using: .utf8),
              let profileDict = try JSONSerialization.jsonObject(with: profileData) as? [String: Any],
              let arn = profileDict["arn"] as? String else {
            throw ProviderFetchError.invalidCredentials(.kiro)
        }

        // Parse region out of the ARN: arn:aws:codewhisperer:<region>:...
        let parts = arn.split(separator: ":")
        let region = parts.count >= 4 ? String(parts[3]) : "us-east-1"

        let expiresAt = (tokenDict["expires_at"] as? String).flatMap(Self.parseExpiry)

        return LocalCredentials(
            accessToken: accessToken,
            profileArn: arn,
            region: region,
            expiresAt: expiresAt
        )
    }

    private static func parseExpiry(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    /// Spawn `kiro-cli whoami` and wait briefly for it to finish. Triggers
    /// kiro-cli's own refresh-token flow as a side effect, persisting the
    /// refreshed access token back to the SQLite DB. We ignore the output —
    /// we only care that the DB is up to date when we reread it.
    private static func refreshViaCLI() async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["kiro-cli", "whoami", "--format", "json"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return
        }

        // Poll for completion with an 8s hard cap so a hung kiro-cli can't
        // block the refresh pipeline.
        for _ in 0..<80 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if !process.isRunning { return }
        }
        process.terminate()
    }

    // MARK: - HTTP call

    static func fetchUsageLimits(
        accessToken: String,
        profileArn: String,
        region: String
    ) async throws -> GetUsageLimitsResponse {
        let host = Self.endpointHost(for: region)
        guard let url = URL(string: "https://\(host)/") else {
            throw ProviderFetchError.networkError("Invalid endpoint URL for region \(region)")
        }

        let body: [String: Any] = [
            "profileArn": profileArn,
            "isEmailRequired": true,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-amz-json-1.0", forHTTPHeaderField: "Content-Type")
        request.setValue("application/x-amz-json-1.0", forHTTPHeaderField: "Accept")
        request.setValue("AmazonCodeWhispererService.GetUsageLimits", forHTTPHeaderField: "X-Amz-Target")
        request.setValue("UsageDeck", forHTTPHeaderField: "User-Agent")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderFetchError.networkError("No response")
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(GetUsageLimitsResponse.self, from: data)
        case 401, 403:
            throw ProviderFetchError.authenticationRequired(
                .kiro,
                message: "Kiro credentials expired. Run `kiro-cli login` again."
            )
        default:
            let snippet = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw ProviderFetchError.networkError("HTTP \(http.statusCode): \(snippet)")
        }
    }

    private static func endpointHost(for region: String) -> String {
        switch region {
        case "us-gov-east-1", "us-gov-west-1", "eu-central-1":
            return "q.\(region).amazonaws.com"
        default:
            return "codewhisperer.\(region).amazonaws.com"
        }
    }

    // MARK: - Mapping

    @MainActor
    static func buildIdentity(from response: GetUsageLimitsResponse, fallback: LocalCredentials) async -> ProviderIdentity {
        ProviderIdentity(
            email: response.userInfo?.email,
            organization: nil,
            plan: response.subscriptionInfo?.subscriptionTitle,
            authMethod: "Kiro CLI"
        )
    }

    static func buildSnapshot(response: GetUsageLimitsResponse, identity: ProviderIdentity) -> UsageSnapshot {
        let breakdown = response.usageBreakdownList?.first

        // When a free trial is active, that pool is the one actually being
        // consumed — surface it as the primary window. The post-trial monthly
        // allocation shows as secondary.
        var primary: RateWindow?
        var secondary: RateWindow?

        if let trial = breakdown?.freeTrialInfo, trial.freeTrialStatus == "ACTIVE" {
            primary = rateWindow(
                used: trial.currentUsageWithPrecision ?? Double(trial.currentUsage ?? 0),
                limit: trial.usageLimitWithPrecision ?? Double(trial.usageLimit ?? 0),
                resetsAt: epoch(trial.freeTrialExpiry),
                label: "Trial \(breakdown?.displayNamePlural ?? "Credits")"
            )
            if let b = breakdown {
                secondary = rateWindow(
                    used: b.currentUsageWithPrecision ?? Double(b.currentUsage ?? 0),
                    limit: b.usageLimitWithPrecision ?? Double(b.usageLimit ?? 0),
                    resetsAt: epoch(b.nextDateReset ?? response.nextDateReset),
                    label: "Monthly"
                )
            }
        } else if let b = breakdown {
            primary = rateWindow(
                used: b.currentUsageWithPrecision ?? Double(b.currentUsage ?? 0),
                limit: b.usageLimitWithPrecision ?? Double(b.usageLimit ?? 0),
                resetsAt: epoch(b.nextDateReset ?? response.nextDateReset),
                label: b.displayNamePlural ?? "Credits"
            )
        }

        return UsageSnapshot(
            providerID: .kiro,
            primary: primary,
            secondary: secondary,
            updatedAt: Date(),
            identity: identity,
            metadata: [
                "plan": response.subscriptionInfo?.subscriptionTitle ?? "",
                "type": response.subscriptionInfo?.type ?? "",
            ]
        )
    }

    private static func rateWindow(used: Double, limit: Double, resetsAt: Date?, label: String) -> RateWindow? {
        guard limit > 0 else { return nil }
        let percent = min(100.0, (used / limit) * 100.0)
        return RateWindow(
            usedPercent: percent,
            usedMessages: Int(used.rounded()),
            limitMessages: Int(limit.rounded()),
            resetsAt: resetsAt,
            label: label
        )
    }

    private static func epoch(_ seconds: Double?) -> Date? {
        guard let s = seconds else { return nil }
        return Date(timeIntervalSince1970: s)
    }
}

// MARK: - Response types

struct GetUsageLimitsResponse: Codable {
    let daysUntilReset: Int?
    let nextDateReset: Double?
    let subscriptionInfo: SubscriptionInfo?
    let overageConfiguration: OverageConfiguration?
    let usageBreakdownList: [UsageBreakdown]?
    let userInfo: UserInfo?
}

struct SubscriptionInfo: Codable {
    let subscriptionTitle: String?
    let type: String?
    let overageCapability: String?
    let upgradeCapability: String?
    let subscriptionManagementTarget: String?
}

struct OverageConfiguration: Codable {
    let overageStatus: String?
}

struct UsageBreakdown: Codable {
    let resourceType: String?
    let unit: String?
    let currency: String?
    let currentUsage: Int?
    let currentUsageWithPrecision: Double?
    let usageLimit: Int?
    let usageLimitWithPrecision: Double?
    let nextDateReset: Double?
    let overageRate: Double?
    let overageCap: Int?
    let overageCharges: Double?
    let displayName: String?
    let displayNamePlural: String?
    let freeTrialInfo: FreeTrialInfo?
}

struct FreeTrialInfo: Codable {
    let currentUsage: Int?
    let currentUsageWithPrecision: Double?
    let usageLimit: Int?
    let usageLimitWithPrecision: Double?
    let freeTrialStatus: String?
    let freeTrialExpiry: Double?
}

struct UserInfo: Codable {
    let email: String?
    let userId: String?
}
