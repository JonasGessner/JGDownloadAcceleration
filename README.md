<h1>JGDownloadAcceleration</h1>© Jonas Gessner 2013

------------------

JGDownloadAcceleration is a Networking library for iOS targeted at downloading large files on to the device's hard disk.

JGDownloadAcceleration's main part is a concurrent NSOperation subclass (JGDownloadOperation) which handles the multipart download.

For managing and queuing multiple operations, JGDownloadAcceleration provides a NSOperationQueue subclass (JGOperationQueue) which handles the networking thread, activity indicator and application background task.


Q. How does the download acceleration even work?

A. Download accelerators (multipart download) use multiple network connections to download a file from a server in chunks (each connection downloads one part of the entire content). This allows to bypass bandwidth limitations set by the server and download speeds can be drastically increased.

More info: <a href="http://en.wikipedia.org/wiki/Download_manager#Download_acceleration">Wikipedia</a>


The server from which downloading a content needs to support the `Range` header in order to use multipart download. See <a href="#requirements">Requirements</a> for more Info.

##Getting started

1. Download JGDownloadAcceleration
2. Add the whole "JGDownloadAcceleration Classes" folder to your Project
3. Start using JGDownloadAcceleration!

##Overview

JGDownloadAcceleration consists of 2 different classes that are available to use for networking.

###JGDownloadOperation
A NSOperation subclass which does the download acceleration magic.

`JGDownloadOperation` is restricted to GET HTTP Requests and to writing downloaded content directly to the hard disk.

Parameters to pass:
A `JGDownloadOperation` instance required to have the `url` parameter, and the `destinationPath` parameter set. If not the Application will terminate with an Assertion Failure.

All `JGDownloadOperation` instances should be initialized with the `initWithURL:destinationPath:resume:` method, where the URL, the local destination path and a `BOOL` to indicate whether the operation should resume (if possible) where it left of is passed.

Optionally, the number of connections to use to download the resource and a tag can be set.


`JGDownloadOperation` uses blocks to communicate with a delegate.

    - (void)setCompletionBlockWithSuccess:(void (^)(JGDownloadOperation *operation))success failure:(void (^)(JGDownloadOperation *operation, NSError *error))failure;
    - (void)setOperationStartedBlock:(void (^)(NSUInteger tag, unsigned long long totalBytesExpectedToRead))block;
    
    - (void)setDownloadProgressBlock:(void (^)(NSUInteger bytesRead, unsigned long long totalBytesReadThisSession, unsigned long long totalBytesWritten, unsigned long long totalBytesExpectedToRead, NSUInteger tag))block;
    

<h5>`setOperationStartedBlock:`</h5> is used to be notified when the operation starts.
The block passes a reference to the operation. The blocks is called on the main thread.

<h5>`setCompletionBlockWithSuccess:failure:`</h5> is used to be notified when the operation finishes and to be informed about the completion state (failed with an error or not?).
The completion block passes a reference to the operation, the failure block passes a reference to the operation and the error. Both blocks are called on the main thread

<h5>`setDownloadProgressBlock:`</h5> is used to determine, calculate, and observe various details of the current download. This block is called on the (secondary) networking Thread! It is called every time a connection inside the operation receives a chunk of data (which is automatically written to the disk).<p>
`NSUInteger bytesRead` indicates the size of the bytes read (NOT since the last call of the block, its pretty complicated because this block is called for each connection, passing the number of bytes the specific connection loaded since this specific connection last loaded a chunk of bytes).<p>
`unsigned long long totalBytesReadThisSession` the total number of bytes read in this current session. If a download is paused at 50% and then resumed, this parameter will start from 0.<p>
`unsigned long long totalBytesWritten` the total bytes read in total.<p>
`unsigned long long totalBytesExpectedToRead` the expected content size of the resource.<p>
`NSUInteger tag` the tag of the operation, very handy for managing multiple operations in a queue.<p>


###JGOperationQueue
A NSOperationQueue subclass which is targeted at enqueing only `JGDownloadOperation` objects.

`JGOperationQueue` handles the shared background thread used by all `JGDownloadOperation` instances. Once all operations are finished the queue exits the networking thread.

Optionally, `JGOperationQueue` handles the status bar NetworkActivityIndicator, according to the number of enqued operations and the background task used for networking requests when the app runs in the background.

  BOOL handleNetworkActivityIndicator
  BOOL handleBackgroundTask
  
Note that when setting `handleBackgroundTask` to `YES`, the App's Info.plist file needs to have "Application uses Wi-Fi" set to `YES`.

##Example


##Requirements


##Credits
JGDownloadAcceleration was created by <a href="http://twitter.com/JonasGessner" target="_blank">Jonas Gessner</a>.
It was created for the iOS Jailbreak tweak "ProTube Extension for YouTube" and the Jailbreak App "ProTube".

##License

JGDownloadOperation is available under the <a href="http://opensource.org/licenses/Python-2.0">Python 2.0 license</a>
