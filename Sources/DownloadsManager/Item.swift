import Foundation
import LocalStorage

public class Item {
    
    var completion: DownloadCompletion
    var progress: DownloadProgress?
    let downloadTask: URLSessionDownloadTask
    
    let fileName: String
    let directory: Directory
    let subDirectory: String
    
    init(downloadTask: URLSessionDownloadTask,
         progress: DownloadProgress?,
         completion: @escaping DownloadCompletion,
         fileName: String,
         directory: Directory,
         subDirectory: String)
    {
        self.downloadTask = downloadTask
        self.completion = completion
        self.progress = progress
        self.fileName = fileName
        self.directory = directory
        self.subDirectory = subDirectory
    }
}
