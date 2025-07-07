# Changelog

## 1.0.3

* SDK now handles errors gracefully without crashing your app
  * No more try-catch blocks required in your code
  * Network failures and validation errors are logged but don't break functionality
  * App continues to work even when tracking operations fail
* Clear error messages when SDK is not properly initialized
  * Helps developers identify missing initialization calls
  * App remains stable even without proper SDK setup
* Better error messages and logging when debug mode is enabled

## 1.0.2

* Added offline request queue support
  * Failed requests are automatically queued
  * Queued requests are retried after successful requests
  * Queue persists between app restarts
* Removed unused meta package dependency
* Code cleanup and improvements

## 1.0.1

* Removed Customer.io push notification token registration from this SDK. For push notification setup with Customer.io, please follow their official documentation.

## 1.0.0

* Initial release
* User identification and tracking
* Event tracking with different types (custom, screen view, lifecycle)
* Device registration and push notification support
* Automatic screen tracking
* Application lifecycle tracking
* Customer.io integration
* Device attributes tracking
