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
public let defaultRefreshThreshold: CGFloat = 68

// Tracks the state of the RefreshableScrollView - it's either:
// 1. waiting for a scroll to happen
// 2. has been primedRefresh by pulling down beyond THRESHOLD
// 3. is doing the refreshing.
// 4. 正在加载更多
// 5. 准备加载更多
public enum RefreshState {
  case waiting, primedRefresh, loadingTop,loadingMore,primedMore
}

// ViewBuilder for the custom progress View, that may render itself
// based on the current RefreshState.
public typealias RefreshProgressBuilder<Progress: View> = (RefreshState) -> Progress

// Default color of the rectangle behind the progress spinner
public let defaultLoadingViewBackgroundColor = Color(UIColor.clear)

public struct RefreshableScrollView<Progress, Content>: View where Progress: View, Content: View {
  let showsIndicators: Bool // if the ScrollView should show indicators
  let loadingViewBackgroundColor: Color
  let threshold: CGFloat // what height do you have to pull down to trigger the refresh
  let onRefresh: OnRefresh // the refreshing action
  let onMoreRefresh: OnRefresh
  let topProgress: RefreshProgressBuilder<Progress> // custom progress view
  let bottomProgress: RefreshProgressBuilder<Progress> //底部加载进程
  let content: () -> Content // the ScrollView content
  @State private var offset: CGFloat = 0
  @State private var state = RefreshState.waiting // the current state
  @State var topOpacity:CGFloat = 0 //顶部透明度 根据下拉上拉动态计算
    @State var bottomOpacity:CGFloat = 0 //底部透明度
    @State var bottomY:CGFloat = 0
    // Haptic Feedback
    let pullReleasedFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)

  // We use a custom constructor to allow for usage of a @ViewBuilder for the content
  public init(showsIndicators: Bool = true,
              loadingViewBackgroundColor: Color = defaultLoadingViewBackgroundColor,
              threshold: CGFloat = defaultRefreshThreshold,
              onRefresh: @escaping OnRefresh,
              onMoreRefresh: @escaping OnRefresh,
              @ViewBuilder topProgress: @escaping RefreshProgressBuilder<Progress>,
              @ViewBuilder bottomProgress: @escaping RefreshProgressBuilder<Progress>,
              @ViewBuilder content: @escaping () -> Content) {
    self.showsIndicators = showsIndicators
    self.loadingViewBackgroundColor = loadingViewBackgroundColor
    self.threshold = threshold
    self.onRefresh = onRefresh
    self.topProgress = topProgress
    self.content = content
    self.onMoreRefresh = onMoreRefresh
    self.bottomProgress = bottomProgress
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
           .alignmentGuide(.top, computeValue: { _ in
             (state == .loadingTop) ? -threshold + max(0, offset) : 0
           }).background(GeometryReader {geometry -> Color in
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
              topProgress(state)
          }.offset(y: (state == .loadingTop) ? -max(0, offset) : -threshold).opacity(topOpacity)
          //底部加载更多
          ZStack {
            Rectangle()
              .foregroundColor(loadingViewBackgroundColor)
              .frame(height: threshold)
              bottomProgress(state)
          }.offset(y: bottomY).opacity(bottomOpacity)
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
        offset = movingY - fixedY
          topOpacity = state != .loadingTop ? offset/defaultRefreshThreshold : 1
          bottomOpacity = state != .loadingMore ? -offset/defaultRefreshThreshold : 1
          if state != .loadingTop || state != .loadingMore { // If we're already loading, ignore everything
          // Map the preference change action to the UI thread
          DispatchQueue.main.async {
            

            // If the user pulled down below the threshold, prime the view
            if offset > threshold && state == .waiting {
              state = .primedRefresh

            // If the view is primedRefresh and we've crossed the threshold again on the
            // way back, trigger the refresh
            }else if -offset > threshold && state == .waiting {
                state = .primedMore
            } else if offset < threshold && state == .primedRefresh {
              state = .loadingTop
              self.pullReleasedFeedbackGenerator.impactOccurred()
              onRefresh { // trigger the refreshing callback
                // once refreshing is done, smoothly move the loading view
                // back to the offset position
                withAnimation {
                  self.state = .waiting
                }
              }
            } else if -offset < threshold  && state == .primedMore {
                state = .loadingMore
                self.pullReleasedFeedbackGenerator.impactOccurred()
                onRefresh {
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
public extension RefreshableScrollView where Progress == RefreshActivityIndicator {
    init(showsIndicators: Bool = true,
         loadingViewBackgroundColor: Color = defaultLoadingViewBackgroundColor,
         threshold: CGFloat = defaultRefreshThreshold,
         onRefresh: @escaping OnRefresh,
         onMoreRefresh: @escaping OnRefresh,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(showsIndicators: showsIndicators,
                  loadingViewBackgroundColor: loadingViewBackgroundColor,
                  threshold: threshold,
                  onRefresh: onRefresh,
                  onMoreRefresh: onMoreRefresh,
                  topProgress: { state in
                    RefreshActivityIndicator(isAnimating: state == .loadingTop) {
                        $0.hidesWhenStopped = false
                    }
                 },
                  bottomProgress: { state in
                    RefreshActivityIndicator(isAnimating: state == .loadingTop) {
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


public struct RefreshableCompat<Progress>: ViewModifier where Progress: View {
    private let showsIndicators: Bool
    private let loadingViewBackgroundColor: Color
    private let threshold: CGFloat
    private let onRefresh: OnRefresh
    private let topProgress: RefreshProgressBuilder<Progress>
    private let bottomProgress: RefreshProgressBuilder<Progress>
    
    public init(showsIndicators: Bool = true,
                loadingViewBackgroundColor: Color = defaultLoadingViewBackgroundColor,
                threshold: CGFloat = defaultRefreshThreshold,
                onRefresh: @escaping OnRefresh,
                @ViewBuilder topProgress: @escaping RefreshProgressBuilder<Progress>,
                @ViewBuilder bottomProgress: @escaping RefreshProgressBuilder<Progress>) {
        self.showsIndicators = showsIndicators
        self.loadingViewBackgroundColor = loadingViewBackgroundColor
        self.threshold = threshold
        self.onRefresh = onRefresh
        self.topProgress = topProgress
        self.bottomProgress = bottomProgress
    }
    
    public func body(content: Content) -> some View {
        RefreshableScrollView(showsIndicators: showsIndicators,
                              loadingViewBackgroundColor: loadingViewBackgroundColor,
                              threshold: threshold,
                              onRefresh: onRefresh,
                              onMoreRefresh: onRefresh,
                              topProgress: topProgress,
                              bottomProgress:bottomProgress ) {
            
        }
    }
}

