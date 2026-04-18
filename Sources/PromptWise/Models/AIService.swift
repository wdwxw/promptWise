import Foundation

/// AI 日志管理器
final class AILogger {
    static let shared = AILogger()
    
    private let fileURL: URL
    private let dateFormatter: DateFormatter
    
    /// 检查 Debug 模式是否启用
    var isDebugEnabled: Bool {
        UserDefaults.standard.bool(forKey: "debugModeEnabled")
    }
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("PromptWise", isDirectory: true)
        let logsFolder = appFolder.appendingPathComponent("logs", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: logsFolder, withIntermediateDirectories: true)
        
        self.fileURL = logsFolder.appendingPathComponent("ai_service.log")
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // 启动时清理过大的日志（超过 5MB）
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int64, size > 5_000_000 {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    func log(_ message: String, level: String = "INFO") {
        guard isDebugEnabled else { return }
        writeLog(message, level: level)
    }
    
    func error(_ message: String) {
        guard isDebugEnabled else { return }
        writeLog(message, level: "ERROR")
    }
    
    func debug(_ message: String) {
        guard isDebugEnabled else { return }
        writeLog(message, level: "DEBUG")
    }
    
    /// 无论 Debug 模式如何，都输出日志（用于关键错误）
    func forceLog(_ message: String, level: String = "INFO") {
        writeLog(message, level: level)
    }
    
    private func writeLog(_ message: String, level: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logLine = "[\(timestamp)] [\(level)] \(message)\n"
        
        print(logLine, terminator: "")
        
        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
    
    /// 记录详细的请求参数
    func logRequest(method: String, url: String, headers: [String: String]?, body: Any?) {
        guard isDebugEnabled else { return }
        
        var logMessage = "=== API 请求 ===\n"
        logMessage += "方法: \(method)\n"
        logMessage += "URL: \(url)\n"
        
        if let headers = headers, !headers.isEmpty {
            logMessage += "请求头:\n"
            for (key, value) in headers {
                // 隐藏 API Key 的敏感信息
                if key.lowercased().contains("authorization") {
                    let maskedValue = value.count > 10 ? "\(value.prefix(10))..." : "***"
                    logMessage += "  \(key): \(maskedValue)\n"
                } else {
                    logMessage += "  \(key): \(value)\n"
                }
            }
        }
        
        if let body = body {
            logMessage += "请求体:\n"
            if let dict = body as? [String: Any] {
                logMessage += formatJSON(dict)
            } else if let data = body as? Data,
                      let str = String(data: data, encoding: .utf8) {
                logMessage += "  \(str)\n"
            } else {
                logMessage += "  \(body)\n"
            }
        }
        
        writeLog(logMessage, level: "DEBUG")
    }
    
    /// 记录详细的响应内容
    func logResponse(statusCode: Int, headers: [String: String]?, body: String?, truncateAt: Int = 2000) {
        guard isDebugEnabled else { return }
        
        var logMessage = "=== API 响应 ===\n"
        logMessage += "状态码: \(statusCode)\n"
        
        if let headers = headers, !headers.isEmpty {
            logMessage += "响应头:\n"
            for (key, value) in headers {
                logMessage += "  \(key): \(value)\n"
            }
        }
        
        if let body = body {
            let displayBody: String
            if body.count > truncateAt {
                displayBody = String(body.prefix(truncateAt)) + "... [已截断，共 \(body.count) 字符]"
            } else {
                displayBody = body
            }
            logMessage += "响应体:\n  \(displayBody)\n"
        }
        
        writeLog(logMessage, level: "DEBUG")
    }
    
    /// 记录流式响应的片段
    func logStreamChunk(_ chunk: String, index: Int) {
        guard isDebugEnabled else { return }
        writeLog("流式片段 #\(index): \(chunk)", level: "DEBUG")
    }
    
    private func formatJSON(_ dict: [String: Any], indent: Int = 2) -> String {
        var result = ""
        let spaces = String(repeating: " ", count: indent)
        
        for (key, value) in dict {
            if let nested = value as? [String: Any] {
                result += "\(spaces)\(key):\n"
                result += formatJSON(nested, indent: indent + 2)
            } else if let array = value as? [[String: Any]] {
                result += "\(spaces)\(key): [\n"
                for item in array {
                    result += formatJSON(item, indent: indent + 2)
                }
                result += "\(spaces)]\n"
            } else {
                result += "\(spaces)\(key): \(value)\n"
            }
        }
        
        return result
    }
    
    var logFilePath: String {
        fileURL.path
    }
}

/// AI 服务错误类型
enum AIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(String)
    case networkError(Error)
    case noModelSelected
    case streamingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code, let message):
            return "HTTP 错误 \(code): \(message)"
        case .decodingError(let message):
            return "解析错误: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .noModelSelected:
            return "未选择模型"
        case .streamingError(let message):
            return "流式传输错误: \(message)"
        }
    }
}

/// Ollama 模型信息
struct OllamaModel: Codable {
    let name: String
    let size: Int64?
    let digest: String?
    let modifiedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case size
        case digest
        case modifiedAt = "modified_at"
    }
}

/// Ollama 模型列表响应
struct OllamaModelsResponse: Codable {
    let models: [OllamaModel]
}

/// AI 服务
@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var isLoading = false
    @Published var error: AIServiceError?
    
    private init() {}
    
    // MARK: - Ollama 模型列表获取
    
    /// 获取 Ollama 可用模型列表
    func fetchOllamaModels(baseURL: String) async throws -> [String] {
        let logger = AILogger.shared
        let urlString = baseURL.trimmingCharacters(in: .init(charactersIn: "/")) + "/api/tags"
        logger.log("获取 Ollama 模型列表: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            logger.error("无效的 URL: \(urlString)")
            throw AIServiceError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("无效的响应类型")
                throw AIServiceError.invalidResponse
            }
            
            logger.log("HTTP 响应状态码: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                logger.error("HTTP 错误: \(httpResponse.statusCode) - \(message)")
                throw AIServiceError.httpError(statusCode: httpResponse.statusCode, message: message)
            }
            
            let modelsResponse = try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
            let modelNames = modelsResponse.models.map { $0.name }
            logger.log("获取到 \(modelNames.count) 个模型: \(modelNames.joined(separator: ", "))")
            return modelNames
        } catch let error as AIServiceError {
            throw error
        } catch {
            logger.error("网络错误: \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - 优化请求（非流式）
    
    /// 发送优化请求（非流式）
    func optimize(
        userPrompt: String,
        config: AIModelConfig
    ) async throws -> String {
        let logger = AILogger.shared
        logger.log("开始优化请求（非流式）")
        logger.log("  配置名称: \(config.name)")
        logger.log("  API 格式: \(config.apiFormat.displayName)")
        logger.log("  模型: \(config.modelName)")
        logger.log("  Base URL: \(config.baseURL)")
        logger.log("  用户输入长度: \(userPrompt.count) 字符")
        logger.log("  系统提示语长度: \(config.systemPrompt.count) 字符")
        logger.log("  温度: \(config.temperature)")
        logger.log("  最大 Token: \(config.maxTokens)")
        
        switch config.apiFormat {
        case .openai:
            return try await optimizeWithOpenAI(userPrompt: userPrompt, config: config)
        case .ollama:
            return try await optimizeWithOllama(userPrompt: userPrompt, config: config)
        }
    }
    
    // MARK: - 优化请求（流式）
    
    /// 发送优化请求（流式），通过回调返回增量内容
    func optimizeStream(
        userPrompt: String,
        config: AIModelConfig,
        onChunk: @escaping (String) -> Void
    ) async throws {
        let logger = AILogger.shared
        logger.log("开始优化请求（流式）")
        logger.log("  配置名称: \(config.name)")
        logger.log("  API 格式: \(config.apiFormat.displayName)")
        logger.log("  模型: \(config.modelName)")
        logger.log("  Base URL: \(config.baseURL)")
        logger.log("  用户输入长度: \(userPrompt.count) 字符")
        logger.log("  系统提示语长度: \(config.systemPrompt.count) 字符")
        logger.log("  温度: \(config.temperature)")
        logger.log("  最大 Token: \(config.maxTokens)")
        
        switch config.apiFormat {
        case .openai:
            try await optimizeWithOpenAIStream(userPrompt: userPrompt, config: config, onChunk: onChunk)
        case .ollama:
            try await optimizeWithOllamaStream(userPrompt: userPrompt, config: config, onChunk: onChunk)
        }
    }
    
    // MARK: - OpenAI 实现
    
    private func optimizeWithOpenAI(userPrompt: String, config: AIModelConfig) async throws -> String {
        let logger = AILogger.shared
        let urlString = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/")) + "/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": config.modelName,
            "messages": [
                ["role": "system", "content": config.systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": config.temperature,
            "max_tokens": config.maxTokens,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // 记录请求详情
        logger.logRequest(
            method: "POST",
            url: urlString,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(config.apiKey)"
            ],
            body: body
        )
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            let responseBody = String(data: data, encoding: .utf8)
            
            // 记录响应详情
            logger.logResponse(
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields as? [String: String],
                body: responseBody
            )
            
            guard httpResponse.statusCode == 200 else {
                let message = responseBody ?? "Unknown error"
                throw AIServiceError.httpError(statusCode: httpResponse.statusCode, message: message)
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw AIServiceError.decodingError("无法解析 OpenAI 响应")
            }
            
            logger.log("OpenAI 非流式响应内容长度: \(content.count) 字符")
            return content
        } catch let error as AIServiceError {
            logger.error("OpenAI 请求失败: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("OpenAI 网络错误: \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }
    
    private func optimizeWithOpenAIStream(
        userPrompt: String,
        config: AIModelConfig,
        onChunk: @escaping (String) -> Void
    ) async throws {
        let logger = AILogger.shared
        let urlString = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/")) + "/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": config.modelName,
            "messages": [
                ["role": "system", "content": config.systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": config.temperature,
            "max_tokens": config.maxTokens,
            "stream": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // 记录请求详情
        logger.logRequest(
            method: "POST",
            url: urlString,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(config.apiKey)"
            ],
            body: body
        )
        
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            logger.log("OpenAI 流式响应开始，状态码: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                throw AIServiceError.httpError(statusCode: httpResponse.statusCode, message: "Stream request failed")
            }
            
            var chunkIndex = 0
            var totalContent = ""
            
            for try await line in bytes.lines {
                // 检查任务是否被取消
                try Task.checkCancellation()
                
                if line.hasPrefix("data: ") {
                    let jsonString = String(line.dropFirst(6))
                    if jsonString == "[DONE]" {
                        logger.log("OpenAI 流式响应完成，共 \(chunkIndex) 个片段，总长度 \(totalContent.count) 字符")
                        break
                    }
                    
                    guard let data = jsonString.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let first = choices.first,
                          let delta = first["delta"] as? [String: Any],
                          let content = delta["content"] as? String else {
                        continue
                    }
                    
                    chunkIndex += 1
                    totalContent += content
                    logger.logStreamChunk(content, index: chunkIndex)
                    
                    await MainActor.run {
                        onChunk(content)
                    }
                }
            }
        } catch is CancellationError {
            logger.log("OpenAI 流式请求被取消")
            throw CancellationError()
        } catch let error as AIServiceError {
            logger.error("OpenAI 流式请求失败: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("OpenAI 流式网络错误: \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }
    
    // MARK: - Ollama 实现
    
    private func optimizeWithOllama(userPrompt: String, config: AIModelConfig) async throws -> String {
        let logger = AILogger.shared
        let urlString = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/")) + "/api/generate"
        guard let url = URL(string: urlString) else {
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体
        var body: [String: Any] = [
            "model": config.modelName,
            "system": config.systemPrompt,
            "prompt": userPrompt,
            "stream": false,
            "options": [
                "temperature": config.temperature,
                "num_predict": config.maxTokens
            ]
        ]
        
        // 只有在关闭思考模式时才添加 think: false 参数
        // 开启时不添加，让模型使用默认行为
        if !config.thinkEnabled {
            body["think"] = false
            logger.log("Ollama 思考模式: 禁用 (添加 think: false)")
        } else {
            logger.log("Ollama 思考模式: 启用 (使用模型默认行为)")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // 记录请求详情
        logger.logRequest(
            method: "POST",
            url: urlString,
            headers: ["Content-Type": "application/json"],
            body: body
        )
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            let responseBody = String(data: data, encoding: .utf8)
            
            // 记录响应详情
            logger.logResponse(
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields as? [String: String],
                body: responseBody
            )
            
            guard httpResponse.statusCode == 200 else {
                let message = responseBody ?? "Unknown error"
                throw AIServiceError.httpError(statusCode: httpResponse.statusCode, message: message)
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseText = json["response"] as? String else {
                throw AIServiceError.decodingError("无法解析 Ollama 响应")
            }
            
            logger.log("Ollama 非流式响应内容长度: \(responseText.count) 字符")
            return responseText
        } catch let error as AIServiceError {
            logger.error("Ollama 请求失败: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("Ollama 网络错误: \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }
    
    private func optimizeWithOllamaStream(
        userPrompt: String,
        config: AIModelConfig,
        onChunk: @escaping (String) -> Void
    ) async throws {
        let logger = AILogger.shared
        let urlString = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/")) + "/api/generate"
        
        guard let url = URL(string: urlString) else {
            logger.error("无效的 URL: \(urlString)")
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体
        var body: [String: Any] = [
            "model": config.modelName,
            "system": config.systemPrompt,
            "prompt": userPrompt,
            "stream": true,
            "options": [
                "temperature": config.temperature,
                "num_predict": config.maxTokens
            ]
        ]
        
        // 只有在关闭思考模式时才添加 think: false 参数
        // 开启时不添加，让模型使用默认行为
        if !config.thinkEnabled {
            body["think"] = false
            logger.log("Ollama 流式请求 - 思考模式: 禁用 (添加 think: false)")
        } else {
            logger.log("Ollama 流式请求 - 思考模式: 启用 (使用模型默认行为)")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // 记录请求详情
        logger.logRequest(
            method: "POST",
            url: urlString,
            headers: ["Content-Type": "application/json"],
            body: body
        )
        
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("无效的响应类型")
                throw AIServiceError.invalidResponse
            }
            
            logger.log("Ollama 流式响应开始，状态码: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                logger.error("HTTP 错误: \(httpResponse.statusCode)")
                throw AIServiceError.httpError(statusCode: httpResponse.statusCode, message: "Stream request failed")
            }
            
            var totalChunks = 0
            var totalContent = ""
            
            for try await line in bytes.lines {
                // 检查任务是否被取消
                try Task.checkCancellation()
                
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let responseText = json["response"] as? String else {
                    continue
                }
                
                totalChunks += 1
                totalContent += responseText
                logger.logStreamChunk(responseText, index: totalChunks)
                
                await MainActor.run {
                    onChunk(responseText)
                }
                
                // 检查是否完成
                if let done = json["done"] as? Bool, done {
                    logger.log("Ollama 流式响应完成，共 \(totalChunks) 个片段，总长度 \(totalContent.count) 字符")
                    break
                }
            }
        } catch is CancellationError {
            logger.log("Ollama 流式请求被取消")
            throw CancellationError()
        } catch let error as AIServiceError {
            logger.error("Ollama 流式请求失败: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("网络错误: \(error.localizedDescription)")
            throw AIServiceError.networkError(error)
        }
    }
}
