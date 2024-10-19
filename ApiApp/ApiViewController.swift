//
//  ApiViewController.swift
//  ApiApp
//
//  Created by mba2408.starlight kyoei.engine on 2024/10/18.
//

import UIKit
import Alamofire        // 追加
import AlamofireImage   // 追加
import RealmSwift    // 追加
import SafariServices

class ApiViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchField: UISearchBar!
    
    let realm = try! Realm()    // 追加
    
    var shopArray: [ApiResponse.Result.Shop] = []   // 追加
    var apiKey: String = ""                         // 追加
    
    var searchCondition:String! = "ランチ"
    
    var isLoading = false
    var isLastLoaded = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        // ここから
        tableView.delegate = self
        tableView.dataSource = self
        searchField.delegate = self

        // APIキー読み込み
        let filePath = Bundle.main.path(forResource: "ApiKey", ofType:"plist" )
        let plist = NSDictionary(contentsOfFile: filePath!)!
        apiKey = plist["key"] as! String

        // shopArray読み込み
        updateShopArray()
        // ここまで追加
        
        // ここから
        // RefreshControlの設定
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        // ここまで追加
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchCondition = searchBar.text!
        // APIキー読み込み
        let filePath = Bundle.main.path(forResource: "ApiKey", ofType:"plist" )
        let plist = NSDictionary(contentsOfFile: filePath!)!
        apiKey = plist["key"] as! String

        // shopArray読み込み
        updateShopArray()
        // ここまで追加
        
        // ここから
        // RefreshControlの設定
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        // ここまで追加
    }

    
    // ここから
    @objc func refresh() {
        // shopArray再読み込み
        updateShopArray()
    }
    // ここまで追加
    
    // ここから
        func updateShopArray(appendLoad: Bool = false) {
            // ここから
            // 現在読み込み中なら読み込みを開始しない
            if isLoading {
                return
            }
            // 最後まで読み込んでいるなら、追加読み込みしない
            if appendLoad && isLastLoaded {
                return
            }
            // 読み込み開始位置を設定
            let startIndex: Int
            if appendLoad {
                startIndex = shopArray.count + 1
            } else {
                startIndex = 1
            }
            // 読み込み中状態開始
            isLoading = true
            // ここまで追加

            let parameters: [String: Any] = [
                "key": apiKey,
                "start": startIndex,
                "count": 20,
                "keyword": searchCondition!,
                "format": "json"
            ]
            print("APIリクエスト 開始位置: \(parameters["start"]!) 読み込み店舗数: \(parameters["count"]!)")    // 追加
            print("APIリクエスト キーワード: \(parameters["keyword"]!)")
        
            AF.request("https://webservice.recruit.co.jp/hotpepper/gourmet/v1/", method: .get, parameters: parameters).responseDecodable(of: ApiResponse.self) { response in
                // 読み込み中状態終了
                self.isLoading = false  // 追加
                // リフレッシュ表示動作停止
                
                // リフレッシュ表示動作停止
                if self.tableView.refreshControl!.isRefreshing {
                    self.tableView.refreshControl!.endRefreshing()
                }
                // ここまで追加
            
                // レスポンス受信処理
                switch response.result {
                case .success(let apiResponse):
                    // ここから
                    // print("受信データ: \(apiResponse)")
                    print("受信店舗数: \(apiResponse.results.shop.count)")
                    if appendLoad {
                        // 追加読み込みの場合は、現在のshopArrayに追加
                        self.shopArray += apiResponse.results.shop
                    } else {
                        // 追加読み込みでない場合はそのまま代入し、isLastLoadedをリセット
                        self.shopArray = apiResponse.results.shop
                        self.isLastLoaded = false
                    }
                    // 読み込み数が0なら最後まで読み込まれたと判断
                    if apiResponse.results.shop.count == 0 {
                        self.isLastLoaded = true
                    }
                    // ここまで変更
                    self.statusLabel.text = ""
                case .failure(let error):
                    print(error)
                    self.shopArray = []
                    self.isLastLoaded = true    // 追加
                    self.statusLabel.text = "データの取得が失敗しました"
                }
                self.tableView.reloadData()
            }
        }

        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return shopArray.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ShopCell
            let shop = shopArray[indexPath.row]
            let url = URL(string: shop.logo_image)!
            cell.logoImageView.af.setImage(withURL: url)
            cell.shopNameLabel.text = shop.name
            cell.addressLabel.text = shop.address
            
            // ここから
            let starImageName = shop.isFavorite ? "star.fill" : "star"
            let starImage = UIImage(systemName: starImageName)?.withRenderingMode(.alwaysOriginal)
            cell.favoriteButton.setImage(starImage, for: .normal)
            // ここまで追加
            
            // ここから
            // 追加データの読み込みが必要か確認
            if shopArray.count - indexPath.row < 10 {
                self.updateShopArray(appendLoad: true)
            }
            // ここまで追加

            return cell
        }
        // ここまで追加
    
    @IBAction func tapFavoriteButton(_ sender: UIButton) {
        // ここから
        let point = sender.convert(CGPoint.zero, to: tableView)
        let indexPath = tableView.indexPathForRow(at: point)!
        let shop = shopArray[indexPath.row]

        if shop.isFavorite {
            print("「\(shop.name)」をお気に入りから削除します")
            try! realm.write {
                let favoriteShop = realm.object(ofType: FavoriteShop.self, forPrimaryKey: shop.id)!
                realm.delete(favoriteShop)
            }
        } else {
            print("「\(shop.name)」をお気に入りに追加します")
            try! realm.write {
                let favoriteShop = FavoriteShop()
                favoriteShop.id = shop.id
                favoriteShop.name = shop.name
                favoriteShop.address = shop.address
                favoriteShop.logoImageURL = shop.logo_image
                if shop.coupon_urls.sp == "" {
                    favoriteShop.couponURL = shop.coupon_urls.pc
                } else {
                    favoriteShop.couponURL = shop.coupon_urls.sp
                }
                realm.add(favoriteShop)
            }
        }
        tableView.reloadData()
        // ここまで追加
    }
    
    // ここから
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.reloadData()
    }
    // ここまで追加
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let shop = shopArray[indexPath.row]
        let urlString: String
        if shop.coupon_urls.sp == "" {
            urlString = shop.coupon_urls.pc
        } else {
            urlString = shop.coupon_urls.sp
        }
        let url = URL(string: urlString)!
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.modalPresentationStyle = .pageSheet
        present(safariViewController, animated: true)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
