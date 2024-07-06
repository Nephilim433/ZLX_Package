import Foundation

public enum Directory {
    
    case documents
    case library
    case caches
    
    var searchPathDirectory: FileManager.SearchPathDirectory {
        switch self {
        case .documents: return .documentDirectory
        case .library: return .libraryDirectory
        case .caches: return .cachesDirectory
        }
    }
    
    public var url: URL {
        if let url = FileManager.default.urls(for: searchPathDirectory, in: .userDomainMask).first {
            return url
        } else {
            fatalError("Could not create URL for specified directory!")
        }
    }
}

public class Storage {
    
    fileprivate init() { }
    
    /// Store an encodable struct to the specified directory on disk
    ///
    /// - Parameters:
    ///   - object: the encodable struct to store
    ///   - directory: where to store the struct
    ///   - fileName: what to name the file where the struct data will be stored
    static public func store<T: Encodable>(_ object: T,
                                           to directory: Directory,
                                           subdirectory: String?,
                                           as fileName: String)
    {
        var url = directory.url
        
        if let sub = subdirectory {
            url.appendPathComponent(sub, isDirectory: true)
            if !FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.createDirectory(at: url,
                                                            withIntermediateDirectories: true,
                                                            attributes: nil)
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
        }
        
        url.appendPathComponent(fileName, isDirectory: false)

        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(object)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            
            FileManager.default.createFile(atPath: url.path, contents: data, attributes: nil)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    /// Retrieve and convert a struct from a file on disk
    ///
    /// - Parameters:
    ///   - fileName: name of the file where struct data is stored
    ///   - directory: directory where struct data is stored
    ///   - type: struct type (i.e. Message.self)
    /// - Returns: decoded struct model(s) of data
    static public func retrieve<T: Decodable>(_ fileName: String,
                                              from directory: Directory,
                                              subdirectory: String?,
                                              as type: T.Type)
        -> T?
    {
        var url = directory.url
        if let sub = subdirectory {
            url.appendPathComponent(sub, isDirectory: true)
        }
        
        url.appendPathComponent(fileName, isDirectory: false)
        
        if !FileManager.default.fileExists(atPath: url.path) {
            return nil
        }
        
        if let data = FileManager.default.contents(atPath: url.path) {
            do {
                return try JSONDecoder().decode(type, from: data)
            } catch {
                fatalError(error.localizedDescription)
            }
        } else {
            fatalError("No data at \(url.path)!")
        }
    }
    
    /// Remove all files at specified directory
    static public func clear(_ directory: Directory, subdirectory: String? = nil) {
        var url = directory.url
        if let sub = subdirectory {
            url.appendPathComponent(sub)
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [])
            for fileUrl in contents {
                try FileManager.default.removeItem(at: fileUrl)
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    /// Remove specified file from specified directory
    static public func removeFile(_ path: String, in directory: Directory) {
        let url = directory.url.appendingPathComponent(path, isDirectory: false)
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
    
    /// Returns BOOL indicating whether file exists at specified directory with specified file name
    static public func fileExists(atPath path: String, in directory: Directory) -> Bool {
        let url = directory.url.appendingPathComponent(path, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    static public func moveFile(fromUrl url: URL, to directory: Directory, subdirectory: String?, fileName: String) -> (Bool, Error?, String?) {
        var path = subdirectory ?? ""
        if !path.isEmpty {
            path = path + "/"
        }
        
        path = path + fileName
        
        let directoryCreationResult = self.createDirectoryIfNotExists(inDirectory: directory, path: subdirectory)
        guard directoryCreationResult.0 else {
            return (false, directoryCreationResult.1, nil)
        }
        
        let directoryUrl = directory.url.appendingPathComponent(path)

        if fileExists(atPath: path, in: directory) {
            do {
                try FileManager.default.removeItem(at: directoryUrl)
                print("Previous file removed at \(directoryUrl)")
            } catch {
                return(false, error, nil)
            }
        }

        do {
            try FileManager.default.moveItem(at: url, to: directoryUrl)
            return (true, nil, path)
        } catch {
            return (false, error, nil)
        }
    }

    static public func createDirectoryIfNotExists(inDirectory directory: Directory, path: String?) -> (Bool, Error?)  {
        var directoryUrl = directory.url
        if let sub = path {
            directoryUrl.appendPathComponent(sub)
        }
        
        if FileManager.default.fileExists(atPath: directoryUrl.path) {
            return (true, nil)
        }
        
        do {
            try FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true, attributes: nil)
            
            return (true, nil)
        } catch  {
            return (false, error)
        }
    }
    
    static public func checkIfAllreadyExists(_ path: String, in directory: Directory) -> String? {
        let fileUrl = directory.url.appendingPathComponent(path)
        
        return FileManager.default.fileExists(atPath: fileUrl.path) ? path : nil
    }
}
