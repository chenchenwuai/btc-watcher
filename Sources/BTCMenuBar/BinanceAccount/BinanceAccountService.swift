import CryptoKit
import Foundation

struct BinanceOpenOrder: Decodable {
    let side: String
    let price: String
    let positionSide: String?
    let closePosition: Bool?
    let type: String?
    let status: String?
    let origQty: String?
    let executedQty: String?
    let stopPrice: String?
    let orderType: String?
    let algoStatus: String?
    let quantity: String?
    let triggerPrice: String?
}

struct BinanceFuturesPosition: Decodable {
    let symbol: String
    let positionSide: String
    let amount: Double
    let quantity: String
    let entryPrice: Double
    let markPrice: Double
    let unrealizedPnl: Double
    let initialMargin: Double
    let marginAsset: String

    var isShort: Bool { positionSide == "SHORT" || (positionSide == "BOTH" && amount < 0) }

    private enum CodingKeys: String, CodingKey {
        case symbol, positionSide, entryPrice, markPrice, marginAsset
        case amount = "positionAmt"
        case unrealizedPnl = "unRealizedProfit"
        case initialMargin = "positionInitialMargin"
    }

    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try fields.decode(String.self, forKey: .symbol)
        positionSide = try fields.decode(String.self, forKey: .positionSide)
        guard ["BOTH", "LONG", "SHORT"].contains(positionSide) else {
            throw DecodingError.dataCorruptedError(forKey: .positionSide, in: fields, debugDescription: "Invalid position side")
        }
        marginAsset = try fields.decode(String.self, forKey: .marginAsset)
        let rawAmount = try fields.decode(String.self, forKey: .amount)
        guard let signedAmount = Double(rawAmount), signedAmount.isFinite else {
            throw DecodingError.dataCorruptedError(forKey: .amount, in: fields, debugDescription: "Invalid position amount")
        }
        amount = signedAmount
        quantity = rawAmount.hasPrefix("-") ? String(rawAmount.dropFirst()) : rawAmount
        entryPrice = try Self.number(in: fields, for: .entryPrice)
        markPrice = try Self.number(in: fields, for: .markPrice)
        unrealizedPnl = try Self.number(in: fields, for: .unrealizedPnl)
        initialMargin = try Self.number(in: fields, for: .initialMargin)
    }

    private static func number(in fields: KeyedDecodingContainer<CodingKeys>, for key: CodingKeys) throws -> Double {
        let value = try fields.decode(String.self, forKey: key)
        guard let number = Double(value), number.isFinite else {
            throw DecodingError.dataCorruptedError(forKey: key, in: fields, debugDescription: "Invalid position number")
        }
        return number
    }
}

final class BinanceAccountService: NSObject, URLSessionTaskDelegate {
    enum Failure: Error {
        case invalidRequest
        case invalidResponse
        case rejected(httpStatus: Int, code: Int?)
    }

    private struct APIError: Decodable {
        let code: Int
    }

    private enum Endpoint: String {
        case spot = "/api/v3/openOrders"
        case futures = "/fapi/v1/openOrders"
        case futuresAlgo = "/fapi/v1/openAlgoOrders"
        case futuresPositions = "/fapi/v3/positionRisk"

        var host: String { self == .spot ? "api.binance.com" : "fapi.binance.com" }
    }

    func openOrders(symbol: String, futures: Bool, apiKey: String, secretKey: Data,
                    configuration: URLSessionConfiguration) async throws -> [BinanceOpenOrder] {
        let session = makeSession(configuration)
        defer { session.finishTasksAndInvalidate() }

        let key = SymmetricKey(data: secretKey)
        let response = [BinanceOpenOrder].self
        if futures {
            async let regular = fetch(response, from: .futures, symbol: symbol, apiKey: apiKey, key: key, session: session)
            async let conditional = fetch(response, from: .futuresAlgo, symbol: symbol, apiKey: apiKey, key: key, session: session)
            return try await regular + conditional
        }
        return try await fetch(response, from: .spot, symbol: symbol, apiKey: apiKey, key: key, session: session)
    }

    func futuresPositions(apiKey: String, secretKey: Data,
                          configuration: URLSessionConfiguration) async throws -> [BinanceFuturesPosition] {
        let session = makeSession(configuration)
        defer { session.finishTasksAndInvalidate() }

        let positions = try await fetch([BinanceFuturesPosition].self, from: .futuresPositions,
                                        apiKey: apiKey, key: SymmetricKey(data: secretKey), session: session)
        return positions.filter { $0.amount != 0 }
    }

    private func makeSession(_ configuration: URLSessionConfiguration) -> URLSession {
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    private func fetch<Response: Decodable>(_ type: Response.Type, from endpoint: Endpoint, symbol: String? = nil,
                                            apiKey: String, key: SymmetricKey, session: URLSession) async throws -> Response {
        var components = URLComponents()
        components.scheme = "https"
        components.host = endpoint.host
        components.path = endpoint.rawValue
        var queryItems: [URLQueryItem] = []
        if let symbol { queryItems.append(URLQueryItem(name: "symbol", value: symbol)) }
        queryItems.append(URLQueryItem(name: "timestamp", value: String(Int64(Date().timeIntervalSince1970 * 1000))))
        components.queryItems = queryItems
        guard let query = components.percentEncodedQuery else { throw Failure.invalidRequest }
        let signature = HMAC<SHA256>.authenticationCode(for: Data(query.utf8), using: key)
            .map { String(format: "%02x", $0) }.joined()
        components.percentEncodedQuery = query + "&signature=" + signature
        guard let url = components.url else { throw Failure.invalidRequest }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-MBX-APIKEY")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw Failure.invalidResponse }
        let decoder = JSONDecoder()
        guard (200..<300).contains(response.statusCode) else {
            let code = (try? decoder.decode(APIError.self, from: data))?.code
            throw Failure.rejected(httpStatus: response.statusCode, code: code)
        }
        guard let result = try? decoder.decode(type, from: data) else {
            throw Failure.invalidResponse
        }
        return result
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Signed requests must stay on the intended Binance host.
        completionHandler(nil)
    }
}
