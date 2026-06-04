//
//  HTTPStatus.swift
//  SwiftBaseClassWAC
//
//  Lightweight helpers for interpreting HTTP status codes.
//

enum HTTPStatusCategory {
    case informational // 1xx
    case success // 2xx
    case redirection // 3xx
    case clientError // 4xx
    case serverError // 5xx
    case unknown

    init(code: Int) {
        switch code {
        case 100 ..< 200: self = .informational
        case 200 ..< 300: self = .success
        case 300 ..< 400: self = .redirection
        case 400 ..< 500: self = .clientError
        case 500 ..< 600: self = .serverError
        default: self = .unknown
        }
    }
}

extension Int {
    /// The category this status code belongs to.
    var httpStatusCategory: HTTPStatusCategory {
        HTTPStatusCategory(code: self)
    }

    /// `true` for 2xx status codes.
    var isSuccessStatus: Bool {
        httpStatusCategory == .success
    }
}
