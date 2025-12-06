import Foundation
import SwiftData

enum ChatSample {
  static let emptyMessage = Chat(
    name: "Emtpy"
  )

  static let towMessages = Chat(
    name: "2 Messages",
    messages: [
      Message("What's the weather?", .user, .sent),
      Message("Pretty good!", .assistant, .received)
    ]
  )

  static let manyMessages = Chat(
    name: "Many Messages",
    messages: [
      Message("What's the weather?", .user, .sent),
      Message("The original text is a snippet of Swift code demonstrating how to define a function named ‘ask’ that takes a string and a completion handler as parameters. The error message is related to Swift’s closure capture rules. Here’s the translation to English", .assistant, .received),
      Message("What is an API Key?", .user, .sent),
      Message("""
      As of my last update, AI providers like OpenAI provide an API for developers to integrate its GPT (Generative Pretrained Transformer) models, including AI models, into their applications. The AI API key would refer to the unique identifier key required to authenticate and interact with the OpenAI API for using AI models. Each key is unique to a user or organization and must be kept secret as it allows the holder to access the API and incur any associated costs.

      Here's an overview of how it's generally used:

      1. **Registration:** A developer or company signs up with OpenAI and sets up an account.
      2. **API Key Generation:** After agreeing to the terms of service and setting up a payment method (if applicable), OpenAI generates a unique API key associated with the account.
      3. **Integration:** The developer uses this API key in the header of their HTTP requests to the OpenAI API to authenticate and gain access to the AI models provided, including ChatGPT.
      4. **Security:** It is important to keep the API key secure. If the key is exposed publicly or to unauthorized users, it may lead to misuse, and the original owner of the key could be charged for unintended usage.
      5. **Rate Limits and Quotas:** The API key is also linked to any rate limits or quotas that OpenAI imposes, based on the subscription level or plan the developer is on.

      If you want to obtain a ChatGPT API Key for your own use, you should visit the OpenAI website, create an account or log into your existing account, and follow the OpenAI documentation on how to create and manage your API keys. Always remember to follow the security best practices recommended by OpenAI to prevent unauthorized use of your API key.
      """, .assistant, .received)
    ]
  )

  static let markdownMessages = Chat(
    name: "Markdown",
    messages: [
      Message("""
      1. # Welcome to my Markdown document

      2. Here is an example of a **bold** text.

      3. You can also write _italic_ text in Markdown.

      4. Let's create an unordered list:
         - Item 1
         - Item 2
         - Item 3

      5. For an ordered list, use numbers:
         1. First item
         2. Second item
         3. Third item

      6. This is an inline code snippet: `var x = 5;`

      7. To create a code block, use three backticks:
         ```
         function greet() {
             console.log("Hello, Markdown!");
         }
         ```

      8. Here is a link to a chat application: [Chat](http://localhost:5173/chat).

      9. We can create a table in Markdown:

         | Name   | Age | City     |
         | ------ | --- | -------- |
         | John   | 25  | New York |
         | Sarah  | 30  | London   |
         | Robert | 20  | Paris    |

      10. Let's add a horizontal rule:

         ---

      11. To include an image, use the following syntax:
         ![Simultaneous Counter Composition](https://uploads8.wikiart.org/images/theo-van-doesburg/simultaneous-counter-composition-1930.jpg!Large.jpg)

      12. Here we have a blockquote:
         > Markdown is a lightweight markup language.

      13. You can highlight some code with syntax highlighting:
         ```python
         def factorial(n):
             if n == 0:
                 return 1
             else:
                 return n * factorial(n - 1)
         ```

      14. Add emphasis to some text with a combination of bold and italic: *This text is italic and **this part is bold**.*

      15. Create a checklist:
         - [x] Task 1
         - [ ] Task 2
         - [ ] Task 3

      16. To escape special characters, use a backslash like this: \\*Not a bullet point\\*

      17. You can create subheadings using the hash symbol:
         ## Subheading

      18. Make a text a superscript: 2^10^ equals 1024.

      19. Strike through some text using two tildes: ~~Not important~~.

      20. Finally, you may want to add footnotes[^1]^.

      [^1]: This is a footnote.
      """, .assistant, .received)
    ]
  )

  static let previewChats = [emptyMessage, towMessages, manyMessages, markdownMessages]
}
