//
//  RefreshScrollView.swift
//  SwiftHomework
//
//  Created by ljx on 2022/8/17.
//
import SwiftUI

// There are two type of positioning views - one that scrolls with the content,
// and one that stays fixed
private enum PositionType {
  case fixed, moving
}

// This struct is the currency of the Preferences, and has a type
// (fixed or moving) and the actual Y-axis value.
// It's Equatable because Swift requires it to be.
private struct Position: Equatable {
  let type: PositionType
  let y: CGFloat
}

// This might seem weird, but it's necessary due to the funny nature of
// how Preferences work. We can't just store the last position and merge
// it with the next one - instead we have a queue of all the latest positions.
private struct PositionPreferenceKey: PreferenceKey {
  typealias Value = [Position]

  static var defaultValue = [Position]()

  static func reduce(value: inout [Position], nextValue: () -> [Position]) {
    value.append(contentsOf: nextValue())
  }
}

private struct PositionIndicator: View {
  let type: PositionType

  var body: some View {
    GeometryReader { proxy in
        // the View itself is an invisible Shape that fills as much as possible
        Color.clear
          // Compute the top Y position and emit it to the Preferences queue
          .preference(key: PositionPreferenceKey.self, value: [Position(type: type, y: proxy.frame(in: .global).minY)])
     }
  }
}

// Callback that'll trigger once refreshing is done
public typealias RefreshComplete = () -> Void

// The actual refresh action that's called once refreshing starts. It has the
// RefreshComplete callback to let the refresh action let the View know
// once it's done refreshing.
public typealias OnRefresh = (@escaping RefreshComplete) -> Void

// The offset threshold. 68 is a good number, but you can play
// with it to your liking.
public let defaultRefreshThreshold: CGFloat = 130

// Tracks the state of the RefreshableScrollView - it's either:
// 1. waiting for a scroll to happen
// 2. has been primed by pulling down beyond THRESHOLD
// 3. is doing the refreshing.
public enum RefreshState {
  case waiting, topPrimed, topLoading,bottomPrimed,bottomLoading
}

// ViewBuilder for the custom progress View, that may render itself
// based on the current RefreshState.
public typealias RefreshProgressBuilder<Progress: View> = (RefreshState) -> Progress
public typealias LoadMoreProgressBuilder<MoreProgress: View> = (RefreshState) -> MoreProgress

// Default color of the rectangle behind the progress spinner
public let defaultLoadingViewBackgroundColor = Color(UIColor.clear)

public struct RefreshableScrollView<Progress,MoreProgress, Content>: View where Progress: View,MoreProgress: View, Content: View {
  let showsIndicators: Bool // if the ScrollView should show indicators
  let loadingViewBackgroundColor: Color
  let threshold: CGFloat // what height do you have to pull down to trigger the refresh
  let onRefresh: OnRefresh // the refreshing action
  let onLoadMore:OnRefresh //加载更多回调
  let refreshProgress: RefreshProgressBuilder<Progress> // custom progress view
  let loadMoreProgress: LoadMoreProgressBuilder<MoreProgress> //底部加载更多
  let content: () -> Content // the ScrollView content
  @State private var offset: CGFloat = 0
  @State private var state = RefreshState.waiting // the current state
    @State private var topOpacity:CGFloat = 0
    @State private var bottomOpacity:CGFloat = 0
    @State private var bottomY: CGFloat = 0
    // Haptic Feedback
    let pullReleasedFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)

  // We use a custom constructor to allow for usage of a @ViewBuilder for the content
  public init(showsIndicators: Bool = true,
              loadingViewBackgroundColor: Color = defaultLoadingViewBackgroundColor,
              threshold: CGFloat = defaultRefreshThreshold,
              onRefresh: @escaping OnRefresh,
              onLoadMore: @escaping OnRefresh,
              @ViewBuilder refreshProgress: @escaping RefreshProgressBuilder<Progress>,
              @ViewBuilder loadMoreProgress: @escaping LoadMoreProgressBuilder<MoreProgress>,
              @ViewBuilder content: @escaping () -> Content) {
    self.showsIndicators = showsIndicators
    self.loadingViewBackgroundColor = loadingViewBackgroundColor
    self.threshold = threshold
    self.onRefresh = onRefresh
    self.onLoadMore = onLoadMore
    self.refreshProgress = refreshProgress
    self.loadMoreProgress = loadMoreProgress
    self.content = content
  }

  public var body: some View {
    // The root view is a regular ScrollView
    ScrollView(showsIndicators: showsIndicators) {
      // The ZStack allows us to position the PositionIndicator,
      // the content and the loading view, all on top of each other.
      ZStack(alignment: .top) {
        // The moving positioning indicator, that sits at the top
        // of the ScrollView and scrolls down with the content
        PositionIndicator(type: .moving)
          .frame(height: 0)

         // Your ScrollView content. If we're loading, we want
         // to keep it below the loading view, hence the alignmentGuide.
         content()
           .background(GeometryReader { geometry -> Color in
                if(geometry.size.height != bottomY){
                    DispatchQueue.main.async {
                        bottomY = geometry.size.height
                    }
                }
                return Color.clear
            })


          // The loading view. It's offset to the top of the content unless we're loading.
          ZStack {
            Rectangle()
              .foregroundColor(loadingViewBackgroundColor)
              .frame(height: threshold)
              refreshProgress(state)
          }.offset(y: -threshold).opacity(state == .topLoading ? 1 : topOpacity)
          
          //加载更多
          ZStack {
            Rectangle()
              .foregroundColor(loadingViewBackgroundColor)
              .frame(height: threshold - 20)
              loadMoreProgress(state)
          }.offset(y: bottomY).opacity(state == .bottomLoading ? 1 :bottomOpacity)
        }
      }
      // Put a fixed PositionIndicator in the background so that we have
      // a reference point to compute the scroll offset.
      .background(PositionIndicator(type: .fixed))
      // Once the scrolling offset changes, we want to see if there should
      // be a state change.
      .onPreferenceChange(PositionPreferenceKey.self) { values in
        // Compute the offset between the moving and fixed PositionIndicators
        let movingY = values.first { $0.type == .moving }?.y ?? 0
        let fixedY = values.first { $0.type == .fixed }?.y ?? 0
        let bottomH = threshold - 20
        offset = movingY - fixedY
          topOpacity = offset/threshold
          bottomOpacity = -offset/bottomH
          print(offset)
        if state != .topLoading {
          DispatchQueue.main.async {
            if offset > threshold && state == .waiting {
              state = .topPrimed
            }
              else if -offset > bottomH && state == .waiting {
                  state = .bottomPrimed
            }
              else if offset < threshold && state == .topPrimed {
                  state = .topLoading
                  self.pullReleasedFeedbackGenerator.impactOccurred()
                  onRefresh {
                      withAnimation {
                          self.state = .waiting
                      }
                  }
            }
              else if -offset < bottomH && state == .bottomPrimed {
                  state = .bottomLoading
                  self.pullReleasedFeedbackGenerator.impactOccurred()
                  onLoadMore {
                      withAnimation {
                          self.state = .waiting
                      }
                  }
              }
          }
        }
      }
    }
    
}

// Extension that uses default RefreshActivityIndicator so that you don't have to
// specify it every time.
public extension RefreshableScrollView where Progress == RefreshActivityIndicator,MoreProgress == RefreshActivityIndicator {
    init(showsIndicators: Bool = true,
         loadingViewBackgroundColor: Color = defaultLoadingViewBackgroundColor,
         threshold: CGFloat = defaultRefreshThreshold,
         onRefresh: @escaping OnRefresh,
         onLoadMore: @escaping OnRefresh,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(showsIndicators: showsIndicators,
                  loadingViewBackgroundColor: loadingViewBackgroundColor,
                  threshold: threshold,
                  onRefresh: onRefresh,
                  onLoadMore: onLoadMore,
                  refreshProgress: { state in
                    RefreshActivityIndicator(isAnimating: state == .topLoading) {
                        $0.hidesWhenStopped = false
                    }
        }, loadMoreProgress: {state in
            RefreshActivityIndicator(isAnimating: state == .topLoading) {
                $0.hidesWhenStopped = false
            }
        },
                 content: content)
    }
}

// Wraps a UIActivityIndicatorView as a loading spinner that works on all SwiftUI versions.
public struct RefreshActivityIndicator: UIViewRepresentable {
  public typealias UIView = UIActivityIndicatorView
  public var isAnimating: Bool = true
  public var configuration = { (indicator: UIView) in }

  public init(isAnimating: Bool, configuration: ((UIView) -> Void)? = nil) {
    self.isAnimating = isAnimating
    if let configuration = configuration {
      self.configuration = configuration
    }
  }

  public func makeUIView(context: UIViewRepresentableContext<Self>) -> UIView {
    UIView()
  }

  public func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<Self>) {
    isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    configuration(uiView)
  }
}

#if compiler(>=5.5)
// Allows using RefreshableScrollView with an async block.
@available(iOS 15.0, *)
public extension RefreshableScrollView {
    init(showsIndicators: Bool = true,
         loadingViewBackgroundColor: Color = defaultLoadingViewBackgroundColor,
         threshold: CGFloat = defaultRefreshThreshold,
         action: @escaping @Sendable () async -> Void,
         @ViewBuilder refreshProgress: @escaping RefreshProgressBuilder<Progress>,
         @ViewBuilder loadMoreProgress: @escaping LoadMoreProgressBuilder<MoreProgress>,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(showsIndicators: showsIndicators,
                  loadingViewBackgroundColor: loadingViewBackgroundColor,
                  threshold: threshold,
                  onRefresh: { refreshComplete in
                    Task {
                        await action()
                        refreshComplete()
                    }
                },
                  onLoadMore: { loadMoreComplete in
                    Task {
                        await action()
                        loadMoreComplete()
                    }
        },
                  refreshProgress: refreshProgress,
                  loadMoreProgress: loadMoreProgress,
                  content: content)
    }
}
#endif

public struct RefreshableCompat<Progress>: ViewModifier where Progress: View {
    private let showsIndicators: Bool
    private let loadingViewBackgroundColor: Color
    private let threshold: CGFloat
    private let onRefresh: OnRefresh
    private let onLoadMore: OnRefresh
    private let refreshProgress: RefreshProgressBuilder<Progress>
    private let loadMoreProgress: RefreshProgressBuilder<Progress>
    public init(showsIndicators: Bool = true,
                loadingViewBackgroundColor: Color = defaultLoadingViewBackgroundColor,
                threshold: CGFloat = defaultRefreshThreshold,
                onRefresh: @escaping OnRefresh,
                onLoadMore: @escaping OnRefresh,
                @ViewBuilder refreshProgress: @escaping RefreshProgressBuilder<Progress>,
                @ViewBuilder loadMoreProgress: @escaping RefreshProgressBuilder<Progress>) {
        self.showsIndicators = showsIndicators
        self.loadingViewBackgroundColor = loadingViewBackgroundColor
        self.threshold = threshold
        self.onRefresh = onRefresh
        self.onLoadMore = onLoadMore
        self.refreshProgress = refreshProgress
        self.loadMoreProgress = loadMoreProgress
    }
    
    public func body(content: Content) -> some View {
        RefreshableScrollView(showsIndicators: showsIndicators,
                              loadingViewBackgroundColor: loadingViewBackgroundColor,
                              threshold: threshold,
                              onRefresh: onRefresh,
                              onLoadMore: onLoadMore,
                              refreshProgress: refreshProgress,
                              loadMoreProgress:loadMoreProgress) {
            content
        }
    }
}

#if compiler(>=5.5)
@available(iOS 15.0, *)
public extension List {
    @ViewBuilder func refreshableCompat<Progress: View>(showsIndicators: Bool = true,
                                                        loadingViewBackgroundColor: Color = defaultLoadingViewBackgroundColor,
                                                        threshold: CGFloat = defaultRefreshThreshold,
                                                        onRefresh: @escaping OnRefresh,
                                                        onLoadMore: @escaping OnRefresh,
                                                        @ViewBuilder refreshProgress: @escaping RefreshProgressBuilder<Progress>,
                                                        @ViewBuilder loadMoreProgress: @escaping RefreshProgressBuilder<Progress>) -> some View {
        if #available(iOS 15.0, macOS 12.0, *) {
            self.refreshable {
                await withCheckedContinuation { cont in
                    onRefresh {
                        cont.resume()
                    }
                }
            }
        } else {
            self.modifier(RefreshableCompat(showsIndicators: showsIndicators,
                                            loadingViewBackgroundColor: loadingViewBackgroundColor,
                                            threshold: threshold,
                                            onRefresh: onRefresh,
                                            onLoadMore: onLoadMore,
                                            refreshProgress: refreshProgress,
                                           loadMoreProgress: loadMoreProgress))
        }
    }
}
#endif

public extension View {
    @ViewBuilder func refreshableCompat<Progress: View>(showsIndicators: Bool = true,
                                                        loadingViewBackgroundColor: Color = defaultLoadingViewBackgroundColor,
                                                        threshold: CGFloat = defaultRefreshThreshold,
                                                        onRefresh: @escaping OnRefresh,
                                                        onLoadMore: @escaping OnRefresh,
                                                        @ViewBuilder refreshProgress: @escaping RefreshProgressBuilder<Progress>,
                                                        @ViewBuilder loadMoreProgress: @escaping RefreshProgressBuilder<Progress>) -> some View {
        self.modifier(RefreshableCompat(showsIndicators: showsIndicators,
                                        loadingViewBackgroundColor: loadingViewBackgroundColor,
                                        threshold: threshold,
                                        onRefresh: onRefresh,
                                        onLoadMore: onRefresh,
                                        refreshProgress: refreshProgress,
                                        loadMoreProgress: loadMoreProgress))
    }
}




