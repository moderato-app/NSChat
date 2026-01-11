import Foundation
import SwiftData
import os

@Model
final class Message: Comparable {
  @Attribute(originalName: "message") var message: String
  @Attribute(originalName: "role") var role: MessageRole
  @Attribute(originalName: "chat") var chat: Chat?
  @Attribute(originalName: "createdAt") var createdAt: Date
  @Attribute(originalName: "updatedAt") var updatedAt: Date
  @Attribute(originalName: "status") var status: MessageStatus
  @Attribute(originalName: "errorInfo") var errorInfo: String
  @Attribute(originalName: "errorType") var errorType: MessageErrorType
  @Relationship(deleteRule: .cascade, originalName: "meta")
  var meta: MessageMeta? = nil

  init(_ message: String, _ role: MessageRole, _ status: MessageStatus, errorInfo: String = "", errorType: MessageErrorType = .unknown) {
    self.message = message
    self.role = role
    self.createdAt = Date.now
    self.updatedAt = Date.now
    self.status = status
    self.errorInfo = errorInfo
    self.errorType = errorType

    if role == .assistant && (status == .sending || status == .sent) ||
      role == .user && (status == .thinking || status == .typing || status == .received)
    {
      fatalError("invalid status")
    }
  }

  init(message: String, role: MessageRole, chat: Chat? = nil, createdAt: Date, updatedAt: Date, status: MessageStatus, errorInfo: String, errorType: MessageErrorType, meta: MessageMeta?) {
    self.message = message
    self.role = role
    self.chat = chat
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.status = status
    self.errorInfo = errorInfo
    self.errorType = errorType
    self.meta = meta
  }

  func clone() -> Message {
    return .init(message: self.message, role: self.role, createdAt: self.createdAt, updatedAt: self.updatedAt, status: self.status, errorInfo: self.errorInfo, errorType: self.errorType, meta: self.meta?.clone())
  }

  static func < (lhs: Message, rhs: Message) -> Bool {
    if lhs.createdAt != rhs.createdAt {
      return lhs.createdAt < rhs.createdAt
    }
    // if createdAt is the same, user message should be before assistant message
    if lhs.role == .user && rhs.role == .assistant {
      return true
    }
    return false
  }
  // user
  func onSent() {
    switch self.status {
    case .sending:
      self.status = .sent
      self.updatedAt = Date.now
      self.meta?.endedAt = Date.now
    case .sent, .thinking, .typing, .received, .error:
      AppLogger.error.error("Error: onSent is invalid, current status: \(self.status.rawValue)")
    }
  }

  // assistant
  func onTyping(text: String) {
    switch self.status {
    case .thinking, .typing:
      self.status = .typing
      self.message += text
      self.updatedAt = Date.now
      if self.meta?.startedAt == nil {
        self.meta?.startedAt = .now
      }
    case .sending, .sent, .received, .error:
      AppLogger.error.error("Error: onTyping is invalid, current status: \(self.status.rawValue)")
    }
  }

  func onEOF(text: String) {
    switch self.status {
    case .thinking, .typing:
      self.status = .received
      self.message += text
      self.updatedAt = Date.now
      self.meta?.endedAt = Date.now
    case .sending, .sent, .received, .error:
      AppLogger.error.error("Error: onEOF is invalid, current status: \(self.status.rawValue)")
    }
  }

  func onError(_ errorInfo: String, _ errorType: MessageErrorType) {
    switch self.status {
    case .sending, .thinking, .typing:
      self.status = .error
      self.errorInfo += errorInfo
      self.errorType = errorType
      self.updatedAt = Date.now
      self.meta?.endedAt = Date.now
      self.meta?.startedAt = .now
    case .error, .received, .sent:
      AppLogger.error.error("Error: onError is invalid, current status: \(self.status.rawValue)")
      AppLogger.error.error("errorInfo:\(errorInfo) errorType:\(errorType.rawValue)")
    }
  }
}

extension Message {
  enum MessageRole: String, CaseIterable, Codable {
    case assistant, system, user
  }

  enum MessageStatus: String, CaseIterable, Codable {
    case sending, sent, thinking, typing, received, error
  }

  enum MessageErrorType: String, CaseIterable, Codable {
    case unknown, apiKey, network
  }
}
