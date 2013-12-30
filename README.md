<h1>JGDownloadAcceleration</h1><h6>© 2013 Jonas Gessner</h6>

----------------
<br>

JGDownloadAcceleration is a Networking library for iOS targeted at downloading large files on to the device's hard disk.

JGDownloadAcceleration's main part is a concurrent NSOperation subclass (JGDownloadOperation) which handles the multipart download.

For managing and queuing multiple operations, JGDownloadAcceleration provides a NSOperationQueue subclass (JGOperationQueue) which handles the networking thread, activity indicator and application background task.


<b>Q.</b> How does the download acceleration even work?

<b>A.</b> Download accelerators (multipart download) use multiple network connections to download a file from a server in chunks (each connection downloads one part of the entire content). This allows to bypass bandwidth limitations set by the server and download speeds can be drastically increased.

More info: <a href="http://en.wikipedia.org/wiki/Download_manager#Download_acceleration" target="_blank">Wikipedia</a>



Current Version: 1.2.1

<p align="center">View it in action!
<a href="http://www.youtube.com/watch?feature=player_embedded&v=HpzOXzAKqWM
" target="_blank"><img src="http://j-gessner.de/img/JGDownloadAcceleration.png" 
alt="View on YouTube" border="10" /></a></p>


##Getting started

1. Download JGDownloadAcceleration
2. Add the whole "JGDownloadAcceleration Classes" folder to your Project
3. Have a read through the Overview section
4. `#import "JGDownloadAcceleration.h"`
5. Start using JGDownloadAcceleration!

##Overview

JGDownloadAcceleration consists of 2 different classes that are available to use for networking.

###JGDownloadOperation
A NSOperation subclass which does the download acceleration magic.

`JGDownloadOperation` is restricted to HTTP GET Requests and to writing downloaded content directly to the hard disk.

Parameters to pass:
A `JGDownloadOperation` instance required to have the `url` parameter, and the `destinationPath` parameter set. If not the Application will terminate with an Assertion Failure.

All `JGDownloadOperation` instances should be initialized with the `initWithURL:destinationPath:allowResume:` or `initWithRequest:destinationPath:allowResume:` methods, where the URL or NSURLRequest, the local destination path and a `BOOL` to indicate whether the operation should resume (if possible) where it left of is passed. Any files located at the destination path will be removed when starting the download.

Optionally, the number of connections to use to download the resource, a tag, and the retry count can be set.
```objc
	NSUInteger tag;
	NSUInteger maximumNumberOfConnections;
	NSUInteger retryCount;
```
By default the tag is 0 and the number of connections is 6. The retry count it the number of connections divided by 2.

The readonly properties are:
```objc
	NSURLRequest *originalRequest;
	NSString *destinationPath;
	unsigned long long contentLength;
	NSError *error;
```
`originalRequest` and `destinationPath` are set in the `initWithURL:destinationPath:allowResume:` or `initWithRequest:destinationPath:allowResume:` methods and should not be changed once the operation has been initialized, therefore they are a `readonly` property.
`contentLength` is the expected length (bytes) of the resource to download. This value will be 0 before the `requestStartedBlock` is called. `error` returns the failure error (it will be `nil` if no error occurred). The error will also be passed in the failure block. (See below for more info on the started and the failure blocks).

#####The custom init methods:
`JGDownloadOperation` can only be initialized using either of the two custom init methods.

`initWithURL:destinationPath:allowResume:`: In this init method the request made will be a simple HTTP GET request from the given URL. No more customization is possible.


`initWithRequest:destinationPath:allowResume:`: This init method allows you to use a custom NSURLRequest with `JGDownloadOperation`. The HTTP Method can only be GET (default). `JGDownloadOperation` also supports the `Range` header.


#####Delegates:
`JGDownloadOperation` uses blocks to communicate with a delegate.
```objc
    - (void)setCompletionBlockWithSuccess:(void (^)(JGDownloadOperation *operation))success failure:(void (^)(JGDownloadOperation *operation, NSError *error))failure;
    - (void)setOperationStartedBlock:(void (^)(NSUInteger tag, unsigned long long totalBytesExpectedToRead))block;
    
    - (void)setDownloadProgressBlock:(void (^)(NSUInteger bytesRead, unsigned long long totalBytesReadThisSession, unsigned long long totalBytesRead, unsigned long long totalBytesExpectedToRead, NSUInteger tag))block;
```

<h4>`setOperationStartedBlock:`</h4> Used to be notified when the operation starts.
The block passes the tag (default 0) of the operation and the expected content size of the resource. The blocks is called from the network thread.

<h4>`setCompletionBlockWithSuccess:failure:`</h4> Used to be notified when the operation finishes and to be informed about the completion state (failed with an error or not?).
The completion block passes a reference to the operation, the failure block passes a reference to the operation and the error. Both blocks are called from a background thread (not the network thread).

<h4>`setDownloadProgressBlock:`</h4> Used to determine, calculate, and observe various details of the current download. This block is called on the (secondary) networking thread! It is called every time a connection inside the operation receives a chunk of data (which is automatically written to the disk). The current progress, current download speed, average download speed (and using that an estimation for the remaining time) can be calculated. For average and current speed a variable in needed to store the time intervals from the last call of the block (for the current speed) and from when the operation started. See the Example project for an implementation of this<p>
`NSUInteger bytesRead` indicates the size of the bytes read (NOT since the last call of the block, its pretty complicated because this block is called for each connection, passing the number of bytes the specific connection loaded since this specific connection last loaded a chunk of bytes).<p>
`unsigned long long totalBytesReadThisSession` the total number of bytes read in this current session. (e.g If a download is paused at 50% and then resumed, this parameter will start from 0)<p>
`unsigned long long totalBytesWritten` the total bytes read in total.<p>
`unsigned long long totalBytesExpectedToRead` the expected content size of the resource.<p>
`NSUInteger tag` the tag of the operation, very handy for managing multiple operations in a queue.
<br>
<br>
Internally this class uses a bunch of helper classes. These should not be touched by anything but the `JGDownloadOperation`.
<br>
<br>
<br>
`JGDownloadOperation` uses a metadata file to store the progress of each connection, to allow the operation to resume when failed or cancelled. The metadata file is stored at the destination path with the file extension `jgd`. The metadata file will automatically be removed when the operation finishes with success. Passing `YES` for "allowResume" in the custom `init` methods will result in a attempt to read the metadata file and resume from the last known state. If the metadata file or the partial downloaded content is not available then the download will start from the beginning. If `NO` is passed for "allowResume" then no metadata files will be written and the download will always start from the beginning. If reading the metadata file is not possible (if the file does not exist) the download will start from the beginning, overwriting any existing progress.
<br>

#####Cancellation:
`cancel` will stop the download,  synchronize the metadata file to allow resuming the download later and leave the partially downloaded file on the disk. The failure completion block will be called with an `NSURLErrorCancelled` error.<p>
`cancelAndClearFiles` will stop the download and remove the partially downloaded file as well as the metadata file from the disk. Neither the success completion block or the failure completion block will be called.



###JGOperationQueue
A NSOperationQueue subclass which is targeted at enqueuing only `JGDownloadOperation` objects.

`JGOperationQueue` handles the shared network thread used by all `JGDownloadOperation` instances. Once all operations are finished the queue exits the networking thread.
queue
Optionally, `JGOperationQueue` handles the status bar NetworkActivityIndicator, according to the number of enqueued operations and the background task used for networking requests when the app runs in the background.
```objc
	BOOL handleNetworkActivityIndicator
	BOOL handleBackgroundTask
```
Note that when setting `handleBackgroundTask` to `YES`, the App's Info.plist file needs to have "Application uses Wi-Fi" set to `YES`.

##Example
An example usage can be found in the Sample Project.

##Requirements
In order to take advantage of multipart download, the server from which you download a content needs to support the `Range` HTTP header. If it doesn't then `JGDownloadAcceleration` will simply use 1 connection to download the content conventionally.

`JGDownloadAcceleration` is built for use with ARC and weak references. This means that iOS 5 or higher is required for using `JGDownloadAcceleration`

__*If your project doesn't use ARC*: you must add the `-fobjc-arc` compiler flag to all JGDownloadAcceleration files in Target Settings > Build Phases > Compile Sources.__

##Credits
JGDownloadAcceleration was created by <a href="http://twitter.com/JonasGessner" target="_blank">Jonas Gessner</a>.
It was created for the iOS Jailbreak tweak "ProTube Extension for YouTube" and the Jailbreak App "ProTube".

##Contact
Contact me on Twitter: <a href="http://twitter.com/JonasGessner">@JonasGessner</a> or by email (found on my GitHub profile) if you have any questions!

Contributing to the Project is much appreciated!

##License

JGDownloadOperation is available under the <a href="http://opensource.org/licenses/Python-2.0" target="_blank">Python License 2.0</a>

An easy to understand explanation of the Python License 2.0 can be found <a href="http://www.tldrlegal.com/license/python-license-2.0" target="_blank">here</a>.
