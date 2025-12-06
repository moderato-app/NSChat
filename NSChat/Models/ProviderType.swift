import Foundation

enum ProviderType: Int32, Codable, CaseIterable {
  case openAI = 0
  case gemini = 1
  case anthropic = 2
  case groq = 3
  case openRouter = 4
  case perplexity = 5
  case mistral = 6
  case elevenLabs = 7
  case stabilityAI = 8
  case deepL = 9
  case togetherAI = 10
  case replicate = 11
  case fal = 12
  case eachAI = 13
  case deepSeek = 14
  case fireworksAI = 15
  case brave = 16
  case mock = 999

  var displayName: String {
    switch self {
    case .openAI: return "OpenAI"
    case .gemini: return "Gemini"
    case .anthropic: return "Anthropic"
    case .stabilityAI: return "Stability AI"
    case .deepL: return "DeepL"
    case .togetherAI: return "Together AI"
    case .replicate: return "Replicate"
    case .elevenLabs: return "ElevenLabs"
    case .fal: return "Fal"
    case .groq: return "Groq"
    case .perplexity: return "Perplexity"
    case .mistral: return "Mistral"
    case .eachAI: return "EachAI"
    case .openRouter: return "OpenRouter"
    case .deepSeek: return "DeepSeek"
    case .fireworksAI: return "Fireworks AI"
    case .brave: return "Brave"
    case .mock: return "Mock"
    }
  }
  
  var openRouterPrefix: String? {
    switch self {
    case .openAI: return "openai"
    case .gemini: return "google"
    case .anthropic: return "anthropic"
    case .groq: return "groq"
    case .perplexity: return "perplexity"
    case .mistral: return "mistralai"
    case .deepSeek: return "deepseek"
    case .fireworksAI: return "fireworks"
    case .togetherAI: return "together"
    case .openRouter: return nil
    // These providers don't have models listed on OpenRouter with matching prefixes
    case .stabilityAI, .deepL, .replicate, .elevenLabs, .fal, .eachAI, .brave, .mock: return nil
    }
  }
}
