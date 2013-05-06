JGDownloadAcceleration
===================

JGDownloadAcceleration provides both a NSOperation and a NSOperationQueue subclass for easy to use multipart download (aka. download acceleration).

Multipart download uses multiple network connections to download a file from a server in chunks (each connection downloads one part of the entire content). This allows to bypass bandwidth limitations set by the server.

More info: <a href="http://en.wikipedia.org/wiki/Download_manager#Download_acceleration">Wikipedia</a>

The server needs to support the `Range` header in order to use multipart download. See <a href="#requirements">Requirements</a> for more Info.

##Getting started
##Overview
##Example
##Requirements
##Credits
JGDownloadAcceleration was created by <a href="http://twitter.com/JonasGessner" target="_blank">Jonas Gessner</a>.
It was created for the iOS Jailbreak tweak "ProTube Extension for YouTube" and the Jailbreak App "ProTube".

##License

JGDownloadOperation is available under the <a href="http://www.tldrlegal.com/l/PYTHON2">Python 2.0 license</a>
