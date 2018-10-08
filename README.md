# MMDialogPopup
A UIViewController to easily show dialog popups in iOS

![](MMDialogPopupDemo.gif)

## Usage
#### Showing a DialogPopup
Create an instance of MMDialogPopViewController, and then pass your view controller (The one you want to show as a popup) in.

```
let dialogPopup = MMDialogPopupViewController(contentViewControler: yourViewController)
dialogPopup.show(onViewController: self)
```

## Author
Mario Amgad Mouris, marioamgad9@gmail.com

## Disclaimer
This view controller is heavily influnced by [Steve Barnegren's](https://github.com/SteveBarnegren/SBCardPopup) one 
