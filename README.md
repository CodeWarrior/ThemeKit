#ThemeKit

ThemeKit is a lightweight Core Graphics drawing engine that takes input as JSON descriptions and outputs UIView hierarchies. It's intended to simplify using image assets and instead use CG for custom UI rendering on the iOS platform

The benefit of doing graphics rendering with Core Graphics is saving space, while image assets need to be stored on the device even if the app is not running, using CG will allow to only keep the images in memory during run-time and therefore save space when the app is suspended. Additionally, Core Graphics gives resolution independence, which is not possible with image assets. For iOS platform this means ThemeKit only needs one JSON description instead of having two separate image assets.

Greater goal is to reach something that is capable of rendering a variety of different UI elements from simple and small JSON descriptions which can be created by hand or using a simple plugin for Photoshop.

As ThemeKit is in very early development, all feedback is highly encouraged, you can find me on [twitter.com/henrinormak](http://twitter.com/henrinormak, "Twitter")

#JSON format

ThemeKit uses JSON to describe the views being rendered. The format is simple and mimics the syntax of CSS. 

##Header
<table>
<tr>
<td width=30%><code>size</code></td>
<td>Dictionary containing two keys. Size used for the outermost container UIView</td>
</tr>
<tr>
<td>| <code>width</code></td>
<td>Floating point value for the width of the frame</td>
</tr>
<tr>
<td>| <code>height</code></td>
<td>Floating point value for the height of the frame</td>
</tr>
<tr>
<td><code>subviews</code> - optional</td>
<td>Array containing descriptions of </code>subview</code>s. Although optional, it's the only way to actually include content into the view</td>
</tr>
</tr>
<tr>
<td><code>title</code> - optional</td>
<td>Short string name for the file, currently unused</td>
</tr>
<tr>
<td><code>origin</code> - optional</td>
<td>Dictionary containing two keys. If present will change the origin of the outermost frame, otherwise <code>CGPointZero</code> will be used</td>
</tr>
<tr>
<td align=lef>| <code>x</code></td>
<td>Floating point value representing X coordinate of the origin</td>
</tr>
<tr>
<td>| <code>y</code></td>
<td>Floating point value representing Y coordinate of the origin</td>
</tr>
</table>

##Subview
<table>
<tr>
<td width=30%><code>type</code></td>
<td>Type of the view, currently supported - <code>rectangle</code>, <code>ellipse</code>, <code>label</code>, <code>path</code></td>
</tr>
<tr>
<td><code>size</code></td>
<td>Dictionary containing two keys. Size of the frame for the view</td>
</tr>
<tr>
<td>| <code>width</code></td>
<td>Floating point value for the width of the frame</td>
</tr>
<tr>
<td>| <code>height</code></td>
<td>Floating point value for the height of the frame</td>
</tr>
<tr>
<td><code>origin</code> - optional</td>
<td>Dictionary containing two keys. If present will change the origin of the frame, otherwise <code>CGPointZero</code> will be used</td>
</tr>
<tr>
<td align=lef>| <code>x</code></td>
<td>Floating point value representing X coordinate of the origin</td>
</tr>
<tr>
<td align=lef>| <code>y</code></td>
<td>Floating point value representing Y coordinate of the origin</td>
</tr>
<tr>
<td><code>color</code> - optional</td>
<td>String with a hexadecimal color code (defaults to <code>#FFF</code>), <code>#</code> is optional and patterns are available, i.e <code>#29</code> == <code>#292929</code></td>
</tr>
<tr>
<td><code>drop-shadow</code> - optional</td>
<td>Dictionary describing the drop shadow for the view</td>
</tr>
<tr>
<td>| <code>offset</code></td>
<td>Dictionary containing two keys</td>
</tr>
<tr>
<td>| | <code>x</code></td>
<td>Offset on the X axis for the drop shadow, can be negative</td>
</tr>
<tr>
<td>| | <code>y</code></td>
<td>Offset on the Y axis for the drop shadow, can be negative</td>
</tr>
<tr>
<td>| <code>color</code> - optional</td>
<td>String with a hexadecimal color code (defaults to <code>#000</code>), <code>#</code> is optional and patterns are available, i.e <code>#29</code> == <code>#292929</code>
</tr>
<tr>
<td>| <code>alpha</code> - optional</td>
<td>Alpha value of the shadow, ranges from 0.0 to 1.0, defaults to 1.0</td>
</tr>
<tr>
<td>| <code>blur</code> - optional</td>
<td>Blur value for the shadow, defaults to 0.0. Not available for <code>label</code></td>
</tr>
<tr>
<td>| <code>blend-mode</code> - optional</td>
<td>Blend mode of the shadow, defaults to <code>normal</code>. Available <code>normal</code>, <code>overlay</code>, <code>multiply</code>, <code>softlight</code>. Not available for <code>label</code></td>
</tr>
<tr>
<td><code>inner-shadow</code></td>
<td>Dictionary describing the inner shadow of the view. Not available for <code>label</code></td>
</tr>
<tr>
<td>| <code>offset</code></td>
<td>Dictionary containing two keys</td>
</tr>
<tr>
<td>| | <code>x</code></td>
<td>Offset on the X axis for the drop shadow, can be negative</td>
</tr>
<tr>
<td>| | <code>y</code></td>
<td>Offset on the Y axis for the drop shadow, can be negative</td>
</tr>
<tr>
<td>| <code>color</code> - optional</td>
<td>String with a hexadecimal color code (defaults to <code>#000</code>), <code>#</code> is optional and patterns are available, i.e <code>#29</code> == <code>#292929</code>
</tr>
<tr>
<td>| <code>alpha</code> - optional</td>
<td>Alpha value of the shadow, ranges from 0.0 to 1.0, defaults to 1.0</td>
</tr>
<tr>
<tr>
<td>| <code>blend-mode</code> - optional</td>
<td>Blend mode of the shadow, defaults to <code>normal</code>. Available <code>normal</code>, <code>overlay</code>, <code>multiply</code>, <code>softlight</code>. Not available for <code>label</code></td>
</tr>
<tr>
<td><code>corner-radius</code></td>
<td>Only available for <code>rectangle</code>. Can either be a single value or an array of up to 4 floating point values</td>
</tr>
<tr>
<td><code>gradient-fill</code></td>
<td>Dictionary describing a gradient overlay. Currently only linear from top-left to bottom-left of the view</td>
</tr>
<tr>
<td>| <code>gradient-colors</code></td>
<td>Array of hexadecimal color codes, minimum of 2</td>
</tr>
<tr>
<td>| <code>gradient-positions</code></td>
<td>Array of unit values describing the locations of the colors in the gradient, has to have a value for each color</td>
</tr>
<tr>
<td>| <code>blend-mode</code> - optional</td>
<td>Blend mode of the gradient, defaults to <code>normal</code>. Available <code>normal</code>, <code>overlay</code>, <code>multiply</code>, <code>softlight</code>. Not available for <code>label</code></td>
</tr>
<tr>
<td>| <code>alpha</code> - optional</td>
<td>Alpha value of the gradient, ranges from 0.0 to 1.0, defaults to 1.0</td>
</tr>
<tr>
<td><code>inner-stroke</code>/<code>outer-stroke</code></td>
<td>Dictionary description of the inner-stroke/outer-stroke. Both can be applied to the same view. Not available for <code>label</code></td>
</tr>
<tr>
<td>| <code>width</code></td>
<td>Width of the stroke</td>
</tr>
<tr>
<td>| <code>color</code> - optional</td>
<td>String with a hexadecimal color code (defaults to <code>#000</code>), <code>#</code> is optional and patterns are available, i.e <code>#29</code> == <code>#292929</code>
</tr>
<tr>
<td>| <code>alpha</code> - optional</td>
<td>Alpha value of the shadow, ranges from 0.0 to 1.0, defaults to 1.0</td>
</tr>
<tr>
<tr>
<td>| <code>blend-mode</code> - optional</td>
<td>Blend mode of the shadow, defaults to <code>normal</code>. Available <code>normal</code>, <code>overlay</code>, <code>multiply</code>, <code>softlight</code>. Not available for <code>label</code></td>
</tr>
<tr>
<td><code>description</code> - <code>path</code> only</td>
<td>Path description in SVG syntax, for example <code>M150 0 L75 200 L225 200 Z</code> draws a triangle</td>
</tr>
<tr>
<td><code>subviews</code> - optional</td>
<td>Array containing descriptions of </code>subview</code>s. UIView hierarchy will reflect this<td>
</tr>
</table>

#Installation notes

Simply drag every file to your Xcode project. After this you can simply call `[[ThemeKit sharedEngine] viewHierarchyFromJSON: data]`, with the data being in the format described, which will return a completely native UIView hierarchy ready to be used anywhere.

As an example, a JSON description of a button is included, returning a small canvas with a button on it.

Example of the button rendered, when compared with an .png image of the same button. Image is on the bottom.
![ThemeKit vs UIImage](http://f.cl.ly/items/420G3b1x1Q0f212E3u16/template.png)

When used < iOS 5, ThemeKit will also need [JSONKit](http://https://github.com/johnezang/JSONKit, "JSONKit on GitHub") to function. From iOS 5 onwards, NSJSONSerialization is used