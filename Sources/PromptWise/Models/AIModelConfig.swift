import Foundation

/// API 格式类型
enum APIFormat: String, Codable, CaseIterable, Identifiable {
    case openai = "openai"
    case ollama = "ollama"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .openai: return "OpenAI 格式"
        case .ollama: return "Ollama"
        }
    }
    
    var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com"
        case .ollama: return "http://localhost:11434"
        }
    }
    
    var requiresAPIKey: Bool {
        switch self {
        case .openai: return true
        case .ollama: return false
        }
    }
}

/// AI 模型配置
struct AIModelConfig: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String                    // 配置名称（如"本地 Ollama"、"OpenAI GPT-4"）
    var apiFormat: APIFormat            // API 格式
    var baseURL: String                 // Base URL
    var apiKey: String                  // API Key（Ollama 可为空）
    var modelName: String               // 模型名称
    var systemPrompt: String            // 系统提示语
    var temperature: Double             // 温度（0.0 - 2.0）
    var maxTokens: Int                  // Token 上限
    var streamEnabled: Bool             // 是否启用流式输出
    var thinkEnabled: Bool              // 是否启用思考模式（Ollama think 参数，支持 Qwen3/DeepSeek R1/Gemma 4 等）
    var order: Int                      // 排序顺序
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String = "",
        apiFormat: APIFormat = .ollama,
        baseURL: String = "",
        apiKey: String = "",
        modelName: String = "",
        systemPrompt: String = "",
        temperature: Double = 0.7,
        maxTokens: Int = 2048,
        streamEnabled: Bool = true,
        thinkEnabled: Bool = true,
        order: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.apiFormat = apiFormat
        self.baseURL = baseURL.isEmpty ? apiFormat.defaultBaseURL : baseURL
        self.apiKey = apiKey
        self.modelName = modelName
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.streamEnabled = streamEnabled
        self.thinkEnabled = thinkEnabled
        self.order = order
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // 自定义解码器，处理旧配置文件没有 thinkEnabled 字段的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        apiFormat = try container.decode(APIFormat.self, forKey: .apiFormat)
        baseURL = try container.decode(String.self, forKey: .baseURL)
        apiKey = try container.decode(String.self, forKey: .apiKey)
        modelName = try container.decode(String.self, forKey: .modelName)
        systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
        temperature = try container.decode(Double.self, forKey: .temperature)
        maxTokens = try container.decode(Int.self, forKey: .maxTokens)
        streamEnabled = try container.decode(Bool.self, forKey: .streamEnabled)
        // thinkEnabled 字段向后兼容：如果不存在则默认为 true
        thinkEnabled = try container.decodeIfPresent(Bool.self, forKey: .thinkEnabled) ?? true
        order = try container.decode(Int.self, forKey: .order)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, apiFormat, baseURL, apiKey, modelName, systemPrompt
        case temperature, maxTokens, streamEnabled, thinkEnabled, order, createdAt, updatedAt
    }
    
    /// 创建默认 Ollama 配置
    static func defaultOllama() -> AIModelConfig {
        AIModelConfig(
            name: "本地 Ollama",
            apiFormat: .ollama,
            baseURL: "http://localhost:11434",
            modelName: "llama3",
            systemPrompt: "你是一个提示语优化专家。请帮助用户优化他们的提示语，使其更加清晰、具体、有效。保持原意的同时，改进表达方式和结构。",
            temperature: 0.7,
            maxTokens: 2048,
            streamEnabled: true
        )
    }
    
    /// 创建默认 OpenAI 配置
    static func defaultOpenAI() -> AIModelConfig {
        AIModelConfig(
            name: "OpenAI GPT-4o",
            apiFormat: .openai,
            baseURL: "https://api.openai.com",
            modelName: "gpt-4o",
            systemPrompt: "你是一个提示语优化专家。请帮助用户优化他们的提示语，使其更加清晰、具体、有效。保持原意的同时，改进表达方式和结构。",
            temperature: 0.7,
            maxTokens: 2048,
            streamEnabled: true
        )
    }
}
