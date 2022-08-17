//
//  NetImageView.swift
//  SwiftHomework
//
//  Created by ljx on 2022/8/17.
//

import SwiftUI
import Combine
struct NetImageView: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct NetImageView_Previews: PreviewProvider {
    static var previews: some View {
        NetImageView()
    }
}

//MARK: 加载网络图片
protocol ImageCatch {
    subscript(_url:URL) -> UIImage? {get set}
}

//定义缓存结构
struct CatcheTempoary: ImageCatch {
    private let cache = NSCache<NSURL,UIImage>()
    
    subscript(_ key: URL) -> UIImage? {
        get{
            cache.object(forKey: key as NSURL)
        }
        
        set{
            newValue == nil ? cache.removeObject(forKey: key as NSURL) : cache.setObject(newValue!, forKey: key as NSURL)
        }
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var isLoading = false
    private var url: URL
    private var cathe: ImageCatch?
    private var cancellable: AnyCancellable?
    private static let imageProcessing = DispatchQueue(label: "image-imageProcessing")
    
    init(url: URL,cathe:ImageCatch? = nil){
        self.url = url
        self.cathe = cathe
    }
    
    deinit {
        cancellable?.cancel()
    }
    
    
}
