#ThemeKit

ThemeKit is a lightweight Core Graphics drawing engine that takes input as JSON descriptions and outputs UIView hierarchies. It's intended to simplify using image assets and instead use CG for custom UI rendering on the iOS platform

The benefit of doing graphics rendering with Core Graphics is saving space, while image assets need to be stored on the device even if the app is not running, using CG will allow to only keep the images in memory during run-time and therefore save space when the app is suspended. Additionally, Core Graphics gives resolution independence, which is not possible with image assets. For iOS platform this means ThemeKit only needs one JSON description instead of having two separate image assets.

Greater goal is to reach something that is capable of rendering a variety of different UI elements from simple and small JSON descriptions which can be created by hand or using a simple plugin for Photoshop.

#Installation notes

Simply drag every file to your Xcode project. After this you can simply call `[[ThemeKit sharedEngine] viewHierarchyFromJSON: data]`, with the data being in the format described, which will return a completely native UIView hierarchy ready to be used anywhere.

As an example, a JSON description of a button is included, returning a small canvas with a button on it.

When used < iOS 5, ThemeKit will also need [JSONKit](http://https://github.com/johnezang/JSONKit, "JSONKit on GitHub") to function. From iOS 5 onwards, NSJSONSerialization is used