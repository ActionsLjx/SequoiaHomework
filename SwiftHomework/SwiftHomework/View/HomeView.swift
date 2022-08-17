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
            if vm.allAppList == nil{
                ProgressView()
            }else{
                ZStack {
                    ScrollView(.vertical){
                            ForEach(vm.allAppList!.indices , id: \.self){ i in
                                if(i<vm.currentCount){
                                    AppInfoCellView(appDetailData: vm.allAppList![i])
                                }
                            }
                    }
                    .background(Color.init(white: 0.95))
                    
                    
                }.navigationTitle("App")
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
