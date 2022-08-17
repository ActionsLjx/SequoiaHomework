//
//  ViewModel.swift
//  SwiftHomework
//
//  Created by ljx on 2022/8/14.
//

import Foundation
import Combine
import UIKit

class ViewModel: ObservableObject {
    //请求的总数据
    @Published var allAppList: AppList?
    @Published var totalCount:Int = 0
    //已经展示的
    @Published var currentCount:Int = 0
    let service = JXNetworkService.shared;

    var cancellable = Set<AnyCancellable>()
    var a = [1,2,3,4,5]
    init() {
        service.getChatAppList()
            .receive(on: RunLoop.main)
            .sink { completion in
                print(completion)
            } receiveValue: { [weak self] data in
                self?.allAppList = data.results;
                self?.totalCount = data.resultCount;
                self?.currentCount = 10;
            }
            .store(in: &cancellable)
    }
    
    func getNetImage(urlString:String){
       


    }
}
