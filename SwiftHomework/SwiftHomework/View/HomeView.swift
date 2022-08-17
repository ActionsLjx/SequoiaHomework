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
                    done()
                } onMoreRefresh: {done in
                    done()
                } topProgress: { state in
                    if state == .waiting {
                           Text("Pull me down...")  
                    } else if state == .primedRefresh {
                           Text("Now release!")
                       } else {
                           Text("Working...")
                       }
                } bottomProgress: { state in
                    if state == .waiting {
                           Text("Pull me down...")
                    } else if state == .primedRefresh {
                           Text("Now release!")
                       } else {
                           Text("Working...")
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
                
            }.navigationTitle("App").background(Color.init(white: 0.95))
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
