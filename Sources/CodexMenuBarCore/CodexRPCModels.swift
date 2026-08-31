import Foundation

struct RPCResponse<Result: Decodable>:
    Decodable
{
    let id: Int
    let result: Result?
    let error: RPCError?
}

struct RPCError: Decodable {
    let code: Int?
    let message: String
}

struct RateLimitsUpdatedNotification:
    Decodable
{
    let method: String
    let params: RateLimitsUpdatedParams
}

struct RateLimitsUpdatedParams:
    Decodable
{
    let rateLimits: RateLimitSnapshot
}
