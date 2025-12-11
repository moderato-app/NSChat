import SwiftUI
import MessageUI
import os

struct MailComposeView: UIViewControllerRepresentable {
  @Environment(\.dismiss) var dismiss
  let mailData: MailData
  
  func makeUIViewController(context: Context) -> MFMailComposeViewController {
    let composer = MFMailComposeViewController()
    composer.mailComposeDelegate = context.coordinator
    composer.setSubject(mailData.subject)
    composer.setToRecipients(mailData.recipients)
    
    // Set email body if provided
    if let body = mailData.body {
      composer.setMessageBody(body, isHTML: false)
    }
    
    // Attach file if provided
    if let attachmentURL = mailData.attachmentURL,
       let mimeType = mailData.attachmentMimeType,
       let data = try? Data(contentsOf: attachmentURL) {
      let fileName = attachmentURL.lastPathComponent
      composer.addAttachmentData(data, mimeType: mimeType, fileName: fileName)
      AppLogger.ui.info("Mail attachment added: \(fileName)")
    } else if mailData.attachmentURL != nil {
      AppLogger.error.error("Failed to load attachment data from: \(mailData.attachmentURL?.path ?? "unknown")")
    }
    
    return composer
  }
  
  func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
    let parent: MailComposeView
    
    init(_ parent: MailComposeView) {
      self.parent = parent
    }
    
    func mailComposeController(
      _ controller: MFMailComposeViewController,
      didFinishWith result: MFMailComposeResult,
      error: Error?
    ) {
      if let error = error {
        AppLogger.logError(.from(
          error: error,
          operation: "Send mail",
          component: "MailComposeView"
        ))
      }
      
      parent.dismiss()
    }
  }
}
