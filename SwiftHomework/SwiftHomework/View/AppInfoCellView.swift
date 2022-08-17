//
//  AppInfoCellView.swift
//  SwiftHomework
//
//  Created by ljx on 2022/8/14.
//

import SwiftUI
import SDWebImageSwiftUI
import Lottie
import Combine
struct AppInfoCellView: View {
    @State var isLike:Bool = false
    var appDetailData:AppDetail!
    @State var cacheImage: UIImage = UIImage()
    @State var cancellable = Set<AnyCancellable>()
    let queue = DispatchQueue.init(label: "iamge-queue")
    var body: some View {
        ZStack{
            HStack{
                Spacer().frame(width: 8)
                VStack{
                    HStack{
                        Image(uiImage: cacheImage)
                            .frame(width: 60, height: 60, alignment: .center)
                            .cornerRadius(8)
                            .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 4))
                            .task {
                                DispatchQueue.global().async {
                                    JXNetworkService.shared.loadImageWithUrl(urlString: appDetailData.artworkUrl60)
                                        .receive(on: queue).sink { response in
                                            
                                        } receiveValue: { image in
                                            cacheImage = image
                                        }.store(in: &cancellable)
                                }
                            }
                        VStack(alignment: .leading) {
                            Text(appDetailData.trackName)
                                .bold()
                                .font(.system(size: 15, weight: Font.Weight.heavy, design: .default))
                                .lineLimit(1)
                            Text(appDetailData.resultDescription)
                                .font(.system(size: 12))
                                .lineLimit(2).frame(alignment: .topLeading)
                        }.frame(height:60, alignment:.topLeading)
                        Spacer()
                        Button(action: {
                            isLike = !isLike;
                        }, label: {
                            Image(isLike ? "heart-fill":"heart")
                                .resizable().aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20, alignment: .center)
                        }).frame(width: 40, height: 40, alignment: .center)
                    }.background(.white)
                        .frame( height: 76, alignment: .center)
                        .cornerRadius(8)
                    Spacer().frame(height: 8)
                }
                Spacer().frame(width: 8)
            }
        }
    }
}

struct AppInfoCellView_Previews: PreviewProvider {
    static var previews: some View {
        AppInfoCellView()
    }
}