import Foundation

struct ChatRequest: Codable {
    let prompt: String
}

struct ChatResponse: Codable {
    let response: String
    let timestamp: String?
}

class APIClient {
    // Update this URL with your actual backend endpoint
    // For Google Cloud Functions: https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/chatbot/chat
    // For local development: http://localhost:8080/chat
    private static let baseURL = "https://us-central1-your-project.cloudfunctions.net/chatbot"
    
    static func sendMessage(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/chat") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        let chatRequest = ChatRequest(prompt: prompt)
        
        do {
            let jsonData = try JSONEncoder().encode(chatRequest)
            request.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(APIError.invalidResponse))
                    return
                }
                
                guard httpResponse.statusCode == 200 else {
                    let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                    completion(.failure(APIError.serverError(httpResponse.statusCode, errorMessage)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(APIError.noData))
                    return
                }
                
                do {
                    let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
                    completion(.success(chatResponse.response))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    static func healthCheck(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/health") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    completion(.failure(APIError.serverUnavailable))
                    return
                }
                
                completion(.success(true))
            }
        }.resume()
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case serverError(Int, String)
    case serverUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .noData:
            return "No data received from server"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .serverUnavailable:
            return "Server is currently unavailable"
        }
    }
}
