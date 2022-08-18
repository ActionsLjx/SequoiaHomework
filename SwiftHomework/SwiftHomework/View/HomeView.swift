//
//  HomeView.swift
//  SwiftHomework
//
//  Created by ljx on 2022/8/14.
//

import SwiftUI

struct HomeView: View {
    @StateObject var vm = ViewModel()
    
    init(){
        
    }
    
    var body: some View {
        NavigationView{
            ZStack {
                RefreshableScrollView.init { done in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                      done()
                    }
                } onLoadMore: { done in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                      done()
                    }
                } refreshProgress: { state in
                    RefreshActivityIndicator(isAnimating: state == .topLoading) {
                             $0.hidesWhenStopped = false
                         }
                } loadMoreProgress: { state in
                    RefreshActivityIndicator(isAnimating: state == .topLoading) {
                             $0.hidesWhenStopped = false
                         }
                } content: {
                    VStack{
                        if let _ = vm.allAppList {
                            ForEach(vm.allAppList!.indices , id: \.self){ i in
                                if(i<vm.currentCount){
                                    AppInfoCellView(appDetailData: vm.allAppList![i])
                                }
                            }
                        }
                    }
                }.background(Color.init(white: 0.95))
            
                if(vm.allAppList == nil){
                    ProgressView().fixedSize()
                }
                }
        .navigationTitle("App").background(Color.init(white: 0.95))
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
