import Foundation

enum HistoryCount: Hashable {
  case zero
  case one
  case two
  case three
  case four
  case six
  case eight
  case ten
  case twenty
  case number(Int)
  case infinite

  var length: Int {
    switch self {
    case .zero:
      return 0
    case .one:
      return 1
    case .two:
      return 2
    case .three:
      return 3
    case .four:
      return 4
    case .six:
      return 6
    case .eight:
      return 8
    case .ten:
      return 10
    case .twenty:
      return 20
    case .number(let n):
      return n
    case .infinite:
      return Int.max
    }
  }

  var lengthString: String {
    if self == .infinite {
      return "∞"
    } else {
      return "\(length)"
    }
  }
}

let historyCountChoices = [
  HistoryCount.zero,
  HistoryCount.one,
  HistoryCount.two,
  HistoryCount.three,
  HistoryCount.four,
  HistoryCount.six,
  HistoryCount.eight,
  HistoryCount.ten,
  HistoryCount.twenty,
  HistoryCount.infinite
]

