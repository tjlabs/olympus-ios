import Foundation

final class JSONConverter {
    static func decodeJsonArray<T: Codable>(data: Data) -> [T]? {
        do {
            let result = try JSONDecoder().decode([T].self, from: data)
            return result
        } catch {
            guard let error = error as? DecodingError else { return nil }
            
            switch error {
            case .dataCorrupted(let context):
//                print(context.codingPath, context.debugDescription, context.underlyingError)
                return nil
            default:
                return nil
            }
        }
    }
    
    static func decodeJson<T: Codable>(data: Data) -> T? {
        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            return result
        } catch {
            guard let error = error as? DecodingError else { return nil }
            
            switch error {
            case .dataCorrupted(let context):
//                print(context.codingPath, context.debugDescription, context.underlyingError)
                return nil
            default:
                return nil
            }
        }
    }
    
    static func encodeJson<T: Codable>(param: T) -> Data? {
        do {
            let result = try JSONEncoder().encode(param)
            return result
        } catch {
            return nil
        }
    }
}
