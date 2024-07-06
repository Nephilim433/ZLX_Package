import Foundation
import LocalStorage

public typealias DownloadCompletion = (_ error: Error?, _ fileUrl: String?) -> Void
public typealias DownloadProgress = (_ progress: CGFloat, _ totalMB: CGFloat) -> Void

public class DownloadsManager: NSObject {

    // MARK: - Defaults

    struct defaults {
        static let backgroundSessionID = "com.klosov.zlx.backgoundDownloadSession"
    }

    // MARK: - Properties
    
    public static let shared = DownloadsManager()
    public var backgroundCompletionHandler: (() -> Void)?

    public var downloads: [String : Item] = [:]

    public var downloadsCount: Int {
        return downloads.count
    }

    private lazy var session: URLSession = {
        let sessionConfiguration = URLSessionConfiguration.background(withIdentifier: defaults.backgroundSessionID)
        return URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Init/deinit

    deinit {
        print("DownloadsManager deinit")
    }

    private override init() {
        print("DownloadsManager init")
    }

    // MARK: - Public methods

    public func dowload(request: URLRequest,
                        directory: Directory,
                        subdirectory: String,
                        fileName: String,
                        progress: DownloadProgress? = nil,
                        completion: @escaping DownloadCompletion) -> String? {
        if let url = checkIfAllreadyExists(subdirectory + "/" + fileName, in: directory) {
            completion(nil, url)
            
            return nil
        }
        
        let downloadTask = session.downloadTask(with: request)
        let key = self.key(downloadTask)
        if downloads[key] != nil {
            print("Already in progress")
            
            return nil
        }
        
        downloads[key] = Item(downloadTask: downloadTask,
                              progress: progress,
                              completion: completion,
                              fileName: fileName,
                              directory: directory,
                              subDirectory: subdirectory)
        
        downloadTask.resume()
        
        return key
    }

    public func currentDownloads() -> [String] {
        return downloads.map { $0.key }
    }
    
    public func cancelAllDownloads() {
        downloads.forEach {
            $0.value.downloadTask.cancel()
        }
        
        downloads.removeAll()
    }
    
    public func cancelDownload(forKey key: String?) {
        let downloadStatus = self.downloadStatus(forKey: key)
        let isInProgress = downloadStatus.isInProgress
        if isInProgress {
            if let item = downloadStatus.item {
                item.downloadTask.cancel()
                downloads.removeValue(forKey: key!)
            }
        }
    }
    
    public func isDownloadInProgress(forKey key:String?) -> Bool {
        return downloadStatus(forKey: key).isInProgress
    }
    
    public func alterBlocksForOngoingDownload(withKey key:String?,
                                              setProgress progressBlock:DownloadProgress?,
                                              setCompletion completionBlock:@escaping DownloadCompletion)
    {
        let downloadStatus = self.downloadStatus(forKey: key)
        let isInProgress = downloadStatus.isInProgress
        if isInProgress {
            if let item = downloadStatus.item {
                item.progress = progressBlock
                item.completion = completionBlock
            }
        }
    }
    
    //MARK: - Private methods
    
    private func downloadStatus(forKey key: String?) -> (isInProgress: Bool, item: Item?) {
        guard let key = key else {
            return (false, nil)
        }
        let downloadItem = downloads.filter { $0.key == key }.first
        return (downloadItem?.key == key, downloadItem?.value)
    }
    
    private func key(_ task: URLSessionDownloadTask) -> String {
        return task.originalRequest?.url?.absoluteString ?? ""
    }
    
    private func checkIfAllreadyExists(_ path: String, in directory: Directory) -> String? {
        return Storage.checkIfAllreadyExists(path, in: directory)
    }
}

// MARK: - URLSessionDelegate

extension DownloadsManager: URLSessionDelegate  {
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadsManager: URLSessionDownloadDelegate {

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let key = self.key(downloadTask)
        if let item = downloads[key], let response = downloadTask.response {
            let statusCode = (response as! HTTPURLResponse).statusCode
            let userInfo = [NSLocalizedDescriptionKey : HTTPURLResponse.localizedString(forStatusCode: statusCode)]
            guard statusCode < 400 else {
                let error = NSError(domain:"HttpError", code: statusCode, userInfo:userInfo)
                OperationQueue.main.addOperation { [weak item] in
                    item?.completion(error, nil)
                }
                return
            }
            let fileMovingResult = Storage.moveFile(fromUrl: location, to: item.directory, subdirectory: item.subDirectory, fileName: item.fileName)
            let (isSuccess, error, filePath) = fileMovingResult
            OperationQueue.main.addOperation {
                isSuccess ? item.completion(nil, filePath) : item.completion(error, nil)
            }
        }
        downloads.removeValue(forKey: key)
    }
    
    public func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        print(totalBytesWritten)
        if let item = downloads[key(downloadTask)], item.progress != nil {
            let progress = CGFloat(totalBytesWritten) / CGFloat(totalBytesExpectedToWrite)
            let totalMB = CGFloat(totalBytesExpectedToWrite / (1024 * 1024))
            OperationQueue.main.addOperation { [weak item] in
                item?.progress?(progress, totalMB)
            }
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        print("didResumeAtOffset\(fileOffset) , expectedTotalBytes \(expectedTotalBytes)")
    }

}

// MARK: - URLSessionTaskDelegate

extension DownloadsManager: URLSessionTaskDelegate {

    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        print("taskIsWaitingForConnectivity \(task)")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        let downloadTask = task as! URLSessionDownloadTask
        let key = self.key(downloadTask)

        if let item = self.downloads[key] {
            OperationQueue.main.addOperation { [weak item] in
                item?.completion(error, nil)
            }
        }
    }
}
